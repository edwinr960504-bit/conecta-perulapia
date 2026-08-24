# =====================================================================
# ARCHIVO 2: tuberias_logistica.py (ACTUALIZADO CON ENDPOINT DE GPS)
# PROPÓSITO: Bolsa de trabajo de Motoristas, GPS y Códigos PIN de entrega
# =====================================================================
from fastapi import APIRouter
from pydantic import BaseModel
import sqlite3
import os
from datetime import datetime

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

class TomarPedido(BaseModel):
    id_pedido: int
    id_repartidor: int

class ValidarPin(BaseModel):
    id_pedido: int
    pin: str

class ActualizarGPS(BaseModel):
    id_pedido: int
    latitud: float
    longitud: float

# --- 1. BOLSA DE TRABAJO (Con Identidad y Número de Viaje) ---
@router.get("/pedidos_disponibles")
@router.get("/api/pedidos_disponibles")
def bolsa_repartidores():
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    cursor.execute("""
        SELECT p.id_pedido, p.descripcion, p.tarifa_envio, p.distancia_km, c.nombre_local, 
               c.direccion, p.estado, p.numero_diario, p.codigo_rastreo
        FROM pedidos p JOIN comercios c ON p.id_comercio = c.id_comercio
        WHERE p.estado IN ('preparacion', 'listo_recoleccion') AND (p.id_repartidor IS NULL OR p.id_repartidor = 0)
        ORDER BY p.id_pedido ASC
    """)
    filas = cursor.fetchall(); conexion.close()
    
    return [{
        "id_pedido": r[0], "id": r[0], "descripcion": r[1], "ganancia_envio": r[2],
        "distancia_km": r[3], "negocio": r[4], "direccion_negocio": r[5], "estado_cocina": r[6],
        "numero_orden": r[7] or r[0], "codigo_rastreo": r[8] or f"CP-0000"
    } for r in filas]

# --- 2. EL MOTORISTA ACEPTA EL VIAJE ---
@router.post("/tomar_pedido")
@router.post("/api/tomar_pedido")
def repartidor_toma_pedido(req: TomarPedido):
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    cursor.execute("""
        UPDATE pedidos SET estado = 'asignado', id_repartidor = ? 
        WHERE id_pedido = ? AND id_repartidor = 0
    """, (req.id_repartidor, req.id_pedido))
    filas = cursor.rowcount
    conexion.commit(); conexion.close()
    
    if filas == 0: return {"status": "error", "mensaje": "Este pedido ya fue tomado por otro repartidor."}
    return {"status": "ok", "mensaje": "¡Viaje asignado! Ve al restaurante por el pedido."}

# --- 3. RECOLECCIÓN EN LOCAL ---
from fastapi import Request

@router.post("/recoger_pedido")
@router.post("/api/recoger_pedido")
async def recoger_en_local(request: Request):
    datos = await request.json()
    
    id_orden = datos.get("id_pedido") or datos.get("id") or datos.get("orden_id")
    pin_ingresado = str(datos.get("pin") or datos.get("pin_recoleccion") or "").strip()
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT pin_recoleccion FROM pedidos WHERE id_pedido = ?", (id_orden,))
    row = cursor.fetchone()
    
    pin_registrado = str(row[0]).strip() if row and row[0] is not None else ""
    
    if pin_registrado and pin_registrado != "None" and pin_ingresado != pin_registrado:
        conexion.close()
        return {"status": "error", "mensaje": f"PIN incorrecto. (Escribiste: {pin_ingresado})"}
    
    cursor.execute("UPDATE pedidos SET estado = 'en_camino' WHERE id_pedido = ?", (id_orden,))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "¡PIN Correcto! El pedido va en camino al cliente."}

# --- 4. ENTREGA AL CLIENTE ---
@router.post("/entregar_pedido")
@router.post("/api/entregar_pedido")
def entregar_a_cliente(req: ValidarPin):
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    cursor.execute("SELECT pin_seguridad FROM pedidos WHERE id_pedido = ?", (req.id_pedido,))
    row = cursor.fetchone()
    
    if not row or str(req.pin).strip() != str(row[0]):
        conexion.close(); return {"status": "error", "mensaje": "PIN de entrega incorrecto."}
    
    fecha_actual = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    cursor.execute("""
        UPDATE pedidos 
        SET estado = 'entregado', fecha_entrega = ? 
        WHERE id_pedido = ?
    """, (fecha_actual, req.id_pedido))
    
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "¡Entrega completada! Dinero sumado a tu billetera."}
    
# --- 5. ACTUALIZACIÓN Y LECTURA DE GPS (MOTORISTA Y ADMIN) ---
@router.post("/actualizar_gps")
@router.post("/api/actualizar_gps")
def gps_motorista(req: ActualizarGPS):
    conexion = sqlite3.connect(DB_PATH); cursor = conexion.cursor()
    cursor.execute("""
        UPDATE pedidos 
        SET latitud_repartidor = ?, longitud_repartidor = ? 
        WHERE id_pedido = ?
    """, (req.latitud, req.longitud, req.id_pedido))
    conexion.commit(); conexion.close()
    return {"status": "ok"}

@router.get("/api/obtener_gps/{id_pedido}")
def obtener_gps_pedido(id_pedido: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT COALESCE(latitud_repartidor, 0.0), COALESCE(longitud_repartidor, 0.0) 
        FROM pedidos WHERE id_pedido = ?
    """, (id_pedido,))
    fila = cursor.fetchone()
    conexion.close()
    
    if fila:
        return {"status": "ok", "latitud": fila[0], "longitud": fila[1]}
    return {"status": "error", "latitud": 0.0, "longitud": 0.0}

# --- 6. BILLETERA DEL REPARTIDOR ---
@router.get("/api/repartidor/billetera/{id_repartidor}")
def obtener_billetera_repartidor(id_repartidor: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    hoy_str = datetime.now().strftime("%Y-%m-%d")
    
    cursor.execute("""
        SELECT id_pedido, tarifa_envio, fecha_entrega 
        FROM pedidos 
        WHERE id_repartidor = ? AND estado = 'entregado'
        ORDER BY id_pedido DESC
    """, (id_repartidor,))
    filas = cursor.fetchall()
    
    saldo_total = 0.0
    ganancia_hoy = 0.0
    viajes_hoy = 0
    historial = []
    
    for r in filas:
        id_ped = r[0]
        ganancia = float(r[1] or 0.0)
        fecha_completa = r[2] or str(datetime.now())
        
        saldo_total += ganancia
        
        if fecha_completa.startswith(hoy_str):
            ganancia_hoy += ganancia
            viajes_hoy += 1
            
        historial.append({
            "id_pedido": id_ped,
            "ganancia": ganancia,
            "fecha_hora": fecha_completa
        })
        
    conexion.close()
    
    return {
        "saldo_total": round(saldo_total, 2),
        "ganancia_hoy": round(ganancia_hoy, 2),
        "viajes_hoy": viajes_hoy,
        "historial": historial
    }

@router.post("/api/repartidor/borrar_movimiento")
def borrar_movimiento_repartidor(datos: dict):
    id_pedido = datos.get("id_pedido")
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET estado = 'archivado' WHERE id_pedido = ?", (id_pedido,))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Movimiento eliminado del historial"}

@router.post("/api/repartidor/limpiar_todo/{id_repartidor}")
def limpiar_todo_repartidor(id_repartidor: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE pedidos SET estado = 'archivado' WHERE id_repartidor = ? AND estado = 'entregado'", (id_repartidor,))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Historial del motorista limpiado"}