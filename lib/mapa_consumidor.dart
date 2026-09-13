// Archivo: mapa_consumidor.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'chat_pedido.dart';

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

  String _nombreRepartidor = "Motorista";
  bool _alertaLlegadaMostrada = false;
  int _cantidadMensajesAnterior = 0;
  bool _hayMensajeNuevo = false;

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
    _verificarLlegadaMotorista();

    // 🔥 RADAR MODO TURBO: Se actualiza cada 3 segundos para optimizar recursos y rendimiento del teclado
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 3), (timer) {
      _obtenerUbicacionYDetallesRepartidor();
      _verificarLlegadaMotorista();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _timerMonitoreo?.cancel();
    super.dispose();
  }

  // 🔥 RADAR INVISIBLE DE ALERTAS DEL SISTEMA Y CHAT
  Future<void> _verificarLlegadaMotorista() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/${widget.idPedido}?canal=motorista_consumidor&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];

        // Comparamos si hay mensajes nuevos
        if (mensajes.length > _cantidadMensajesAnterior) {
          final ultimoMsj = mensajes.last;

          // ALERTA 1: EL MOTORISTA LLEGÓ (SISTEMA)
          if (ultimoMsj['remitente'] == 'Sistema Automático' &&
              !_alertaLlegadaMostrada) {
            _alertaLlegadaMostrada = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ultimoMsj['mensaje'],
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: Colors.green.shade700,
                  duration: const Duration(seconds: 8),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.75,
                    left: 20,
                    right: 20,
                  ),
                ),
              );
            }
          }
          // ALERTA 2: MENSAJE NORMAL DEL MOTORISTA (TEXTO/FOTO)
          else if (ultimoMsj['remitente'] != 'Cliente' &&
              ultimoMsj['remitente'] != 'Sistema Automático') {
            if (mounted) {
              setState(() {
                _hayMensajeNuevo = true; // Enciende el puntito rojo en el botón
              });
              // Lanza una notificación cortita arriba para que sepa que le escribieron
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("📩 Nuevo mensaje de $_nombreRepartidor"),
                  backgroundColor: Colors.blueAccent.shade700,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.80,
                    left: 20,
                    right: 20,
                  ),
                ),
              );
            }
          }
          // Actualizamos el contador para no repetir alertas
          _cantidadMensajesAnterior = mensajes.length;
        }
      }
    } catch (_) {
      // Ignorar errores de red temporales en segundo plano
    }
  }

  Future<void> _obtenerUbicacionYDetallesRepartidor() async {
    try {
      final url = Uri.parse('$urlCentral/api/obtener_gps/${widget.idPedido}');
      final res = await http.get(url).timeout(const Duration(seconds: 2));

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
    } catch (_) {
      // Fallo silencioso para no interrumpir la experiencia de rastreo
    }
  }

  void _centrarEnCasa() {
    _mapController.move(_ubicacionCasaCliente, 16.5);
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

  void _abrirVentanaDeChat() {
    setState(() {
      _hayMensajeNuevo = false;
    });

    // 🔥 Frame delay para evitar el retraso (cámara lenta) al desplegar el teclado y la ventana flotante
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
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
              remitente: "Cliente",
              canal: "motorista_consumidor",
              nombreDestino: "Hablando con $_nombreRepartidor",
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Rastreo: ${widget.codigoRastreo}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0055A4),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 🗺️ MAPA LIBRE Y A PANTALLA COMPLETA
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

          // ⏳ PÍLDORA DISCRETA DE TIEMPO EN LA PARTE SUPERIOR
          if (_motoristaEnCamino)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const Icon(Icons.two_wheeler,
                        color: Color(0xFF0055A4), size: 20),
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
                  ],
                ),
              ),
            ),

          // 🎛️ TODOS LOS CONTROLES APILADOS EN LA ESQUINA INFERIOR DERECHA
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomIn",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0055A4),
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOut",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0055A4),
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btnUbicarMotorista",
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  onPressed: _centrarEnMotorista,
                  tooltip: "Ubicar repartidor",
                  child: const Icon(Icons.motorcycle),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "btnCentrarCasa",
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0055A4),
                  onPressed: _centrarEnCasa,
                  tooltip: "Centrar en mi ubicación",
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 24),

                // 💬 BOTÓN DE CHAT CON CAMPANITA (BADGE)
                FloatingActionButton.extended(
                  heroTag: "btnChatFlotante",
                  backgroundColor: Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  icon: Badge(
                    isLabelVisible: _hayMensajeNuevo,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  label: const Text("Chat Motorista",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _abrirVentanaDeChat,
                ),
              ],
            ),
          ),

          if (_cargando)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF0055A4)),
            ),
        ],
      ),
    );
  }
}
