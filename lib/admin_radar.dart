// ========================================================
// ARCHIVO: admin_radar.dart (ACTUALIZADO CON CLIENTES ACTIVOS Y DIRECTORIOS)
// ========================================================
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'admin_radar_directorios.dart'; // 🔥 Importación del módulo de la barra inferior

class AdminRadar extends StatefulWidget {
  const AdminRadar({super.key});

  @override
  State<AdminRadar> createState() => _AdminRadarState();
}

class _AdminRadarState extends State<AdminRadar>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LatLng _centroPerulapia = const LatLng(13.7746, -89.0244);

  List<dynamic> _pedidosActivos = [];
  List<dynamic> _comerciosActivos = [];
  List<dynamic> _flotaActiva = []; // Motoristas conectados
  List<dynamic> _clientesActivos = []; // 🔥 NUEVA LISTA DE CLIENTES ACTIVOS

  // 🔥 NUEVAS LISTAS PARA EL MÓDULO INFERIOR
  List<dynamic> _directorioFlota = [];
  List<dynamic> _directorioComercios = [];

  bool _cargandoRadar = true;
  Timer? _timerGlobal;
  late AnimationController _blinkController;

  // 🔥 Muestra la información del local al tocarlo en el mapa
  void _mostrarInfoComercio(Map<String, dynamic> comercio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final logo = comercio['logo']?.toString() ?? '';
        final tieneLogo = logo.isNotEmpty && logo != 'Sin logo';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage:
                        tieneLogo ? NetworkImage("$urlCentral$logo") : null,
                    child: !tieneLogo
                        ? Icon(Icons.store,
                            color: Colors.green.shade800, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comercio['nombre_local'] ?? 'Local',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(comercio['direccion'] ?? 'Sin dirección',
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blueGrey),
                title: const Text("Horario de Atención"),
                subtitle: Text(comercio['horarios'] ?? 'No especificado'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // 🔥 Muestra la información del motorista al tocarlo en el mapa
  void _mostrarInfoMoto(Map<String, dynamic> moto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final foto = moto['foto']?.toString() ?? '';
        final tieneFoto = foto.isNotEmpty && foto != 'Sin foto';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage:
                        tieneFoto ? NetworkImage("$urlCentral$foto") : null,
                    child: !tieneFoto
                        ? Icon(Icons.person,
                            color: Colors.blue.shade800, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(moto['nombre'] ?? 'Motorista',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text("En ruta activa",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.blueGrey),
                title: const Text("Teléfono de Contacto"),
                subtitle: Text(moto['telefono'] ?? 'No disponible'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _cargarCentroDeControl();
    // Actualiza todo el mapa global cada 5 segundos
    _timerGlobal = Timer.periodic(const Duration(seconds: 5), (timer) {
      _cargarCentroDeControl();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _timerGlobal?.cancel();
    super.dispose();
  }

  Future<void> _cargarCentroDeControl() async {
    try {
      final resPedidos =
          await http.get(Uri.parse('$urlCentral/api/admin/radar_despacho'));
      final resComercios =
          await http.get(Uri.parse('$urlCentral/api/comercios_activos'));
      final resFlota = await http
          .get(Uri.parse('$urlCentral/api/admin/flota_global_activa'));
      // 🔥 CARGAMOS CLIENTES ACTIVOS DESDE EL ENDPOINT NUEVO
      final resClientes =
          await http.get(Uri.parse('$urlCentral/api/admin/clientes_activos'));

      // 🔥 Peticiones para los directorios completos en la barra inferior
      final resDirectorioFlota =
          await http.get(Uri.parse('$urlCentral/api/admin/repartidores_admin'));
      final resDirectorioComercios =
          await http.get(Uri.parse('$urlCentral/api/admin/comercios_admin'));

      if (resPedidos.statusCode == 200 && mounted) {
        setState(() {
          _pedidosActivos = json.decode(utf8.decode(resPedidos.bodyBytes));
          if (resComercios.statusCode == 200) {
            _comerciosActivos =
                json.decode(utf8.decode(resComercios.bodyBytes));
          }
          if (resFlota.statusCode == 200) {
            _flotaActiva = json.decode(utf8.decode(resFlota.bodyBytes));
          }
          if (resClientes.statusCode == 200) {
            _clientesActivos = json.decode(utf8.decode(resClientes.bodyBytes));
          }
          if (resDirectorioFlota.statusCode == 200) {
            _directorioFlota =
                json.decode(utf8.decode(resDirectorioFlota.bodyBytes));
          }
          if (resDirectorioComercios.statusCode == 200) {
            _directorioComercios =
                json.decode(utf8.decode(resDirectorioComercios.bodyBytes));
          }

          _cargandoRadar = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoRadar = false);
    }
  }

  Future<void> _matarPedidoFantasma(int idPedido) async {
    final res = await http.post(
      Uri.parse('$urlCentral/api/cancelar_pedido'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_pedido': idPedido}),
    );
    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Pedido eliminado de raíz"),
          backgroundColor: Colors.red));
      Navigator.pop(context); // Cierra el bottom sheet
      _cargarCentroDeControl();
    }
  }

  // 🔥 Despliega la lista de clientes activos al presionar el botón del dashboard
  void _mostrarListaClientes(List<dynamic> clientes) {
    // Filtramos activos e inactivos
    final activos =
        clientes.where((c) => c['activo_buscando'] == true).toList();
    final inactivos =
        clientes.where((c) => c['activo_buscando'] == false).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          padding: const EdgeInsets.only(top: 15),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              const Text("Control de Consumidores",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
              const SizedBox(height: 5),
              // Resumen de cantidades
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BadgeConteo(
                      label: "Activos",
                      cantidad: activos.length,
                      color: Colors.green),
                  const SizedBox(width: 15),
                  _BadgeConteo(
                      label: "Inactivos",
                      cantidad: inactivos.length,
                      color: Colors.grey),
                ],
              ),
              const Divider(height: 25),
              Expanded(
                child: clientes.isEmpty
                    ? const Center(child: Text("No hay clientes registrados"))
                    : ListView.builder(
                        itemCount: clientes.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (ctx, i) {
                          final c = clientes[i];
                          final foto = c['foto']?.toString() ?? '';
                          final tieneFoto =
                              foto.isNotEmpty && foto != 'Sin foto';
                          final bool estaActivo = c['activo_buscando'] ?? false;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.indigo.shade100,
                                    backgroundImage: tieneFoto
                                        ? NetworkImage("$urlCentral$foto")
                                        : null,
                                    child: !tieneFoto
                                        ? const Icon(Icons.person,
                                            color: Color(0xFF1E3A8A))
                                        : null,
                                  ),
                                  // Indicador de punto verde o gris
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: estaActivo
                                            ? Colors.green
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(c['nombre'] ?? 'Cliente',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "Tel: ${c['telefono']}\nCorreo: ${c['correo']}"),
                              trailing: Chip(
                                label: Text(
                                  estaActivo ? "Viendo app" : "Inactivo",
                                  style: TextStyle(
                                      color: estaActivo
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: estaActivo
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      },
    );
  }

  // 🔥 Despliega la lista de pedidos según el filtro seleccionado
  void _mostrarListaPedidos(
      String titulo, List<dynamic> listaFiltrada, Color colorTema) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.only(top: 15),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorTema)),
              Text("${listaFiltrada.length} pedidos en esta fase",
                  style: const TextStyle(color: Colors.grey)),
              const Divider(),
              Expanded(
                child: listaFiltrada.isEmpty
                    ? const Center(
                        child: Text("No hay pedidos en esta categoría"))
                    : ListView.builder(
                        itemCount: listaFiltrada.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (ctx, i) {
                          final p = listaFiltrada[i];
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                side: BorderSide(
                                    color: colorTema.withValues(alpha: 0.5),
                                    width: 1),
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(ctx); // Cierra la lista
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminMapaMonitor(
                                      idPedido: p['id_pedido'],
                                      comercio: p['comercio'] ?? 'Local',
                                      repartidor:
                                          p['repartidor'] ?? 'Sin asignar',
                                      estado: p['estado'] ?? 'pendiente',
                                    ),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor:
                                    colorTema.withValues(alpha: 0.2),
                                child: Icon(Icons.delivery_dining,
                                    color: colorTema),
                              ),
                              title: Text(
                                  "Orden #${p['id_pedido']} - ${p['comercio']}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "Motorista: ${p['repartidor']}\nCliente: ${p['cliente'] ?? 'Desconocido'}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.red),
                                onPressed: () =>
                                    _matarPedidoFantasma(p['id_pedido']),
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Clasificamos los pedidos
    final pendientes =
        _pedidosActivos.where((p) => p['estado'] == 'pendiente').toList();
    final enCocina = _pedidosActivos
        .where((p) =>
            p['estado'] == 'aceptado' ||
            p['estado'] ==
                'preparacion' || // 🔥 Corrección: Cambiado de 'preparando' a 'preparacion'
            p['estado'] == 'listo_recoleccion')
        .toList();
    final enRuta = _pedidosActivos
        .where((p) => p['estado'] == 'asignado' || p['estado'] == 'en_camino')
        .toList();

    List<Marker> marcadoresMapa = [];

    // 🛵 FLOTA DE MOTOS (Ubicación real y Tappable)
    for (var moto in _flotaActiva) {
      double lat = double.tryParse(moto['latitud']?.toString() ?? '0') ?? 0;
      double lon = double.tryParse(moto['longitud']?.toString() ?? '0') ?? 0;

      if (lat != 0 && lon != 0) {
        marcadoresMapa.add(Marker(
          point: LatLng(lat, lon),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _mostrarInfoMoto(moto),
            child: FadeTransition(
              opacity: _blinkController,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4)
                    ]),
                child:
                    const Icon(Icons.motorcycle, color: Colors.white, size: 24),
              ),
            ),
          ),
        ));
      }
    }

// 🏪 COMERCIOS (Animación Inteligente corregida)
    for (var comercio in _comerciosActivos) {
      double lat = double.tryParse(comercio['latitud']?.toString() ?? '0') ?? 0;
      double lon =
          double.tryParse(comercio['longitud']?.toString() ?? '0') ?? 0;

      if (lat != 0 && lon != 0) {
        // Validamos el estado real cruzando el ID con el directorio completo
        bool estaAbierto = false;
        try {
          final infoDir = _directorioComercios.firstWhere(
              (c) =>
                  c['id_comercio'] == comercio['id_comercio'] ||
                  c['id'] == comercio['id_comercio'],
              orElse: () => null);
          if (infoDir != null) {
            estaAbierto =
                infoDir['activo_app'] == true || infoDir['estado'] == 'activo';
          } else {
            estaAbierto = comercio['estado'] == 'activo';
          }
        } catch (_) {
          estaAbierto = comercio['estado'] == 'activo';
        }

        Widget pinComercio = Container(
          decoration: BoxDecoration(
              color: estaAbierto
                  ? Colors.green.shade700
                  : Colors
                      .grey.shade600, // Verde brillante si abre, Gris si cierra
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4)
              ]),
          child: const Icon(Icons.storefront, color: Colors.white, size: 22),
        );

        // 🔥 Forzamos la animación de parpadeo estrictamente para los abiertos
        if (estaAbierto) {
          pinComercio =
              FadeTransition(opacity: _blinkController, child: pinComercio);
        }

        marcadoresMapa.add(Marker(
          point: LatLng(lat, lon),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => _mostrarInfoComercio(comercio),
            child: pinComercio,
          ),
        ));
      }
    }

    // 🛵 FLOTA DE MOTOS (Animación Inteligente)
    for (var moto in _flotaActiva) {
      double lat = double.tryParse(moto['latitud']?.toString() ?? '0') ?? 0;
      double lon = double.tryParse(moto['longitud']?.toString() ?? '0') ?? 0;

      if (lat != 0 && lon != 0) {
        // Determinamos si anda en chinga (en ruta) cruzando con el directorio
        bool enRuta = false;
        try {
          final infoDir = _directorioFlota.firstWhere(
              (m) => m['id_usuario'] == moto['id_repartidor'],
              orElse: () => null);
          if (infoDir != null) enRuta = infoDir['en_ruta'] == true;
        } catch (_) {}

        Widget pinMoto = Container(
          decoration: BoxDecoration(
              color: enRuta
                  ? Colors.blue.shade700
                  : Colors.indigo
                      .shade300, // Azul fuerte si viaja, celeste apagado si espera
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4)
              ]),
          child: const Icon(Icons.motorcycle, color: Colors.white, size: 24),
        );

        // Si anda en pedido, parpadea. Si está esperando viaje en la calle, se queda quieto.
        if (enRuta) {
          pinMoto = FadeTransition(opacity: _blinkController, child: pinMoto);
        }

        marcadoresMapa.add(Marker(
          point: LatLng(lat, lon),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _mostrarInfoMoto(moto),
            child: pinMoto,
          ),
        ));
      }
    }

    // 🛵 FLOTA DE MOTOS (Ubicación real y Tappable)
    for (var moto in _flotaActiva) {
      double lat = double.tryParse(moto['latitud']?.toString() ?? '0') ?? 0;
      double lon = double.tryParse(moto['longitud']?.toString() ?? '0') ?? 0;

      if (lat != 0 && lon != 0) {
        marcadoresMapa.add(Marker(
          point: LatLng(lat, lon),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _mostrarInfoMoto(moto),
            child: FadeTransition(
              opacity: _blinkController,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4)
                    ]),
                child:
                    const Icon(Icons.motorcycle, color: Colors.white, size: 24),
              ),
            ),
          ),
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Centro de Control y Monitoreo"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. EL MAPA GLOBAL
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroPerulapia,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
              ),
              MarkerLayer(markers: marcadoresMapa),
            ],
          ),

          if (_cargandoRadar) const Center(child: CircularProgressIndicator()),

          // 2. DASHBOARD FLOTANTE (ESTADÍSTICAS ARRIBA)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 🔥 NUEVO BOTÓN DE CLIENTES ACTIVOS AL INICIO
                    _DashboardBoton(
                      titulo: "Clientes",
                      cantidad: _clientesActivos.length,
                      color: const Color(0xFF1E3A8A),
                      icono: Icons.group,
                      onTap: () => _mostrarListaClientes(_clientesActivos),
                    ),
                    _DashboardBoton(
                      titulo: "Pendientes",
                      cantidad: pendientes.length,
                      color: Colors.red.shade700,
                      icono: Icons.warning_amber_rounded,
                      onTap: () => _mostrarListaPedidos("Pedidos sin aceptar",
                          pendientes, Colors.red.shade700),
                    ),
                    _DashboardBoton(
                      titulo: "En Cocina",
                      cantidad: enCocina.length,
                      color: Colors.orange.shade700,
                      icono: Icons.soup_kitchen,
                      onTap: () => _mostrarListaPedidos("Preparando en local",
                          enCocina, Colors.orange.shade700),
                    ),
                    _DashboardBoton(
                      titulo: "En Ruta",
                      cantidad: enRuta.length,
                      color: Colors.green.shade700,
                      icono: Icons.motorcycle,
                      onTap: () => _mostrarListaPedidos(
                          "En manos del motorista",
                          enRuta,
                          Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔥 INVOCACIÓN AL MÓDULO INFERIOR (FLOTA Y LOCALES)
          AdminRadarDirectorios(
            flota: _directorioFlota,
            comercios: _directorioComercios,
          ),

          // 3. BOTÓN PARA CENTRAR MAPA
          Positioned(
            right: 15,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: "btnCentrarControl",
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              onPressed: () => _mapController.move(_centroPerulapia, 15.0),
              child: const Icon(Icons.my_location),
            ),
          )
        ],
      ),
    );
  }
}

// Widget auxiliar para los botones del Dashboard
class _DashboardBoton extends StatelessWidget {
  final String titulo;
  final int cantidad;
  final Color color;
  final IconData icono;
  final VoidCallback onTap;

  const _DashboardBoton(
      {required this.titulo,
      required this.cantidad,
      required this.color,
      required this.icono,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icono, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(cantidad.toString(),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(titulo,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
        ],
      ),
    );
  }
}

// 🔥 PANTALLA EXCLUSIVA "MODO DIOS" PARA AUDITORÍA 1 a 1 🔥
class AdminMapaMonitor extends StatefulWidget {
  final int idPedido;
  final String comercio;
  final String repartidor;
  final String estado;

  const AdminMapaMonitor({
    super.key,
    required this.idPedido,
    required this.comercio,
    required this.repartidor,
    required this.estado,
  });

  @override
  State<AdminMapaMonitor> createState() => _AdminMapaMonitorState();
}

class _AdminMapaMonitorState extends State<AdminMapaMonitor> {
  LatLng _ubicacionMotorista = const LatLng(13.7746, -89.0244);
  LatLng _ubicacionDestino = const LatLng(13.7746, -89.0244);

  bool _cargando = true;
  Timer? _timerMonitoreo;
  List<LatLng> _rutaCalles = [];
  String _infoRuta = "Buscando señal GPS...";

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _rastrearPosicionGPS();
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 4), (timer) {
      _rastrearPosicionGPS();
    });
  }

  @override
  void dispose() {
    _timerMonitoreo?.cancel();
    super.dispose();
  }

  Future<void> _rastrearPosicionGPS() async {
    try {
      final url = Uri.parse('$urlCentral/api/obtener_gps/${widget.idPedido}');
      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));

        double latRep =
            double.tryParse(data['latitud_repartidor']?.toString() ?? '0') ??
                0.0;
        double lonRep =
            double.tryParse(data['longitud_repartidor']?.toString() ?? '0') ??
                0.0;

        bool faseRecoleccion =
            widget.estado == 'asignado' || widget.estado == 'aceptado';

        double latDest = double.tryParse(faseRecoleccion
                ? (data['latitud_comercio']?.toString() ?? '0')
                : (data['latitud_cliente']?.toString() ?? '0')) ??
            0.0;

        double lonDest = double.tryParse(faseRecoleccion
                ? (data['longitud_comercio']?.toString() ?? '0')
                : (data['longitud_cliente']?.toString() ?? '0')) ??
            0.0;

        if (latRep != 0.0 && lonRep != 0.0 && latDest != 0.0) {
          LatLng posRep = LatLng(latRep, lonRep);
          LatLng posDest = LatLng(latDest, lonDest);

          const Distance dist = Distance();
          double km = dist.as(LengthUnit.Meter, posRep, posDest) / 1000;
          int minutos = (km * 3).ceil();

          if (mounted) {
            bool primeraCarga = _cargando;
            setState(() {
              _ubicacionMotorista = posRep;
              _ubicacionDestino = posDest;
              _cargando = false;
              _infoRuta = "A ${km.toStringAsFixed(2)} km • Aprox. $minutos min";
            });

            if (primeraCarga) {
              _mapController.move(_ubicacionMotorista, 15.5);
            }

            _trazarRutaWaze();
          }
        }
      }
    } catch (e) {
      debugPrint("Error en auditoría GPS: $e");
    }
  }

  Future<void> _trazarRutaWaze() async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_ubicacionMotorista.longitude},${_ubicacionMotorista.latitude};${_ubicacionDestino.longitude},${_ubicacionDestino.latitude}?geometries=geojson&overview=full');

      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final coordenadasRaw = data['routes'][0]['geometry']['coordinates'];

        List<LatLng> puntos = [];
        for (var coord in coordenadasRaw) {
          puntos.add(LatLng(coord[1], coord[0]));
        }
        if (mounted) {
          setState(() {
            _rutaCalles = puntos;
          });
        }
      }
    } catch (e) {
      debugPrint("Fallo al trazar línea Waze en Admin: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool faseRecoleccion =
        widget.estado == 'asignado' || widget.estado == 'aceptado';
    List<LatLng> puntosRutaFinal = _rutaCalles.isNotEmpty ? _rutaCalles : [];

    return Scaffold(
      appBar: AppBar(
        title: Text("Auditoría: Orden #${widget.idPedido}"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionMotorista,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
              ),
              if (puntosRutaFinal.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: puntosRutaFinal,
                      color: faseRecoleccion
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                      strokeWidth: 6.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacionDestino,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: faseRecoleccion
                            ? Colors.white
                            : Colors.blue.shade800,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: faseRecoleccion
                                ? Colors.orange.shade800
                                : Colors.white,
                            width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4)
                        ],
                      ),
                      child: Icon(
                          faseRecoleccion ? Icons.storefront : Icons.home,
                          color: faseRecoleccion
                              ? Colors.orange.shade800
                              : Colors.white,
                          size: 22),
                    ),
                  ),
                  Marker(
                    point: _ubicacionMotorista,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.two_wheeler,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("MÉTRICAS EN VIVO",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: faseRecoleccion
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(widget.estado.toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: faseRecoleccion
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800,
                                  fontSize: 11)),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text("🛵 Motorista: ${widget.repartidor}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E3A8A))),
                    const SizedBox(height: 4),
                    Text(
                        faseRecoleccion
                            ? "🏪 Recogiendo en: ${widget.comercio}"
                            : "🏠 Entregando a: Cliente",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.speed,
                            color: Colors.blueGrey, size: 18),
                        const SizedBox(width: 5),
                        Text(_infoRuta,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _BadgeConteo extends StatelessWidget {
  final String label;
  final int cantidad;
  final Color color;

  const _BadgeConteo(
      {required this.label, required this.cantidad, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text("$cantidad $label",
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
