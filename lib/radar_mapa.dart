import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'gps_service.dart';

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

  String _distanciaYtiempo = "Calculando ruta...";
  List<LatLng> _rutaCalles = [];

  final MapController _mapController = MapController();
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _ubicacionDestino = LatLng(widget.latDestino, widget.lonDestino);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _obtenerUbicacionReal();

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

          const Distance dist = Distance();
          double km =
              dist.as(LengthUnit.Meter, nuevaPos, _ubicacionDestino) / 1000;
          int minutos = (km * 3).ceil();

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

  void _centrarEnMoto() {
    _mapController.move(_ubicacionMotorista, 17.0);
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
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual + 1.0);
  }

  void _zoomOut() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual - 1.0);
  }

  void _mostrarDialogoEntrega(BuildContext context) {
    if (widget.faseRecoleccion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Estás en fase de recolección en el local. Dicta tu PIN al comerciante."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Validar con el Cliente"),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "PIN del Cliente",
            prefixIcon: Icon(Icons.vpn_key),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Por favor ingresa un PIN"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final url = Uri.parse('$urlCentral/api/entregar_pedido');
                final res = await http.post(
                  url,
                  headers: {"Content-Type": "application/json"},
                  body: json.encode({"id_pedido": widget.idPedido, "pin": pin}),
                );

                final data = json.decode(utf8.decode(res.bodyBytes));

                if (!context.mounted) return;

                if (data['status'] == 'ok') {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("¡Misión Cumplida! Ganancia sumada."),
                      backgroundColor: Colors.green,
                    ),
                  );
                  GpsService.apagarGps();
                  Navigator.pop(
                      context); // Cierra el mapa y vuelve a la pantalla anterior
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(data['mensaje'] ?? "PIN Incorrecto"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Error de conexión al servidor"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Confirmar Entrega",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                  Marker(
                    point: _ubicacionMotorista,
                    width: 45,
                    height: 45,
                    child: FadeTransition(
                      opacity: _blinkController,
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
                  ),
                  Marker(
                    point: _ubicacionDestino,
                    width: 45,
                    height: 45,
                    child: FadeTransition(
                      opacity: _blinkController,
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
                  ),
                ],
              ),
            ],
          ),

          // Botones flotantes de Zoom y Francotirador
          Positioned(
            right: 16,
            bottom: 230,
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

          // 🔥 ORDEN INVERTIDO: TARJETA WAZE ARRIBA, BOTÓN VERDE ABAJO 🔥
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Tarjeta de navegación Waze con la flecha parpadeante (Arriba)
                GestureDetector(
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
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
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
                                  size: 26),
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
                                      fontSize: 15,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _distanciaYtiempo,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: widget.faseRecoleccion
                                          ? Colors.orange.shade800
                                          : Colors.blue.shade800,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (_cargando)
                            const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Botón verde de Entrega al Cliente (Abajo)
                if (!widget.faseRecoleccion) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.check_circle,
                          color: Colors.white, size: 24),
                      label: const Text(
                        "ENTREGAR AL CLIENTE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _mostrarDialogoEntrega(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
