import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';

class MapaComercianteScreen extends StatefulWidget {
  final int idPedido;
  final String numeroOrden;

  const MapaComercianteScreen({
    super.key,
    required this.idPedido,
    this.numeroOrden = "0000",
  });

  @override
  State<MapaComercianteScreen> createState() => _MapaComercianteScreenState();
}

class _MapaComercianteScreenState extends State<MapaComercianteScreen>
    with SingleTickerProviderStateMixin {
  // Coordenadas iniciales por defecto
  LatLng _ubicacionLocal = const LatLng(13.7333, -89.1167);
  LatLng _ubicacionMotorista = const LatLng(13.7333, -89.1167);
  bool _cargando = true;
  bool _motoristaEnCamino = false;
  Timer? _timerMonitoreo;
  String _distanciaYtiempo = "Buscando repartidor...";

  late AnimationController _animController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Animación de parpadeo para la moto en el mapa
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _obtenerUbicacionRepartidor();

    // Consulta la ubicación de la moto cada 5 segundos
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 5), (timer) {
      _obtenerUbicacionRepartidor();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _timerMonitoreo?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacionRepartidor() async {
    try {
      final url = Uri.parse('$urlCentral/api/obtener_gps/${widget.idPedido}');
      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));

        // Extraemos las coordenadas del local (comercio) de la base de datos
        double latLoc =
            double.tryParse(data['latitud_comercio']?.toString() ?? '0') ?? 0.0;
        double lonLoc =
            double.tryParse(data['longitud_comercio']?.toString() ?? '0') ??
                0.0;

        // Extraemos las coordenadas actuales de la moto
        double latRep = double.tryParse(
                data['latitud_repartidor']?.toString() ??
                    data['latitud_motorista']?.toString() ??
                    '0') ??
            0.0;
        double lonRep = double.tryParse(
                data['longitud_repartidor']?.toString() ??
                    data['longitud_motorista']?.toString() ??
                    '0') ??
            0.0;

        if (latLoc != 0.0 && lonLoc != 0.0) {
          _ubicacionLocal = LatLng(latLoc, lonLoc);
        }

        if (latRep != 0.0 && lonRep != 0.0) {
          LatLng nuevaPosRepartidor = LatLng(latRep, lonRep);

          // Calculamos la distancia entre el motorista y el local
          const Distance distCalculator = Distance();
          double metros = distCalculator.as(
              LengthUnit.Meter, _ubicacionLocal, nuevaPosRepartidor);
          double km = metros / 1000;
          int minutos = (km * 3).ceil(); // Cálculo estimado de minutos urbanos

          if (mounted) {
            setState(() {
              _ubicacionMotorista = nuevaPosRepartidor;
              _cargando = false;
              _motoristaEnCamino = true;
              _distanciaYtiempo =
                  "A ${km.toStringAsFixed(2)} km • Llega en aprox. $minutos min";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error obteniendo GPS del repartidor: $e");
    }
  }

  // 🎯 CONTROLES DE CÁMARA
  void _centrarEnLocal() {
    _mapController.move(_ubicacionLocal, 16.0);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en el Local"),
        duration: Duration(milliseconds: 500)));
  }

  void _centrarEnMotorista() {
    if (_motoristaEnCamino) {
      _mapController.move(_ubicacionMotorista, 16.5);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Centrado en el Repartidor"),
          duration: Duration(milliseconds: 500)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Aún esperando la señal del repartidor"),
          duration: Duration(milliseconds: 500)));
    }
  }

  void _zoomIn() {
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom + 1.0);
  }

  void _zoomOut() {
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom - 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Viene por Orden #${widget.numeroOrden}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionLocal,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
                tileProvider: NetworkTileProvider(),
              ),
              // Línea que une al local con la moto
              if (_motoristaEnCamino)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_ubicacionLocal, _ubicacionMotorista],
                      color: Colors.orange.shade800,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // 🏪 Marcador fijo del Local (Comercio)
                  Marker(
                    point: _ubicacionLocal,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 5)
                        ],
                        border:
                            Border.all(color: Colors.orange.shade800, width: 3),
                      ),
                      child: Icon(Icons.storefront,
                          color: Colors.orange.shade800, size: 28),
                    ),
                  ),
                  // 🛵 Marcador dinámico de la Moto (repartidor)
                  if (_motoristaEnCamino)
                    Marker(
                      point: _ubicacionMotorista,
                      width: 50,
                      height: 50,
                      child: FadeTransition(
                        opacity: _animController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 5)
                            ],
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.motorcycle,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 🔘 CONTROLES LATERALES DERECHOS (+, -, MOTO, LOCAL)
          Positioned(
            right: 16,
            bottom:
                170, // Espacio suficiente para que no choque con el panel de abajo
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón Zoom In (+)
                FloatingActionButton(
                  heroTag: "btnZoomIn",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                // Botón Zoom Out (-)
                FloatingActionButton(
                  heroTag: "btnZoomOut",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                // Botón Centrar Motorista
                FloatingActionButton(
                  heroTag: "btnCentrarMotoComercio",
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: _centrarEnMotorista,
                  tooltip: "Ubicar repartidor",
                  child: const Icon(Icons.motorcycle),
                ),
                const SizedBox(height: 12),
                // Botón Centrar Local
                FloatingActionButton(
                  heroTag: "btnCentrarLocal",
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  elevation: 4,
                  onPressed: _centrarEnLocal,
                  tooltip: "Ubicar local",
                  child: const Icon(Icons.storefront),
                ),
              ],
            ),
          ),

          // 📊 PANEL DE INFORMACIÓN INFERIOR Y BOTÓN DE ENTREGA
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.delivery_dining,
                            color: Colors.orange.shade800, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _motoristaEnCamino
                                  ? "El repartidor va en camino"
                                  : "Esperando ubicación...",
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _distanciaYtiempo,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_cargando)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.orange.shade800),
                        )
                    ],
                  ),
                  const SizedBox(height: 15),
                  // 🔥 BOTÓN PARA ENTREGAR LA ORDEN DIRECTO DESDE EL MAPA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        "ENTREGAR AL MOTORISTA",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        // Al darle tap, regresamos `true` a la pestaña de Cocina
                        // para que dispare de inmediato su propio diálogo/PIN de entrega.
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
