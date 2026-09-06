import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart'; // Tu archivo de red central

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
  String _infoRuta = "Buscando señal...";

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _rastrearPosicionGPS();
    // Actualiza el radar del admin cada 4 segundos
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

        // Determinar destino: Si está asignado va al local, si está en camino va al cliente
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
      // Usamos overview=full para que la línea no se rompa
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
      // Silencioso en modo admin
    }
  }

  @override
  Widget build(BuildContext context) {
    bool faseRecoleccion =
        widget.estado == 'asignado' || widget.estado == 'aceptado';

    return Scaffold(
      appBar: AppBar(
        title: Text("Auditoría: Orden #${widget.idPedido}"),
        backgroundColor: Colors.black87,
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
              if (_rutaCalles.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _rutaCalles,
                      color: faseRecoleccion ? Colors.orange : Colors.blue,
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
                        color: faseRecoleccion ? Colors.orange : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(faseRecoleccion ? Icons.store : Icons.home,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  Marker(
                    point: _ubicacionMotorista,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.two_wheeler,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Panel de Información Flotante para el Administrador
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
                        Text(widget.estado.toUpperCase(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: faseRecoleccion
                                    ? Colors.orange
                                    : Colors.blue,
                                fontSize: 12)),
                      ],
                    ),
                    const Divider(),
                    Text("🛵 Motorista: ${widget.repartidor}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                        faseRecoleccion
                            ? "🏪 Recogiendo en: ${widget.comercio}"
                            : "🏠 Entregando a: Cliente",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
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
