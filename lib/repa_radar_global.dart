import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';

class RadarGlobalScreen extends StatefulWidget {
  final int idRepartidor;

  const RadarGlobalScreen({
    super.key,
    required this.idRepartidor,
  });

  @override
  State<RadarGlobalScreen> createState() => _RadarGlobalScreenState();
}

class _RadarGlobalScreenState extends State<RadarGlobalScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _comerciosActivos = [];
  List<dynamic> _pedidosDisponibles = [];
  bool _cargando = true;
  Timer? _timerRadar;

  final MapController _mapController = MapController();
  late AnimationController _blinkController;

  final LatLng _centroPerulapia = const LatLng(13.7746, -89.0244);

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _escanearRadar();
    _timerRadar = Timer.periodic(const Duration(seconds: 4), (timer) {
      _escanearRadar();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _timerRadar?.cancel();
    super.dispose();
  }

  Future<void> _escanearRadar() async {
    try {
      final resComercios =
          await http.get(Uri.parse('$urlCentral/api/comercios_activos'));
      final resPedidos =
          await http.get(Uri.parse('$urlCentral/api/pedidos_disponibles'));

      if (resComercios.statusCode == 200 && resPedidos.statusCode == 200) {
        if (mounted) {
          setState(() {
            _comerciosActivos =
                json.decode(utf8.decode(resComercios.bodyBytes));
            _pedidosDisponibles =
                json.decode(utf8.decode(resPedidos.bodyBytes));
            _cargando = false;
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error escaneando el radar: $e");
    }
  }

  LatLng _generarCoordenadaLocal(String nombreLocal, int baseId) {
    int hash = nombreLocal.codeUnits.fold(0, (a, b) => a + b);
    double latOffset = ((hash % 15) - 7) * 0.0007;
    double lonOffset = ((baseId % 15) - 7) * 0.0007;
    return LatLng(_centroPerulapia.latitude + latOffset,
        _centroPerulapia.longitude + lonOffset);
  }

  Future<void> _aceptarViaje(int idPedido) async {
    try {
      final res = await http.post(
        Uri.parse('$urlCentral/api/tomar_pedido'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_pedido': idPedido,
          'id_repartidor': widget.idRepartidor,
        }),
      );

      if (res.statusCode == 200) {
        final respuesta = json.decode(utf8.decode(res.bodyBytes));
        if (respuesta['status'] == 'ok') {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "¡VIAJE ACEPTADO! Ve a la pestaña 'Viaje' para iniciar la ruta."),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
            _escanearRadar();
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

  void _mostrarDetallePedido(Map<String, dynamic> pedido) {
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
                  Text("Distancia de entrega: ${pedido['distancia_km']} km",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                      pedido['estado_cocina'] == 'listo_recoleccion'
                          ? Icons.check_circle
                          : Icons.soup_kitchen,
                      color: pedido['estado_cocina'] == 'listo_recoleccion'
                          ? Colors.green
                          : Colors.orange,
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                      pedido['estado_cocina'] == 'listo_recoleccion'
                          ? "¡Comida Lista para recoger!"
                          : "Cocinando (En preparación)",
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
                  onPressed: () => _aceptarViaje(pedido['id_pedido']),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 CONTROLES DE ZOOM (+) Y (-) EN EL RADAR GLOBAL 🔥
  void _zoomIn() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual + 1.0);
  }

  void _zoomOut() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual - 1.0);
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> marcadoresMapa = _comerciosActivos.map((comercio) {
      final id = comercio['id_comercio'] ?? 1;
      final nombre = comercio['nombre_local'] ?? '';
      final ubicacion = _generarCoordenadaLocal(nombre, id);

      bool tienePedido = _pedidosDisponibles.any((p) => p['negocio'] == nombre);
      if (tienePedido) return Marker(point: ubicacion, child: const SizedBox());

      return Marker(
        point: ubicacion,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Radar Global (Bolsa de Viajes)",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroPerulapia,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
                tileProvider: NetworkTileProvider(),
              ),
              MarkerLayer(markers: marcadoresMapa),
            ],
          ),

          // PANEL SUPERIOR: ESTADO DEL RADAR
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.radar, color: Color(0xFF0F766E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _cargando
                          ? "Escaneando Perulapía..."
                          : "${_pedidosDisponibles.length} pedidos disponibles ahora",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (_cargando)
                    const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ),

          // ➕ ➖ BOTONES FLOTANTES DE ZOOM Y CENTRO EN EL RADAR GLOBAL
          Positioned(
            right: 16,
            bottom:
                180, // Subido para que no choque con las tarjetas horizontales de abajo
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomInGlobalRadar",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F766E),
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOutGlobalRadar",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F766E),
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btnCentroRadarGlobal",
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () => _mapController.move(_centroPerulapia, 15.5),
                  tooltip: "Centrar en Perulapía",
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
