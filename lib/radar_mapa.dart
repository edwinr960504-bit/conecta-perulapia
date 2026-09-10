// Archivo: radar_mapa.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

  StreamSubscription<Position>? _streamPosicion;
  Timer? _timerRuta;

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
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _iniciarMotorNavegacion();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _streamPosicion?.cancel();
    _timerRuta?.cancel();
    super.dispose();
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
      debugPrint("⚠️ No se pudo trazar la ruta de calles: $e");
    }
  }

  Future<void> _iniciarMotorNavegacion() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position posInicial = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );

        if (mounted) {
          LatLng nuevaPos = LatLng(posInicial.latitude, posInicial.longitude);
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
          _mapController.move(
              _ubicacionMotorista, 17.0); // Zoom óptimo y visible
        }

        const opcionesNavegacion = LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        );

        _streamPosicion =
            Geolocator.getPositionStream(locationSettings: opcionesNavegacion)
                .listen((Position pos) {
          if (mounted) {
            LatLng nuevaPos = LatLng(pos.latitude, pos.longitude);
            const Distance dist = Distance();
            double km =
                dist.as(LengthUnit.Meter, nuevaPos, _ubicacionDestino) / 1000;
            int minutos = (km * 3).ceil();

            setState(() {
              _ubicacionMotorista = nuevaPos;
              _distanciaYtiempo =
                  "A ${km.toStringAsFixed(2)} km • Llegada en $minutos min";
            });

            if (pos.heading > 0) {
              _mapController.rotate(-pos.heading);
            }
          }
        });

        _timerRuta = Timer.periodic(const Duration(seconds: 5), (timer) {
          _trazarRutaWaze();
        });
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

  Future<void> _abrirNavegadorNativo(String tipo) async {
    final lat = widget.latDestino;
    final lon = widget.lonDestino;
    Uri url;

    if (tipo == 'google') {
      url = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving');
    } else {
      url = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "No se pudo abrir $tipo. Asegúrate de tener la app instalada.")),
      );
    }
  }

  void _centrarEnMoto() {
    _mapController.move(_ubicacionMotorista, 17.0);
    _mapController.rotate(0);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado y orientado al norte"),
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
                      backgroundColor: Colors.red),
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
                        backgroundColor: Colors.green),
                  );
                  GpsService.apagarGps();
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(data['mensaje'] ?? "PIN Incorrecto"),
                        backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Error de conexión al servidor"),
                      backgroundColor: Colors.red),
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
              initialZoom: 17.0,
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
                    strokeWidth: 6.0, // Línea de ruta con mayor grosor visible
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacionMotorista,
                    width: 46,
                    height: 46, // Tamaño cómodo y visible para la moto
                    child: FadeTransition(
                      opacity: _blinkController,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4)
                          ],
                        ),
                        child: const Icon(Icons.two_wheeler,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  Marker(
                    point: _ubicacionDestino,
                    width: 46,
                    height: 46, // Tamaño cómodo y visible para el destino
                    child: FadeTransition(
                      opacity: _blinkController,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.faseRecoleccion
                              ? Colors.orange.shade800
                              : Colors.blue.shade800,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4)
                          ],
                        ),
                        child: Icon(
                            widget.faseRecoleccion ? Icons.store : Icons.home,
                            color: Colors.white,
                            size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ➕ ➖ ZOOM Y BRÚJULA ACCESIBLES ABAJO A LA DERECHA
          Positioned(
            right: 16,
            bottom: widget.faseRecoleccion ? 180 : 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomInRepa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOutRepa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, size: 20),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    FadeTransition(
                      opacity:
                          Tween(begin: 0.7, end: 0.0).animate(_blinkController),
                      child: ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.5)
                            .animate(_blinkController),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: "btnCentrarMotoRepa",
                      mini: true,
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      onPressed: _centrarEnMoto,
                      tooltip: "Centrar y orientar",
                      child: const Icon(Icons.navigation, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // PANEL INFERIOR CON BUEN TAMAÑO Y ACCESIBLE
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
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
                                      size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Destino: ${widget.nombreDestino}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
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
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.map, size: 18),
                                  label: const Text("Google Maps",
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () =>
                                      _abrirNavegadorNativo('google'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.lightBlue.shade300,
                                    foregroundColor: Colors.black87,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.drive_eta, size: 18),
                                  label: const Text("Waze",
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () =>
                                      _abrirNavegadorNativo('waze'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!widget.faseRecoleccion) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.check_circle,
                          color: Colors.white, size: 22),
                      label: const Text(
                        "ENTREGAR AL CLIENTE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
