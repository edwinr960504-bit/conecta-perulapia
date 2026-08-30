# ========================================================
# ARCHIVO COMPLETO: tuberias_admin.py (PODER TOTAL Y FOTOS DE LOCALES)
# ========================================================
from fastapi import APIRouter
from pydantic import BaseModel
import sqlite3
import os

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

# --- MODELOS DE DATOS ---
class DecisionJuez(BaseModel):
    id_objetivo: int
    nuevo_estado: str

class CancelarReq(BaseModel):
    id_pedido: int

class BorrarReq(BaseModel):
    id_objetivo: int

class AnuncioReq(BaseModel):
    mensaje: str
    imagen_url: str = ""

class AccionMasiva(BaseModel):
    estado: str # 'activo' o 'cerrado'

# Función auxiliar para dejar rastro en la caja negra (Auditoría)
def registrar_auditoria(accion: str):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS auditoria_admin (
            id_log INTEGER PRIMARY KEY AUTOINCREMENT,
            accion TEXT,
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("INSERT INTO auditoria_admin (accion) VALUES (?)", (accion,))
    conexion.commit()
    conexion.close()

# ========================================================
# 1. RADAR Y DESPACHO EN VIVO
# ========================================================
@router.get("/api/admin/radar_despacho")
def radar_despacho():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT 
            p.id_pedido, p.descripcion, p.estado, p.total_pago, p.distancia_km,
            COALESCE(u_rep.nombre, 'Esperando Motorista') AS repartidor,
            c.nombre_local, p.latitud_repartidor, p.longitud_repartidor
        FROM pedidos p
        JOIN comercios c ON p.id_comercio = c.id_comercio
        LEFT JOIN usuarios u_rep ON p.id_repartidor = u_rep.id_usuario
        WHERE p.estado IN ('pendiente', 'preparacion', 'listo_recoleccion', 'asignado', 'en_camino')
        ORDER BY p.id_pedido ASC
    """)
    rutas = cursor.fetchall()
    conexion.close()
    
    return [{
        "id_pedido": r[0], "descripcion": r[1], "estado": r[2], 
        "total": r[3], "distancia": r[4], "repartidor": r[5], 
        "comercio": r[6], "lat": r[7], "lon": r[8]
    } for r in rutas]

# ========================================================
# 2. FINANZAS Y CORTE DE CAJA
# ========================================================
@router.get("/api/admin/finanzas_caja")
def finanzas_caja():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT 
            COALESCE(SUM(total_pago), 0.0), 
            COALESCE(SUM(comision_app), 0.0), 
            COALESCE(SUM(tarifa_envio), 0.0),
            COUNT(id_pedido)
        FROM pedidos 
        WHERE estado = 'entregado'
    """)
    corte = cursor.fetchone()
    conexion.close()
    
    return {
        "status": "ok",
        "volumen_total_ventas": round(corte[0], 2),
        "ganancia_comisiones_app": round(corte[1], 2),
        "pago_total_motoristas": round(corte[2], 2),
        "pedidos_completados": corte[3]
    }

# ========================================================
# 3. EL JUEZ (Aprobaciones de Cuentas con Auditoría)
# ========================================================
@router.post("/api/admin/juez_comercio")
def juzgar_comercio(d: DecisionJuez):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE comercios SET estado = ? WHERE id_comercio = ?", (d.nuevo_estado, d.id_objetivo))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"Comercio ID {d.id_objetivo} cambiado a estado: {d.nuevo_estado}")
    return {"mensaje": "Estado actualizado"}

@router.post("/api/admin/juez_repartidor")
def juzgar_repartidor(d: DecisionJuez):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE usuarios SET estado = ? WHERE id_usuario = ?", (d.nuevo_estado, d.id_objetivo))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"Usuario ID {d.id_objetivo} cambiado a estado: {d.nuevo_estado}")
    return {"mensaje": "Estado actualizado"}

# ========================================================
# 4. INCINERADOR DE PEDIDOS
# ========================================================
@router.post("/api/cancelar_pedido")
def forzar_cancelacion(req: CancelarReq):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM pedidos WHERE id_pedido = ?", (req.id_pedido,))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"Pedido fantasma #{req.id_pedido} eliminado de raíz.")
    return {"status": "ok", "mensaje": "Pedido eliminado de raíz."}

# ========================================================
# 5. DIRECTORIO MAESTRO Y CONTROL ABSOLUTO
# ========================================================
@router.get("/api/admin/metricas_globales")
def metricas_globales():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    # Contamos clientes
    cursor.execute("SELECT COUNT(*) FROM usuarios WHERE LOWER(rol) = 'cliente'")
    clientes = cursor.fetchone()[0]
    
    # Contamos repartidores o motoristas[cite: 6]
    cursor.execute("SELECT COUNT(*) FROM usuarios WHERE LOWER(rol) IN ('repartidor', 'motorista')")
    repartidores = cursor.fetchone()[0]
    
    # Cuenta absolutamente todos los comercios sin importar el estado[cite: 6]
    cursor.execute("SELECT COUNT(*) FROM comercios")
    comercios = cursor.fetchone()[0]
    
    conexion.close()
    return {
        "clientes": clientes, 
        "repartidores": repartidores, 
        "comercios": comercios
    }

@router.get("/api/admin/directorio_completo")
def directorio_completo():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT id_usuario, COALESCE(nombre, 'Sin Nombre'), COALESCE(rol, 'cliente'), 
               COALESCE(estado, 'pendiente'), COALESCE(telefono, 'Sin Tel'), 
               COALESCE(foto_perfil, 'Sin foto'), COALESCE(correo, 'Sin correo'),
               COALESCE(direccion, 'Sin dirección'), COALESCE(dui, 'N/A'),
               COALESCE(tipo_vehiculo, 'N/A'), COALESCE(licencia, 'N/A'), COALESCE(tarjeta_circulacion, 'N/A')
        FROM usuarios ORDER BY id_usuario DESC
    """)
    usuarios = [{
        "id": r[0], "nombre": r[1], "rol": r[2], "estado": r[3], "telefono": r[4], 
        "foto": r[5], "correo": r[6], "direccion": r[7], "dui": r[8],
        "vehiculo": r[9], "licencia": r[10], "placa": r[11], "tipo": "usuario"
    } for r in cursor.fetchall()]
    
    cursor.execute("""
        SELECT id_comercio, COALESCE(nombre_local, 'Local'), 'comercio', 
               COALESCE(estado, 'pendiente'), COALESCE(telefono, 'Sin Tel'), 
               COALESCE(logo, 'Sin logo'), COALESCE(correo, 'Sin correo'),
               COALESCE(direccion, 'Sin dirección'), COALESCE(tipo_plan, 'N/A')
        FROM comercios ORDER BY id_comercio DESC
    """)
    comercios = [{
        "id": r[0], "nombre": r[1], "rol": "comercio", "estado": r[3], "telefono": r[4], 
        "foto": r[5], "correo": r[6], "direccion": r[7], "dui": "N/A",
        "vehiculo": "N/A", "licencia": "N/A", "placa": "N/A", "plan": r[8], "tipo": "comercio"
    } for r in cursor.fetchall()]
    conexion.close()
    
    return {"directorio": usuarios + comercios}

@router.post("/api/admin/eliminar_usuario")
def eliminar_usuario(req: BorrarReq):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM usuarios WHERE id_usuario = ?", (req.id_objetivo,))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"Usuario ID {req.id_objetivo} eliminado permanentemente.")
    return {"status": "ok"}

@router.post("/api/admin/eliminar_comercio")
def eliminar_comercio(req: BorrarReq):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM comercios WHERE id_comercio = ?", (req.id_objetivo,))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"Comercio ID {req.id_objetivo} eliminado permanentemente.")
    return {"status": "ok"}

# ========================================================
# 🔥 6. CONTROL MASIVO DE LOCALES (Para pruebas rápidas)
# ========================================================
@router.post("/api/admin/estado_masivo_comercios")
def estado_masivo_comercios(datos: AccionMasiva):
    nuevo_estado = "activo" if datos.estado.lower() == "activo" else "cerrado"
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE comercios SET estado = ?", (nuevo_estado,))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"ADMIN DICTATORIAL: Todos los comercios cambiados masivamente a estado: {nuevo_estado}")
    return {"status": "ok", "mensaje": f"Todos los negocios ahora están {nuevo_estado}s."}

# ========================================================
# 7. NUEVAS TUBERÍAS DE PODER TOTAL (AUDITORÍA Y DIFUSIÓN)
# ========================================================
@router.get("/api/admin/auditoria_logs")
def ver_auditoria():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT id_log, accion, fecha FROM auditoria_admin ORDER BY id_log DESC LIMIT 50")
    logs = [{"id": r[0], "accion": r[1], "fecha": r[2]} for r in cursor.fetchall()]
    conexion.close()
    return {"status": "ok", "logs": logs}

@router.post("/api/admin/publicar_anuncio")
def publicar_anuncio(anuncio: AnuncioReq):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS anuncios_globales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mensaje TEXT,
            imagen_url TEXT
        )
    """)
    cursor.execute("DELETE FROM anuncios_globales")
    cursor.execute("INSERT INTO anuncios_globales (mensaje, imagen_url) VALUES (?, ?)", (anuncio.mensaje, anuncio.imagen_url))
    conexion.commit()
    conexion.close()
    registrar_auditoria(f"Anuncio global actualizado: {anuncio.mensaje}")
    return {"status": "ok", "mensaje": "Anuncio publicado en toda la red."}