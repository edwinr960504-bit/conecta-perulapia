# Admin Core 2.0 para Windows

Este panel privado es una aplicación de escritorio independiente en Python/Tkinter. No forma parte del paquete Flutter móvil, no almacena credenciales ni conserva el token entre ejecuciones. El acceso y los permisos siguen validándose en FastAPI como Superadmin.

## Requisitos

- Windows 10/11.
- Python 3.10 o posterior con Tcl/Tk (la distribución oficial de Python para Windows incluye Tkinter).
- Conexión a internet para cargar las teselas de OpenStreetMap del radar.
- FastAPI ejecutándose con la misma clave `ADMIN_JWT_SECRET` usada para inicializar el Superadmin.

Instala la dependencia del mapa desde la carpeta `admin_desktop`:

```powershell
py -3 -m pip install -r requirements.txt
```

## Iniciar FastAPI

Desde PowerShell, con una clave de firma ya provisionada en el entorno de usuario:

```powershell
Set-Location 'C:\ruta\al\proyecto\conecta_backend'
$env:ADMIN_JWT_SECRET = [Environment]::GetEnvironmentVariable('ADMIN_JWT_SECRET', 'User')
py -3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Mantén esa terminal abierta mientras usas el panel.

`ADMIN_JWT_SECRET` firma los tokens de sesión; no es la contraseña del Superadmin. Si FastAPI responde HTTP 401, verifica el identificador y la contraseña registrados. Si responde HTTP 503 indicando que falta `ADMIN_JWT_SECRET`, establece la variable en la misma terminal antes de iniciar Uvicorn y reinicia el proceso.

## Abrir el panel

En otra terminal:

```powershell
Set-Location 'C:\ruta\al\proyecto\admin_desktop'
py -3 admin_app.py
```

El servidor predeterminado es `http://127.0.0.1:8000`. El panel solo permite HTTP sin cifrar para loopback; para cualquier servidor remoto exige HTTPS. No habilites HTTP externo ni copies la clave de firma al escritorio.

Inicia sesión con el identificador y contraseña de Superadmin. El token se guarda únicamente en la memoria del proceso y se revoca al cerrar sesión. Las operaciones críticas solicitan motivo, muestran confirmación y usan los endpoints auditados del backend.

## Funciones disponibles

- **Diseño de centro de control:** tema azul corporativo, navegación por áreas, contraste de estados, tarjetas de indicadores y tablas filtrables.
- **Radar en vivo:** mapa OpenStreetMap con marcadores para repartidores activos/inactivos, locales activos/inactivos y destinos de pedidos activos, además de contadores directos del backend. Se actualiza cada 15 segundos; al abrir un ticket asociado a pedido, el botón de seguimiento enfoca el mapa en repartidor, cliente y local usando `/api/admin/pedidos/{id}/gps`. OpenStreetMap recibe las solicitudes de teselas de la zona visualizada, pero no los nombres ni los datos del pedido. El backend no informa la antigüedad de cada posición.
- **Bandeja de pedidos:** pendientes, en curso e historial; filtros por estado y búsqueda por ID, comercio, cliente o código. Historial paginado; doble clic abre seguimiento con coordenadas actuales y cronología.
- **Actividad reciente:** eventos de ciclo de pedido y actos administrativos, combinados cronológicamente y actualizados cada 15 segundos mientras se ve esa pestaña.
- **Finanzas:** métricas agregadas disponibles más detalle paginado por pedido (total, método de pago, comisión y tarifa), filtro de fecha y exportación CSV de todos los resultados filtrados.
- **Directorio y soporte:** consulta de usuarios y comercios con ubicaciones registradas y conteos de operación; centro de atención que clasifica los canales de cliente, comercio y repartidor, tanto generales como vinculados a pedido. La bandeja muestra código de rastreo, actor, estado, canal y actividad; las conversaciones abiertas se actualizan cada 3 segundos. Permite saltar desde el expediente a las posiciones del envío y responder como Admin Central con motivo auditado, resolver o archivar el caso.
- **Auditoría y gestión:** bitácora paginada/filtrable, motivo y diff; cambios de estado, archivo, cancelación, acciones masivas y anuncios requieren motivo y confirmación.

Los endpoints `/api/admin/metricas_operativas`, `/api/admin/flota_admin`, `/api/admin/comercios_admin`, `/api/admin/directorio_completo`, `/api/admin/pedidos_historial` y `/api/admin/eventos_pedido` alimentan los contadores, listados, ubicaciones e historial. `/api/admin/tickets_soporte/{id_ticket}/mensajes` consulta y responde el canal asociado a cada expediente, con respuestas auditadas. Las rutas administrativas están protegidas por sesión Superadmin. El cierre de sesión y de la ventana intentan revocar la sesión del servidor.

La base de datos del backend no se modifica directamente desde el cliente de escritorio.
