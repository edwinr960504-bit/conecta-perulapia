// Archivo: mapa_comerciante.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'chat_pedido.dart';
import 'logistica_service.dart';

// 🔥 MEMORIA GLOBAL: Guarda cuántos mensajes hemos leído en toda la app para sincronizar Cocina y Mapa
Map<int, int> globalMensajesConocidos = {};

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
    with TickerProviderStateMixin {
  LatLng _ubicacionLocal = const LatLng(13.7333, -89.1167);
  LatLng _ubicacionMotorista = const LatLng(13.7333, -89.1167);
  bool _cargando = true;
  bool _motoristaEnCamino = false;
  Timer? _timerMonitoreo;
  String _distanciaYtiempo = "Buscando repartidor...";
  List<LatLng> _rutaCalles = [];

  // Alerta de mensajes nuevos
  bool _hayMensajesNuevos = false;

  late final AnimationController _animController;
  late final AnimationController _chatBlinkController;
  final MapController _mapController = MapController();

  Future<void> _trazarRutaWaze() async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_ubicacionMotorista.longitude},${_ubicacionMotorista.latitude};${_ubicacionLocal.longitude},${_ubicacionLocal.latitude}?geometries=geojson&overview=full');

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
      debugPrint("⚠️ No se pudo trazar la ruta del motorista: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _chatBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.3,
      upperBound: 1.0,
    );

    _obtenerUbicacionRepartidor();
    _verificarMensajesChatMapa();

    _timerMonitoreo = Timer.periodic(const Duration(seconds: 3), (timer) {
      _obtenerUbicacionRepartidor();
      _verificarMensajesChatMapa();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _chatBlinkController.dispose();
    _timerMonitoreo?.cancel();
    super.dispose();
  }

  Future<void> _verificarMensajesChatMapa() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/${widget.idPedido}?canal=motorista_comercio&t=$timestamp');

      final res = await http.get(url).timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];
        int totalActual = mensajes.length;

        if (!globalMensajesConocidos.containsKey(widget.idPedido)) {
          globalMensajesConocidos[widget.idPedido] = totalActual;
          _hayMensajesNuevos = false;
        } else {
          int conocidos = globalMensajesConocidos[widget.idPedido]!;

          if (totalActual > conocidos) {
            int motoristaNuevos = 0;
            for (int i = conocidos; i < totalActual; i++) {
              final remitente =
                  (mensajes[i]['remitente'] ?? '').toString().toLowerCase();
              if (!remitente.contains('comercio')) {
                motoristaNuevos++;
              }
            }

            if (motoristaNuevos > 0 && mounted) {
              setState(() {
                _hayMensajesNuevos = true;
              });

              if (!_chatBlinkController.isAnimating) {
                _chatBlinkController.repeat(reverse: true);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("📩 Nuevo mensaje del motorista"),
                  backgroundColor: Colors.teal.shade700,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.82,
                    left: 20,
                    right: 20,
                  ),
                ),
              );
            } else {
              globalMensajesConocidos[widget.idPedido] = totalActual;
            }
          } else if (totalActual == conocidos && _hayMensajesNuevos) {
            setState(() {
              _hayMensajesNuevos = false;
              _chatBlinkController.stop();
              _chatBlinkController.value = 1.0;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _obtenerUbicacionRepartidor() async {
    try {
      final url = Uri.parse('$urlCentral/api/obtener_gps/${widget.idPedido}');
      final res = await http.get(url).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));

        double latLoc =
            double.tryParse(data['latitud_comercio']?.toString() ?? '0') ?? 0.0;
        double lonLoc =
            double.tryParse(data['longitud_comercio']?.toString() ?? '0') ??
                0.0;

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
          bool eraLaPrimeraVez = _cargando;
          _ubicacionLocal = LatLng(latLoc, lonLoc);
          if (eraLaPrimeraVez) {
            _mapController.move(_ubicacionLocal, 16.0);
          }
        }

        if (latRep != 0.0 && lonRep != 0.0) {
          LatLng nuevaPosRepartidor = LatLng(latRep, lonRep);

          const Distance distCalculator = Distance();
          double metros = distCalculator.as(
              LengthUnit.Meter, _ubicacionLocal, nuevaPosRepartidor);
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

            _trazarRutaWaze();
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error obteniendo GPS del repartidor: $e");
    }
  }

  void _centrarEnLocal() {
    _mapController.move(_ubicacionLocal, 16.0);
  }

  void _centrarEnMotorista() {
    if (_motoristaEnCamino) {
      _mapController.move(_ubicacionMotorista, 16.5);
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

  void _mostrarDialogoEntregaMapa(int idPed) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Validar Repartidor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Pídele el PIN de 4 dígitos al repartidor:",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: "PIN del Repartidor",
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final mensajero = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              Navigator.pop(ctx);

              String resultado = await LogisticaService.recogerPedido(
                  idPed, pinCtrl.text.trim());

              if (resultado == "OK") {
                mensajero.showSnackBar(
                  const SnackBar(
                    content: Text("¡Entregado y registrado permanentemente!"),
                    backgroundColor: Colors.green,
                  ),
                );
                nav.pop(true);
              } else {
                mensajero.showSnackBar(
                  SnackBar(
                    content: Text("Error: $resultado"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Confirmar y Entregar",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirVentanaDeChatComercio() async {
    setState(() {
      _hayMensajesNuevos = false;
      _chatBlinkController.stop();
      _chatBlinkController.value = 1.0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: ChatPedidoScreen(
            idPedido: widget.idPedido,
            remitente: "Comercio",
            canal: "motorista_comercio",
            nombreDestino: "Chat con Motorista",
          ),
        ),
      ),
    ).then((_) {
      _sincronizarHistorialAlCerrar();
    });
  }

  Future<void> _sincronizarHistorialAlCerrar() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/${widget.idPedido}?canal=motorista_comercio&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];

        globalMensajesConocidos[widget.idPedido] = mensajes.length;

        if (mounted) {
          setState(() {
            _hayMensajesNuevos = false;
          });
          _chatBlinkController.stop();
          _chatBlinkController.value = 1.0;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    List<LatLng> puntosRutaFinal = _rutaCalles.isNotEmpty ? _rutaCalles : [];

    return Scaffold(
      appBar: AppBar(
        title: Text("Viene por Orden #${widget.numeroOrden}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              if (_motoristaEnCamino)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: puntosRutaFinal,
                      color: Colors.orange.shade800,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
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
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining,
                      color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _distanciaYtiempo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_cargando)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.orange.shade800),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomInMapa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOutMapa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btnCentrarMotoMapa",
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  onPressed: _centrarEnMotorista,
                  tooltip: "Ubicar repartidor",
                  child: const Icon(Icons.motorcycle),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "btnCentrarLocalMapa",
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  onPressed: _centrarEnLocal,
                  tooltip: "Ubicar local",
                  child: const Icon(Icons.storefront),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text(
                      "Entregar",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _mostrarDialogoEntregaMapa(widget.idPedido);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: FadeTransition(
                    opacity: _hayMensajesNuevos
                        ? _chatBlinkController
                        : const AlwaysStoppedAnimation(1.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hayMensajesNuevos
                            ? Colors.red.shade700
                            : Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: _hayMensajesNuevos
                              ? const BorderSide(color: Colors.white, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                      icon: Icon(
                          _hayMensajesNuevos
                              ? Icons.mark_chat_unread
                              : Icons.chat_bubble_outline,
                          size: 20),
                      label: const Text(
                        "Chat",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        _abrirVentanaDeChatComercio();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
