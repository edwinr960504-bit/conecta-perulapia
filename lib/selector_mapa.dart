import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SelectorMapaPantalla extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const SelectorMapaPantalla({
    super.key,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<SelectorMapaPantalla> createState() => _SelectorMapaPantallaState();
}

class _SelectorMapaPantallaState extends State<SelectorMapaPantalla> {
  late LatLng _puntoCentral;
  final MapController _mapController = MapController();
  bool _cargandoDireccion = false;
  String _direccionTexto = "Mueve el mapa para ubicar el negocio";

  @override
  void initState() {
    super.initState();
    // 🔥 Si ya existen coordenadas guardadas, el mapa abre exactamente ahí
    if (widget.initialLat != null && widget.initialLon != null) {
      _puntoCentral = LatLng(widget.initialLat!, widget.initialLon!);
      _direccionTexto = "Ubicación actual guardada del local";
    } else {
      _puntoCentral = const LatLng(13.7942, -89.0492);
    }
  }

  Future<void> _obtenerDireccionLegible(LatLng posicion) async {
    setState(() {
      _cargandoDireccion = true;
      _direccionTexto = "Buscando dirección exacta...";
    });

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${posicion.latitude}&lon=${posicion.longitude}&zoom=18&addressdetails=1');

      final respuesta =
          await http.get(url, headers: {'User-Agent': 'PerulapiaConnect'});
      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        if (mounted) {
          setState(() {
            _direccionTexto =
                datos['display_name'] ?? "Ubicación seleccionada en el mapa";
            _cargandoDireccion = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _direccionTexto =
              "Lat: ${posicion.latitude.toStringAsFixed(4)}, Lon: ${posicion.longitude.toStringAsFixed(4)}";
          _cargandoDireccion = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ubicar Local en el Mapa"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Listener(
            onPointerUp: (_) {
              _obtenerDireccionLegible(_mapController.camera.center);
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _puntoCentral,
                initialZoom: 17.0,
                onPositionChanged: (posicion, hasGesture) {
                  if (hasGesture) {
                    _puntoCentral = posicion.center;
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.perulapia_connect',
                ),
              ],
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35.0),
              child: Icon(
                Icons.location_pin,
                size: 50,
                color: Colors.red,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _cargandoDireccion
                                ? "Calculando dirección..."
                                : _direccionTexto,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'latitud': _mapController.camera.center.latitude,
                            'longitud': _mapController.camera.center.longitude,
                            'direccion': _direccionTexto,
                          });
                        },
                        child: const Text(
                          "Confirmar esta Ubicación",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
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
