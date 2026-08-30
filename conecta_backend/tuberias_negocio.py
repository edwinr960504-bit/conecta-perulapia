# ========================================================
# ARCHIVO COMPLETO: tuberias_negocio.py (CON SOPORTE DE DUI Y PREFIJOS)
# PROPÓSITO: Gestión completa de comercios, menús, logos y registros con DUI
# ========================================================
from fastapi import APIRouter, UploadFile, File, Form
import sqlite3
import os
import shutil
from datetime import datetime

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

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
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN dui TEXT DEFAULT '00000000-0'")
        except Exception: pass
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
        except Exception: pass
        conn.commit()
        conn.close()
    except Exception:
        pass

reparar_tablas_negocio()

from pydantic import BaseModel

class ComercioNuevo(BaseModel):
    nombre_local: str
    telefono: str
    correo: str
    contrasena: str
    dui: str = "00000000-0"
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
# 1. REGISTRO Y PERFIL DE COMERCIOS (CON CAPTURA DE DUI)
# ========================================================
@router.post("/registrar_comercio")
@router.post("/registrar_comercio/")
@router.post("/api/registrar_comercio")
@router.post("/api/registrar_comercio/")
def registrar_comercio(c: ComercioNuevo):
    tel_limpio = c.telefono.strip()
    correo_limpio = c.correo.strip().lower()
    nombre_limpio = c.nombre_local.strip()
    dui_limpio = c.dui.strip()

    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT nombre_local FROM comercios 
        WHERE LOWER(nombre_local) = LOWER(?) OR telefono = ? OR LOWER(correo) = ? OR dui = ?
    """, (nombre_limpio, tel_limpio, correo_limpio, dui_limpio))
    if cursor.fetchone():
        conexion.close()
        return {"Alerta": "Ya existe un comercio registrado con ese nombre, correo, teléfono o DUI."}
        
    cursor.execute("""
        SELECT nombre FROM usuarios 
        WHERE telefono = ? OR LOWER(correo) = ? OR dui = ?
    """, (tel_limpio, correo_limpio, dui_limpio))
    if cursor.fetchone():
        conexion.close()
        return {"Alerta": "Ese teléfono, correo o DUI ya está en uso en otra cuenta."}
    
    cursor.execute("""
        INSERT INTO comercios (
            nombre_local, telefono, correo, contrasena, dui, direccion, 
            tipo_plan, logo, estado, fecha_registro
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'activo', CURRENT_TIMESTAMP)
    """, (nombre_limpio, tel_limpio, c.correo, c.contrasena, dui_limpio, c.direccion, c.tipo_plan, c.logo))
    
    id_nuevo = cursor.lastrowid
    conexion.commit()
    conexion.close()
    
    return {"status": "ok", "mensaje": f"Comercio '{nombre_limpio}' registrado con DUI.", "id_comercio": id_nuevo, "id_identidad": f"C-{id_nuevo}"}

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
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE comercios SET logo = ? WHERE id_comercio = ?", (url_relativa, id_comercio))
    filas = cursor.rowcount
    conexion.commit()
    conexion.close()
    
    if filas == 0:
        return {"status": "error", "mensaje": "ID de Comercio fantasma. No se pudo guardar la foto."}
        
    return {"status": "ok", "url": url_relativa}

@router.get("/api/comercio/perfil/{id_comercio}")
def obtener_perfil_comercio(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    conexion.row_factory = sqlite3.Row
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT id_comercio, nombre_local, direccion, horarios, logo, tipo_plan, estado, dui 
        FROM comercios WHERE id_comercio = ?
    """, (id_comercio,))
    comercio = cursor.fetchone()
    conexion.close()
    
    if comercio:
        logo_path = comercio["logo"] if comercio["logo"] and comercio["logo"] != "Sin logo" else ""
        return {
            "status": "ok",
            "id_comercio": comercio["id_comercio"],
            "id_identidad": f"C-{comercio['id_comercio']}",
            "nombre_local": comercio["nombre_local"],
            "direccion": comercio["direccion"] or "",
            "horarios": comercio["horarios"] or "",
            "dui": comercio["dui"] or "",
            "logo": logo_path,
            "estado": comercio["estado"] or "cerrado"
        }
    return {"status": "error", "mensaje": "Comercio no encontrado en la base de datos"}

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
    filas = cursor.rowcount
    conexion.commit()
    conexion.close()
    
    if filas == 0:
        return {"status": "error", "mensaje": "ID de comercio fantasma. Actualización bloqueada."}
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
    prods = cursor.fetchall()
    conexion.close()
    
    return [{
        "id": p[0], "id_producto": p[0], "id_identidad_producto": f"P-{p[0]}", "nombre": p[1], "nombre_producto": p[1],
        "descripcion": p[2], "precio": p[3], "foto": p[4], "foto_platillo": p[4], "disponible": bool(p[5])
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
    return {"status": "ok", "mensaje": "Platillo agregado", "id_producto": id_prod, "id_identidad": f"P-{id_prod}"}

@router.post("/actualizar_producto")
@router.post("/actualizar_producto/")
@router.post("/api/actualizar_producto")
@router.post("/api/actualizar_producto/")
def actualizar_producto(ep: EstadoProducto):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    if ep.foto:
        cursor.execute("""
            UPDATE productos 
            SET disponible = ?, precio = ?, foto_platillo = ? 
            WHERE id_producto = ?
        """, (ep.disponible, ep.precio, ep.foto, ep.id_producto))
    else:
        cursor.execute("""
            UPDATE productos 
            SET disponible = ?, precio = ? 
            WHERE id_producto = ?
        """, (ep.disponible, ep.precio, ep.id_producto))
    conexion.commit()
    conexion.close()
    return {"status": "ok"}

@router.post("/eliminar_producto")
@router.post("/eliminar_producto/")
@router.post("/api/eliminar_producto")
@router.post("/api/eliminar_producto/")
def eliminar_producto(del_req: EliminarProducto):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM productos WHERE id_producto = ?", (del_req.id_producto,))
    conexion.commit()
    conexion.close()
    return {"status": "ok"}

# ========================================================
# 3. DIRECTORIO Y ENDPOINT DE ESTADO BLINDADO CON PREFIJO C
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
        cursor.execute("""
            SELECT foto_platillo FROM productos 
            WHERE id_comercio = ? AND foto_platillo != 'Sin foto' AND foto_platillo != '' 
            LIMIT 3
        """, (id_com,))
        fotos_prods = [row[0] for row in cursor.fetchall()]
        
        resultado.append({
            "id": id_com,
            "id_comercio": id_com,
            "id_identidad": f"C-{id_com}",
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
def cambiar_estado(id_comercio: str, datos: dict):
    try:
        id_limpio = int(id_comercio)
    except ValueError:
        return {"status": "error", "mensaje": "ID de comercio no válido con formato esperado [C-ID]."}

    nuevo_estado = "activo" if datos.get("abierto") else "cerrado"
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT id_comercio, nombre_local FROM comercios WHERE id_comercio = ?", (id_limpio,))
    comercio_encontrado = cursor.fetchone()
    
    if not comercio_encontrado:
        conexion.close()
        return {"status": "error", "mensaje": "Candado de Identidad [C]: Comercio fantasma detectado o ID cruzado de usuario."}
        
    cursor.execute("UPDATE comercios SET estado = ? WHERE id_comercio = ?", (nuevo_estado, id_limpio))
    conexion.commit()
    conexion.close()
    
    return {"status": "ok", "abierto": (nuevo_estado == "activo"), "mensaje": "Estado de categoría C actualizado correctamente"}

@router.get("/billetera/comercio/{id_comercio}")
@router.get("/api/billetera/comercio/{id_comercio}")
def billetera_comercio(id_comercio: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT id_pedido, descripcion, total_pago, fecha_entrega 
        FROM pedidos WHERE id_comercio = ? AND estado = 'entregado' 
        ORDER BY id_pedido DESC
    """, (id_comercio,))
    filas = cursor.fetchall()
    conexion.close()
    ganancia_total = sum([float(r[2] or 5.0) for r in filas])
    return {"ganancia_total": round(ganancia_total, 2), "historial": [{"id_pedido": r[0], "ganancia": float(r[2] or 5.0), "fecha": r[3], "descripcion": r[1]} for r in filas]}