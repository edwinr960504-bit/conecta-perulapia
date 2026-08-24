import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class RadarMapaScreen extends StatefulWidget {
  final int idPedido;
  final String codigoRastreo;
  final bool faseRecoleccion;
  final double latDestino;
  final double lonDestino;
  final String nombreDestino;

  const RadarMapaScreen({
    super.key,
    required this.idPedido,
    required this.codigoRastreo,
    required this.faseRecoleccion,
    required this.latDestino,
    required this.lonDestino,
    required this.nombreDestino,
  });

  @override
  State<RadarMapaScreen> createState() => _RadarMapaScreenState();
}

class _RadarMapaScreenState extends State<RadarMapaScreen>
    with SingleTickerProviderStateMixin {
  LatLng _ubicacionMotorista = const LatLng(13.7746, -89.0244);
  late LatLng _ubicacionDestino;
  bool _cargando = true;
  Timer? _timerMonitoreo;

  // 🔥 Variables en tiempo real para Waze 🔥
  String _distanciaYtiempo = "Calculando ruta...";
  List<LatLng> _rutaCalles = [];

  final MapController _mapController = MapController();
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _ubicacionDestino = LatLng(widget.latDestino, widget.lonDestino);

    // Animación para la flechita
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _obtenerUbicacionReal();

    // Actualiza la ubicación y recálcula la distancia cada 4 segundos
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 4), (timer) {
      _obtenerUbicacionReal();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _timerMonitoreo?.cancel();
    super.dispose();
  }

  // 🔥 Trazador de Calles Inteligente (OSRM) 🔥
  Future<void> _trazarRutaWaze() async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_ubicacionMotorista.longitude},${_ubicacionMotorista.latitude};${_ubicacionDestino.longitude},${_ubicacionDestino.latitude}?geometries=geojson');

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
      debugPrint("⚠️ No se pudo trazar la ruta de calles: $e");
    }
  }

  Future<void> _obtenerUbicacionReal() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );

        if (mounted) {
          LatLng nuevaPos = LatLng(pos.latitude, pos.longitude);

          // 🔥 CÁLCULO DE ETA EN TIEMPO REAL 🔥
          const Distance dist = Distance();
          double km =
              dist.as(LengthUnit.Meter, nuevaPos, _ubicacionDestino) / 1000;
          int minutos = (km * 3).ceil(); // Aprox 3 mins por KM

          setState(() {
            _ubicacionMotorista = nuevaPos;
            _cargando = false;
            _distanciaYtiempo =
                "A ${km.toStringAsFixed(2)} km • Llegada en $minutos min";
          });

          _trazarRutaWaze();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _distanciaYtiempo = "Usando ubicación de reserva...";
          _cargando = false;
        });
      }
    }
  }

  // 🎯 CONTROLES DE CÁMARA 🎯
  void _centrarEnMoto() {
    _mapController.move(_ubicacionMotorista, 17.0); // Más zoom al centrar
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en tu ubicación"),
        duration: Duration(milliseconds: 500)));
  }

  void _centrarEnDestino() {
    _mapController.move(_ubicacionDestino, 17.0);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en el destino"),
        duration: Duration(milliseconds: 500)));
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
    List<LatLng> puntosRutaFinal = _rutaCalles.isNotEmpty
        ? _rutaCalles
        : [_ubicacionMotorista, _ubicacionDestino];

    return Scaffold(
      appBar: AppBar(
        title: Text("Navegación: ${widget.codigoRastreo}"),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionMotorista,
              initialZoom: 16.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
              ),
              // 🔥 Ruta Waze dibujada en la calle 🔥
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: puntosRutaFinal,
                    color: widget.faseRecoleccion
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                    strokeWidth: 6.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // 🛵 Tu Moto
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
                          BoxShadow(color: Colors.black38, blurRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.two_wheeler,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  // 🏁 Destino
                  Marker(
                    point: _ubicacionDestino,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.faseRecoleccion
                            ? Colors.orange.shade800
                            : Colors.blue.shade800,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 4)
                        ],
                      ),
                      child: Icon(
                          widget.faseRecoleccion ? Icons.store : Icons.home,
                          color: Colors.white,
                          size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 🔘 COLUMNA DE BOTONES FLOTANTES LATERALES
          Positioned(
            right: 16,
            bottom: 170,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomInRepa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: widget.faseRecoleccion
                      ? Colors.orange.shade800
                      : Colors.blue.shade800,
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOutRepa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: widget.faseRecoleccion
                      ? Colors.orange.shade800
                      : Colors.blue.shade800,
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                // 🔥 Icono de "Francotirador" (GPS Fixed) 🔥
                FloatingActionButton(
                  heroTag: "btnCentrarMotoRepa",
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: _centrarEnMoto,
                  tooltip: "Centrar en mi ubicación",
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // 🏠 BANNER INFERIOR DINÁMICO EN TIEMPO REAL
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _centrarEnDestino,
              child: Card(
                elevation: 6,
                color: widget.faseRecoleccion
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      color: widget.faseRecoleccion
                          ? Colors.orange.shade200
                          : Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 14.0),
                  child: Row(
                    children: [
                      // 🔥 FLECHA DE NAVEGACIÓN PARPADEANTE 🔥
                      FadeTransition(
                        opacity: _blinkController,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.faseRecoleccion
                                ? Colors.orange.shade100
                                : Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.navigation,
                              color: widget.faseRecoleccion
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800,
                              size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Destino: ${widget.nombreDestino}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 🔥 TEXTO DINÁMICO (MINUTOS Y KM) 🔥
                            Text(
                              _distanciaYtiempo,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.faseRecoleccion
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (_cargando)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
