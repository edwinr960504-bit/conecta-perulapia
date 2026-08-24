# ========================================================
# ARCHIVO: tuberias_identidad.py (COMPLETO Y BLINDADO)
# PROPÓSITO: Autenticación, perfiles de usuario, viajes activos y registros
# ========================================================
from fastapi import APIRouter
from pydantic import BaseModel
import sqlite3
import os

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

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
    id_usuario: int = 1
    telefono: str = ""
    correo: str = ""
    direccion: str = "San dirección"
    nombre: str = None

@router.post("/login")
@router.post("/login/")
@router.post("/api/login")
@router.post("/api/login/")
def login(cred: Credenciales):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT id_usuario, nombre, rol, estado 
        FROM usuarios 
        WHERE (telefono = ? OR correo = ? OR dui = ?) AND contrasena = ?
    """, (cred.identificador, cred.identificador, cred.identificador, cred.contrasena))
    usuario = cursor.fetchone()
    
    if usuario:
        conexion.close()
        if usuario[3] == 'pendiente': return {"status": "error", "mensaje": "Cuenta en revisión por la Central."}
        if usuario[3] == 'suspendido': return {"status": "error", "mensaje": "Cuenta SUSPENDIDA."}
        return {"status": "ok", "id": usuario[0], "nombre": usuario[1], "rol": usuario[2]}
    
    cursor.execute("""
        SELECT id_comercio, nombre_local, estado 
        FROM comercios 
        WHERE (telefono = ? OR correo = ? OR dui = ?) AND contrasena = ?
    """, (cred.identificador, cred.identificador, cred.identificador, cred.contrasena))
    comercio = cursor.fetchone()
    conexion.close()
    
    if comercio:
        if comercio[2] == 'pendiente': return {"status": "error", "mensaje": "Comercio en revisión por la Central."}
        if comercio[2] == 'suspendido': return {"status": "error", "mensaje": "Comercio SUSPENDIDO."}
        return {"status": "ok", "id": comercio[0], "nombre": comercio[1], "rol": "comercio"}
    
    return {"status": "error", "mensaje": "Credenciales incorrectas o cuenta no encontrada."}

@router.post("/registrar_usuario")
@router.post("/registrar_usuario/")
@router.post("/api/registrar_usuario")
@router.post("/api/registrar_usuario/")
def registrar_usuario(usuario: UsuarioNuevo):
    clave_final = usuario.contrasena
    if usuario.password and usuario.password != "123456":
        clave_final = usuario.password

    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT nombre FROM usuarios WHERE telefono = ? OR correo = ?", (usuario.telefono, usuario.correo))
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "Alerta": "El número o correo ya está registrado en el sistema.", "mensaje": "El número o correo ya está registrado en el sistema."}
    
    cursor.execute("""
        INSERT INTO usuarios (
            nombre, telefono, correo, contrasena, rol, dui, 
            direccion, tipo_vehiculo, tarjeta_circulacion, licencia, foto_perfil, estado
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'N/A', 'N/A', 'N/A', ?, 'pendiente')
    """, (usuario.nombre, usuario.telefono, usuario.correo, clave_final, usuario.rol, usuario.dui, usuario.direccion, usuario.foto_perfil))
    
    id_nuevo = cursor.lastrowid
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": f"¡Éxito! {usuario.nombre} registrado correctamente.", "id_usuario": id_nuevo}

@router.post("/registrar_repartidor")
@router.post("/registrar_repartidor/")
@router.post("/api/registrar_repartidor")
@router.post("/api/registrar_repartidor/")
def registrar_repartidor(r: RepartidorNuevo):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    cursor.execute("SELECT nombre FROM usuarios WHERE telefono = ? OR dui = ?", (r.telefono, r.dui))
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "Alerta": "Este repartidor (DUI o Teléfono) ya se encuentra registrado."}
    
    cursor.execute("""
        INSERT INTO usuarios (
            nombre, telefono, correo, contrasena, rol, dui, 
            direccion, tipo_vehiculo, licencia, tarjeta_circulacion, estado
        ) VALUES (?, ?, ?, ?, 'repartidor', ?, ?, ?, ?, ?, 'pendiente')
    """, (r.nombre, r.telefono, r.correo, r.contrasena, r.dui, r.direccion, r.tipo_vehiculo, r.licencia, r.tarjeta_circulacion))
    
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Solicitud de motorista enviada a la Central exitosamente."}

@router.get("/perfil/{id_usuario}")
@router.get("/api/perfil/{id_usuario}")
def obtener_perfil(id_usuario: int):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        SELECT COALESCE(nombre, 'Usuario'), COALESCE(telefono, 'Sin teléfono'), 
               COALESCE(correo, 'Sin correo'), COALESCE(direccion, 'Sin dirección') 
        FROM usuarios WHERE id_usuario = ?
    """, (id_usuario,))
    u = cursor.fetchone()
    conexion.close()
    return {"nombre": u[0], "telefono": u[1], "correo": u[2], "direccion": u[3]} if u else {}

@router.post("/actualizar_contacto")
@router.post("/actualizar_contacto/")
@router.post("/actualizar_perfil/{id_usuario}")
@router.post("/actualizar_perfil/{id_usuario}/")
@router.post("/api/actualizar_contacto")
@router.post("/api/actualizar_contacto/")
@router.post("/api/actualizar_perfil/{id_usuario}")
@router.post("/api/actualizar_perfil/{id_usuario}/")
def actualizar_contacto(datos: ActualizarContacto, id_usuario: int = None):
    target_id = id_usuario if id_usuario else datos.id_usuario
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    if datos.nombre and datos.nombre.strip() != "":
        cursor.execute("""
            UPDATE usuarios 
            SET nombre = ?, telefono = ?, correo = ?, direccion = ? 
            WHERE id_usuario = ?
        """, (datos.nombre, datos.telefono, datos.correo, datos.direccion, target_id))
    else:
        cursor.execute("""
            UPDATE usuarios 
            SET telefono = ?, correo = ?, direccion = ? 
            WHERE id_usuario = ?
        """, (datos.telefono, datos.correo, datos.direccion, target_id))
        
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Datos actualizados correctamente."}

# --- 🔥 ENDPOINT MÁGICO PARA LAS DOS FASES DEL REPARTIDOR ---
@router.get("/viaje_activo/repartidor/{id_repartidor}")
@router.get("/api/viaje_activo/repartidor/{id_repartidor}")
def viaje_repartidor(id_repartidor: int):
    conexion = sqlite3.connect(DB_PATH)
    conexion.row_factory = sqlite3.Row
    cursor = conexion.cursor()
    
    cursor.execute("""
        SELECT p.id_pedido, p.descripcion, p.total_pago, p.distancia_km, p.estado, 
               p.latitud_repartidor, p.longitud_repartidor, p.pin_recoleccion,
               p.numero_diario AS numero_orden, p.codigo_rastreo,
               COALESCE(c.nombre_local, 'Local') AS comercio_nombre,
               COALESCE(c.direccion, 'Centro') AS comercio_direccion,
               COALESCE(u.direccion, 'Dirección no especificada') AS cliente_direccion,
               p.latitud_cliente, p.longitud_cliente,
               13.7333 AS latitud_comercio, -89.1167 AS longitud_comercio
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