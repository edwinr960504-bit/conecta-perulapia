// Archivo: repa_viajes.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'gps_service.dart';
import 'radar_mapa.dart';

class BotonNavegacionParpadeante extends StatefulWidget {
  final Color color;
  const BotonNavegacionParpadeante({super.key, required this.color});

  @override
  State<BotonNavegacionParpadeante> createState() =>
      _BotonNavegacionParpadeanteState();
}

class _BotonNavegacionParpadeanteState extends State<BotonNavegacionParpadeante>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.2),
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

class _RepaViajesState extends State<RepaViajes> {
  Map<String, dynamic>? _viaje;
  bool _cargando = true;
  LatLng _ubicacionActual = const LatLng(13.7746, -89.0244);
  LatLng _ubicacionDestino = const LatLng(13.7746, -89.0244);
  Timer? _gpsTimerLocal;
  Timer? _timerEstadoViaje;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarViajeVivo();
    _iniciarMonitoreoPosicion();

    _timerEstadoViaje = Timer.periodic(const Duration(seconds: 3), (_) {
      _cargarViajeSilencioso();
    });
  }

  @override
  void dispose() {
    _gpsTimerLocal?.cancel();
    _timerEstadoViaje?.cancel();
    super.dispose();
  }

  void _iniciarMonitoreoPosicion() {
    _actualizarPosicionLocal();
    _gpsTimerLocal = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _viaje != null) {
        _actualizarPosicionLocal();
      }
    });
  }

  Future<void> _actualizarPosicionLocal() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      );
      if (mounted) {
        setState(() {
          _ubicacionActual = LatLng(pos.latitude, pos.longitude);
        });
        // Mueve la camarita de la miniatura automáticamente siguiendo a la moto en tiempo real
        _mapController.move(_ubicacionActual, _mapController.camera.zoom);
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
          final String estado = viajeData['estado'] ?? 'asignado';
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

          final int idPed = viajeData['id_pedido'] ?? 0;
          if (idPed > 0) GpsService.iniciarLatidosGps(idPed);
        } else {
          setState(() {
            _viaje = null;
            _cargando = false;
          });
        }
      }
    } catch (e) {
      // Falla en silencio
    }
  }

  String _calcularDistanciaYtiempoETA() {
    const Distance distanciaMundial = Distance();
    final double metros = distanciaMundial.as(
        LengthUnit.Meter, _ubicacionActual, _ubicacionDestino);
    final double km = metros / 1000;
    final int minutos = (km * 2).ceil();
    return "${km.toStringAsFixed(1)} km • Aprox. $minutos min";
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

    final int idPed = _viaje!['id_pedido'] ?? 0;
    final bool faseRecoleccion = _viaje!['estado'] == 'asignado';
    final String nombreDestinoFinal = faseRecoleccion
        ? (_viaje!['comercio_nombre'] ?? 'Local')
        : (_viaje!['cliente_direccion'] ?? 'Cliente');

    final String codigoRastreo = _viaje!['codigo_rastreo'] ?? 'CP-0000';
    final String pinRecoleccion =
        _viaje!['pin_recoleccion']?.toString() ?? '----';

    return RefreshIndicator(
      onRefresh: _cargarViajeVivo,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ENCABEZADO CÓDIGO Y PIN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Código de Orden",
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(codigoRastreo,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 25, width: 1, color: Colors.white30),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("PIN de Recolección",
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(pinRecoleccion,
                        style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 🗺️ MAPA MINIATURA VIVO Y ACTUALIZADO
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
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
              },
              child: Column(
                children: [
                  SizedBox(
                    height: 240,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _ubicacionActual,
                        initialZoom: 16.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.perulapia_connect',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                                points: [_ubicacionActual, _ubicacionDestino],
                                color: Colors.blue.shade700,
                                strokeWidth: 5.0),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                                point: _ubicacionActual,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 4)
                                      ]),
                                  child: const Icon(Icons.two_wheeler,
                                      color: Colors.white, size: 20),
                                )),
                            Marker(
                                point: _ubicacionDestino,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: faseRecoleccion
                                          ? Colors.orange.shade800
                                          : Colors.blue.shade800,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 4)
                                      ]),
                                  child: Icon(
                                      faseRecoleccion
                                          ? Icons.store
                                          : Icons.home,
                                      color: Colors.white,
                                      size: 20),
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.grey.shade100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.navigation,
                                color: Colors.blue, size: 16),
                            SizedBox(width: 4),
                            Text("Monitoreo GPS en vivo",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          icon: const Icon(Icons.fullscreen,
                              color: Color(0xFF0F766E), size: 18),
                          label: const Text("PANTALLA COMPLETA",
                              style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          onPressed: () {
                            Navigator.push(
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
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ACCESO RÁPIDO A RUTA
          Card(
            elevation: 2,
            color:
                faseRecoleccion ? Colors.orange.shade50 : Colors.blue.shade50,
            shape: RoundedRectangleBorder(
                side: BorderSide(
                    color: faseRecoleccion
                        ? Colors.orange.shade300
                        : Colors.blue.shade300),
                borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
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
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    BotonNavegacionParpadeante(
                      color: faseRecoleccion
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              faseRecoleccion
                                  ? "Ruta hacia el Local (Toca aquí)"
                                  : "Ruta hacia el Cliente (Toca aquí)",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: faseRecoleccion
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(_calcularDistanciaYtiempoETA(),
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 14),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // DESTINO ACTUAL
          Card(
            elevation: 2,
            child: ListTile(
              dense: true,
              leading: Icon(faseRecoleccion ? Icons.store : Icons.home,
                  color: const Color(0xFF0F766E), size: 26),
              title: Text(faseRecoleccion
                  ? "Recoger paquete en:"
                  : "Entregar en casa de:"),
              subtitle: Text(nombreDestinoFinal,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),

          // BOTÓN DE ACCIÓN / ENTREGA
          if (!faseRecoleccion)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon:
                  const Icon(Icons.check_circle, color: Colors.white, size: 24),
              label: const Text("Entregar al Cliente",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              onPressed: () {
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
                            prefixIcon: Icon(Icons.vpn_key))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancelar")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () async {
                          final pin = pinCtrl.text.trim();
                          if (pin.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Por favor ingresa un PIN"),
                                    backgroundColor: Colors.red));
                            return;
                          }

                          try {
                            final url =
                                Uri.parse('$urlCentral/api/entregar_pedido');
                            final res = await http.post(
                              url,
                              headers: {"Content-Type": "application/json"},
                              body:
                                  json.encode({"id_pedido": idPed, "pin": pin}),
                            );

                            final data =
                                json.decode(utf8.decode(res.bodyBytes));

                            if (!context.mounted) return;

                            if (data['status'] == 'ok') {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "¡Misión Cumplida! Ganancia sumada."),
                                      backgroundColor: Colors.green));
                              GpsService.apagarGps();
                              _cargarViajeVivo();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          data['mensaje'] ?? "PIN Incorrecto"),
                                      backgroundColor: Colors.red));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Error de conexión al servidor"),
                                    backgroundColor: Colors.red));
                          }
                        },
                        child: const Text("Confirmar Entrega",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
