import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';

class MapaConsumidorScreen extends StatefulWidget {
  final int idPedido;
  final String codigoRastreo;

  const MapaConsumidorScreen({
    super.key,
    required this.idPedido,
    required this.codigoRastreo,
  });

  @override
  State<MapaConsumidorScreen> createState() => _MapaConsumidorScreenState();
}

class _MapaConsumidorScreenState extends State<MapaConsumidorScreen>
    with SingleTickerProviderStateMixin {
  LatLng _ubicacionCasaCliente = const LatLng(13.7333, -89.1167);
  LatLng _ubicacionMotorista = const LatLng(13.7333, -89.1167);
  bool _cargando = true;
  bool _motoristaEnCamino = false;
  Timer? _timerMonitoreo;
  String _distanciaYtiempo = "Buscando ubicación...";

  String _nombreRepartidor = "Buscando motorista...";
  final String _vehiculoRepartidor = "En camino hacia ti";

  late AnimationController _animController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _obtenerUbicacionYDetallesRepartidor();

    _timerMonitoreo = Timer.periodic(const Duration(seconds: 5), (timer) {
      _obtenerUbicacionYDetallesRepartidor();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _timerMonitoreo?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacionYDetallesRepartidor() async {
    try {
      final url = Uri.parse('$urlCentral/api/obtener_gps/${widget.idPedido}');
      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));

        final String estado = data['estado_pedido'] ?? '';
        if (estado == 'entregado' ||
            estado == 'cancelado' ||
            estado == 'archivado') {
          _timerMonitoreo?.cancel();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Tu pedido ha finalizado con éxito!"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        double latCasa =
            double.tryParse(data['latitud_cliente']?.toString() ?? '0') ?? 0.0;
        double lonCasa =
            double.tryParse(data['longitud_cliente']?.toString() ?? '0') ?? 0.0;

        double latRep =
            double.tryParse(data['latitud_repartidor']?.toString() ?? '0') ??
                0.0;
        double lonRep =
            double.tryParse(data['longitud_repartidor']?.toString() ?? '0') ??
                0.0;

        if (latCasa != 0.0 && lonCasa != 0.0) {
          _ubicacionCasaCliente = LatLng(latCasa, lonCasa);
        }

        String nombreRemoto =
            data['nombre_repartidor'] ?? data['repartidor'] ?? '';

        if (mounted) {
          setState(() {
            if (nombreRemoto.isNotEmpty) {
              _nombreRepartidor = nombreRemoto;
            } else {
              _nombreRepartidor = "Motorista Conecta";
            }
          });
        }

        if (latRep != 0.0 && lonRep != 0.0) {
          LatLng nuevaPosRepartidor = LatLng(latRep, lonRep);
          const Distance distCalculator = Distance();
          double metros = distCalculator.as(
              LengthUnit.Meter, _ubicacionCasaCliente, nuevaPosRepartidor);
          double km = metros / 1000;
          int minutos = (km * 3).ceil();

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
      debugPrint("⚠️ Error obteniendo GPS: $e");
    }
  }

  // 🔥 CONTROLES DE CÁMARA 🔥
  void _centrarEnCasa() {
    _mapController.move(_ubicacionCasaCliente, 16.5);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en tu ubicación"),
        duration: Duration(milliseconds: 500)));
  }

  void _centrarEnMotorista() {
    if (_motoristaEnCamino) {
      _mapController.move(_ubicacionMotorista, 16.5);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Centrado en el repartidor"),
          duration: Duration(milliseconds: 500)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Aún esperando la señal del repartidor"),
            duration: Duration(milliseconds: 500)),
      );
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
        title: Text("Rastreo: ${widget.codigoRastreo}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0055A4),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ubicacionCasaCliente,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
                tileProvider: NetworkTileProvider(),
              ),
              if (_motoristaEnCamino)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_ubicacionMotorista, _ubicacionCasaCliente],
                      color: Colors.blueAccent,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacionCasaCliente,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 5)
                        ],
                        border: Border.all(
                            color: const Color(0xFF0055A4), width: 3),
                      ),
                      child: const Icon(Icons.home,
                          color: Color(0xFF0055A4), size: 28),
                    ),
                  ),
                  if (_motoristaEnCamino)
                    Marker(
                      point: _ubicacionMotorista,
                      width: 50,
                      height: 50,
                      child: FadeTransition(
                        opacity: _animController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 5)
                            ],
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.two_wheeler,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 🔘 COLUMNA DE BOTONES LATERALES (+, -, Moto, Mi Ubicación)
          Positioned(
            right: 16,
            bottom: 150, // Espacio para que no choque con el panel de abajo
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomInCli",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0055A4),
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOutCli",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0055A4),
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btnUbicarMotoristaCli",
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: _centrarEnMotorista,
                  tooltip: "Ubicar repartidor",
                  child: const Icon(Icons.motorcycle), // 🔥 Icono de Moto
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "btnCentrarCasaCli",
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0055A4),
                  elevation: 4,
                  onPressed: _centrarEnCasa,
                  tooltip: "Centrar en mi ubicación",
                  child: const Icon(
                      Icons.my_location), // 🔥 Icono de Flechita (GPS)
                ),
              ],
            ),
          ),

          // 📊 PANEL INFERIOR INTERACTIVO
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _centrarEnMotorista, // 🔥 Si toca el panel, busca la moto
              child: Container(
                padding: const EdgeInsets.all(16),
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
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.delivery_dining,
                              color: Color(0xFF0055A4), size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _motoristaEnCamino
                                    ? "¡Tu comida va en camino! (Toca para ubicar)"
                                    : "Esperando al repartidor...",
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
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
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF0055A4)))
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFF0055A4),
                          child:
                              Icon(Icons.person, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_nombreRepartidor,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(_vehiculoRepartidor,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (value) {
                            if (value == 'llamar') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Llamando a $_nombreRepartidor...")));
                            } else if (value == 'mensaje') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Abriendo chat...")));
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'llamar',
                              child: Row(children: [
                                Icon(Icons.phone,
                                    color: Colors.green, size: 20),
                                SizedBox(width: 10),
                                Text("Llamar al motorista")
                              ]),
                            ),
                            const PopupMenuItem<String>(
                              value: 'mensaje',
                              child: Row(children: [
                                Icon(Icons.chat_bubble,
                                    color: Colors.blue, size: 20),
                                SizedBox(width: 10),
                                Text("Enviar mensaje")
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
