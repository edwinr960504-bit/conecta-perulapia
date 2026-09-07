# ========================================================
# ARCHIVO: main.py
# PROPÓSITO: Servidor Central y Director de Tráfico de Conecta Perulapía
# CONECTA CON: Streamlit (Panel Central), Flutter (App Clientes/Motoristas)
# ========================================================
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import os

# --- IMPORTACIÓN DE LAS 5 TUBERÍAS MAESTRAS ---
import tuberias_pedidos
import tuberias_logistica  # <- ¡NUEVA TUBERÍA DE MOTORISTAS Y PINES!
import tuberias_admin
import tuberias_identidad
import tuberias_negocio
import adm_soporte
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")

def inicializar_base_maestra():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    # 1. Tabla de Usuarios (Clientes y Repartidores)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            telefono TEXT,
            correo TEXT,
            contrasena TEXT,
            rol TEXT,
            dui TEXT,
            direccion TEXT,
            tipo_vehiculo TEXT DEFAULT 'N/A',
            licencia TEXT DEFAULT 'N/A',
            tarjeta_circulacion TEXT DEFAULT 'N/A',
            foto_perfil TEXT DEFAULT 'Sin foto',
            estado TEXT DEFAULT 'pendiente'
        )
    """)
    
    # 2. Tabla de Comercios
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS comercios (
            id_comercio INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre_local TEXT,
            telefono TEXT,
            correo TEXT,
            contrasena TEXT,
            direccion TEXT,
            tipo_plan TEXT,
            logo TEXT,
            estado TEXT DEFAULT 'pendiente',
            fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # 3. Tabla de Pedidos Principal
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS pedidos (
            id_pedido INTEGER PRIMARY KEY AUTOINCREMENT,
            id_cliente INTEGER,
            id_comercio INTEGER,
            descripcion TEXT,
            precio_comida REAL,
            tarifa_envio REAL,
            comision_app REAL,
            total_pago REAL,
            distancia_km REAL,
            pin_seguridad TEXT,
            pin_recoleccion TEXT,
            codigo_rastreo TEXT,
            metodo_pago TEXT,
            estado TEXT DEFAULT 'pendiente',
            id_repartidor INTEGER DEFAULT 0,
            latitud_repartidor REAL DEFAULT 0.0,
            longitud_repartidor REAL DEFAULT 0.0,
            latitud_cliente REAL DEFAULT 13.7333,
            longitud_cliente REAL DEFAULT -89.1167,
            tiempo_preparacion TEXT DEFAULT 'Por confirmar',
            numero_diario INTEGER DEFAULT 1,
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            fecha_entrega TEXT
        )
    """)
    
    # 4. Tabla de Productos del Menú
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS productos (
            id_producto INTEGER PRIMARY KEY AUTOINCREMENT,
            id_comercio INTEGER,
            nombre_producto TEXT,
            descripcion TEXT,
            precio REAL,
            foto_platillo TEXT,
            disponible INTEGER DEFAULT 1
        )
    """)
    
    conexion.commit()
    conexion.close()

# Ejecutar al arrancar el servidor principal con persistencia absoluta
inicializar_base_maestra()

# --- CREACIÓN DE LA APLICACIÓN PRINCIPAL ---
app = FastAPI(
    title="Backend Central Conecta Perulapía",
    description="Servidor modular blindado para comercios, repartidores y clientes de San Bartolomé Perulapía",
    version="2.2 - Edición Logística Completa"
)

# --- BLINDAJE CORS (Permite connections entrantes desde WiFi, Flutter y Streamlit sin bloqueos) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- ADUANA DE ARCHIVOS ESTÁTICOS 1 (Para fotos de platillos y documentos) ---
RUTA_FOTOS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fotos_seguridad")
if not os.path.exists(RUTA_FOTOS):
    os.makedirs(RUTA_FOTOS, exist_ok=True)

app.mount("/fotos_seguridad", StaticFiles(directory=RUTA_FOTOS), name="fotos")

# --- 🔥 ADUANA DE ARCHIVOS ESTÁTICOS 2 (Para el chat multimedia: audios y fotos) 🔥 ---
RUTA_CHAT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
os.makedirs(RUTA_CHAT, exist_ok=True)

app.mount("/static", StaticFiles(directory=RUTA_CHAT), name="static_chat")

# --- CONEXIÓN DE ROUTERS (Las arterias del sistema) ---
app.include_router(tuberias_pedidos.router)
app.include_router(tuberias_logistica.router)  
app.include_router(tuberias_admin.router)
app.include_router(tuberias_identidad.router)
app.include_router(tuberias_negocio.router)
app.include_router(adm_soporte.router)

# ========================================================
# ENDPOINTS DE CONTROL Y MONITOREO
# ========================================================

# ========================================================
# ENDPOINT INYECTADO DIRECTAMENTE (CLIENTES ACTIVOS)
# ========================================================
@app.get("/api/admin/clientes_activos")
def clientes_activos_admin():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    
    # 1. Obtenemos a todos los clientes registrados
    cursor.execute("""
        SELECT id_usuario, COALESCE(nombre, 'Cliente'), 
               COALESCE(telefono, 'Sin teléfono'), COALESCE(correo, 'Sin correo'),
               COALESCE(foto_perfil, 'Sin foto'), COALESCE(estado, 'activo')
        FROM usuarios
        WHERE LOWER(rol) = 'cliente'
    """)
    filas = cursor.fetchall()
    
    # 2. Consultamos quiénes tienen un pedido activo
    cursor.execute("""
        SELECT DISTINCT id_cliente FROM pedidos 
        WHERE estado NOT IN ('entregado', 'cancelado', 'archivado')
    """)
    con_pedido_activo = {row[0] for row in cursor.fetchall()}
    conexion.close()
    
    resultado = []
    for r in filas:
        id_usu = r[0]
        es_activo = id_usu in con_pedido_activo or r[5] == 'activo'
        
        resultado.append({
            "id_usuario": id_usu,
            "nombre": r[1],
            "telefono": r[2],
            "correo": r[3],
            "foto": r[4],
            "activo_buscando": es_activo
        })
        
    return resultado

@app.get("/")
def raiz():
    return {
        "status": "Online",
        "sistema": "Conecta Perulapía - Backend Maestro",
        "modulos_activos": [
            "Pedidos y Cocina (tuberias_pedidos)",
            "Logística, PINes y Motoristas (tuberias_logistica)",
            "Cabina de Control y Finanzas (tuberias_admin)",
            "Identidad y Seguridad (tuberias_identidad)",
            "Menús y Comercios (tuberias_negocio)",
            "Soporte y Chat Multimedia (adm_soporte)"
        ],
        "compatibilidad_movil": "Activa (Soporte dual con y sin /api/)"
    }

@app.get("/ping")
@app.get("/api/ping")
def ping():
    return {"ping": "pong", "conexion": "estable"}
# ========================================================
# ENDPOINTS INYECTADOS DIRECTAMENTE (TROPAS Y LOCALES)
# ========================================================
@app.get("/api/admin/repartidores_admin")
def repartidores_admin_lista():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    # Traemos a todos los motoristas registrados
    cursor.execute("""
        SELECT id_usuario, COALESCE(nombre, 'Motorista'), 
               COALESCE(telefono, 'Sin teléfono'), COALESCE(foto_perfil, 'Sin foto'),
               COALESCE(estado, 'inactivo')
        FROM usuarios
        WHERE LOWER(rol) IN ('repartidor', 'motorista')
    """)
    filas = cursor.fetchall()
    
    # Revisamos si están ocupados en un pedido actualmente
    cursor.execute("SELECT DISTINCT id_repartidor FROM pedidos WHERE estado IN ('asignado', 'en_camino')")
    ocupados = {row[0] for row in cursor.fetchall()}
    conexion.close()
    
    resultado = []
    for r in filas:
        id_rep = r[0]
        es_activo = r[4] == 'activo'
        en_ruta = id_rep in ocupados
        
        resultado.append({
            "id_usuario": id_rep,
            "nombre": r[1],
            "telefono": r[2],
            "foto": r[3],
            "activo_app": es_activo,
            "en_ruta": en_ruta
        })
    return resultado
from pydantic import BaseModel
import sqlite3

# --- AUTO-PARCHE DE BASE DE DATOS ---
def preparar_gps_flota():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    # Añadimos las columnas de GPS a los usuarios si no existen
    try: cursor.execute("ALTER TABLE usuarios ADD COLUMN latitud_actual REAL DEFAULT 0.0")
    except: pass
    try: cursor.execute("ALTER TABLE usuarios ADD COLUMN longitud_actual REAL DEFAULT 0.0")
    except: pass
    conexion.commit()
    conexion.close()

preparar_gps_flota()

# --- MODELO RECEPTOR ---
class GpsMotoristaVivo(BaseModel):
    id_usuario: int
    latitud: float
    longitud: float

# --- ENDPOINT 1: RECEPTOR DE LA APP DEL MOTORISTA ---
@app.post("/api/motorista/actualizar_gps_vivo")
def actualizar_gps_vivo(datos: GpsMotoristaVivo):
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    cursor.execute("""
        UPDATE usuarios 
        SET latitud_actual = ?, longitud_actual = ? 
        WHERE id_usuario = ?
    """, (datos.latitud, datos.longitud, datos.id_usuario))
    conexion.commit()
    conexion.close()
    return {"status": "ok"}

# --- ENDPOINT 2: EMISOR PARA EL RADAR (MODO DIOS) ---
@app.get("/api/admin/flota_global_activa")
def flota_global_activa():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    # Traemos a TODOS los motoristas que estén "activos", tengan pedido o no
    cursor.execute("""
        SELECT id_usuario, latitud_actual, longitud_actual, 
               nombre, COALESCE(foto_perfil, 'Sin foto'), COALESCE(telefono, 'Sin teléfono')
        FROM usuarios
        WHERE LOWER(rol) IN ('repartidor', 'motorista') 
          AND estado = 'activo'
          AND latitud_actual != 0.0
    """)
    flota = cursor.fetchall()
    conexion.close()
    
    return [{
        "id_repartidor": r[0], 
        "latitud": r[1], 
        "longitud": r[2], 
        "nombre": r[3],
        "foto": r[4],
        "telefono": r[5]
    } for r in flota]

@app.get("/api/admin/comercios_admin")
def comercios_admin_lista():
    conexion = sqlite3.connect(DB_PATH)
    cursor = conexion.cursor()
    # Traemos a todos los negocios
    cursor.execute("""
        SELECT id_comercio, COALESCE(nombre_local, 'Comercio'), 
               COALESCE(telefono, 'Sin teléfono'), COALESCE(logo, 'Sin logo'),
               COALESCE(estado, 'cerrado')
        FROM comercios
    """)
    filas = cursor.fetchall()
    conexion.close()
    
    resultado = []
    for r in filas:
        resultado.append({
            "id_comercio": r[0],
            "nombre": r[1],
            "telefono": r[2],
            "foto": r[3],
            "activo_app": r[4] == 'activo'
        })
    return resultado