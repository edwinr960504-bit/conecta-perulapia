import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

class _RadarMapaScreenState extends State<RadarMapaScreen> {
  LatLng _ubicacionMotorista = const LatLng(13.7746, -89.0244);
  late LatLng _ubicacionDestino;
  bool _cargando = true;
  Timer? _timerMonitoreo;
  String _estadoTexto = "Buscando señal GPS...";

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _ubicacionDestino = LatLng(widget.latDestino, widget.lonDestino);
    _obtenerUbicacionReal();

    _timerMonitoreo = Timer.periodic(const Duration(seconds: 4), (timer) {
      _obtenerUbicacionReal();
    });
  }

  @override
  void dispose() {
    _timerMonitoreo?.cancel();
    super.dispose();
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
          setState(() {
            _ubicacionMotorista = LatLng(pos.latitude, pos.longitude);
            _cargando = false;
            _estadoTexto = widget.faseRecoleccion
                ? "Navegando hacia el Local (Comercio)"
                : "Navegando hacia la casa del Cliente";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estadoTexto = "Usando ubicación de reserva...";
          _cargando = false;
        });
      }
    }
  }

  void _centrarEnMoto() {
    _mapController.move(_ubicacionMotorista, 16.5);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en tu ubicación"),
        duration: Duration(milliseconds: 500)));
  }

  void _centrarEnDestino() {
    _mapController.move(_ubicacionDestino, 16.5);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en el destino"),
        duration: Duration(milliseconds: 500)));
  }

  // 🔥 FUNCIONES DE ZOOM DIRECTAS AL MAP CONTROLLER 🔥
  void _zoomIn() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual + 1);
  }

  void _zoomOut() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ruta: ${widget.codigoRastreo}"),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. EL MAPA OCUPA TODA LA PANTALLA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionMotorista,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_ubicacionMotorista, _ubicacionDestino],
                    color: widget.faseRecoleccion
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                    strokeWidth: 5.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacionMotorista,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
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

          // 2. BOTONES FLOTANTES DE ZOOM Y UBICACIÓN (A LA DERECHA)
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón + (Acercar)
                FloatingActionButton(
                  heroTag: "zoom_in_mapa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 8),
                // Botón - (Alejar)
                FloatingActionButton(
                  heroTag: "zoom_out_mapa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, size: 20),
                ),
                const SizedBox(height: 16),
                // Botón Centrar Moto
                FloatingActionButton(
                  heroTag: "centrar_moto_mapa",
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  onPressed: _centrarEnMoto,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // 3. TARJETA INFERIOR
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _centrarEnDestino,
              child: Card(
                elevation: 4,
                color: widget.faseRecoleccion
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      color: widget.faseRecoleccion
                          ? Colors.orange.shade200
                          : Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                          widget.faseRecoleccion
                              ? Icons.storefront
                              : Icons.home,
                          color: widget.faseRecoleccion
                              ? Colors.orange.shade800
                              : Colors.blue,
                          size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.faseRecoleccion
                                  ? "Ubicación del Local (Toca para ver)"
                                  : "Ubicación del Cliente (Toca para ver)",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.faseRecoleccion
                                      ? Colors.orange.shade800
                                      : Colors.blue,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Destino: ${widget.nombreDestino}",
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _estadoTexto,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
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
