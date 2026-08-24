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