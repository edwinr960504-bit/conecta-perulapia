import urllib.request
import json

print("========================================")
print("🔍 INICIANDO ESCÁNER DE RUTAS FASTAPI")
print("========================================")

try:
    # 1. Escanear la raíz del servidor
    respuesta_raiz = urllib.request.urlopen("http://127.0.0.1:8000/")
    datos_raiz = json.loads(respuesta_raiz.read().decode())
    print("\n✅ [1/2] El servidor en el puerto 8000 está VIVO.")
    print(f"   Mensaje de status de la raíz: '{datos_raiz.get('status', 'No encontrado')}'")
    
    # 2. Escanear el mapa de rutas interno de FastAPI (OpenAPI)
    respuesta_docs = urllib.request.urlopen("http://127.0.0.1:8000/openapi.json")
    datos_docs = json.loads(respuesta_docs.read().decode())
    rutas_activas = datos_docs.get("paths", {}).keys()
    
    endpoint = "/api/admin/clientes_activos"
    
    print(f"\n✅ [2/2] Buscando la ruta fantasma: {endpoint}")
    
    if endpoint in rutas_activas:
        print("\n🎉 ¡EL ENDPOINT EXISTE!")
        print("El código está bien y el servidor lo reconoce. Si la app móvil da error, el problema es el puente USB (adb reverse) o la IP en Flutter.")
    else:
        print("\n🚨 ¡PROBLEMA DETECTADO: EL ENDPOINT NO EXISTE EN LA MEMORIA!")
        print("El servidor que está corriendo ahorita NO TIENE los cambios que hicimos.")
        print("\n👉 CAUSAS PROBABLES:")
        print(" 1. Editaste un archivo duplicado en otra carpeta (ej. tienes un proyecto en Documentos y otro en Descargas).")
        print(" 2. No guardaste los cambios en main.py (Ctrl + S).")
        print(" 3. ¡TIENES UN SERVIDOR ZOMBIE! Una terminal vieja se quedó trabada en el puerto 8000 ejecutando código viejo.")

except Exception as e:
    print(f"\n❌ El servidor está APAGADO o inalcanzable. Detalle: {e}")

print("\n========================================")