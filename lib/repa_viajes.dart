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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.navigation, color: widget.color, size: 28),
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
    _gpsTimerLocal = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _viaje != null) {
        _actualizarPosicionLocal();
      }
    });
  }

  // 🔥 EXTRACCIÓN DIRECTA: Sin pedir permisos, directo a la antena
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

    return RefreshIndicator(
      onRefresh: _cargarViajeVivo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Viaje Activo #$idPed",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 15),
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _ubicacionActual,
                      initialZoom: 16.0,
                      interactionOptions:
                          const InteractionOptions(flags: InteractiveFlag.none),
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
                              strokeWidth: 4.0),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                              point: _ubicacionActual,
                              width: 35,
                              height: 35,
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.orange.shade800,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                                child: const Icon(Icons.two_wheeler,
                                    color: Colors.white, size: 18),
                              )),
                          Marker(
                              point: _ubicacionDestino,
                              width: 35,
                              height: 35,
                              child: Container(
                                decoration: BoxDecoration(
                                    color: faseRecoleccion
                                        ? Colors.orange.shade800
                                        : Colors.blue.shade800,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                                child: Icon(
                                    faseRecoleccion ? Icons.store : Icons.home,
                                    color: Colors.white,
                                    size: 16),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.navigation, color: Colors.blue, size: 18),
                          SizedBox(width: 6),
                          Text("GPS Activo",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        icon: const Icon(Icons.fullscreen,
                            color: Color(0xFF0F766E), size: 20),
                        label: const Text("VER MAPA COMPLETO",
                            style: TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RadarMapaScreen(
                                idPedido: idPed,
                                codigoRastreo:
                                    _viaje!['codigo_rastreo'] ?? 'CP-0000',
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
          const SizedBox(height: 10),
          Card(
            elevation: 4,
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
                      codigoRastreo: _viaje!['codigo_rastreo'] ?? 'CP-0000',
                      faseRecoleccion: faseRecoleccion,
                      latDestino: _ubicacionDestino.latitude,
                      lonDestino: _ubicacionDestino.longitude,
                      nombreDestino: nombreDestinoFinal,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    BotonNavegacionParpadeante(
                      color: faseRecoleccion
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 12),
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
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(_calcularDistanciaYtiempoETA(),
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(faseRecoleccion ? Icons.store : Icons.home,
                  color: const Color(0xFF0F766E), size: 30),
              title: Text(faseRecoleccion
                  ? "Recoger paquete en:"
                  : "Entregar en casa de:"),
              subtitle: Text(nombreDestinoFinal,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          if (faseRecoleccion)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade800,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3))
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text("Dicta este PIN en el Local",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(_viaje!['pin_recoleccion']?.toString() ?? '----',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8)),
                  const Divider(color: Colors.white54, height: 30),
                  Text(
                      "Código de Orden: ${_viaje!['codigo_rastreo'] ?? 'CP-0000'}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text(
                      "Cuando el comerciante ingrese tu PIN, la aplicación te guiará automáticamente hacia el cliente.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon:
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
              label: const Text("Entregar al Cliente",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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
