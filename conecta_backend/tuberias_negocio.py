# ========================================================
# ARCHIVO: tuberias_negocio.py (COMPLETO Y DEFINITIVO)
# PROPÓSITO: Gestión de comercios, menús, logos persistentes y collage de platillos
# ========================================================
from fastapi import APIRouter, UploadFile, File, Form
import sqlite3
import os
import shutil
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
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN horarios TEXT DEFAULT 'Sin horarios'")
        except Exception: pass
        
        conn.commit()
        conn.close()
    except Exception:
        pass

reparar_tablas_negocio()

# --- MODELOS DE DATOS ---
from pydantic import BaseModel

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
    foto: str = None  

class EliminarProducto(BaseModel):
    id_producto: int

# ========================================================
# 1. REGISTRO Y PERFIL DE COMERCIOS
# ========================================================
@router.post("/registrar_comercio")
@router.post("/registrar_comercio/")
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
    
    return {"status": "ok", "mensaje": f"Comercio '{c.nombre_local}' registrado.", "id_comercio": id_nuevo}

# 🔥 SUBIDA DE FOTO DE PERFIL DEL COMERCIO (GUARDA EN BD DE INMEDIATO)
@router.post("/subir_foto_comercio/")
@router.post("/subir_foto_comercio")
@router.post("/api/subir_foto_comercio")
@router.post("/api/subir_foto_comercio/")
async def subir_foto_comercio(id_comercio: str = Form(...), file: UploadFile = File(...)):
    ruta_carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fotos_seguridad")
    os.makedirs(ruta_carpeta, exist_ok=True)
    
    nombre_archivo = f"local_{id_comercio}_{file.filename}"
    ruta_destino = os.path.join(ruta_carpeta, nombre_archivo)
    
    with open(ruta_destino, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    url_relativa = f"/fotos_seguridad/{nombre_archivo}"
    
    # ACTUALIZACIÓN DIRECTA EN LA BASE DE DATOS
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE comercios SET logo = ? WHERE id_comercio = ?", (url_relativa, id_comercio))
    conexion.commit()
    conexion.close()
    
    return {"status": "ok", "url": url_relativa}

# 🔥 PERFIL INDIVIDUAL PARA CARGAR DATOS Y LOGO EN AJUSTES Y MENÚ LATERAL
@router.get("/api/comercio/perfil/{id_comercio}")
def obtener_perfil_comercio(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    conexion.row_factory = sqlite3.Row
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT id_comercio, nombre_local, direccion, horarios, logo, tipo_plan 
        FROM comercios WHERE id_comercio = ?
    """, (id_comercio,))
    comercio = cursor.fetchone()
    conexion.close()
    
    if comercio:
        logo_path = comercio["logo"] if comercio["logo"] and comercio["logo"] != "Sin logo" else ""
        return {
            "status": "ok",
            "id_comercio": comercio["id_comercio"],
            "nombre_local": comercio["nombre_local"],
            "direccion": comercio["direccion"] or "",
            "horarios": comercio["horarios"] or "",
            "logo": logo_path
        }
    return {"status": "error", "mensaje": "Comercio no encontrado"}

@router.post("/api/comercio/actualizar_perfil")
def actualizar_perfil_comercio(datos: dict):
    id_comercio = datos.get('id_comercio')
    nombre = datos.get('nombre_local')
    direccion = datos.get('direccion')
    horarios = datos.get('horarios')
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        UPDATE comercios 
        SET nombre_local = ?, direccion = ?, horarios = ? 
        WHERE id_comercio = ?
    """, (nombre, direccion, horarios, id_comercio))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Perfil actualizado correctamente"}

# ========================================================
# 2. GESTIÓN DE FOTOGRAFÍAS Y MENÚS DE PLATILLOS
# ========================================================
@router.post("/subir_foto_producto")
@router.post("/subir_foto_producto/")
@router.post("/api/subir_foto_producto")
@router.post("/api/subir_foto_producto/")
async def subir_foto_producto(id_producto: int = Form(...), file: UploadFile = File(...)):
    ruta_carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fotos_seguridad")
    os.makedirs(ruta_carpeta, exist_ok=True)
    
    nombre_archivo = f"producto_{id_producto}_{file.filename}"
    ruta_destino = os.path.join(ruta_carpeta, nombre_archivo)
    
    with open(ruta_destino, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    url_relativa = f"/fotos_seguridad/{nombre_archivo}"
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE productos SET foto_platillo = ? WHERE id_producto = ?", (url_relativa, id_producto))
    conexion.commit()
    conexion.close()
    
    return {"status": "ok", "url": url_relativa}

@router.get("/productos_comercio/{id_comercio}")
@router.get("/api/productos_comercio/{id_comercio}")
def obtener_productos(id_comercio: str):
    try: id_limpio = int(id_comercio)
    except ValueError: return []

    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT id_producto, COALESCE(nombre_producto, 'Platillo'), COALESCE(descripcion, 'Sin descripción'), 
               COALESCE(precio, 0.0), COALESCE(foto_platillo, 'Sin foto'), COALESCE(disponible, 1)
        FROM productos WHERE id_comercio = ? ORDER BY disponible DESC, nombre_producto ASC
    """, (id_limpio,))
    prods = cursor.fetchall(); conexion.close()
    
    return [{
        "id": p[0], "id_producto": p[0], "nombre": p[1], "nombre_producto": p[1],
        "descripcion": p[2], "precio": p[3], "foto": p[4], "foto_platillo": p[4], "disponible": bool(p[5])
    } for p in prods]

@router.post("/agregar_producto")
@router.post("/agregar_producto/")
@router.post("/api/agregar_producto")
@router.post("/api/agregar_producto/")
def agregar_producto(p: ProductoNuevo):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        INSERT INTO productos (id_comercio, nombre_producto, descripcion, precio, foto_platillo, disponible) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, (p.id_comercio, p.nombre_producto, p.descripcion, p.precio, p.foto_platillo, p.disponible))
    id_prod = cursor.lastrowid
    conexion.commit(); conexion.close()
    return {"status": "ok", "mensaje": "Platillo agregado", "id_producto": id_prod}

@router.post("/actualizar_producto")
@router.post("/actualizar_producto/")
@router.post("/api/actualizar_producto")
@router.post("/api/actualizar_producto/")
def actualizar_producto(ep: EstadoProducto):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    if ep.foto:
        cursor.execute("UPDATE productos SET disponible = ?, precio = ?, foto_platillo = ? WHERE id_producto = ?", (ep.disponible, ep.precio, ep.foto, ep.id_producto))
    else:
        cursor.execute("UPDATE productos SET disponible = ?, precio = ? WHERE id_producto = ?", (ep.disponible, ep.precio, ep.id_producto))
    conexion.commit(); conexion.close()
    return {"status": "ok"}

@router.post("/eliminar_producto")
@router.post("/eliminar_producto/")
@router.post("/api/eliminar_producto")
@router.post("/api/eliminar_producto/")
def eliminar_producto(del_req: EliminarProducto):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM productos WHERE id_producto = ?", (del_req.id_producto,))
    conexion.commit(); conexion.close()
    return {"status": "ok"}

# ========================================================
# 3. DIRECTORIO DE COMERCIOS ACTIVOS (CON COLLAGE DE PLATILLOS)
# ========================================================
@router.get("/comercios_activos")
@router.get("/comercios_activos/")
@router.get("/api/comercios_activos")
@router.get("/api/comercios_activos/")
def comercios_activos():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT id_comercio, COALESCE(nombre_local, 'Comercio'), COALESCE(direccion, 'Sin dirección'), 
               COALESCE(logo, 'Sin logo'), COALESCE(tipo_plan, 'comision') 
        FROM comercios WHERE estado = 'activo' ORDER BY nombre_local ASC
    """)
    locales = cursor.fetchall()
    
    resultado = []
    for l in locales:
        id_com = l[0]
        # Obtenemos hasta 3 fotos de los platillos para armar el fondo collage dinámico
        cursor.execute("""
            SELECT foto_platillo FROM productos 
            WHERE id_comercio = ? AND foto_platillo != 'Sin foto' AND foto_platillo != ''
            LIMIT 3
        """, (id_com,))
        fotos_prods = [row[0] for row in cursor.fetchall()]
        
        resultado.append({
            "id": id_com,
            "id_comercio": id_com,
            "id_local": id_com,
            "nombre": l[1],
            "nombre_local": l[1],
            "direccion": l[2],
            "logo": l[3],
            "tipo_plan": l[4],
            "fotos_productos": fotos_prods
        })
        
    conexion.close()
    return resultado

@router.post("/api/comercio/estado/{id_comercio}")
def cambiar_estado(id_comercio: int, datos: dict):
    nuevo_estado = "activo" if datos.get("abierto") else "cerrado"
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE comercios SET estado = ? WHERE id_comercio = ?", (nuevo_estado, id_comercio))
    conexion.commit(); conexion.close()
    return {"status": "ok", "abierto": (nuevo_estado == "activo")}

@router.get("/billetera/comercio/{id_comercio}")
@router.get("/api/billetera/comercio/{id_comercio}")
def billetera_comercio(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("SELECT id_pedido, descripcion, total_pago, fecha_entrega FROM pedidos WHERE id_comercio = ? AND estado = 'entregado' ORDER BY id_pedido DESC", (id_comercio,))
    filas = cursor.fetchall(); conexion.close()
    ganancia_total = sum([float(r[2] or 5.0) for r in filas])
    return {"ganancia_total": round(ganancia_total, 2), "historial": [{"id_pedido": r[0], "ganancia": float(r[2] or 5.0), "fecha": r[3], "descripcion": r[1]} for r in filas]}