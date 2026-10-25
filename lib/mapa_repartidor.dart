// Archivo: mapa_repartidor.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'api_http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'gps_service.dart';
import 'chat_pedido.dart';

// 🔥 MEMORIA GLOBAL: Comparte el estado de lectura de mensajes con toda la app
Map<int, int> globalMensajesConocidosRepartidor = {};

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
    with TickerProviderStateMixin {
  LatLng _ubicacionMotorista = const LatLng(13.7746, -89.0244);
  late LatLng _ubicacionDestino;

  StreamSubscription<Position>? _streamPosicion;
  Timer? _timerRuta;
  Timer? _timerChatNotif;

  String _distanciaYtiempo = "Calculando ruta...";
  List<LatLng> _rutaCalles = [];

  bool _hayMensajeNuevo = false;

  final MapController _mapController = MapController();

  late AnimationController _blinkController;
  // Controlador para el parpadeo suave del botón de chat
  late AnimationController _chatBlinkController;

  @override
  void initState() {
    super.initState();
    _ubicacionDestino = LatLng(widget.latDestino, widget.lonDestino);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _chatBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.3,
      upperBound: 1.0,
    );

    _iniciarMotorNavegacion();
    _iniciarEscaneoChat();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _chatBlinkController.dispose();
    _streamPosicion?.cancel();
    _timerRuta?.cancel();
    _timerChatNotif?.cancel();
    super.dispose();
  }

  void _iniciarEscaneoChat() {
    final canalActivo =
        widget.faseRecoleccion ? "motorista_comercio" : "motorista_consumidor";

    _timerChatNotif = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final url = Uri.parse(
            '$urlCentral/api/chat/historial/${widget.idPedido}?canal=$canalActivo&t=$timestamp');
        final res = await http.get(url).timeout(const Duration(seconds: 2));

        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          List mensajes = data['mensajes'] ?? [];
          int totalActual = mensajes.length;

          if (!globalMensajesConocidosRepartidor.containsKey(widget.idPedido)) {
            globalMensajesConocidosRepartidor[widget.idPedido] = totalActual;
            _hayMensajeNuevo = false;
          } else {
            int conocidos = globalMensajesConocidosRepartidor[widget.idPedido]!;

            if (totalActual > conocidos) {
              int nuevosExternos = 0;
              for (int i = conocidos; i < totalActual; i++) {
                if (mensajes[i]['remitente'] != 'Motorista' &&
                    mensajes[i]['remitente'] != 'Sistema Automático') {
                  nuevosExternos++;
                }
              }

              if (nuevosExternos > 0 && mounted) {
                setState(() {
                  _hayMensajeNuevo = true;
                });

                if (!_chatBlinkController.isAnimating) {
                  _chatBlinkController.repeat(reverse: true);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text("📩 Nuevo mensaje de ${widget.nombreDestino}"),
                    backgroundColor: widget.faseRecoleccion
                        ? Colors.orange.shade800
                        : Colors.blue.shade800,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height * 0.82,
                      left: 20,
                      right: 20,
                    ),
                  ),
                );
              } else {
                globalMensajesConocidosRepartidor[widget.idPedido] =
                    totalActual;
              }
            } else if (totalActual == conocidos && _hayMensajeNuevo) {
              // Sincronización: Si se leyó en otra pantalla, apagamos el parpadeo aquí
              setState(() {
                _hayMensajeNuevo = false;
                _chatBlinkController.stop();
                _chatBlinkController.value = 1.0;
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _iniciarMotorNavegacion() async {
    bool activo = await Geolocator.isLocationServiceEnabled();
    if (!activo) return;

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return;
    }

    Position posInicial = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high));

    if (mounted) {
      setState(() {
        _ubicacionMotorista = LatLng(posInicial.latitude, posInicial.longitude);
      });
      _trazarRutaWaze();
      _mapController.move(_ubicacionMotorista, 17.5);
    }

    const opcionesNavegacion = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _streamPosicion =
        Geolocator.getPositionStream(locationSettings: opcionesNavegacion)
            .listen((Position pos) {
      if (mounted) {
        LatLng nuevaPos = LatLng(pos.latitude, pos.longitude);
        const Distance dist = Distance();
        double km =
            dist.as(LengthUnit.Meter, nuevaPos, _ubicacionDestino) / 1000;

        int totalMinutos = (km * 3).ceil();
        String tiempoTexto = "";
        if (totalMinutos >= 60) {
          int horas = totalMinutos ~/ 60;
          int minsRestantes = totalMinutos % 60;
          tiempoTexto =
              "$horas h ${minsRestantes > 0 ? '$minsRestantes min' : ''}";
        } else {
          tiempoTexto = "$totalMinutos min";
        }

        setState(() {
          _ubicacionMotorista = nuevaPos;
          _distanciaYtiempo =
              "A ${km.toStringAsFixed(1)} km • Llega en $tiempoTexto";
        });
      }
    });

    _timerRuta = Timer.periodic(const Duration(seconds: 3), (timer) {
      _trazarRutaWaze();
    });
  }

  Future<void> _trazarRutaWaze() async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_ubicacionMotorista.longitude},${_ubicacionMotorista.latitude};${_ubicacionDestino.longitude},${_ubicacionDestino.latitude}?geometries=geojson&overview=full');
      final res = await http.get(url).timeout(const Duration(seconds: 3));

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
    } catch (_) {}
  }

  Future<void> _abrirWazeNativo() async {
    final lat = widget.latDestino;
    final lon = widget.lonDestino;
    final Uri url = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "No se pudo abrir Waze. Asegúrate de tener la app instalada.")),
      );
    }
  }

  void _abrirChatEnMapa() {
    setState(() {
      _hayMensajeNuevo = false;
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
            remitente: "Motorista",
            canal: widget.faseRecoleccion
                ? "motorista_comercio"
                : "motorista_consumidor",
            nombreDestino:
                widget.faseRecoleccion ? "Chat con Local" : "Chat con Cliente",
          ),
        ),
      ),
    ).then((_) {
      _sincronizarHistorialAlCerrar();
    });
  }

  Future<void> _sincronizarHistorialAlCerrar() async {
    try {
      final canalActivo = widget.faseRecoleccion
          ? "motorista_comercio"
          : "motorista_consumidor";
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/${widget.idPedido}?canal=$canalActivo&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];

        // Sincronizamos la memoria global para que se entere toda la app
        globalMensajesConocidosRepartidor[widget.idPedido] = mensajes.length;

        if (mounted) {
          setState(() {
            _hayMensajeNuevo = false;
            _chatBlinkController.stop();
            _chatBlinkController.value = 1.0;
          });
        }
      }
    } catch (_) {}
  }

  void _centrarEnMoto() {
    _mapController.move(_ubicacionMotorista, 17.5);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Centrado en tu ubicación"),
        duration: Duration(milliseconds: 400)));
  }

  void _centrarEnDestino() {
    _mapController.move(_ubicacionDestino, 17.0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            "Centrado en ${widget.faseRecoleccion ? 'el Local' : 'el Cliente'}"),
        duration: const Duration(milliseconds: 400)));
  }

  void _zoomIn() => _mapController.move(
      _mapController.camera.center, _mapController.camera.zoom + 1.0);
  void _zoomOut() => _mapController.move(
      _mapController.camera.center, _mapController.camera.zoom - 1.0);

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
              labelText: "PIN del Cliente", prefixIcon: Icon(Icons.vpn_key)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Por favor ingresa un PIN"),
                    backgroundColor: Colors.red));
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
              } catch (_) {
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

    final Color colorTema =
        widget.faseRecoleccion ? Colors.orange.shade800 : Colors.blue.shade800;

    return Scaffold(
      appBar: AppBar(
        title: Text("Navegación: ${widget.codigoRastreo}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
                initialCenter: _ubicacionMotorista, initialZoom: 17.5),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.perulapia_connect',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: puntosRutaFinal,
                    color: colorTema,
                    strokeWidth: 6.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ubicacionMotorista,
                    width: 55,
                    height: 55,
                    child: GestureDetector(
                      onTap: _centrarEnMoto,
                      child: FadeTransition(
                        opacity: _blinkController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade900,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.amberAccent, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 3))
                            ],
                          ),
                          child: const Icon(Icons.navigation,
                              color: Colors.amberAccent, size: 30),
                        ),
                      ),
                    ),
                  ),
                  Marker(
                    point: _ubicacionDestino,
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: _centrarEnDestino,
                      child: FadeTransition(
                        opacity: _blinkController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorTema,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: Icon(
                              widget.faseRecoleccion ? Icons.store : Icons.home,
                              color: Colors.white,
                              size: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 📍 PÍLDORA SUPERIOR ULTRA FINA Y ELEGANTE
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    Icon(
                      widget.faseRecoleccion ? Icons.store : Icons.home,
                      color: colorTema,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Destino: ${widget.nombreDestino} • $_distanciaYtiempo",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🎛️ CONTROLES FLOTANTES LATERALES (Más arriba para no topar con Waze/Entregar)
          Positioned(
            right: 16,
            bottom: widget.faseRecoleccion ? 110 : 175,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomInRepa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: colorTema,
                  elevation: 4,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton(
                  heroTag: "btnZoomOutRepa",
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: colorTema,
                  elevation: 4,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btnCentrarMotoRepa",
                  backgroundColor: Colors.indigo.shade900,
                  foregroundColor: Colors.amberAccent,
                  elevation: 4,
                  onPressed: _centrarEnMoto,
                  tooltip: "Centrar Moto",
                  child: const Icon(Icons.navigation),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "btnCentrarDestinoRepa",
                  backgroundColor: Colors.white,
                  foregroundColor: colorTema,
                  elevation: 4,
                  onPressed: _centrarEnDestino,
                  tooltip: "Centrar Destino",
                  child:
                      Icon(widget.faseRecoleccion ? Icons.store : Icons.home),
                ),
              ],
            ),
          ),

          // 🚀 BOTONES INFERIORES FLOTANTES
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FadeTransition(
                        opacity: _hayMensajeNuevo
                            ? Tween<double>(begin: 0.3, end: 1.0)
                                .animate(_chatBlinkController)
                            : const AlwaysStoppedAnimation(1.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                colorTema, // Mantiene su color base
                            foregroundColor: Colors.white,
                            elevation: 6,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: _hayMensajeNuevo
                                  ? const BorderSide(
                                      color: Colors.white, width: 2)
                                  : BorderSide.none,
                            ),
                          ),
                          icon: Badge(
                            isLabelVisible: _hayMensajeNuevo,
                            backgroundColor: Colors.red,
                            child:
                                const Icon(Icons.chat_bubble_outline, size: 20),
                          ),
                          label: Text(
                            widget.faseRecoleccion
                                ? "Chat Local"
                                : "Chat Cliente",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _abrirChatEnMapa,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade300,
                          foregroundColor: Colors.black87,
                          elevation: 6,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.drive_eta, size: 20),
                        label: const Text(
                          "Waze",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _abrirWazeNativo,
                      ),
                    ),
                  ],
                ),
                if (!widget.faseRecoleccion) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        "ENTREGAR AL CLIENTE",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
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
