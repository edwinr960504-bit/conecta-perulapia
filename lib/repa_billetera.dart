import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart'; // <-- Tubería central

class RepaBilletera extends StatefulWidget {
  final int idRepartidor;
  const RepaBilletera({super.key, required this.idRepartidor});

  @override
  State<RepaBilletera> createState() => _RepaBilleteraState();
}

class _RepaBilleteraState extends State<RepaBilletera> {
  bool _cargando = true;
  double _saldoTotal = 0.0;
  double _gananciaHoy = 0.0;
  int _viajesHoy = 0;
  List<dynamic> _movimientos = [];
  String frecuenciaPago = 'Cada 24 horas';

  @override
  void initState() {
    super.initState();
    _cargarBilleteraViva();
  }

  Future<void> _cargarBilleteraViva() async {
    try {
      final url = Uri.parse(
          '$urlCentral/api/repartidor/billetera/${widget.idRepartidor}');
      final res = await http.get(url);

      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _saldoTotal = double.tryParse(data['saldo_total'].toString()) ?? 0.0;
          _gananciaHoy =
              double.tryParse(data['ganancia_hoy'].toString()) ?? 0.0;
          _viajesHoy = int.tryParse(data['viajes_hoy'].toString()) ?? 0;
          _movimientos = data['historial'] ?? [];
          _cargando = false;
        });
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      debugPrint("Error al cargar billetera: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- LÓGICA DE LIMPIEZA EN EL SERVIDOR ---
  Future<void> _limpiarHistorialServidor() async {
    final url = Uri.parse(
        '$urlCentral/api/repartidor/limpiar_todo/${widget.idRepartidor}');
    try {
      await http.post(url);
      _cargarBilleteraViva();
    } catch (e) {
      debugPrint("Error al limpiar historial: $e");
    }
  }

  Future<void> _borrarMovimientoServidor(int idPedido) async {
    final url = Uri.parse('$urlCentral/api/repartidor/borrar_movimiento');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_pedido": idPedido}),
      );
      _cargarBilleteraViva();
    } catch (e) {
      debugPrint("Error al borrar movimiento: $e");
    }
  }

  void _confirmarLimpiarTodo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Limpiar Historial"),
        content: const Text(
            "¿Deseas vaciar y archivar todo el historial de viajes en el servidor?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _limpiarHistorialServidor();
            },
            child: const Text("Sí, limpiar",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _cargando
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F766E)))
        : RefreshIndicator(
            onRefresh: _cargarBilleteraViva,
            child: Column(
              children: [
                // --- CABECERA DINÁMICA ---
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F766E),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Saldo Disponible para Retiro",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "\$ ${_saldoTotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                "Ganancia Hoy",
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                "\$ ${_gananciaHoy.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                "Viajes Hoy",
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                "$_viajesHoy",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- LISTA DE MOVIMIENTOS E HISTORIAL ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        "Configuración de Pago",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: frecuenciaPago,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                        items: ['Cada 24 horas', 'Semanal'].map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (nuevoValor) {
                          if (nuevoValor != null) {
                            setState(() => frecuenciaPago = nuevoValor);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon:
                            const Icon(Icons.attach_money, color: Colors.white),
                        label: const Text(
                          "SOLICITAR RETIRO AHORA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Solicitud de retiro enviada a la central."),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                      const Divider(height: 40),

                      // --- TÍTULO Y BOTÓN LIMPIAR todo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Últimos Movimientos",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_movimientos.isNotEmpty)
                            TextButton.icon(
                              onPressed: _confirmarLimpiarTodo,
                              icon: const Icon(Icons.delete_sweep,
                                  color: Colors.red),
                              label: const Text("Limpiar todo",
                                  style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_movimientos.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              "No hay viajes entregados registrados o el historial está limpio.",
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      ..._movimientos.map((m) {
                        final int idPed =
                            int.tryParse(m['id_pedido'].toString()) ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.monetization_on,
                              color: Colors.green,
                            ),
                            title: Text(
                              "Pago de Pedido #$idPed",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                                "Fecha: ${m['fecha_hora'] ?? m['fecha'] ?? 'Hoy'}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "+\$${double.parse(m['ganancia'].toString()).toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.grey, size: 20),
                                  tooltip: "Borrar movimiento",
                                  onPressed: () =>
                                      _borrarMovimientoServidor(idPed),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
  }
}
