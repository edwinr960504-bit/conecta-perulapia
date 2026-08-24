# ========================================================
# ARCHIVO: tuberias_negocio.py
# PROPÓSITO: Gestión de comercios y menús con Escudo Anti-Null y Doble Llave para Flutter
# ========================================================
from fastapi import APIRouter
from pydantic import BaseModel
import sqlite3
import os
from datetime import datetime

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

# --- MOTOR DE AUTO-REPARACIÓN DE BASE DE DATOS ---
def reparar_tablas_negocio():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        try: cursor.execute("ALTER TABLE productos ADD COLUMN descripcion TEXT DEFAULT 'Sin descripción'")
        except Exception: pass
        try: cursor.execute("ALTER TABLE productos ADD COLUMN disponible INTEGER DEFAULT 1")
        except Exception: pass
        try: cursor.execute("ALTER TABLE productos ADD COLUMN foto_platillo TEXT DEFAULT 'Sin foto'")
        except Exception: pass
        
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN logo TEXT DEFAULT 'Sin logo'")
        except Exception: pass
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN tipo_plan TEXT DEFAULT 'comision'")
        except Exception: pass
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN direccion TEXT DEFAULT 'Sin dirección'")
        except Exception: pass
        
        conn.commit()
        conn.close()
    except Exception:
        pass

reparar_tablas_negocio()

# --- MODELOS DE DATOS ---
class ComercioNuevo(BaseModel):
    nombre_local: str
    telefono: str
    correo: str
    contrasena: str
    direccion: str = "Sin dirección"
    tipo_plan: str = "comision"
    logo: str = "Sin logo"

class ProductoNuevo(BaseModel):
    id_comercio: int
    nombre_producto: str
    descripcion: str = "Sin descripción"
    precio: float
    foto_platillo: str = "Sin foto"
    disponible: int = 1

class EstadoProducto(BaseModel):
    id_producto: int
    disponible: int
    precio: float

class EliminarProducto(BaseModel):
    id_producto: int

# ========================================================
# 1. REGISTRO DE COMERCIOS (Anti-Duplicados)
# ========================================================
@router.post("/registrar_comercio")
@router.post("/registrar_comercio/")
@router.post("/reg_comercio")
@router.post("/reg_comercio/")
@router.post("/api/registrar_comercio")
@router.post("/api/registrar_comercio/")
def registrar_comercio(c: ComercioNuevo):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT nombre_local FROM comercios WHERE nombre_local = ? OR telefono = ?", (c.nombre_local, c.telefono))
    if cursor.fetchone():
        conexion.close()
        return {"Alerta": "Ya existe un comercio registrado con ese nombre o número de teléfono."}
    
    cursor.execute("""
        INSERT INTO comercios (
            nombre_local, telefono, correo, contrasena, direccion, 
            tipo_plan, logo, estado, fecha_registro
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pendiente', CURRENT_TIMESTAMP)
    """, (c.nombre_local, c.telefono, c.correo, c.contrasena, c.direccion, c.tipo_plan, c.logo))
    
    id_nuevo = cursor.lastrowid
    conexion.commit()
    conexion.close()
    
    return {"status": "ok", "mensaje": f"Comercio '{c.nombre_local}' registrado. Pendiente de aprobación por la Central.", "id_comercio": id_nuevo}

# ========================================================
# 2. CONSULTA, EDICIÓN Y BORRADO DE MENÚS (Con Escudo Anti-Null)
# ========================================================
@router.get("/productos_comercio/{id_comercio}")
@router.get("/api/productos_comercio/{id_comercio}")
def obtener_productos(id_comercio: str):
    try:
        id_limpio = int(id_comercio)
    except ValueError:
        return []

    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT 
            id_producto, 
            COALESCE(nombre_producto, 'Platillo'), 
            COALESCE(descripcion, 'Sin descripción'), 
            COALESCE(precio, 0.0), 
            COALESCE(foto_platillo, 'Sin foto'), 
            COALESCE(disponible, 1)
        FROM productos 
        WHERE id_comercio = ?
        ORDER BY disponible DESC, nombre_producto ASC
    """, (id_limpio,))
    
    prods = cursor.fetchall()
    conexion.close()
    
    return [{
        "id": p[0],
        "id_producto": p[0],
        "nombre": p[1],
        "nombre_producto": p[1],
        "descripcion": p[2],
        "precio": p[3],
        "foto": p[4],
        "foto_platillo": p[4],
        "disponible": bool(p[5])
    } for p in prods]

@router.post("/agregar_producto")
@router.post("/agregar_producto/")
@router.post("/registrar_producto")
@router.post("/registrar_producto/")
@router.post("/api/agregar_producto")
@router.post("/api/agregar_producto/")
@router.post("/api/registrar_producto")
@router.post("/api/registrar_producto/")
def agregar_producto(p: ProductoNuevo):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        INSERT INTO productos (id_comercio, nombre_producto, descripcion, precio, foto_platillo, disponible) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, (p.id_comercio, p.nombre_producto, p.descripcion, p.precio, p.foto_platillo, p.disponible))
    
    id_prod = cursor.lastrowid
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": f"Platillo '{p.nombre_producto}' agregado al menú.", "id_producto": id_prod}

@router.post("/actualizar_producto")
@router.post("/actualizar_producto/")
@router.post("/api/actualizar_producto")
@router.post("/api/actualizar_producto/")
def actualizar_producto(ep: EstadoProducto):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        UPDATE productos SET disponible = ?, precio = ? WHERE id_producto = ?
    """, (ep.disponible, ep.precio, ep.id_producto))
    
    conexion.commit()
    conexion.close()
    estado_txt = "Disponible" if ep.disponible == 1 else "Agotado temporalmente"
    return {"status": "ok", "mensaje": f"Platillo actualizado a: {estado_txt} ($ {ep.precio})"}

@router.post("/eliminar_producto")
@router.post("/eliminar_producto/")
@router.post("/api/eliminar_producto")
@router.post("/api/eliminar_producto/")
def eliminar_producto(del_req: EliminarProducto):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM productos WHERE id_producto = ?", (del_req.id_producto,))
    filas = cursor.rowcount
    conexion.commit()
    conexion.close()
    
    if filas == 0:
        return {"status": "error", "mensaje": "No se encontró el producto en la base de datos."}
    return {"status": "ok", "mensaje": "Platillo eliminado correctamente del menú."}

# ========================================================
# 3. DIRECTORIO DE COMERCIOS ACTIVOS (Solo muestra los abiertos: estado = 'activo')
# ========================================================
@router.get("/comercios_activos")
@router.get("/comercios_activos/")
@router.get("/api/comercios_activos")
@router.get("/api/comercios_activos/")
def comercios_activos():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT 
            id_comercio, 
            COALESCE(nombre_local, 'Comercio'), 
            COALESCE(direccion, 'Sin dirección'), 
            COALESCE(logo, 'Sin logo'), 
            COALESCE(tipo_plan, 'comision') 
        FROM comercios 
        WHERE estado = 'activo'
        ORDER BY nombre_local ASC
    """)
    locales = cursor.fetchall()
    conexion.close()
    
    return [{
        "id": l[0],
        "id_comercio": l[0],
        "id_local": l[0],
        "nombre": l[1],
        "nombre_local": l[1],
        "direccion": l[2],
        "logo": l[3],
        "tipo_plan": l[4]
    } for l in locales]

# ========================================================
# 4. CANDADO DE SEGURIDAD: ABRIR / CERRAR LOCAL REAL
# ========================================================
@router.post("/api/comercio/estado/{id_comercio}")
@router.post("/comercio/estado/{id_comercio}")
@router.post("/comercio/cambiar_estado")
@router.post("/api/comercio/cambiar_estado")
def cambiar_estado_comercio_flexible(id_comercio: int, datos: dict):
    # Traduce el interruptor (true/false) a los estados de la base de datos ('activo' o 'cerrado')
    if "abierto" in datos:
        nuevo_estado = "activo" if datos.get("abierto") else "cerrado"
    else:
        nuevo_estado = str(datos.get("estado", "activo")).lower().strip()
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    # REGLA DE ORO: Si intenta CERRAR, verifica si hay pedidos vivos en proceso
    if nuevo_estado == "cerrado":
        cursor.execute("""
            SELECT COUNT(*) FROM pedidos 
            WHERE id_comercio = ? AND estado IN ('pendiente', 'preparacion', 'listo_recoleccion', 'asignado')
        """, (id_comercio,))
        pedidos_vivos = cursor.fetchone()[0]
        
        if pedidos_vivos > 0:
            conexion.close()
            return {
                "status": "error", 
                "mensaje": f"¡No puedes cerrar el local! Tienes {pedidos_vivos} pedido(s) en proceso. Entrégalo o cancélalo primero."
            }, 400
            
    # Actualiza el estado real en la columna 'estado' de la tabla comercios
    cursor.execute("UPDATE comercios SET estado = ? WHERE id_comercio = ?", (nuevo_estado, id_comercio))
    conexion.commit()
    conexion.close()
    
    return {
        "status": "ok", 
        "mensaje": f"Estado del negocio actualizado a: {nuevo_estado.upper()}",
        "abierto": (nuevo_estado == "activo")
    }

# ========================================================
# 5. BILLETERA Y FINANZAS DEL COMERCIO (En tiempo real)
# ========================================================
@router.get("/billetera/comercio/{id_comercio}")
@router.get("/api/billetera/comercio/{id_comercio}")
def billetera_comercio(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT id_pedido, descripcion, total_pago, fecha_entrega 
        FROM pedidos 
        WHERE id_comercio = ? AND estado = 'entregado'
        ORDER BY id_pedido DESC
    """, (id_comercio,))
    
    filas = cursor.fetchall()
    conexion.close()
    
    ganancia_total = 0.0
    historial = []
    
    for r in filas:
        id_ped = r[0]
        desc = r[1] or "Pedido de comida"
        monto = float(r[2] or 0.0)
        
        if monto <= 0.0:
            monto = 5.00
            
        ganancia_total += monto
        fecha_hora = r[3] or datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        historial.append({
            "id_pedido": id_ped,
            "ganancia": round(monto, 2),
            "fecha": fecha_hora,
            "descripcion": desc
        })
        
    return {
        "ganancia_total": round(ganancia_total, 2),
        "historial": historial
    }
# ========================================================
# BORRAR MOVIMIENTOS DE LA BILLETERA / HISTORIAL
# ========================================================
@router.post("/api/billetera/borrar_movimiento")
def borrar_movimiento_billetera(datos: dict):
    id_pedido = datos.get("id_pedido")
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    # Marcamos el pedido como archivado para que ya no salga en la billetera
    cursor.execute("UPDATE pedidos SET estado = 'archivado' WHERE id_pedido = ?", (id_pedido,))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": f"Pedido {id_pedido} borrado del historial"}

@router.post("/api/billetera/limpiar_todo/{id_comercio}")
def limpiar_todo_billetera(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    # Archiva todos los entregados de este comercio
    cursor.execute("UPDATE pedidos SET estado = 'archivado' WHERE id_comercio = ? AND estado = 'entregado'", (id_comercio,))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Historial limpiado con éxito"}