import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'mapa_consumidor.dart';

// ========================================================
// BOTÓN ANIMADO (PARPADEANTE) PARA EL CLIENTE
// ========================================================
class BotonMapaParpadeante extends StatefulWidget {
  final VoidCallback onPressed;
  const BotonMapaParpadeante({super.key, required this.onPressed});

  @override
  State<BotonMapaParpadeante> createState() => _BotonMapaParpadeanteState();
}

class _BotonMapaParpadeanteState extends State<BotonMapaParpadeante>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.map),
        label: const Text(
          "VER MAPA EN VIVO",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

// ========================================================
// VISTA RASTREO
// ========================================================
class CliRastreo extends StatefulWidget {
  final int idCliente;
  final Function(bool)? onEstadoPedidos;
  const CliRastreo({super.key, this.idCliente = 1, this.onEstadoPedidos});

  @override
  State<CliRastreo> createState() => _CliRastreoState();
}

class _CliRastreoState extends State<CliRastreo> {
  List<dynamic> _listaPedidos = [];
  bool _cargando = true;

  Timer? _latidosClienteTimer;
  Timer? _timerMonitoreoPedidos; // 🔥 EL NUEVO MOTOR AUTOMÁTICO

  LatLng? _miUbicacionReal;

  @override
  void initState() {
    super.initState();
    _cargarPedidosSilencioso();

    // 🔥 LATIDO: Trae los cambios de estado automáticamente cada 4 seg
    _timerMonitoreoPedidos =
        Timer.periodic(const Duration(seconds: 4), (timer) {
      _cargarPedidosSilencioso();
    });
  }

  @override
  void dispose() {
    _latidosClienteTimer?.cancel();
    _timerMonitoreoPedidos?.cancel();
    super.dispose();
  }

  void _iniciarLatidosCliente(int idPedido) {
    _latidosClienteTimer?.cancel();
    _latidosClienteTimer =
        Timer.periodic(const Duration(seconds: 8), (timer) async {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }

        Position pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );

        if (mounted) {
          setState(() {
            _miUbicacionReal = LatLng(pos.latitude, pos.longitude);
          });
        }

        final url = Uri.parse('$urlCentral/actualizar_gps_cliente');
        await http
            .post(
              url,
              headers: {"Content-Type": "application/json"},
              body: json.encode({
                "id_pedido": idPedido,
                "latitud": pos.latitude,
                "longitud": pos.longitude,
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("Error enviando GPS del cliente: $e");
      }
    });
  }

  // 🔥 NUEVA FUNCIÓN DE CARGA FLUIDA SIN BLOQUEAR LA PANTALLA
  Future<void> _cargarPedidosSilencioso() async {
    final url = Uri.parse(
        '$urlCentral/api/pedidos_activos/cliente/${widget.idCliente}');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List lista = json.decode(utf8.decode(res.bodyBytes));

        final listaActivos = lista.where((p) {
          final estado = (p['estado_codigo'] ?? '').toString().toLowerCase();
          return estado != 'entregado' &&
              estado != 'cancelado' &&
              estado != 'archivado';
        }).toList();

        final listaOrdenada = listaActivos.reversed.toList();

        if (listaOrdenada.isNotEmpty) {
          final int primerIdPedido = listaOrdenada.first['id_pedido'] ?? 0;
          if (primerIdPedido > 0 && _latidosClienteTimer == null) {
            _iniciarLatidosCliente(primerIdPedido);
          }
        } else {
          _latidosClienteTimer?.cancel();
          _latidosClienteTimer = null;
        }

        if (widget.onEstadoPedidos != null) {
          widget.onEstadoPedidos!(listaOrdenada.isNotEmpty);
        }

        if (mounted) {
          setState(() {
            _listaPedidos = listaOrdenada;
            _cargando = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error rastreo: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cancelarPedido(int idPedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cancelar Pedido?"),
        content: const Text(
            "El local aún no ha aceptado tu orden. ¿Deseas eliminar este pedido para buscar otro comercio?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, eliminar",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        final url = Uri.parse('$urlCentral/api/cancelar_pedido/$idPedido');
        final res = await http.post(url);

        if (res.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Pedido eliminado con éxito",
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.orange),
          );
          _latidosClienteTimer?.cancel();
          _latidosClienteTimer = null;
          _cargarPedidosSilencioso();
        }
      } catch (e) {
        debugPrint("Error al cancelar: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Rastreo de Pedidos Activos"),
        backgroundColor: const Color(0xFF0055A4),
        foregroundColor: Colors.white,
      ),
      body: _cargando && _listaPedidos.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0055A4)))
          : _listaPedidos.isEmpty
              ? RefreshIndicator(
                  onRefresh: _cargarPedidosSilencioso,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Icon(Icons.delivery_dining, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Center(
                          child: Text(
                              "No tienes pedidos activos en este momento.",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey))),
                      Center(
                          child: Text(
                              "Buscando actualizaciones automáticamente...",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarPedidosSilencioso,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _listaPedidos.length,
                    itemBuilder: (context, index) {
                      final p = _listaPedidos[index];
                      final estadoCodigo = p['estado_codigo'] ?? '';

                      final int numCompra =
                          p['numero_orden'] ?? p['id_pedido'] ?? 0;
                      final bool enCamino = (p['en_camino'] == true ||
                          estadoCodigo == 'en_camino');

                      String textoLlegadaExtra = "";
                      if (enCamino &&
                          _miUbicacionReal != null &&
                          p['lat'] != null &&
                          p['lon'] != null) {
                        double latRep =
                            double.tryParse(p['lat'].toString()) ?? 0.0;
                        double lonRep =
                            double.tryParse(p['lon'].toString()) ?? 0.0;

                        if (latRep != 0.0 && lonRep != 0.0) {
                          const Distance dist = Distance();
                          double km = dist.as(LengthUnit.Meter,
                                  _miUbicacionReal!, LatLng(latRep, lonRep)) /
                              1000;
                          int minutos = (km * 3).ceil();
                          textoLlegadaExtra = " • Llega en aprox. $minutos min";
                        }
                      }

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Color(0xFF0055A4),
                                        child: Icon(Icons.receipt_long,
                                            color: Colors.white),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Mi Compra del Día #$numCompra",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18),
                                          ),
                                          Text(
                                            "Serial: ${p['codigo_rastreo'] ?? 'CP-0000'}",
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey),
                                          ),
                                          Text(
                                            "${p['fecha'] ?? 'Hoy'}",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text("PIN",
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                        "${p['pin_seguridad'] ?? '---'}",
                                        style: const TextStyle(
                                            fontSize: 20,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  "${p['estado']}$textoLlegadaExtra",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0055A4),
                                      fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (enCamino)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: BotonMapaParpadeante(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MapaConsumidorScreen(
                                            idPedido: p['id_pedido'],
                                            codigoRastreo:
                                                p['codigo_rastreo'] ??
                                                    'CP-0000',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      "Total a pagar: \$${double.parse((p['total'] ?? 0).toString()).toStringAsFixed(2)}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  if (estadoCodigo == 'pendiente')
                                    IconButton(
                                      onPressed: () =>
                                          _cancelarPedido(p['id_pedido']),
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 26),
                                      tooltip: "Eliminar pedido",
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
