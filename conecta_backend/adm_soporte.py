# ========================================================
# ARCHIVO: adm_soporte.py (VERSIÓN DEFINITIVA Y BLINDADA)
# PROPÓSITO: Chat en vivo, Tickets de Soporte, Alertas y Publicidad
# ========================================================
from fastapi import APIRouter, UploadFile, File
from pydantic import BaseModel
import sqlite3
import os
import shutil
import uuid
from datetime import datetime, timedelta

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
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            leido INTEGER DEFAULT 0
        )
    """)
    try: cursor.execute("ALTER TABLE mensajes_chat ADD COLUMN leido INTEGER DEFAULT 0")
    except Exception: pass

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
    rol: str = "cliente"
    id_pedido: int = 0
    mensaje: str
    evidencia: str = ""

# ========================================================
# 1. TUBERÍAS DEL CHAT Y MENSAJERÍA
# ========================================================
@router.post("/api/chat/enviar_mensaje")
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
    return {"status": "ok", "mensaje": "Mensaje enviado y caso actualizado de forma permanente"}

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
    return {"status": "ok", "mensaje": "Ticket abierto exitosamente en disco."}

@router.get("/api/chat/historial/{id_pedido}")
def obtener_historial_chat(id_pedido: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE mensajes_chat SET leido = 1 WHERE id_pedido = ? AND remitente != 'Admin Central'", (id_pedido,))
    conexion.commit()
    
    cursor.execute("SELECT id_mensaje, remitente, mensaje, evidencia, fecha, canal FROM mensajes_chat WHERE id_pedido = ? ORDER BY id_mensaje ASC", (id_pedido,))
    filas = cursor.fetchall()
    
    mensajes = [{"id_mensaje": m[0], "remitente": m[1], "mensaje": m[2], "evidencia": m[3], "fecha": m[4], "canal": m[5]} for m in filas]
    conexion.close()
    return {"status": "ok", "mensajes": mensajes}

@router.delete("/api/chat/borrar_mensaje/{id_mensaje}")
def borrar_un_mensaje(id_mensaje: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM mensajes_chat WHERE id_mensaje = ?", (id_mensaje,))
    if cursor.rowcount == 0:
        conexion.rollback(); conexion.close()
        return {"status": "error", "mensaje": "Mensaje no encontrado."}
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "Mensaje borrado permanentemente"}

@router.delete("/api/chat/borrar_todo/{id_pedido}")
def borrar_todo_chat(id_pedido: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM mensajes_chat WHERE id_pedido = ?", (id_pedido,))
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "Chat borrado permanentemente"}

# ========================================================
# 2. PANEL DE ADMINISTRACIÓN Y ELIMINACIÓN NUCLEAR
# ========================================================
@router.get("/api/admin/tickets_soporte")
def ver_quejas_admin():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT 
            s.id_soporte, s.id_pedido, COALESCE(s.rol, 'cliente'), s.mensaje, s.fecha, s.estado,
            COALESCE(p.codigo_rastreo, 'CP-0000'), COALESCE(u_cliente.nombre, 'Cliente Desconocido'),
            COALESCE(c_local.nombre_local, 'Sin Comercio'), COALESCE(u_motorista.nombre, 'Sin Motorista'),
            COALESCE(u_cliente.telefono, c_local.telefono, u_motorista.telefono, '7777-7777') as telefono,
            (SELECT COUNT(*) FROM mensajes_chat m WHERE m.id_pedido = s.id_pedido AND m.leido = 0 AND m.remitente != 'Admin Central') as mensajes_nuevos,
            (SELECT MAX(fecha) FROM mensajes_chat m WHERE m.id_pedido = s.id_pedido) as ultima_actividad
        FROM soporte s
        LEFT JOIN pedidos p ON s.id_pedido = p.id_pedido
        LEFT JOIN usuarios u_cliente ON p.id_cliente = u_cliente.id_usuario
        LEFT JOIN comercios c_local ON p.id_comercio = c_local.id_comercio
        LEFT JOIN usuarios u_motorista ON p.id_repartidor = u_motorista.id_usuario
        GROUP BY s.id_pedido, s.rol
        ORDER BY COALESCE(ultima_actividad, s.fecha) DESC
    """)
    filas = cursor.fetchall()
    conexion.close()
    
    return [{
        "id_ticket": r[0], "id_pedido": r[1], "tipo_usuario": r[2], "queja": r[3],
        "fecha": r[4], "estado": r[5], "codigo_rastreo": r[6], "nombre_cliente": r[7],
        "nombre_comercio": r[8], "nombre_repartidor": r[9], "telefono": r[10],
        "mensajes_nuevos": r[11], "ultima_actividad": r[12]
    } for r in filas]

@router.post("/api/admin/resolver_ticket/{id_ticket}")
def resolver_ticket(id_ticket: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE soporte SET estado = 'resuelto' WHERE id_soporte = ?", (id_ticket,))
    if cursor.rowcount == 0:
        conexion.rollback(); conexion.close()
        return {"status": "error", "mensaje": "Ticket no encontrado."}
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "Queja marcada como resuelta permanentemente."}

# 🔥 BLINDAJE NUCLEAR: Borra de raíz garantizando que desaparezca para todos
@router.post("/api/admin/eliminar_ticket/{id_ticket}")
def eliminar_ticket_admin(id_ticket: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    try:
        cursor.execute("SELECT id_pedido FROM soporte WHERE id_soporte = ?", (id_ticket,))
        fila = cursor.fetchone()
        
        if fila:
            id_pedido = fila[0]
            cursor.execute("DELETE FROM mensajes_chat WHERE id_pedido = ?", (id_pedido,))
            cursor.execute("DELETE FROM soporte WHERE id_soporte = ?", (id_ticket,))
            conexion.commit()
            return {"status": "ok", "mensaje": "Chat y ticket eliminados permanentemente por completo."}
        else:
            return {"status": "error", "mensaje": "Ticket no encontrado en la base de datos."}
    except Exception as e:
        conexion.rollback()
        return {"status": "error", "mensaje": f"Error del sistema: {str(e)}"}
    finally:
        conexion.close()

# ========================================================
# 3. NOTIFICACIONES INTELIGENTES (Ignoran fantasmas)
# ========================================================
@router.get("/api/admin/alertas_dashboard")
def alertas_dashboard():
    try:
        conexion = sqlite3.connect(DB_PATH)
        cursor = conexion.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM pedidos WHERE estado NOT IN ('entregado', 'cancelado', 'archivado')")
        pedidos_activos = cursor.fetchone()[0]
        
        cursor.execute("""
            SELECT COUNT(DISTINCT m.id_pedido) 
            FROM mensajes_chat m
            JOIN soporte s ON m.id_pedido = s.id_pedido
            WHERE m.leido = 0 AND m.remitente != 'Admin Central' AND s.estado = 'abierto'
        """)
        tickets_abiertos = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM usuarios WHERE estado = 'pendiente'")
        usuarios_pendientes = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM comercios WHERE estado = 'pendiente'")
        comercios_pendientes = cursor.fetchone()[0]
        
        conexion.close()
        return {
            "pedidos_activos": pedidos_activos, 
            "cuentas_pendientes": usuarios_pendientes + comercios_pendientes, 
            "tickets_abiertos": tickets_abiertos
        }
    except Exception:
        return {"pedidos_activos": 0, "cuentas_pendientes": 0, "tickets_abiertos": 0}

@router.get("/api/cliente/notificaciones_chat")
def notificaciones_cliente():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT COUNT(*) 
        FROM mensajes_chat m
        JOIN soporte s ON m.id_pedido = s.id_pedido
        WHERE m.leido = 0 AND m.remitente = 'Admin Central' AND s.estado = 'abierto'
    """)
    count = cursor.fetchone()[0]
    conexion.close()
    return {"sin_leer": count}

# ========================================================
# 4. REGLA DE 3 HORAS Y ACCESO DEL CLIENTE
# ========================================================
@router.get("/api/cliente/validar_soporte/{codigo}")
def validar_rastreo_cliente(codigo: str):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT id_pedido, estado, COALESCE(fecha_entrega, fecha) 
        FROM pedidos WHERE codigo_rastreo = ?
    """, (codigo,))
    pedido = cursor.fetchone()
    
    if not pedido:
        conexion.close()
        return {"status": "error", "mensaje": "Ese código de rastreo no existe en nuestra base de datos."}
        
    id_pedido, estado, fecha_ref = pedido
    
    cursor.execute("SELECT id_soporte FROM soporte WHERE id_pedido = ? AND estado = 'abierto'", (id_pedido,))
    if cursor.fetchone():
        conexion.close()
        return {"status": "ok", "id_pedido": id_pedido, "mensaje": "Redirigiendo a tu caso activo..."}
        
    if estado in ['entregado', 'cancelado', 'archivado']:
        try:
            fecha_dt = datetime.strptime(fecha_ref, "%Y-%m-%d %H:%M:%S")
            limite_tiempo = fecha_dt + timedelta(hours=3)
            
            if datetime.now() > limite_tiempo:
                conexion.close()
                return {
                    "status": "error", 
                    "mensaje": "El tiempo máximo de 3 horas para reportar un inconveniente con este pedido ya expiró."
                }
        except Exception:
            pass 
            
    conexion.close()
    return {"status": "ok", "id_pedido": id_pedido, "mensaje": "Código válido. Abriendo nuevo chat..."}

@router.get("/api/cliente/chat_activo/{id_cliente}")
def chequear_chat_activo(id_cliente: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT s.id_pedido 
        FROM soporte s
        JOIN pedidos p ON s.id_pedido = p.id_pedido
        WHERE p.id_cliente = ? AND s.estado = 'abierto'
        LIMIT 1
    """, (id_cliente,))
    chat = cursor.fetchone()
    conexion.close()
    
    if chat:
        return {"status": "ok", "tiene_chat": True, "id_pedido": chat[0]}
    return {"status": "ok", "tiene_chat": False}

# ========================================================
# 5. EXTRAS Y ARCHIVOS MULTIMEDIA
# ========================================================
@router.get("/api/obtener_anuncio")
def obtener_anuncio():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT mensaje, imagen_url FROM anuncios_globales ORDER BY id DESC LIMIT 1")
    anuncio = cursor.fetchone()
    conexion.close()
    if anuncio: return {"status": "ok", "hay_anuncio": True, "mensaje": anuncio[0], "imagen_url": anuncio[1]}
    return {"status": "ok", "hay_anuncio": False}

@router.get("/api/admin/clientes_activos")
def clientes_activos_admin():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT id_usuario, COALESCE(nombre, 'Cliente'), 
               COALESCE(telefono, 'Sin teléfono'), COALESCE(correo, 'Sin correo'),
               COALESCE(foto_perfil, 'Sin foto'), COALESCE(estado, 'activo')
        FROM usuarios WHERE LOWER(rol) = 'cliente'
    """)
    filas = cursor.fetchall()
    
    cursor.execute("SELECT DISTINCT id_cliente FROM pedidos WHERE estado NOT IN ('entregado', 'cancelado', 'archivado')")
    con_pedido_activo = {row[0] for row in cursor.fetchall()}
    conexion.close()
    
    return [{
        "id_usuario": r[0], "nombre": r[1], "telefono": r[2], "correo": r[3],
        "foto": r[4], "activo_buscando": (r[0] in con_pedido_activo or r[5] == 'activo')
    } for r in filas]

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

    # ========================================================
# ENDPOINT PARA EXTRAER EL CÓDIGO DE RASTREO REAL EN EL CHAT
# ========================================================
@router.get("/api/chat/codigo_por_pedido/{id_pedido}")
def obtener_codigo_por_pedido(id_pedido: int):
    if id_pedido < 0:
        return {"status": "ok", "codigo_rastreo": "Soporte General"}
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT COALESCE(codigo_rastreo, 'CP-0000') FROM pedidos WHERE id_pedido = ?", (id_pedido,))
    fila = cursor.fetchone()
    conexion.close()
    
    if fila:
        return {"status": "ok", "codigo_rastreo": fila[0]}
    return {"status": "ok", "codigo_rastreo": f"Pedido #{id_pedido}"}