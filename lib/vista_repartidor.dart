// Archivo: vista_repartidor.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';

import 'vista_login.dart';
import 'carrito_service.dart';
import 'red.dart';
import 'gps_service.dart';

import 'repa_billetera.dart';
import 'repa_soporte.dart';
import 'repa_perfil.dart';
import 'repa_viajes.dart';

class VistaRepartidor extends StatefulWidget {
  final String nombre;
  final int idUsuario;

  const VistaRepartidor({
    super.key,
    required this.nombre,
    required this.idUsuario,
  });

  @override
  State<VistaRepartidor> createState() => _VistaRepartidorState();
}

class _VistaRepartidorState extends State<VistaRepartidor> {
  int _indiceActual = 0;
  bool _radarActivo = false;
  String _fotoPerfilReal = "";

  int _llaveRadar = 0;
  int _llaveViaje = 0;
  int _llaveBilletera = 0;

  @override
  void initState() {
    super.initState();
    _activarGPSMotorista();
    _cargarFotoPerfilCabecera();
  }

  Future<void> _activarGPSMotorista() async {
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _cargarFotoPerfilCabecera() async {
    try {
      final res = await http
          .get(Uri.parse('$urlCentral/api/perfil/${widget.idUsuario}'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _fotoPerfilReal = data['foto_perfil'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error cargando foto para cabecera: $e");
    }
  }

  void _cambiarPestana(int indice) {
    setState(() {
      _indiceActual = indice;
      if (indice == 0) _llaveRadar++;
      if (indice == 1) _llaveViaje++;
      if (indice == 2) _llaveBilletera++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vistas = [
      RepaRadar(
        key: ValueKey(_llaveRadar),
        idRepartidor: widget.idUsuario,
        radarActivo: _radarActivo,
        onCambiarRadar: (v) => setState(() => _radarActivo = v),
        onPedidoAceptado: () {
          setState(() {
            _indiceActual = 1;
            _llaveViaje++;
          });
        },
      ),
      RepaViajes(
        key: ValueKey(_llaveViaje),
        idRepartidor: widget.idUsuario,
      ),
      RepaBilletera(
        key: ValueKey(_llaveBilletera),
        idRepartidor: widget.idUsuario,
      ),
      RepaSoporte(idRepartidor: widget.idUsuario),
    ];

    final titulos = [
      "Radar de Entregas",
      "Viaje Activo",
      "Mi Billetera",
      "Soporte",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_indiceActual],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      drawer: _crearMenuLateral(context),
      body: Stack(
        children: [
          IndexedStack(
            index: _indiceActual,
            children: vistas,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: _cambiarPestana,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F766E),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Viaje'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Billetera'),
          BottomNavigationBarItem(
              icon: Icon(Icons.support_agent), label: 'Soporte'),
        ],
      ),
    );
  }

  Widget _crearMenuLateral(BuildContext context) {
    String urlFinalFoto = "";
    if (_fotoPerfilReal.isNotEmpty && _fotoPerfilReal != 'Sin foto') {
      urlFinalFoto = _fotoPerfilReal.startsWith('http')
          ? _fotoPerfilReal
          : '$urlCentral$_fotoPerfilReal';
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F766E)),
            accountName: Text(
              widget.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text('Rol: MOTORISTA'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage:
                  urlFinalFoto.isNotEmpty ? NetworkImage(urlFinalFoto) : null,
              child: urlFinalFoto.isEmpty
                  ? const Icon(Icons.two_wheeler,
                      size: 40, color: Color(0xFF0F766E))
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF0F766E)),
            title: const Text('Mi Perfil / Datos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        RepaPerfil(idRepartidor: widget.idUsuario)),
              );
              _cargarFotoPerfilCabecera();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Cerrar Sesión',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              CarritoService.limpiar();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPantalla()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class RepaRadar extends StatefulWidget {
  final int idRepartidor;
  final bool radarActivo;
  final ValueChanged<bool> onCambiarRadar;
  final VoidCallback onPedidoAceptado;

  const RepaRadar({
    super.key,
    required this.idRepartidor,
    required this.radarActivo,
    required this.onCambiarRadar,
    required this.onPedidoAceptado,
  });

  @override
  State<RepaRadar> createState() => _RepaRadarState();
}

class _RepaRadarState extends State<RepaRadar>
    with SingleTickerProviderStateMixin {
  List<dynamic> _comerciosActivos = [];
  List<dynamic> _pedidosDisponibles = [];
  bool _cargando = false;
  Timer? _temporizador;

  final MapController _mapController = MapController();
  late AnimationController _blinkController;

  final LatLng _centroPerulapia = const LatLng(13.7746, -89.0244);
  LatLng? _miUbicacionReal;

  LatLng? _destinoSeleccionadoRuta;
  List<LatLng> _rutaCalles = [];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    if (widget.radarActivo) {
      _obtenerMiGPS();
      _cargarBolsa();
    }

    _temporizador = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (widget.radarActivo && mounted) {
        _obtenerMiGPS();
        _cargarBolsa();
      }
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _trazarRutaHacia(LatLng destino) async {
    if (_miUbicacionReal == null) return;
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_miUbicacionReal!.longitude},${_miUbicacionReal!.latitude};${destino.longitude},${destino.latitude}?geometries=geojson&overview=full');

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
            _destinoSeleccionadoRuta = destino;
            _rutaCalles = puntos;
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ No se pudo trazar la ruta: $e");
    }
  }

  Future<void> _enviarUbicacionAlRadar(double lat, double lon) async {
    try {
      final url = Uri.parse('$urlCentral/api/motorista/actualizar_gps_vivo');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_usuario': widget.idRepartidor,
          'latitud': lat,
          'longitud': lon,
        }),
      );
    } catch (e) {
      // Falla en silencio
    }
  }

  Future<void> _obtenerMiGPS() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.best));
      if (mounted) {
        setState(() {
          _miUbicacionReal = LatLng(pos.latitude, pos.longitude);
        });
        _enviarUbicacionAlRadar(pos.latitude, pos.longitude);

        if (_destinoSeleccionadoRuta != null) {
          _trazarRutaHacia(_destinoSeleccionadoRuta!);
        }
      }
    } catch (e) {
      debugPrint("Error sacando GPS real: $e");
    }
  }

  Future<void> _cargarBolsa() async {
    if (!mounted) return;
    try {
      final resComercios =
          await http.get(Uri.parse('$urlCentral/api/comercios_activos'));
      final resPedidos =
          await http.get(Uri.parse('$urlCentral/api/pedidos_disponibles'));

      if (resComercios.statusCode == 200 &&
          resPedidos.statusCode == 200 &&
          mounted) {
        setState(() {
          _comerciosActivos = json.decode(utf8.decode(resComercios.bodyBytes));
          _pedidosDisponibles = json.decode(utf8.decode(resPedidos.bodyBytes));
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error de radar: $e");
    }
  }

  LatLng _obtenerUbicacionComercioReal(Map<String, dynamic> comercio) {
    double lat = double.tryParse(comercio['latitud']?.toString() ?? '0') ?? 0;
    double lon = double.tryParse(comercio['longitud']?.toString() ?? '0') ?? 0;

    if (lat != 0 && lon != 0) {
      return LatLng(lat, lon);
    }

    double latP =
        double.tryParse(comercio['latitud_comercio']?.toString() ?? '0') ?? 0;
    double lonP =
        double.tryParse(comercio['longitud_comercio']?.toString() ?? '0') ?? 0;
    if (latP != 0 && lonP != 0) {
      return LatLng(latP, lonP);
    }

    String nombre = comercio['nombre_local'] ?? comercio['negocio'] ?? 'Local';
    int baseId = comercio['id_comercio'] ?? comercio['id'] ?? 1;
    int hash = nombre.codeUnits.fold(0, (a, b) => a + b);
    double latOffset = ((hash % 15) - 7) * 0.0004;
    double lonOffset = ((baseId % 15) - 7) * 0.0004;
    return LatLng(_centroPerulapia.latitude + latOffset,
        _centroPerulapia.longitude + lonOffset);
  }

  void _zoomIn() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual + 1.0);
  }

  void _mostrarDetallePedido(Map<String, dynamic> pedido) {
    LatLng coordsLocal = _obtenerUbicacionComercioReal(pedido);

    double distanciaAprox = 0.0;
    if (_miUbicacionReal != null) {
      const Distance dist = Distance();
      distanciaAprox =
          dist.as(LengthUnit.Meter, _miUbicacionReal!, coordsLocal) / 1000;
    }

    String nombreLocal =
        pedido['negocio'] ?? pedido['nombre_local'] ?? 'Comercio';
    String numOrden = pedido['numero_orden']?.toString() ??
        pedido['id_pedido']?.toString() ??
        '1';
    String ganancia = pedido['ganancia_envio']?.toString() ?? '1.00';
    String totalPago = pedido['total_pago']?.toString() ??
        pedido['precio_comida']?.toString() ??
        '0.00';
    String estadoPedido = pedido['estado']?.toString() ?? 'pendiente';
    int idPedidoReal = int.tryParse(pedido['id_pedido']?.toString() ??
            pedido['id']?.toString() ??
            '0') ??
        0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.green.shade100, shape: BoxShape.circle),
                      child: Icon(Icons.storefront,
                          color: Colors.green.shade800, size: 30),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Local: $nombreLocal",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          Text("Orden #$numOrden",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Ganancia",
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text("\$$ganancia",
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    const Icon(Icons.directions_bike,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _miUbicacionReal != null
                            ? "Estás a ${distanciaAprox.toStringAsFixed(2)} km del establecimiento"
                            : "Calculando GPS...",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.payments, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Cobro total del viaje: \$$totalPago",
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      estadoPedido == 'pendiente'
                          ? Icons.access_time
                          : (estadoPedido == 'listo_recoleccion'
                              ? Icons.check_circle
                              : Icons.soup_kitchen),
                      color: estadoPedido == 'pendiente'
                          ? Colors.red
                          : (estadoPedido == 'listo_recoleccion'
                              ? Colors.green
                              : Colors.orange),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      estadoPedido == 'pendiente'
                          ? "Esperando confirmación del local"
                          : (estadoPedido == 'listo_recoleccion'
                              ? "¡Comida Lista para recoger!"
                              : "Cocinando (En preparación)"),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 130,
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.directions,
                        size: 16, color: Colors.white),
                    label: const Text("Ruta",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      _trazarRutaHacia(coordsLocal);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("¡Ruta trazada en el mapa!"),
                            duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.touch_app, color: Colors.white),
                    label: const Text("ACEPTAR ESTE VIAJE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    onPressed: () => _tomarPedido(idPedidoReal),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarListaLocalesActivos() {
    Map<String, List<dynamic>> localesAgrupados = {};
    for (var p in _pedidosDisponibles) {
      String nombreLocal = p['negocio'] ??
          p['nombre_local'] ??
          p['comercio'] ??
          'Comercio Local';
      localesAgrupados.putIfAbsent(nombreLocal, () => []).add(p);
    }

    List<String> nombresLocales = localesAgrupados.keys.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              Text(
                "Locales solicitando repartidor (${nombresLocales.length})",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E)),
              ),
              const Divider(height: 25),
              Expanded(
                child: nombresLocales.isEmpty
                    ? const Center(
                        child: Text("No hay locales solicitando repartidor"))
                    : ListView.builder(
                        itemCount: nombresLocales.length,
                        itemBuilder: (context, index) {
                          String nombreLocal = nombresLocales[index];
                          List<dynamic> pedidosDelLocal =
                              localesAgrupados[nombreLocal]!;

                          LatLng coords = _obtenerUbicacionComercioReal(
                              pedidosDelLocal.first);
                          double distanciaAprox = 0.0;
                          if (_miUbicacionReal != null) {
                            const Distance dist = Distance();
                            distanciaAprox = dist.as(LengthUnit.Meter,
                                    _miUbicacionReal!, coords) /
                                1000;
                          }

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.green.shade100,
                                        child: Icon(Icons.storefront,
                                            color: Colors.green.shade800),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(nombreLocal,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            Text(
                                                "A ${distanciaAprox.toStringAsFixed(2)} km de ti",
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0F766E),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _trazarRutaHacia(coords);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content:
                                                      Text("¡Ruta trazada!"),
                                                  duration:
                                                      Duration(seconds: 1)),
                                            );
                                          },
                                          icon: const Icon(Icons.directions,
                                              size: 16, color: Colors.white),
                                          label: const Text("Ruta",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  const Text(
                                      "Pedidos de este local (Desliza para ver más):",
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 95,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: pedidosDelLocal.length,
                                      itemBuilder: (context, pIndex) {
                                        final p = pedidosDelLocal[pIndex];
                                        String numOrden =
                                            p['numero_orden']?.toString() ??
                                                p['id_pedido']?.toString() ??
                                                '1';
                                        String ganancia =
                                            p['ganancia_envio']?.toString() ??
                                                '1.00';
                                        String descripcion = p['descripcion'] ??
                                            'Pedido de comida';

                                        return Container(
                                          width: 220,
                                          margin:
                                              const EdgeInsets.only(right: 10),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            border: Border.all(
                                                color: Colors.green.shade200),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text("Orden #$numOrden",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13)),
                                                  Text("\$$ganancia",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.green)),
                                                ],
                                              ),
                                              Text(descripcion,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 28,
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF0F766E),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    _mostrarDetallePedido(p);
                                                  },
                                                  child: const Text(
                                                      "Ver y Aceptar",
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _tomarPedido(int idPedido) async {
    try {
      final res = await http.post(
        Uri.parse('$urlCentral/api/tomar_pedido'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
            {'id_pedido': idPedido, 'id_repartidor': widget.idRepartidor}),
      );

      if (res.statusCode == 200) {
        final respuesta = json.decode(utf8.decode(res.bodyBytes));
        if (respuesta['status'] == 'ok') {
          await GpsService.enviarUbicacion(idPedido);
          GpsService.iniciarLatidosGps(idPedido);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("¡VIAJE ACEPTADO!"),
                  backgroundColor: Colors.green),
            );
            widget.onPedidoAceptado();
          }
        } else {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(respuesta['mensaje'] ?? "Error"),
                  backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error al aceptar viaje: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> marcadoresMapa = [];

    if (widget.radarActivo) {
      for (var comercio in _comerciosActivos) {
        final nombreComercio =
            comercio['nombre_local'] ?? comercio['nombre'] ?? '';
        final LatLng ubicacionReal = _obtenerUbicacionComercioReal(comercio);

        final bool tienePedido = _pedidosDisponibles.any((p) {
          final negocioPedido =
              p['negocio'] ?? p['nombre_local'] ?? p['comercio'] ?? '';
          return negocioPedido.toString().trim().toLowerCase() ==
              nombreComercio.toString().trim().toLowerCase();
        });

        if (tienePedido) continue;

        marcadoresMapa.add(
          Marker(
            point: ubicacionReal,
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child:
                  const Icon(Icons.storefront, color: Colors.white, size: 20),
            ),
          ),
        );
      }

      for (var pedido in _pedidosDisponibles) {
        final LatLng ubicacionPedido = _obtenerUbicacionComercioReal(pedido);

        marcadoresMapa.add(
          Marker(
            point: ubicacionPedido,
            width: 55,
            height: 55,
            child: GestureDetector(
              onTap: () => _mostrarDetallePedido(pedido),
              child: FadeTransition(
                opacity: _blinkController,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.greenAccent,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ],
                  ),
                  child: const Icon(Icons.storefront,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        );
      }

      if (_miUbicacionReal != null) {
        marcadoresMapa.add(
          Marker(
            point: _miUbicacionReal!,
            width: 45,
            height: 45,
            child: FadeTransition(
              opacity: _blinkController,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 6)
                  ],
                ),
                child: const Icon(Icons.two_wheeler,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          color: widget.radarActivo ? Colors.green.shade50 : Colors.red.shade50,
          child: SwitchListTile(
            title: Text(
                widget.radarActivo ? "RADAR ACTIVO" : "FUERA DE SERVICIO",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.radarActivo
                        ? Colors.green.shade800
                        : Colors.red.shade800)),
            subtitle: Text(widget.radarActivo
                ? "Escaneando Perulapía en vivo..."
                : "Enciende el radar para ver el mapa"),
            value: widget.radarActivo,
            activeThumbColor: Colors.green,
            onChanged: (val) {
              widget.onCambiarRadar(val);
              if (val) {
                setState(() => _cargando = true);
                _obtenerMiGPS();
                _cargarBolsa();
              } else {
                setState(() => _pedidosDisponibles = []);
              }
            },
          ),
        ),
        Expanded(
          child: !widget.radarActivo
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar_outlined, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Activa el radar para buscar viajes",
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _miUbicacionReal ?? _centroPerulapia,
                        initialZoom: 16.0,
                      ),
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
                                points: _rutaCalles,
                                color: Colors.green.shade700,
                                strokeWidth: 6.0,
                              ),
                            ],
                          ),
                        MarkerLayer(markers: marcadoresMapa),
                      ],
                    ),
                    if (_cargando)
                      const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF0F766E))),
                    Positioned(
                      bottom: 120,
                      right: 15,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: "btnZoomInRadarMain",
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F766E),
                            elevation: 4,
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 16),
                          FloatingActionButton(
                            heroTag: "btnCentroRadarPrincipal",
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            onPressed: () {
                              if (_miUbicacionReal != null) {
                                _mapController.move(_miUbicacionReal!, 16.5);
                              } else {
                                _mapController.move(_centroPerulapia, 16.0);
                              }
                            },
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 15,
                      right: 15,
                      child: FloatingActionButton.extended(
                        heroTag: "btnCuadroLocalesActivos",
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 4,
                        onPressed: _mostrarListaLocalesActivos,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.storefront,
                              color: Colors.green.shade800, size: 20),
                        ),
                        label: Text(
                          "${_pedidosDisponibles.length} ${_pedidosDisponibles.length == 1 ? 'local con pedido' : 'locales con pedido'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
