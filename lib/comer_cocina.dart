import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'pedido_service.dart';
import 'logistica_service.dart';
import 'red.dart';
import 'mapa_comerciante.dart';

// ========================================================
// BOTÓN ANIMADO (PARPADEANTE) PARA EL COMERCIO
// ========================================================
class BotonRepartidorEnCamino extends StatefulWidget {
  final VoidCallback onPressed;
  const BotonRepartidorEnCamino({super.key, required this.onPressed});

  @override
  State<BotonRepartidorEnCamino> createState() =>
      _BotonRepartidorEnCaminoState();
}

class _BotonRepartidorEnCaminoState extends State<BotonRepartidorEnCamino>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.orangeAccent, width: 2),
            ),
          ),
          icon: const Icon(Icons.map_rounded),
          label: const Text(
            "REPARTIDOR EN CAMINO",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

// ========================================================
// VISTA COCINA
// ========================================================
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

class _VistaCocinaState extends State<VistaCocina> {
  final PedidoService _pedidoService = PedidoService();
  List<dynamic> _pedidos = [];
  bool _cargando = true;
  Timer? _latido;

  @override
  void initState() {
    super.initState();
    _cargarPedidosReales();
    _latido = Timer.periodic(
      const Duration(seconds: 4),
      (t) => _cargarPedidosReales(),
    );
  }

  @override
  void dispose() {
    _latido?.cancel();
    super.dispose();
  }

  Future<void> _cargarPedidosReales() async {
    try {
      final pedidos = await _pedidoService.obtenerPedidos(widget.idComercio);
      if (mounted) {
        setState(() {
          _pedidos = pedidos;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar pedidos: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _aceptarPedido(int idPedido) async {
    try {
      final exito = await _pedidoService.aceptarPedido(idPedido, "15-20 mins");
      if (!mounted) return;

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Orden en preparación!"),
            backgroundColor: Colors.green,
          ),
        );
        _cargarPedidosReales();
      }
    } catch (e) {
      debugPrint("Error al aceptar pedido: $e");
    }
  }

  // 🔥 FUNCIÓN EXTRAÍDA: Muestra el diálogo del PIN para entregar el pedido
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
                    content: Text("¡Entregado! El cliente fue notificado."),
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

                  // 🔥 VALIDACIÓN BLINDADA Y LIMPIA CON EL JSON DE RESPUESTA
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
                            ? "¡Local abierto al público!"
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
                                          // 🔥 CONEXIÓN MÁGICA CON EL MAPA DEL COMERCIO
                                          BotonRepartidorEnCamino(
                                            onPressed: () async {
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
                                              // Si el comerciante apretó "ENTREGAR AL MOTORISTA" dentro del mapa
                                              if (entregar == true) {
                                                _mostrarDialogoEntrega(idPed);
                                              }
                                            },
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
