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

# Ejecutar al arrancar el servidor principal
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