// Archivo: comer_cocina.dart
import 'package:flutter/material.dart';
import 'api_http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'pedido_service.dart';
import 'logistica_service.dart';
import 'red.dart';
import 'mapa_comerciante.dart'; // Extrae la memoria global
import 'chat_pedido.dart';
import 'comer_flota.dart';

class BotonRepartidorEnCaminoCompacto extends StatefulWidget {
  final VoidCallback onPressed;
  const BotonRepartidorEnCaminoCompacto({super.key, required this.onPressed});

  @override
  State<BotonRepartidorEnCaminoCompacto> createState() =>
      _BotonRepartidorEnCaminoCompactoState();
}

class _BotonRepartidorEnCaminoCompactoState
    extends State<BotonRepartidorEnCaminoCompacto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.orangeAccent, width: 2),
          ),
        ),
        icon: const Icon(Icons.map_rounded, size: 18),
        label: const Text(
          "En Camino",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

class VistaCocina extends StatefulWidget {
  final String idComercio;
  final bool localAbierto;
  final ValueChanged<bool> onLocalAbiertoChanged;

  const VistaCocina({
    super.key,
    required this.idComercio,
    required this.localAbierto,
    required this.onLocalAbiertoChanged,
  });

  @override
  State<VistaCocina> createState() => _VistaCocinaState();
}

class _VistaCocinaState extends State<VistaCocina>
    with TickerProviderStateMixin {
  final PedidoService _pedidoService = PedidoService();
  List<dynamic> _pedidos = [];
  List<RepartidorPropio> _flota = [];
  bool _cargando = true;
  Timer? _latido;

  // Estado de alerta visual
  final Map<int, bool> _hayMensajesNuevos = {};

  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.3,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _cargarPedidosReales();
    _latido = Timer.periodic(
      const Duration(seconds: 4),
      (t) => _cargarPedidosReales(),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _latido?.cancel();
    super.dispose();
  }

  Future<void> _cargarPedidosReales() async {
    try {
      final pedidos = await _pedidoService.obtenerPedidos(widget.idComercio);
      final flota =
          await FlotaService.listar(int.parse(widget.idComercio.toString()));
      if (mounted) {
        setState(() {
          _pedidos = pedidos;
          _flota = flota;
          _cargando = false;
        });

        _verificarNotificacionesChat(pedidos);
      }
    } catch (e) {
      debugPrint("Error al cargar pedidos: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificarNotificacionesChat(List<dynamic> pedidos) async {
    for (var p in pedidos) {
      final int idPed = p['id_pedido'] ?? p['id'] ?? 0;
      final bool motoristaAsignado = p['id_repartidor'] != null ||
          p['repartidor_id'] != null ||
          p['estado'] == 'asignado' ||
          p['estado'] == 'en_camino';

      if (idPed > 0 && motoristaAsignado) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final url = Uri.parse(
              '$urlCentral/api/chat/historial/$idPed?canal=motorista_comercio&t=$timestamp');

          final res = await http.get(url).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            final data = json.decode(utf8.decode(res.bodyBytes));
            List mensajes = data['mensajes'] ?? [];
            int totalActual = mensajes.length;

            if (!globalMensajesConocidos.containsKey(idPed)) {
              globalMensajesConocidos[idPed] = totalActual;
              _hayMensajesNuevos[idPed] = false;
            } else {
              int conocidos = globalMensajesConocidos[idPed]!;
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
                    _hayMensajesNuevos[idPed] = true;
                  });
                } else {
                  globalMensajesConocidos[idPed] = totalActual;
                }
              } else if (totalActual == conocidos &&
                  _hayMensajesNuevos[idPed] == true) {
                setState(() {
                  _hayMensajesNuevos[idPed] = false;
                });
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  // 🔥 Se llama EXCLUSIVAMENTE cuando cerramos el chat dentro de la cocina (sí leíste los mensajes)
  Future<void> _marcarHistorialComoLeido(int idPed) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/$idPed?canal=motorista_comercio&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];
        globalMensajesConocidos[idPed] = mensajes.length;
        if (mounted) {
          setState(() {
            _hayMensajesNuevos[idPed] = false;
          });
        }
      }
    } catch (_) {}
  }

  // 🔥 Se llama cuando vuelves del mapa (verifica si leíste o no el chat allá adentro)
  Future<void> _sincronizarEstadoDesdeGlobal(int idPed) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/$idPed?canal=motorista_comercio&t=$timestamp');
      final res = await http.get(url).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        List mensajes = data['mensajes'] ?? [];
        int totalActual = mensajes.length;
        int conocidos = globalMensajesConocidos[idPed] ?? totalActual;

        if (mounted) {
          setState(() {
            // Si el total de mensajes sigue siendo mayor a los conocidos globalmente, sigue la alerta
            _hayMensajesNuevos[idPed] = totalActual > conocidos;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _aceptarPedido(int idPedido) async {
    try {
      final exito = await _pedidoService.aceptarPedido(idPedido, "15-20 mins");
      if (!mounted) return;

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Orden en preparación guardada permanentemente!"),
            backgroundColor: Colors.green,
          ),
        );
        _cargarPedidosReales();
      }
    } catch (e) {
      debugPrint("Error al aceptar pedido: $e");
    }
  }

  Future<void> _elegirRepartidorPropio(int idPed) async {
    final libres = _flota.where((r) => !r.ocupado).toList();
    if (libres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Tus repartidores están ocupados. Lanza el pedido al radar."),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final elegido = await showModalBottomSheet<RepartidorPropio>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text("Asignar a un repartidor libre",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final r in libres)
              ListTile(
                leading: const Icon(Icons.two_wheeler, color: Colors.teal),
                title: Text(r.nombre),
                subtitle: Text(r.telefono),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (elegido == null) return;
    final res = await FlotaService.asignar(idPed, elegido.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['mensaje'] ?? ''),
      backgroundColor: res['status'] == 'ok' ? Colors.green : Colors.red,
    ));
    _cargarPedidosReales();
  }

  Future<void> _lanzarARadar(int idPed) async {
    final res = await FlotaService.lanzarRadar(idPed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['mensaje'] ?? ''),
      backgroundColor: res['status'] == 'ok' ? Colors.green : Colors.red,
    ));
  }

  void _mostrarDialogoEntrega(int idPed) {
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
                _cargarPedidosReales();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 2,
            color: widget.localAbierto ? Colors.green[50] : Colors.red[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(
                widget.localAbierto ? "LOCAL ABIERTO" : "LOCAL CERRADO",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      widget.localAbierto ? Colors.green[800] : Colors.red[800],
                ),
              ),
              subtitle: Text(
                widget.localAbierto
                    ? "Recibiendo pedidos nuevos"
                    : "Pausado. No apareces en la app.",
              ),
              value: widget.localAbierto,
              activeTrackColor: Colors.green,
              inactiveTrackColor: Colors.redAccent,
              onChanged: (bool nuevoValor) async {
                final bool estadoAnterior = widget.localAbierto;
                widget.onLocalAbiertoChanged(nuevoValor);
                final mensajero = ScaffoldMessenger.of(context);

                try {
                  final url = Uri.parse(
                      '$urlCentral/api/comercio/estado/${widget.idComercio}');
                  final respuesta = await http.post(
                    url,
                    headers: {"Content-Type": "application/json"},
                    body: json.encode({"abierto": nuevoValor}),
                  );

                  final datosResq =
                      json.decode(utf8.decode(respuesta.bodyBytes));

                  if (respuesta.statusCode != 200 ||
                      datosResq['status'] == 'error') {
                    widget.onLocalAbiertoChanged(estadoAnterior);
                    mensajero.showSnackBar(
                      SnackBar(
                        content: Text(datosResq['mensaje'] ??
                            "No se pudo cambiar el estado del local."),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    mensajero.showSnackBar(
                      SnackBar(
                        content: Text(nuevoValor
                            ? "¡Local abierto permanentemente!"
                            : "Local cerrado correctamente."),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  widget.onLocalAbiertoChanged(estadoAnterior);
                  mensajero.showSnackBar(
                    const SnackBar(
                        content: Text("Error de conexión."),
                        backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ),
        ),
        Expanded(
          child: _cargando && _pedidos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _pedidos.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 80,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay pedidos pendientes.\n¡Todo está al día!',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _cargarPedidosReales,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Actualizar"),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarPedidosReales,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _pedidos.length,
                        itemBuilder: (context, index) {
                          final p = _pedidos[index];
                          final bool esPendiente = p['estado'] == 'pendiente';
                          final int idPed = p['id_pedido'] ?? p['id'] ?? 0;

                          final bool motoristaAsignado =
                              p['id_repartidor'] != null ||
                                  p['repartidor_id'] != null ||
                                  p['estado'] == 'asignado' ||
                                  p['estado'] == 'en_camino';

                          final bool hayAlerta =
                              _hayMensajesNuevos[idPed] ?? false;

                          return Card(
                            elevation: esPendiente ? 4 : 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: esPendiente
                                    ? Colors.orange
                                    : Colors.grey.shade300,
                                width: esPendiente ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Venta del Día #${p['numero_orden'] ?? idPed}",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "Serial: ${p['codigo_rastreo'] ?? 'CP-0000'}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: esPendiente
                                              ? Colors.orange[100]
                                              : Colors.blue[100],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          p['estado'].toString().toUpperCase(),
                                          style: TextStyle(
                                            color: esPendiente
                                                ? Colors.orange[800]
                                                : Colors.blue[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  const Text(
                                    "Detalle del pedido:",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p['descripcion'] ?? 'Sin descripción',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (esPendiente)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _aceptarPedido(idPed),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text(
                                          "ACEPTAR Y PREPARAR",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        if (motoristaAsignado) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child:
                                                    BotonRepartidorEnCaminoCompacto(
                                                  onPressed: () async {
                                                    // 🔥 Ya no apagamos la alerta aquí, el usuario debe leer el chat
                                                    final entregar =
                                                        await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            MapaComercianteScreen(
                                                          idPedido: idPed,
                                                          numeroOrden:
                                                              "${p['numero_orden'] ?? idPed}",
                                                        ),
                                                      ),
                                                    );

                                                    // Al volver del mapa, verifica de forma segura si leyó el chat allá o no
                                                    await _sincronizarEstadoDesdeGlobal(
                                                        idPed);

                                                    if (entregar == true) {
                                                      _mostrarDialogoEntrega(
                                                          idPed);
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: FadeTransition(
                                                  opacity: hayAlerta
                                                      ? _blinkController
                                                      : const AlwaysStoppedAnimation(
                                                          1.0),
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: hayAlerta
                                                          ? Colors.red.shade700
                                                          : Colors
                                                              .teal.shade700,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12,
                                                          horizontal: 8),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        side: hayAlerta
                                                            ? const BorderSide(
                                                                color: Colors
                                                                    .white,
                                                                width: 2)
                                                            : BorderSide.none,
                                                      ),
                                                    ),
                                                    icon: Icon(
                                                        hayAlerta
                                                            ? Icons
                                                                .mark_chat_unread
                                                            : Icons
                                                                .chat_bubble_outline,
                                                        size: 18),
                                                    label: const Text(
                                                      "Chat",
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    onPressed: () {
                                                      // Entró directo al chat, apagamos la alerta
                                                      setState(() {
                                                        _hayMensajesNuevos[
                                                            idPed] = false;
                                                      });
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ChatPedidoScreen(
                                                            idPedido: idPed,
                                                            remitente:
                                                                "Comercio",
                                                            canal:
                                                                "motorista_comercio",
                                                            nombreDestino:
                                                                "Chat con Motorista",
                                                          ),
                                                        ),
                                                      ).then((_) {
                                                        // 🔥 Regresó del chat, marcamos todo como leído globalmente
                                                        _marcarHistorialComoLeido(
                                                            idPed);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        if (!motoristaAsignado &&
                                            _flota.isNotEmpty) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.teal.shade700,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  icon: const Icon(
                                                      Icons.two_wheeler,
                                                      size: 18),
                                                  label: const Text(
                                                      "Mi repartidor"),
                                                  onPressed: () =>
                                                      _elegirRepartidorPropio(
                                                          idPed),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  icon: const Icon(
                                                      Icons.radar,
                                                      size: 18),
                                                  label: const Text(
                                                      "Lanzar a radar"),
                                                  onPressed: () =>
                                                      _lanzarARadar(idPed),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                            icon: const Icon(
                                                Icons.delivery_dining),
                                            label: const Text(
                                              "Entregar a Repartidor",
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () =>
                                                _mostrarDialogoEntrega(idPed),
                                          ),
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
        ),
      ],
    );
  }
}
