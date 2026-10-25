// Archivo: repa_viajes.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'api_http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'gps_service.dart';
import 'chat_pedido.dart';
import 'mapa_repartidor.dart'; // 🔥 Importamos la memoria global

class BotonNavegacionParpadeante extends StatefulWidget {
  final Color color;
  const BotonNavegacionParpadeante({super.key, required this.color});

  @override
  State<BotonNavegacionParpadeante> createState() =>
      _BotonNavegacionParpadeanteState();
}

class _BotonNavegacionParpadeanteState extends State<BotonNavegacionParpadeante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.navigation, color: widget.color, size: 22),
      ),
    );
  }
}

class RepaViajes extends StatefulWidget {
  final int idRepartidor;
  const RepaViajes({super.key, required this.idRepartidor});

  @override
  State<RepaViajes> createState() => _RepaViajesState();
}

// 🔥 Cambiamos a TickerProviderStateMixin para soportar múltiples animaciones
class _RepaViajesState extends State<RepaViajes> with TickerProviderStateMixin {
  Map<String, dynamic>? _viaje;
  bool _cargando = true;
  LatLng _ubicacionActual = const LatLng(13.7746, -89.0244);
  LatLng _ubicacionDestino = const LatLng(13.7746, -89.0244);

  StreamSubscription<Position>? _streamPosicion;
  Timer? _timerRuta;
  Timer? _timerEstadoViaje;
  Timer? _timerChatNotif;

  List<LatLng> _rutaCalles = [];
  bool _hayMensajeNuevo = false;
  int _gpsIniciadoParaPedido = 0;

  final MapController _mapController = MapController();

  late final AnimationController _blinkController;
  late final AnimationController _chatBlinkController;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // 🔥 Controlador para el parpadeo del botón de chat
    _chatBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.3,
      upperBound: 1.0,
    );

    _cargarViajeVivo();
    _iniciarMotorNavegacion();

    _timerEstadoViaje = Timer.periodic(const Duration(seconds: 3), (_) {
      _cargarViajeSilencioso();
    });

    _iniciarEscaneoChatRepartidor();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _chatBlinkController.dispose();
    _streamPosicion?.cancel();
    _timerRuta?.cancel();
    _timerEstadoViaje?.cancel();
    _timerChatNotif?.cancel();
    super.dispose();
  }

  // 🔍 Monitoreo Inteligente conectado con la Memoria Global
  void _iniciarEscaneoChatRepartidor() {
    _timerChatNotif = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_viaje == null) return;
      final int idPed =
          int.tryParse(_viaje!['id_pedido']?.toString() ?? '0') ?? 0;
      final String estado = _viaje!['estado']?.toString() ?? 'asignado';
      final bool faseRecoleccion = estado == 'asignado';
      final canal =
          faseRecoleccion ? "motorista_comercio" : "motorista_consumidor";

      if (idPed > 0) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final url = Uri.parse(
              '$urlCentral/api/chat/historial/$idPed?canal=$canal&t=$timestamp');
          final res = await http.get(url).timeout(const Duration(seconds: 2));

          if (res.statusCode == 200) {
            final data = json.decode(utf8.decode(res.bodyBytes));
            List mensajes = data['mensajes'] ?? [];
            int totalActual = mensajes.length;

            if (!globalMensajesConocidosRepartidor.containsKey(idPed)) {
              globalMensajesConocidosRepartidor[idPed] = totalActual;
              _hayMensajeNuevo = false;
            } else {
              int conocidos = globalMensajesConocidosRepartidor[idPed]!;

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
                } else {
                  globalMensajesConocidosRepartidor[idPed] = totalActual;
                }
              } else if (totalActual == conocidos && _hayMensajeNuevo) {
                // Si el mensaje se leyó en el Mapa (y se actualizó la global), apagamos la alerta aquí
                setState(() {
                  _hayMensajeNuevo = false;
                  _chatBlinkController.stop();
                  _chatBlinkController.value = 1.0;
                });
              }
            }
          }
        } catch (_) {}
      }
    });
  }

  // 🔥 Se llama cuando cerramos el chat desde ESTA pantalla
  Future<void> _sincronizarHistorialAlCerrar(
      int idPed, bool faseRecoleccion) async {
    try {
      final canal =
          faseRecoleccion ? "motorista_comercio" : "motorista_consumidor";
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/$idPed?canal=$canal&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];
        globalMensajesConocidosRepartidor[idPed] =
            mensajes.length; // Actualiza global
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

  // 🔥 Se llama cuando regresamos de la pantalla del Mapa
  Future<void> _sincronizarEstadoDesdeGlobal(
      int idPed, bool faseRecoleccion) async {
    try {
      final canal =
          faseRecoleccion ? "motorista_comercio" : "motorista_consumidor";
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/$idPed?canal=$canal&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];
        int totalActual = mensajes.length;
        int conocidos = globalMensajesConocidosRepartidor[idPed] ?? totalActual;

        if (mounted) {
          setState(() {
            _hayMensajeNuevo = totalActual > conocidos;
            if (!_hayMensajeNuevo) {
              _chatBlinkController.stop();
              _chatBlinkController.value = 1.0;
            }
          });
        }
      }
    } catch (_) {}
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
        _ubicacionActual = LatLng(posInicial.latitude, posInicial.longitude);
      });
      _trazarRutaWaze();
      if (_viaje != null) {
        _mapController.move(_ubicacionActual, 16.5);
      }
    }

    const opcionesNavegacion = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _streamPosicion =
        Geolocator.getPositionStream(locationSettings: opcionesNavegacion)
            .listen((Position pos) {
      if (mounted && _viaje != null) {
        setState(() {
          _ubicacionActual = LatLng(pos.latitude, pos.longitude);
        });
      }
    });

    _timerRuta = Timer.periodic(const Duration(seconds: 5), (timer) {
      _trazarRutaWaze();
    });
  }

  Future<void> _trazarRutaWaze() async {
    if (_viaje == null) return;
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_ubicacionActual.longitude},${_ubicacionActual.latitude};${_ubicacionDestino.longitude},${_ubicacionDestino.latitude}?geometries=geojson&overview=full');
      final res = await http.get(url).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final coordenadasRaw = data['routes'][0]['geometry']['coordinates'];

        List<LatLng> puntos = [];
        for (var coord in coordenadasRaw) {
          puntos.add(LatLng(coord[1], coord[0]));
        }
        if (mounted) setState(() => _rutaCalles = puntos);
      }
    } catch (_) {}
  }

  Future<void> _cargarViajeVivo() async {
    setState(() => _cargando = true);
    await _cargarViajeSilencioso();
  }

  Future<void> _cargarViajeSilencioso() async {
    try {
      final res = await http.get(Uri.parse(
          '$urlCentral/api/viaje_activo/repartidor/${widget.idRepartidor}'));
      if (res.statusCode == 200 && mounted) {
        final datos = json.decode(utf8.decode(res.bodyBytes));

        if (datos['tiene_viaje'] == true) {
          final viajeData = datos['viaje'];
          final String estado = viajeData['estado']?.toString() ?? 'asignado';
          final bool faseRecoleccion = estado == 'asignado';

          double latDest = double.tryParse(faseRecoleccion
                  ? (viajeData['latitud_comercio']?.toString() ?? '13.7746')
                  : (viajeData['latitud_cliente']?.toString() ?? '13.7750')) ??
              13.7750;

          double lonDest = double.tryParse(faseRecoleccion
                  ? (viajeData['longitud_comercio']?.toString() ?? '-89.0244')
                  : (viajeData['longitud_cliente']?.toString() ??
                      '-89.0240')) ??
              -89.0244;

          setState(() {
            _viaje = viajeData;
            _ubicacionDestino = LatLng(latDest, lonDest);
            _cargando = false;
          });

          final int idPed =
              int.tryParse(viajeData['id_pedido']?.toString() ?? '0') ?? 0;
          if (idPed > 0 && _gpsIniciadoParaPedido != idPed) {
            GpsService.iniciarLatidosGps(idPed);
            _gpsIniciadoParaPedido = idPed;
          }
        } else {
          setState(() {
            _viaje = null;
            _cargando = false;
          });
        }
      }
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  String _calcularDistanciaYtiempoETA() {
    const Distance distanciaMundial = Distance();
    final double metros = distanciaMundial.as(
        LengthUnit.Meter, _ubicacionActual, _ubicacionDestino);
    final double km = metros / 1000;
    int totalMinutos = (km * 3).ceil();
    if (totalMinutos <= 0) totalMinutos = 1;
    String tiempoTexto = "";
    if (totalMinutos >= 60) {
      int horas = totalMinutos ~/ 60;
      int minsRestantes = totalMinutos % 60;
      tiempoTexto = "$horas h ${minsRestantes > 0 ? '$minsRestantes min' : ''}";
    } else {
      tiempoTexto = "$totalMinutos min";
    }
    return "${km.toStringAsFixed(1)} km • Llega en $tiempoTexto";
  }

  void _abrirChat() {
    // Al abrir el chat, apagamos la alerta visual y detenemos el parpadeo
    setState(() {
      _hayMensajeNuevo = false;
      _chatBlinkController.stop();
      _chatBlinkController.value = 1.0;
    });

    final int idPed =
        int.tryParse(_viaje!['id_pedido']?.toString() ?? '0') ?? 0;
    final bool faseRecoleccion = _viaje!['estado'] == 'asignado';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPedidoScreen(
          idPedido: idPed,
          remitente: "Motorista",
          canal:
              faseRecoleccion ? "motorista_comercio" : "motorista_consumidor",
          nombreDestino:
              faseRecoleccion ? "Chat con Local" : "Chat con Cliente",
        ),
      ),
    ).then((_) {
      _sincronizarHistorialAlCerrar(idPed, faseRecoleccion);
    });
  }

  void _mostrarDialogoEntrega(
      BuildContext context, int idPed, bool faseRecoleccion) {
    if (faseRecoleccion) return;

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
              if (pin.isEmpty) return;

              try {
                final url = Uri.parse('$urlCentral/api/entregar_pedido');
                final res = await http.post(url,
                    headers: {"Content-Type": "application/json"},
                    body: json.encode({"id_pedido": idPed, "pin": pin}));
                final data = json.decode(utf8.decode(res.bodyBytes));
                if (!context.mounted) return;

                if (data['status'] == 'ok') {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("¡Entregado con éxito!"),
                      backgroundColor: Colors.green));
                  GpsService.apagarGps();
                  _cargarViajeVivo();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(data['mensaje'] ?? "PIN Incorrecto"),
                      backgroundColor: Colors.red));
                }
              } catch (_) {}
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
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }

    if (_viaje == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text("No tienes entregas activas.",
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white),
              onPressed: _cargarViajeVivo,
              icon: const Icon(Icons.refresh),
              label: const Text("Actualizar Pantalla"),
            )
          ],
        ),
      );
    }

    final int idPed =
        int.tryParse(_viaje!['id_pedido']?.toString() ?? '0') ?? 0;
    final bool faseRecoleccion = _viaje!['estado'] == 'asignado';
    final String codigoRastreo =
        _viaje!['codigo_rastreo']?.toString() ?? 'CP-0000';
    final String pinRecoleccion =
        _viaje!['pin_recoleccion']?.toString() ?? '----';

    final String nombreDestinoFinal = faseRecoleccion
        ? (_viaje!['comercio_nombre'] ?? _viaje!['negocio'] ?? 'Local')
        : (_viaje!['cliente_nombre'] ?? 'Cliente');
    final String direccionFinal = faseRecoleccion
        ? (_viaje!['comercio_direccion'] ?? 'Dirección no especificada')
        : (_viaje!['cliente_direccion'] ?? 'Dirección no especificada');
    final String horarioLocal =
        _viaje!['comercio_horario']?.toString() ?? '9am - 6pm';

    List<LatLng> puntosRutaFinal = _rutaCalles.isNotEmpty
        ? _rutaCalles
        : [_ubicacionActual, _ubicacionDestino];

    return RefreshIndicator(
      onRefresh: _cargarViajeVivo,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 🗺️ 1. MAPA COMPACTO CON BOTÓN DE PANTALLA COMPLETA
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                        initialCenter: _ubicacionActual, initialZoom: 16.5),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.perulapia_connect',
                      ),
                      if (_rutaCalles.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: puntosRutaFinal,
                              color: faseRecoleccion
                                  ? Colors.orange.shade600
                                  : Colors.blue.shade600,
                              strokeWidth: 5.0,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _ubicacionActual,
                            width: 40,
                            height: 40,
                            child: FadeTransition(
                              opacity: _blinkController,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.blue.shade800, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black45, blurRadius: 4)
                                  ],
                                ),
                                child: Icon(Icons.navigation,
                                    color: Colors.blue.shade800, size: 22),
                              ),
                            ),
                          ),
                          Marker(
                            point: _ubicacionDestino,
                            width: 45,
                            height: 45,
                            child: Container(
                              decoration: BoxDecoration(
                                color: faseRecoleccion
                                    ? Colors.orange.shade700
                                    : Colors.indigo.shade800,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38, blurRadius: 4)
                                ],
                              ),
                              child: Icon(
                                  faseRecoleccion ? Icons.store : Icons.home,
                                  color: Colors.white,
                                  size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () async {
                          // 🔥 Ya NO apagamos la alerta antes de abrir, obligamos al usuario a leer el chat allá
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RadarMapaScreen(
                                idPedido: idPed,
                                codigoRastreo: codigoRastreo,
                                faseRecoleccion: faseRecoleccion,
                                latDestino: _ubicacionDestino.latitude,
                                lonDestino: _ubicacionDestino.longitude,
                                nombreDestino: nombreDestinoFinal,
                              ),
                            ),
                          );
                          // 🔥 Al volver del mapa, verificamos si leyó los mensajes allá
                          _sincronizarEstadoDesdeGlobal(idPed, faseRecoleccion);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.fullscreen,
                                color: Colors.teal.shade700, size: 20),
                            const SizedBox(width: 6),
                            Text("PANTALLA COMPLETA",
                                style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🕒 2. TARJETA DE ESTADO SUAVE E INTERACTIVA
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _mapController.move(_ubicacionDestino, 17.0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Centrando mapa en el destino..."),
                    duration: Duration(milliseconds: 800)),
              );
            },
            child: Card(
              elevation: 2,
              color:
                  faseRecoleccion ? Colors.orange.shade50 : Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                    color: faseRecoleccion
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                    width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    BotonNavegacionParpadeante(
                      color: faseRecoleccion
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faseRecoleccion
                                ? "Camino al Local (En vivo)"
                                : "Camino al Cliente (En vivo)",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: faseRecoleccion
                                    ? Colors.orange.shade900
                                    : Colors.blue.shade900,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(_calcularDistanciaYtiempoETA(),
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.my_location, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 🏪 3. TARJETA BLANCA: DATOS DEL LOCAL Y PIN INTEGRADO
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(faseRecoleccion ? Icons.storefront : Icons.home,
                        size: 40, color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(faseRecoleccion ? "Recoger en:" : "Entregar a:",
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                        Text(nombreDestinoFinal.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(direccionFinal,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (faseRecoleccion) ...[
                          const SizedBox(height: 4),
                          Text("Horario: $horarioLocal",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                  if (faseRecoleccion) ...[
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Text("PIN de Recolección",
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.password,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(pinRecoleccion,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 💬 4. BOTONES LLEGUE AL LOCAL Y CHAT
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: Text(
                      faseRecoleccion ? "Llegué al Local" : "Llegué a Puerta",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      final destino = faseRecoleccion ? 'local' : 'cliente';
                      final url = Uri.parse(
                          '$urlCentral/api/repartidor/notificar_llegada');
                      await http.post(url,
                          headers: {"Content-Type": "application/json"},
                          body: json.encode(
                              {"id_pedido": idPed, "destino": destino}));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Aviso enviado con éxito"),
                                backgroundColor: Colors.green));
                      }
                    } catch (_) {}
                  },
                ),
              ),
              const SizedBox(width: 12),

              // 🔥 BOTÓN CHAT (Con diseño animado inteligente, sin cambiar color, con borde blanco si alerta)
              Expanded(
                child: FadeTransition(
                  opacity: _hayMensajeNuevo
                      ? _chatBlinkController
                      : const AlwaysStoppedAnimation(1.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.blueAccent.shade700, // Siempre Azul
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: _hayMensajeNuevo
                              ? const BorderSide(color: Colors.white, width: 2)
                              : BorderSide.none,
                        )),
                    icon: Badge(
                      isLabelVisible: _hayMensajeNuevo,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.chat_bubble_outline, size: 18),
                    ),
                    label: Text(faseRecoleccion ? "Chat Local" : "Chat Cliente",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: _abrirChat,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ 5. BOTÓN ENTREGAR AL CLIENTE
          if (!faseRecoleccion)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text("Entregar al Cliente",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  _mostrarDialogoEntrega(context, idPed, faseRecoleccion);
                },
              ),
            ),
        ],
      ),
    );
  }
}
