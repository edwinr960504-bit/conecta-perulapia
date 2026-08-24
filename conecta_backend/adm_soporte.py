# ========================================================
# ARCHIVO: adm_soporte.py (VERSIÓN MAESTRA BLINDADA)
# PROPÓSITO: Chat en vivo, Tickets de Soporte, Alertas y Publicidad
# ========================================================
from fastapi import APIRouter, UploadFile, File
from pydantic import BaseModel
import sqlite3
import os
import shutil
import uuid

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

# --- MOTOR DE AUTO-REPARACIÓN DE LAS TABLAS ---
def asegurar_tablas_soporte():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS mensajes_chat (
            id_mensaje INTEGER PRIMARY KEY AUTOINCREMENT,
            id_pedido INTEGER,
            remitente TEXT, 
            mensaje TEXT,
            evidencia TEXT DEFAULT '', 
            canal TEXT DEFAULT 'admin_cliente',
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS soporte (
            id_soporte INTEGER PRIMARY KEY AUTOINCREMENT,
            id_usuario INTEGER,
            rol TEXT DEFAULT 'cliente',
            id_pedido INTEGER,
            mensaje TEXT,
            evidencia TEXT DEFAULT '',
            estado TEXT DEFAULT 'abierto',
            respuesta_admin TEXT DEFAULT '',
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS anuncios_globales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mensaje TEXT,
            imagen_url TEXT
        )
    """)
    conexion.commit()
    conexion.close()

asegurar_tablas_soporte()

# --- MODELOS DE DATOS ---
class MensajeChat(BaseModel):
    id_pedido: int
    remitente: str
    mensaje: str
    evidencia: str = ""
    canal: str = "admin_cliente"

class TicketSoporte(BaseModel):
    id_usuario: int = 1
    rol: str = "cliente" # 'cliente', 'repartidor', 'local'
    id_pedido: int = 0
    mensaje: str
    evidencia: str = ""

# ========================================================
# 1. ENDPOINTS DE CHAT (LÓGICA DE UN CASO ÚNICO POR PEDIDO)
# ========================================================
@router.post("/api/chat/enviar_mensaje")
@router.post("/enviar_mensaje_chat/")
def enviar_mensaje(req: MensajeChat):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        INSERT INTO mensajes_chat (id_pedido, remitente, mensaje, evidencia, canal) 
        VALUES (?, ?, ?, ?, ?)
    """, (req.id_pedido, req.remitente, req.mensaje, req.evidencia, req.canal))
    
    cursor.execute("SELECT id_soporte FROM soporte WHERE id_pedido = ?", (req.id_pedido,))
    ticket = cursor.fetchone()
    
    if ticket:
        cursor.execute("""
            UPDATE soporte SET mensaje = ?, fecha = CURRENT_TIMESTAMP, estado = 'abierto' WHERE id_soporte = ?
        """, (req.mensaje, ticket[0]))
    else:
        cursor.execute("""
            INSERT INTO soporte (id_usuario, rol, id_pedido, mensaje, evidencia, estado) 
            VALUES (1, 'cliente', ?, ?, ?, 'abierto')
        """, (req.id_pedido, req.mensaje, req.evidencia))
    
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Mensaje enviado y caso actualizado"}

@router.post("/enviar_soporte/")
@router.post("/api/enviar_soporte")
def enviar_soporte(req: TicketSoporte):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        INSERT INTO soporte (id_usuario, rol, id_pedido, mensaje, evidencia, estado) 
        VALUES (?, ?, ?, ?, ?, 'abierto')
    """, (req.id_usuario, req.rol, req.id_pedido, req.mensaje, req.evidencia))
    
    cursor.execute("""
        INSERT INTO mensajes_chat (id_pedido, remitente, mensaje, evidencia, canal) 
        VALUES (?, ?, ?, ?, 'admin_cliente')
    """, (req.id_pedido, req.rol.capitalize(), req.mensaje, req.evidencia))
    
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Ticket abierto exitosamente."}

@router.get("/api/chat/historial/{id_pedido}/{canal}")
@router.get("/api/chat/historial/{id_pedido}")
def obtener_historial_chat(id_pedido: int, canal: str = "admin_cliente"):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT remitente, mensaje, evidencia, fecha, canal FROM mensajes_chat WHERE id_pedido = ? ORDER BY id_mensaje ASC", (id_pedido,))
    filas = cursor.fetchall()
    
    if not filas:
        cursor.execute("SELECT 'Cliente', mensaje, evidencia, fecha, 'admin_cliente' FROM soporte WHERE id_pedido = ?", (id_pedido,))
        filas = cursor.fetchall()

    mensajes = [{"remitente": m[0], "mensaje": m[1], "evidencia": m[2], "fecha": m[3], "canal": m[4]} for m in filas]
    conexion.close()
    return {"status": "ok", "mensajes": mensajes}

# ========================================================
# 2. PANEL DE ADMINISTRACIÓN (RADIOGRAFÍA EXACTA CON ROL)
# ========================================================
@router.get("/api/admin/tickets_soporte")
@router.get("/api/soporte/activos")
def ver_quejas_admin():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    # Consulta maestra robusta libre de errores de columnas faltantes
    cursor.execute("""
        SELECT 
            MAX(s.id_soporte), 
            s.id_pedido, 
            COALESCE(s.rol, 'cliente'), 
            s.mensaje, 
            s.fecha, 
            s.estado,
            COALESCE(p.codigo_rastreo, 'CP-0000'),
            COALESCE(u_cliente.nombre, 'Cliente Desconocido'),
            COALESCE(c_local.nombre_local, 'Sin Comercio'),
            COALESCE(u_motorista.nombre, 'Sin Motorista'),
            '' as foto_perfil
        FROM soporte s
        LEFT JOIN pedidos p ON s.id_pedido = p.id_pedido
        LEFT JOIN usuarios u_cliente ON p.id_cliente = u_cliente.id_usuario
        LEFT JOIN comercios c_local ON p.id_comercio = c_local.id_comercio
        LEFT JOIN usuarios u_motorista ON p.id_repartidor = u_motorista.id_usuario
        GROUP BY s.id_pedido, s.rol
        ORDER BY s.estado ASC, MAX(s.id_soporte) DESC
    """)
    filas = cursor.fetchall()
    conexion.close()
    
    return [{
        "id_ticket": r[0],
        "id_pedido": r[1],
        "tipo_usuario": r[2], # Devuelve estrictamente 'cliente', 'repartidor' o 'local'
        "queja": r[3],
        "fecha": r[4],
        "estado": r[5],
        "codigo_rastreo": r[6],
        "nombre_cliente": r[7],
        "nombre_comercio": r[8],
        "nombre_repartidor": r[9],
        "foto_perfil": r[10]
    } for r in filas]

@router.post("/api/admin/resolver_ticket/{id_ticket}")
def resolver_ticket(id_ticket: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE soporte SET estado = 'resuelto' WHERE id_soporte = ?", (id_ticket,))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Queja marcada como resuelta exitosamente."}

# ========================================================
# 3. NOTIFICACIONES GLOBALES (CAMPANITAS Y ALERTAS)
# ========================================================
@router.get("/api/admin/alertas_pendientes")
def alertas_pendientes():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT COUNT(DISTINCT id_pedido) FROM soporte WHERE estado = 'abierto'")
    tickets_abiertos = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM usuarios WHERE estado = 'pendiente'")
    usuarios_pendientes = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM comercios WHERE estado = 'pendiente'")
    comercios_pendientes = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM pedidos WHERE estado NOT IN ('entregado', 'cancelado', 'archivado')")
    pedidos_activos = cursor.fetchone()[0]
    
    conexion.close()
    return {
        "soporte": tickets_abiertos,
        "aprobaciones": usuarios_pendientes + comercios_pendientes,
        "radar": pedidos_activos
    }

# ========================================================
# 4. DISTRIBUIDOR DE PUBLICIDAD PARA EL CONSUMIDOR
# ========================================================
@router.get("/api/obtener_anuncio")
@router.get("/api/obtener_anuncio/")
def obtener_anuncio():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT mensaje, imagen_url FROM anuncios_globales ORDER BY id DESC LIMIT 1")
    anuncio = cursor.fetchone()
    conexion.close()
    
    if anuncio:
        return {"status": "ok", "hay_anuncio": True, "mensaje": anuncio[0], "imagen_url": anuncio[1]}
    return {"status": "ok", "hay_anuncio": False}

# ========================================================
# 5. SEGUIMIENTO DE TICKETS DEL CONSUMIDOR
# ========================================================
@router.get("/api/cliente/mis_tickets/{id_cliente}")
def mis_tickets_cliente(id_cliente: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT 
            MAX(s.id_soporte), 
            p.id_pedido, 
            s.estado, 
            COALESCE(p.codigo_rastreo, 'CP-0000')
        FROM soporte s
        JOIN pedidos p ON s.id_pedido = p.id_pedido
        WHERE p.id_cliente = ?
        GROUP BY p.id_pedido
        ORDER BY s.estado ASC, MAX(s.id_soporte) DESC
    """, (id_cliente,))
    filas = cursor.fetchall()
    conexion.close()
    
    return [{
        "id_ticket": r[0],
        "id_pedido": r[1],
        "estado": r[2],
        "codigo_rastreo": r[3]
    } for r in filas]

# ========================================================
# 6. LIMPIEZA DE CASOS RESUELTOS
# ========================================================
@router.post("/api/cliente/borrar_ticket/{id_pedido}")
def borrar_ticket_cliente(id_pedido: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("DELETE FROM soporte WHERE id_pedido = ? AND estado = 'resuelto'", (id_pedido,))
    cursor.execute("DELETE FROM mensajes_chat WHERE id_pedido = ?", (id_pedido,))
    
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Caso resuelto eliminado exitosamente"}

# ========================================================
# 7. VALIDACIÓN DE CÓDIGO DE RASTREO
# ========================================================
@router.get("/api/cliente/validar_rastreo/{codigo}")
def validar_rastreo_cliente(codigo: str):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT id_pedido FROM pedidos WHERE codigo_rastreo = ?", (codigo,))
    fila = cursor.fetchone()
    conexion.close()
    
    if fila:
        return {"status": "ok", "id_pedido": fila[0]}
    return {"status": "error", "mensaje": "No se encontró ningún pedido con ese rastreo."}

# ========================================================
# 8. HISTORIAL DE PEDIDOS CON DETALLE DE RASTREO
# ========================================================
@router.get("/api/cliente/historial_detallado/{id_cliente}")
def historial_detallado_cliente(id_cliente: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT 
            p.id_pedido, 
            COALESCE(p.codigo_rastreo, 'CP-0000'), 
            p.estado, 
            p.fecha, 
            COALESCE(c.nombre_local, 'Comercio Local'), 
            p.total
        FROM pedidos p
        LEFT JOIN comercios c ON p.id_comercio = c.id_comercio
        WHERE p.id_cliente = ?
        ORDER BY p.id_pedido DESC
    """, (id_cliente,))
    
    filas = cursor.fetchall()
    conexion.close()
    
    return [{
        "id_pedido": r[0],
        "codigo_rastreo": r[1],
        "estado": r[2],
        "fecha": r[3],
        "nombre_local": r[4],
        "total": r[5]
    } for r in filas]

# ========================================================
# 9. SUBIDA DE MULTIMEDIA (FOTOS Y AUDIOS DEL CHAT)
# ========================================================
MEDIA_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "chat_media")
os.makedirs(MEDIA_PATH, exist_ok=True)

@router.post("/api/chat/subir_evidencia")
async def subir_evidencia(archivo: UploadFile = File(...)):
    try:
        extension = archivo.filename.split(".")[-1]
        nuevo_nombre = f"{uuid.uuid4()}.{extension}"
        ruta_guardado = os.path.join(MEDIA_PATH, nuevo_nombre)
        
        with open(ruta_guardado, "wb") as buffer:
            shutil.copyfileobj(archivo.file, buffer)
            
        return {"status": "ok", "ruta": f"/static/chat_media/{nuevo_nombre}"}
    except Exception as e:
        return {"status": "error", "mensaje": str(e)}