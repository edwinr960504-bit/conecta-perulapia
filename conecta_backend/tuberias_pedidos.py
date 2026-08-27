# =====================================================================
# ARCHIVO COMPLETO: tuberias_pedidos.py (BLINDADO)
# =====================================================================
from fastapi import APIRouter
from pydantic import BaseModel
import sqlite3
import os
import random
from datetime import datetime

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

def asegurar_estructura():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cols = [
            ("id_repartidor", "INTEGER DEFAULT 0"), 
            ("latitud_repartidor", "REAL DEFAULT 0.0"), 
            ("longitud_repartidor", "REAL DEFAULT 0.0"), 
            ("latitud_cliente", "REAL DEFAULT 0.0"), 
            ("longitud_cliente", "REAL DEFAULT 0.0"), 
            ("tiempo_preparacion", "TEXT DEFAULT 'Por confirmar'"),
            ("numero_diario", "INTEGER DEFAULT 1"),
            ("codigo_rastreo", "TEXT DEFAULT 'CP-0000'")
        ]
        for col, tipo in cols:
            try: cursor.execute(f"ALTER TABLE pedidos ADD COLUMN {col} {tipo}")
            except Exception: pass
        conn.commit(); conn.close()
    except Exception: pass

asegurar_estructura()

class PedidoNuevo(BaseModel):
    id_cliente: int  # 🔥 ELIMINADO EL "= 1". Si la app no manda quién es, el pedido no se contamina en el perfil de otro.
    id_comercio: int = None
    comercio_id: int = None
    id_local: int = None
    id_negocio: int = None
    descripcion: str = "Pedido de comida"
    precio_comida: float = 0.0
    distancia_km: float = 1.0
    metodo_pago: str = "Efectivo"
    latitud_cliente: float = 13.7333
    longitud_cliente: float = -89.1167

class AccionComercio(BaseModel):
    id_pedido: int = None
    id: int = None
    orden_id: int = None
    tiempo_preparacion: str = "20 minutos"
    tiempo: str = None

@router.post("/crear_pedido")
@router.post("/crear_pedido/")
@router.post("/api/crear_pedido")
@router.post("/api/crear_pedido/")
def crear_pedido(p: PedidoNuevo):
    conexion = sqlite3.connect(DB_PATH)
    conexion.execute("BEGIN IMMEDIATE;")
    cursor = conexion.cursor()
    
    try:
        ahora = datetime.now()
        hoy_str = ahora.strftime("%Y-%m-%d")
        fecha_exacta = ahora.strftime("%Y-%m-%d %H:%M:%S")
        
        cursor.execute("SELECT MAX(numero_diario) FROM pedidos WHERE fecha LIKE ?", (f"{hoy_str}%",))
        row_max = cursor.fetchone()
        ultimo_num = row_max[0] if (row_max and row_max[0] is not None) else 0
        num_diario = ultimo_num + 1
        
        envio = 1.00 if p.distancia_km <= 1.5 else (1.50 if p.distancia_km <= 3.0 else 2.00)
        comision = round(p.precio_comida * 0.10, 2)
        total = round(p.precio_comida + envio, 2)
        
        pin_seguridad = str(random.randint(1000, 9999))
        pin_recoleccion = str(random.randint(1000, 9999))
        codigo_rastreo = f"CP-{random.randint(10000, 99999)}"
        
        comercio_real = p.id_comercio or p.comercio_id or p.id_local or p.id_negocio or 1
        
        cursor.execute("""
            INSERT INTO pedidos (
                id_cliente, id_comercio, descripcion, precio_comida, tarifa_envio, 
                comision_app, total_pago, distancia_km, pin_seguridad, pin_recoleccion, 
                codigo_rastreo, metodo_pago, estado, id_repartidor, latitud_repartidor, 
                longitud_repartidor, latitud_cliente, longitud_cliente, numero_diario, fecha
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendiente', 0, 0.0, 0.0, ?, ?, ?, ?)
        """, (
            p.id_cliente, 
            comercio_real, 
            p.descripcion, p.precio_comida, envio, comision, total, p.distancia_km, 
            pin_seguridad, pin_recoleccion, codigo_rastreo, p.metodo_pago, 
            p.latitud_cliente, p.longitud_cliente, num_diario, fecha_exacta
        ))
        
        orden_id = cursor.lastrowid
        conexion.commit()
    except Exception as e:
        conexion.rollback()
        raise e
    finally:
        conexion.close()
    
    return {
        "status": "ok", 
        "mensaje": f"Pedido enviado exitosamente", 
        "id_pedido": orden_id,
        "codigo_rastreo": codigo_rastreo,
        "total_pago": total
    }

@router.get("/pedidos_comercio/{id_comercio}")
@router.get("/pedidos_comercio/{id_comercio}/")
@router.get("/api/pedidos_comercio/{id_comercio}")
@router.get("/api/pedidos_comercio/{id_comercio}/")
def ver_pedidos_cocina(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT p.id_pedido, p.descripcion, p.precio_comida, p.total_pago, p.estado, p.fecha,
               COALESCE(u.nombre, 'Cliente Conecta'), COALESCE(u.telefono, 'Sin teléfono'), 
               COALESCE(u.direccion, 'Perulapía'), p.pin_recoleccion, p.distancia_km, 
               p.id_repartidor, 
               (SELECT COUNT(*) FROM pedidos p2 WHERE p2.id_comercio = p.id_comercio AND DATE(p2.fecha) = DATE(p.fecha) AND p2.id_pedido <= p.id_pedido), 
               p.codigo_rastreo
        FROM pedidos p 
        LEFT JOIN usuarios u ON p.id_cliente = u.id_usuario
        WHERE p.id_comercio = ? AND p.estado IN ('pendiente', 'preparacion', 'listo_recoleccion', 'asignado') 
        ORDER BY p.id_pedido ASC
    """, (id_comercio,))
    filas = cursor.fetchall()
    conexion.close()
    
    return [{
        "id": r[0], "id_pedido": r[0], 
        "numero_orden": r[12] or r[0],
        "codigo_rastreo": r[13] or f"CP-0000",
        "descripcion": r[1], "precio": r[2], "total": r[3],
        "estado": r[4], "fecha": r[5], "nombre_cliente": r[6], "telefono_cliente": r[7],
        "direccion_cliente": r[8], "pin_recoleccion": r[9], "distancia_km": r[10]
    } for r in filas]

@router.post("/comercio_acepta")
@router.post("/comercio_acepta/")
@router.post("/api/comercio_acepta")
@router.post("/api/comercio_acepta/")
def comercio_acepta(req: AccionComercio):
    id_orden = req.id_pedido or req.id or req.orden_id
    tiempo_cocina = req.tiempo_preparacion or req.tiempo or "20 minutos"
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET estado = 'preparacion', tiempo_preparacion = ? WHERE id_pedido = ?", (tiempo_cocina, id_orden))
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": f"Orden aceptada en cocina."}

@router.post("/comercio_pedido_listo")
@router.post("/comercio_pedido_listo/")
@router.post("/api/comercio_pedido_listo")
@router.post("/api/comercio_pedido_listo/")
def comercio_pedido_listo(req: AccionComercio):
    id_orden = req.id_pedido or req.id or req.orden_id
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET estado = 'listo_recoleccion' WHERE id_pedido = ? AND estado = 'preparacion'", (id_orden,))
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "¡Comida lista para recolección!"}

@router.get("/api/pedidos_activos/cliente/{id_cliente}")
def radar_del_cliente(id_cliente: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT p.id_pedido, p.estado, p.pin_seguridad, p.latitud_repartidor, p.longitud_repartidor, p.total_pago,
               COALESCE(c.nombre_local, 'Comercio Local'), COALESCE(u_rep.nombre, ''), COALESCE(u_rep.telefono, ''),
               p.tiempo_preparacion, p.descripcion, p.id_repartidor, 
               (SELECT COUNT(*) FROM pedidos p2 WHERE p2.id_cliente = p.id_cliente AND DATE(p2.fecha) = DATE(p.fecha) AND p2.id_pedido <= p.id_pedido), 
               p.fecha, p.codigo_rastreo
        FROM pedidos p 
        LEFT JOIN comercios c ON p.id_comercio = c.id_comercio
        LEFT JOIN usuarios u_rep ON p.id_repartidor = u_rep.id_usuario
        WHERE p.id_cliente = ? AND p.estado NOT IN ('entregado', 'cancelado', 'archivado') 
        ORDER BY p.id_pedido ASC
    """, (id_cliente,))
    filas = cursor.fetchall()
    conexion.close()
    
    resultado = []
    for r in filas:
        est_db = r[1]
        id_rep = r[11] or 0
        lat_db, lon_db = r[3], r[4]
        nombre_negocio = r[6]
        
        if est_db == 'pendiente': texto_pantalla = f"⏳ Esperando confirmación de {nombre_negocio}..."
        elif est_db == 'preparacion': texto_pantalla = f"👨‍🍳 Cocinando tu pedido en {nombre_negocio} ({r[9]})"
        elif est_db == 'listo_recoleccion': texto_pantalla = f"🛍️ Pedido listo en {nombre_negocio}. Esperando motorista"
        elif est_db == 'en_camino': texto_pantalla = f"🛵 ¡En camino! El motorista ({r[7]}) lleva tu pedido"
        else: texto_pantalla = f"🛵 Motorista ({r[7]}) asignado, yendo a {nombre_negocio}"

        resultado.append({
            "id_pedido": r[0], "numero_orden": r[12] or r[0],
            "codigo_rastreo": r[14] or f"CP-0000",
            "estado": texto_pantalla, "estado_codigo": est_db,
            "pin_seguridad": r[2], "total": r[5], "negocio": nombre_negocio,
            "tiempo_preparacion": r[9], "descripcion": r[10],
            "repartidor": r[7] if id_rep > 0 else "", "telefono_rep": r[8], "id_repartidor": id_rep,
            "lat": lat_db if lat_db != 0.0 else None, "lon": lon_db if lon_db != 0.0 else None,
            "en_camino": (est_db == 'en_camino'), "fecha": r[13]
        })
    return resultado

@router.get("/api/historial_cliente/{id_cliente}")
def historial_cliente(id_cliente: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT p.id_pedido, p.descripcion, p.total_pago, p.fecha_entrega, p.estado, 
               p.metodo_pago, 
               (SELECT COUNT(*) FROM pedidos p2 WHERE p2.id_cliente = p.id_cliente AND DATE(p2.fecha) = DATE(p.fecha) AND p2.id_pedido <= p.id_pedido), 
               p.codigo_rastreo, COALESCE(c.nombre_local, 'Comercio Local')
        FROM pedidos p 
        LEFT JOIN comercios c ON p.id_comercio = c.id_comercio
        WHERE p.id_cliente = ? AND p.estado = 'entregado'
        ORDER BY p.id_pedido DESC
    """, (id_cliente,))
    
    filas = cursor.fetchall(); conexion.close()
    
    historial = []
    for r in filas:
        historial.append({
            "id_pedido": r[0], "numero_diario": r[6] or r[0], "codigo_rastreo": r[7] or f"CP-0000",
            "negocio": r[8], "articulos": r[1], "total": float(r[2] or 0.0),
            "fecha": r[3], "estado": (r[4] or "Entregado").capitalize(), "metodo_pago": r[5]
        })
    return historial

class CoordenadasGPS(BaseModel):
    id_pedido: int
    latitud: float
    longitud: float

@router.post("/actualizar_gps")
@router.post("/actualizar_gps/")
@router.post("/api/actualizar_gps")
@router.post("/api/actualizar_gps/")
def actualizar_gps(c: CoordenadasGPS):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET latitud_repartidor = ?, longitud_repartidor = ? WHERE id_pedido = ?", (c.latitud, c.longitud, c.id_pedido))
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "Ubicación actualizada con éxito"}

@router.post("/actualizar_gps_cliente")
@router.post("/actualizar_gps_cliente/")
@router.post("/api/actualizar_gps_cliente")
@router.post("/api/actualizar_gps_cliente/")
def actualizar_gps_cliente(c: CoordenadasGPS):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET latitud_cliente = ?, longitud_cliente = ? WHERE id_pedido = ?", (c.latitud, c.longitud, c.id_pedido))
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "Ubicación del cliente actualizada en tiempo real"}

@router.get("/api/obtener_gps/{id_pedido}")
def obtener_gps(id_pedido: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT latitud_repartidor, longitud_repartidor, latitud_cliente, longitud_cliente, estado FROM pedidos WHERE id_pedido = ?", (id_pedido,))
    row = cursor.fetchone()
    conexion.close()
    
    if row:
        return {
            "status": "ok", "latitud_repartidor": row[0] or 0.0, "longitud_repartidor": row[1] or 0.0,
            "latitud": row[0] or 0.0, "longitud": row[1] or 0.0, "latitud_cliente": row[2] or 13.7333,
            "longitud_cliente": row[3] or -89.1167, "latitud_comercio": 13.7333, "longitud_comercio": -89.1167, "estado_pedido": row[4]
        }
    return {"status": "error", "estado_pedido": "desconocido"}

@router.post("/api/cancelar_pedido/{id_pedido}")
def cancelar_pedido(id_pedido: int):
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    try:
        cursor.execute("DELETE FROM pedidos WHERE id_pedido = ? AND estado = 'pendiente'", (id_pedido,))
        conexion.commit(); conexion.close()
        return {"status": "ok", "mensaje": "Pedido eliminado"}
    except Exception as e:
        return {"status": "error"}

@router.post("/api/cliente/borrar_historial")
def borrar_historial_cliente(datos: dict):
    id_pedido = datos.get("id_pedido")
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET estado = 'archivado' WHERE id_pedido = ? AND estado IN ('entregado', 'cancelado')", (id_pedido,))
    conexion.commit(); conexion.close()
    return {"status": "ok"}

@router.post("/api/cliente/limpiar_todo/{id_cliente}")
def limpiar_todo_cliente(id_cliente: int):
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET estado = 'archivado' WHERE id_cliente = ? AND estado IN ('entregado', 'cancelado')", (id_cliente,))
    conexion.commit(); conexion.close()
    return {"status": "ok"}