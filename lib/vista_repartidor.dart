import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import 'vista_login.dart';
import 'carrito_service.dart';
import 'red.dart';
import 'gps_service.dart';

import 'repa_billetera.dart';
import 'repa_soporte.dart';
import 'repa_perfil.dart';
import 'repa_viajes.dart';

class VistaRepartidor extends StatefulWidget {
  final String nombre;
  final int idUsuario;

  const VistaRepartidor({
    super.key,
    required this.nombre,
    required this.idUsuario,
  });

  @override
  State<VistaRepartidor> createState() => _VistaRepartidorState();
}

class _VistaRepartidorState extends State<VistaRepartidor> {
  int _indiceActual = 0;
  bool _radarActivo = false;

  int _llaveRadar = 0;
  int _llaveViaje = 0;
  int _llaveBilletera = 0;

  @override
  void initState() {
    super.initState();
    _verificarYPedirPermisosGPS();
  }

  Future<void> _verificarYPedirPermisosGPS() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      var resultado = await Permission.location.request();
      if (resultado.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  void _cambiarPestana(int indice) {
    setState(() {
      _indiceActual = indice;
      if (indice == 0) _llaveRadar++;
      if (indice == 1) _llaveViaje++;
      if (indice == 2) _llaveBilletera++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vistas = [
      RepaRadar(
        key: ValueKey(_llaveRadar),
        idRepartidor: widget.idUsuario,
        radarActivo: _radarActivo,
        onCambiarRadar: (v) => setState(() => _radarActivo = v),
        onPedidoAceptado: () {
          setState(() {
            _indiceActual = 1;
            _llaveViaje++;
          });
        },
      ),
      RepaViajes(
        key: ValueKey(_llaveViaje),
        idRepartidor: widget.idUsuario,
      ),
      RepaBilletera(
        key: ValueKey(_llaveBilletera),
        idRepartidor: widget.idUsuario,
      ),
      RepaSoporte(idRepartidor: widget.idUsuario),
    ];

    final titulos = [
      "Radar de Entregas",
      "Viaje Activo",
      "Mi Billetera",
      "Soporte",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_indiceActual],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      drawer: _crearMenuLateral(context),
      body: Stack(
        children: [
          IndexedStack(
            index: _indiceActual,
            children: vistas,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: _cambiarPestana,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F766E),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Viaje'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Billetera'),
          BottomNavigationBarItem(
              icon: Icon(Icons.support_agent), label: 'Soporte'),
        ],
      ),
    );
  }

  Widget _crearMenuLateral(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F766E)),
            accountName: Text(
              widget.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text('Rol: MOTORISTA'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child:
                  Icon(Icons.two_wheeler, size: 40, color: Color(0xFF0F766E)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF0F766E)),
            title: const Text('Mi Perfil / Datos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        RepaPerfil(idRepartidor: widget.idUsuario)),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Cerrar Sesión',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              CarritoService.limpiar();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPantalla()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class RepaRadar extends StatefulWidget {
  final int idRepartidor;
  final bool radarActivo;
  final ValueChanged<bool> onCambiarRadar;
  final VoidCallback onPedidoAceptado;

  const RepaRadar({
    super.key,
    required this.idRepartidor,
    required this.radarActivo,
    required this.onCambiarRadar,
    required this.onPedidoAceptado,
  });

  @override
  State<RepaRadar> createState() => _RepaRadarState();
}

class _RepaRadarState extends State<RepaRadar>
    with SingleTickerProviderStateMixin {
  List<dynamic> _comerciosActivos = [];
  List<dynamic> _pedidosDisponibles = [];
  bool _cargando = false;
  Timer? _temporizador;

  final MapController _mapController = MapController();
  late AnimationController _blinkController;

  final LatLng _centroPerulapia = const LatLng(13.7746, -89.0244);
  LatLng? _miUbicacionReal;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    if (widget.radarActivo) {
      _obtenerMiGPS();
      _cargarBolsa();
    }

    // 🔥 EL MOTOR TURBO A 2 SEGUNDOS 🔥
    _temporizador = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (widget.radarActivo && mounted) {
        _obtenerMiGPS();
        _cargarBolsa();
      }
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _obtenerMiGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high));
        if (mounted) {
          setState(() {
            _miUbicacionReal = LatLng(pos.latitude, pos.longitude);
          });
        }
      }
    } catch (e) {
      debugPrint("Error sacando GPS real: $e");
    }
  }

  Future<void> _cargarBolsa() async {
    if (!mounted) return;
    try {
      final resComercios =
          await http.get(Uri.parse('$urlCentral/api/comercios_activos'));
      final resPedidos =
          await http.get(Uri.parse('$urlCentral/api/pedidos_disponibles'));

      if (resComercios.statusCode == 200 &&
          resPedidos.statusCode == 200 &&
          mounted) {
        setState(() {
          _comerciosActivos = json.decode(utf8.decode(resComercios.bodyBytes));
          _pedidosDisponibles = json.decode(utf8.decode(resPedidos.bodyBytes));
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error de radar: $e");
    }
  }

  LatLng _generarCoordenadaLocal(String nombreLocal, int baseId) {
    int hash = nombreLocal.codeUnits.fold(0, (a, b) => a + b);
    double latOffset = ((hash % 15) - 7) * 0.0004;
    double lonOffset = ((baseId % 15) - 7) * 0.0004;
    return LatLng(_centroPerulapia.latitude + latOffset,
        _centroPerulapia.longitude + lonOffset);
  }

  void _zoomIn() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual + 1.0);
  }

  void _zoomOut() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual - 1.0);
  }

  void _mostrarDetallePedido(Map<String, dynamic> pedido) {
    double distanciaAprox = 0.0;
    if (_miUbicacionReal != null) {
      final ubicacionLocal = _generarCoordenadaLocal(
          pedido['negocio'] ?? 'Local', pedido['id_pedido'] ?? 1);
      const Distance dist = Distance();
      distanciaAprox =
          dist.as(LengthUnit.Meter, _miUbicacionReal!, ubicacionLocal) / 1000;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.fastfood,
                        color: Colors.orange.shade800, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "Orden #${pedido['numero_orden'] ?? pedido['id_pedido']}",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Recoger en: ${pedido['negocio'] ?? 'Local'}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Ganancia",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text("\$${pedido['ganancia_envio']}",
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                children: [
                  const Icon(Icons.directions_bike,
                      color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                      _miUbicacionReal != null
                          ? "Estás a ${distanciaAprox.toStringAsFixed(2)} km del restaurante"
                          : "Distancia al cliente: ${pedido['distancia_km']} km",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                      pedido['estado'] == 'pendiente'
                          ? Icons.access_time
                          : (pedido['estado'] == 'listo_recoleccion'
                              ? Icons.check_circle
                              : Icons.soup_kitchen),
                      color: pedido['estado'] == 'pendiente'
                          ? Colors.red
                          : (pedido['estado'] == 'listo_recoleccion'
                              ? Colors.green
                              : Colors.orange),
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                      pedido['estado'] == 'pendiente'
                          ? "Esperando confirmación del local"
                          : (pedido['estado'] == 'listo_recoleccion'
                              ? "¡Comida Lista para recoger!"
                              : "Cocinando (En preparación)"),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.touch_app, color: Colors.white),
                  label: const Text("ACEPTAR ESTE VIAJE",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  onPressed: () => _tomarPedido(pedido['id_pedido']),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _tomarPedido(int idPedido) async {
    try {
      final res = await http.post(
        Uri.parse('$urlCentral/api/tomar_pedido'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
            {'id_pedido': idPedido, 'id_repartidor': widget.idRepartidor}),
      );

      if (res.statusCode == 200) {
        final respuesta = json.decode(utf8.decode(res.bodyBytes));
        if (respuesta['status'] == 'ok') {
          await GpsService.enviarUbicacion(idPedido);
          GpsService.iniciarLatidosGps(idPedido);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("¡VIAJE ACEPTADO!"),
                  backgroundColor: Colors.green),
            );
            widget.onPedidoAceptado();
          }
        } else {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(respuesta['mensaje'] ?? "Error"),
                  backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error al aceptar viaje: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> marcadoresMapa = [];

    if (widget.radarActivo) {
      marcadoresMapa = _comerciosActivos.map((comercio) {
        final id = comercio['id_comercio'] ?? 1;
        final nombre = comercio['nombre_local'] ?? '';
        final ubicacion = _generarCoordenadaLocal(nombre, id);
        bool tienePedido =
            _pedidosDisponibles.any((p) => p['negocio'] == nombre);

        if (tienePedido) {
          return Marker(point: ubicacion, child: const SizedBox());
        }

        return Marker(
          point: ubicacion,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ],
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 20),
          ),
        );
      }).toList();

      for (var pedido in _pedidosDisponibles) {
        final nombre = pedido['negocio'] ?? 'Local';
        final ubicacion =
            _generarCoordenadaLocal(nombre, pedido['id_pedido'] ?? 1);
        marcadoresMapa.add(
          Marker(
            point: ubicacion,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _mostrarDetallePedido(pedido),
              child: FadeTransition(
                opacity: _blinkController,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.redAccent,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ],
                  ),
                  child: const Icon(Icons.monetization_on,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        );
      }

      if (_miUbicacionReal != null) {
        marcadoresMapa.add(
          Marker(
            point: _miUbicacionReal!,
            width: 45,
            height: 45,
            child: FadeTransition(
              opacity: _blinkController,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 6)
                  ],
                ),
                child: const Icon(Icons.two_wheeler,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          color: widget.radarActivo ? Colors.green.shade50 : Colors.red.shade50,
          child: SwitchListTile(
            title: Text(
                widget.radarActivo ? "RADAR ACTIVO" : "FUERA DE SERVICIO",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.radarActivo
                        ? Colors.green.shade800
                        : Colors.red.shade800)),
            subtitle: Text(widget.radarActivo
                ? "Escaneando Perulapía en vivo..."
                : "Enciende el radar para ver el mapa"),
            value: widget.radarActivo,
            activeThumbColor: Colors.green,
            onChanged: (val) {
              widget.onCambiarRadar(val);
              if (val) {
                setState(() => _cargando = true);
                _obtenerMiGPS();
                _cargarBolsa();
              } else {
                setState(() => _pedidosDisponibles = []);
              }
            },
          ),
        ),
        Expanded(
          child: !widget.radarActivo
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar_outlined, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Activa el radar para buscar viajes",
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _miUbicacionReal ?? _centroPerulapia,
                        initialZoom: 16.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.perulapia_connect',
                        ),
                        MarkerLayer(markers: marcadoresMapa),
                      ],
                    ),
                    if (_cargando)
                      const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF0F766E))),

                    // Botones de Zoom y Centrar GPS
                    Positioned(
                      bottom: 180,
                      right: 15,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: "btnZoomInRadarMain",
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F766E),
                            elevation: 4,
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 6),
                          FloatingActionButton(
                            heroTag: "btnZoomOutRadarMain",
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F766E),
                            elevation: 4,
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton(
                            heroTag: "btnCentroRadarPrincipal",
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            onPressed: () {
                              if (_miUbicacionReal != null) {
                                _mapController.move(_miUbicacionReal!, 16.5);
                              } else {
                                _mapController.move(_centroPerulapia, 16.0);
                              }
                            },
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),

                    // Lista de tarjetas horizontal
                    if (_pedidosDisponibles.isNotEmpty)
                      Positioned(
                        bottom: 15,
                        left: 0,
                        right: 0,
                        height: 155,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _pedidosDisponibles.length,
                          itemBuilder: (ctx, i) {
                            final p = _pedidosDisponibles[i];
                            return Container(
                              width: 320,
                              margin: const EdgeInsets.only(right: 10),
                              child: Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              "Orden #${p['numero_orden'] ?? p['id_pedido']}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          Text("\$${p['ganancia_envio']}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.green)),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text("📍 ${p['negocio'] ?? 'Local'}",
                                          style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          "🛵 A ${p['distancia_km']} km del cliente",
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                      const Spacer(),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 40,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0F766E),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: () =>
                                              _mostrarDetallePedido(p),
                                          child: const Text("VER DETALLES",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
