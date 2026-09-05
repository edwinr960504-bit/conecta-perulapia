# ========================================================
# ARCHIVO COMPLETO: tuberias_identidad.py (BLINDADO CON PREFIJOS Y MAPAS REALES)
# PROPÓSITO: Autenticación, perfiles de usuario, viajes activos y registros
# ========================================================
from fastapi import APIRouter, UploadFile, File, Form
from pydantic import BaseModel
import sqlite3
import os
import shutil

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

# 🔥 AUTO-REPARADOR DE BASE DE DATOS: Asegura las columnas de latitud y longitud en la tabla comercios
def asegurar_columnas_mapa():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN latitud REAL DEFAULT 13.7746")
        except Exception: pass
        try: cursor.execute("ALTER TABLE comercios ADD COLUMN longitud REAL DEFAULT -89.0244")
        except Exception: pass
        conn.commit()
        conn.close()
    except Exception:
        pass

asegurar_columnas_mapa()

class Credenciales(BaseModel):
    identificador: str
    contrasena: str

class UsuarioNuevo(BaseModel):
    nombre: str
    telefono: str
    correo: str
    contrasena: str = "123456"
    password: str = None
    rol: str = "cliente"
    dui: str = "00000000-0"
    direccion: str = "San Bartolomé Perulapía"
    foto_perfil: str = "Sin foto"

class RepartidorNuevo(BaseModel):
    nombre: str
    telefono: str
    correo: str
    contrasena: str
    dui: str
    direccion: str
    tipo_vehiculo: str
    licencia: str
    tarjeta_circulacion: str

class ActualizarContacto(BaseModel):
    id_usuario: int 
    telefono: str = ""
    correo: str = ""
    direccion: str = "Sin dirección"
    nombre: str = None

@router.post("/login")
@router.post("/login/")
@router.post("/api/login")
@router.post("/api/login/")
def login(cred: Credenciales):
    identificador_limpio = cred.identificador.strip().lower()
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    # 1. Buscar en usuarios (Clientes o Repartidores)
    cursor.execute("""
        SELECT id_usuario, nombre, rol, estado 
        FROM usuarios 
        WHERE (telefono = ? OR LOWER(correo) = ? OR dui = ?) AND contrasena = ?
    """, (identificador_limpio, identificador_limpio, identificador_limpio, cred.contrasena))
    usuario = cursor.fetchone()
    
    if usuario:
        conexion.close()
        if usuario[3] == 'pendiente': return {"status": "error", "mensaje": "Cuenta en revisión por la Central."}
        if usuario[3] == 'suspendido': return {"status": "error", "mensaje": "Cuenta SUSPENDIDA."}
        
        # Asignación de prefijo de identidad según rol ('U' para usuario/cliente, 'R' para repartidor)
        prefijo_rol = "R" if usuario[2] == "repartidor" else "U"
        return {
            "status": "ok", 
            "id": usuario[0], 
            "id_identidad": f"{prefijo_rol}-{usuario[0]}",
            "nombre": usuario[1], 
            "rol": usuario[2]
        }
    
    # 2. Buscar en comercios
    cursor.execute("""
        SELECT id_comercio, nombre_local, estado 
        FROM comercios 
        WHERE (telefono = ? OR LOWER(correo) = ? OR dui = ?) AND contrasena = ?
    """, (identificador_limpio, identificador_limpio, identificador_limpio, cred.contrasena))
    comercio = cursor.fetchone()
    conexion.close()
    
    if comercio:
        if comercio[2] == 'pendiente': return {"status": "error", "mensaje": "Comercio en revisión por la Central."}
        if comercio[2] == 'suspendido': return {"status": "error", "mensaje": "Comercio SUSPENDIDO."}
        
        # Asignación de prefijo 'C' estricto para comercios
        return {
            "status": "ok", 
            "id": comercio[0], 
            "id_identidad": f"C-{comercio[0]}",
            "nombre": comercio[1], 
            "rol": "comercio"
        }
    
    return {"status": "error", "mensaje": "Credenciales incorrectas o cuenta no encontrada."}

@router.post("/registrar_usuario")
@router.post("/registrar_usuario/")
@router.post("/api/registrar_usuario")
@router.post("/api/registrar_usuario/")
def registrar_usuario(usuario: UsuarioNuevo):
    clave_final = usuario.contrasena
    if usuario.password and usuario.password != "123456":
        clave_final = usuario.password

    tel_limpio = usuario.telefono.strip()
    correo_limpio = usuario.correo.strip().lower()

    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT nombre FROM usuarios WHERE telefono = ? OR LOWER(correo) = ?", (tel_limpio, correo_limpio))
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "Alerta": "El número o correo ya está registrado en el sistema.", "mensaje": "El número o correo ya está registrado."}
    
    cursor.execute("SELECT nombre_local FROM comercios WHERE telefono = ? OR LOWER(correo) = ?", (tel_limpio, correo_limpio))
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "Alerta": "Este teléfono o correo pertenece a un Comercio.", "mensaje": "Dato en uso por un negocio."}
    
    cursor.execute("""
        INSERT INTO usuarios (
            nombre, telefono, correo, contrasena, rol, dui, 
            direccion, tipo_vehiculo, tarjeta_circulacion, licencia, foto_perfil, estado
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'N/A', 'N/A', 'N/A', ?, 'pendiente')
    """, (usuario.nombre, tel_limpio, correo_limpio, clave_final, usuario.rol, usuario.dui, usuario.direccion, usuario.foto_perfil))
    
    id_nuevo = cursor.lastrowid
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": f"¡Éxito! {usuario.nombre} registrado correctamente.", "id_usuario": id_nuevo, "id_identidad": f"U-{id_nuevo}"}

@router.post("/registrar_repartidor")
@router.post("/registrar_repartidor/")
@router.post("/api/registrar_repartidor")
@router.post("/api/registrar_repartidor/")
def registrar_repartidor(r: RepartidorNuevo):
    tel_limpio = r.telefono.strip()
    correo_limpio = r.correo.strip().lower()
    
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT nombre FROM usuarios WHERE telefono = ? OR dui = ?", (tel_limpio, r.dui))
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "Alerta": "Este repartidor (DUI o Teléfono) ya se encuentra registrado."}
    
    cursor.execute("SELECT nombre_local FROM comercios WHERE telefono = ? OR LOWER(correo) = ?", (tel_limpio, correo_limpio))
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "Alerta": "Ese teléfono o correo pertenece a un negocio activo."}
    
    cursor.execute("""
        INSERT INTO usuarios (
            nombre, telefono, correo, contrasena, rol, dui, 
            direccion, tipo_vehiculo, licencia, tarjeta_circulacion, estado
        ) VALUES (?, ?, ?, ?, 'repartidor', ?, ?, ?, ?, ?, 'pendiente')
    """, (r.nombre, tel_limpio, r.correo, r.contrasena, r.dui, r.direccion, r.tipo_vehiculo, r.licencia, r.tarjeta_circulacion))
    
    id_nuevo = cursor.lastrowid
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Solicitud de motorista enviada a la Central exitosamente.", "id_identidad": f"R-{id_nuevo}"}

@router.get("/perfil/{id_usuario}")
@router.get("/api/perfil/{id_usuario}")
def obtener_perfil(id_usuario: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT COALESCE(nombre, 'Usuario'), COALESCE(telefono, 'Sin teléfono'), 
               COALESCE(correo, 'Sin correo'), COALESCE(direccion, 'Sin dirección'),
               COALESCE(foto_perfil, 'Sin foto')
        FROM usuarios WHERE id_usuario = ?
    """, (id_usuario,))
    u = cursor.fetchone()
    conexion.close()
    return {"nombre": u[0], "telefono": u[1], "correo": u[2], "direccion": u[3], "foto_perfil": u[4]} if u else {}

@router.post("/actualizar_contacto")
@router.post("/actualizar_contacto/")
@router.post("/api/actualizar_contacto")
@router.post("/api/actualizar_contacto/")
def actualizar_contacto(datos: ActualizarContacto, id_usuario: int = None):
    target_id = id_usuario if id_usuario else datos.id_usuario
    if not target_id or target_id <= 0:
        return {"status": "error", "mensaje": "Error de identidad. Cierre sesión e intente de nuevo."}
        
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    if datos.nombre and datos.nombre.strip() != "":
        cursor.execute("UPDATE usuarios SET nombre = ?, telefono = ?, correo = ?, direccion = ? WHERE id_usuario = ?", (datos.nombre, datos.telefono, datos.correo, datos.direccion, target_id))
    else:
        cursor.execute("UPDATE usuarios SET telefono = ?, correo = ?, direccion = ? WHERE id_usuario = ?", (datos.telefono, datos.correo, datos.direccion, target_id))
        
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Datos actualizados correctamente en su perfil privado."}

@router.post("/subir_foto_cliente")
@router.post("/subir_foto_cliente/")
@router.post("/api/subir_foto_cliente")
@router.post("/api/subir_foto_cliente/")
async def subir_foto_cliente(id_cliente: str = Form(...), file: UploadFile = File(...)):
    ruta_carpeta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fotos_seguridad")
    os.makedirs(ruta_carpeta, exist_ok=True)
    nombre_archivo = f"cliente_{id_cliente}_{file.filename}"
    ruta_destino = os.path.join(ruta_carpeta, nombre_archivo)
    
    with open(ruta_destino, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    url_relativa = f"/fotos_seguridad/{nombre_archivo}"
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("UPDATE usuarios SET foto_perfil = ? WHERE id_usuario = ?", (url_relativa, id_cliente))
    conexion.commit()
    conexion.close()
    return {"status": "ok", "url": url_relativa}

@router.get("/viaje_activo/repartidor/{id_repartidor}")
@router.get("/api/viaje_activo/repartidor/{id_repartidor}")
def viaje_repartidor(id_repartidor: int):
    conexion = sqlite3.connect(DB_PATH)
    conexion.row_factory = sqlite3.Row
    cursor = conexion.cursor()
    
    # 🔥 CONSULTA ACTUALIZADA: Lee las coordenadas reales y actualizadas del comercio desde la tabla comercios[cite: 16]
    cursor.execute("""
        SELECT p.id_pedido, p.descripcion, p.total_pago, p.distancia_km, p.estado, 
               p.latitud_repartidor, p.longitud_repartidor, p.pin_recoleccion,
               p.numero_diario AS numero_orden, p.codigo_rastreo,
               COALESCE(c.nombre_local, 'Local') AS comercio_nombre,
               COALESCE(c.direccion, 'Centro') AS comercio_direccion,
               COALESCE(u.direccion, 'Dirección no especificada') AS cliente_direccion,
               p.latitud_cliente, p.longitud_cliente,
               COALESCE(c.latitud, p.latitud_comercio, 13.7333) AS latitud_comercio, 
               COALESCE(c.longitud, p.longitud_comercio, -89.1167) AS longitud_comercio
        FROM pedidos p 
        LEFT JOIN comercios c ON p.id_comercio = c.id_comercio
        LEFT JOIN usuarios u ON p.id_cliente = u.id_usuario
        WHERE p.id_repartidor = ? AND p.estado IN ('asignado', 'en_camino')
        ORDER BY p.id_pedido DESC LIMIT 1
    """, (id_repartidor,))
    viaje = cursor.fetchone()
    conexion.close()
    
    if not viaje:
        return {"status": "ok", "tiene_viaje": False, "viaje": None}
    return {"status": "ok", "tiene_viaje": True, "viaje": dict(viaje)}