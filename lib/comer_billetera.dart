import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';

class ComerBilletera extends StatefulWidget {
  final int idComercio;
  const ComerBilletera({super.key, required this.idComercio});

  @override
  State<ComerBilletera> createState() => _ComerBilleteraState();
}

class _ComerBilleteraState extends State<ComerBilletera> {
  String frecuenciaPago = 'Cada 24 horas';
  String gananciaTotal = "0.00";
  List movimientos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarBilletera();
  }

  Future<void> cargarBilletera() async {
    try {
      final url = Uri.parse(
        '$urlCentral/billetera/comercio/${widget.idComercio}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          gananciaTotal = double.parse(
            (data['ganancia_total'] ?? 0).toString(),
          ).toStringAsFixed(2);
          movimientos = data['historial'] ?? [];
          cargando = false;
        });
      } else {
        if (mounted) setState(() => cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => cargando = false);
      debugPrint("Error conectando a la billetera: $e");
    }
  }

  Future<void> _limpiarHistorialServidor() async {
    final url = Uri.parse(
        '$urlCentral/api/billetera/limpiar_todo/${widget.idComercio}');
    try {
      await http.post(url);
      cargarBilletera();
    } catch (e) {
      debugPrint("Error al limpiar historial: $e");
    }
  }

  Future<void> _borrarMovimientoServidor(int idPedido) async {
    final url = Uri.parse('$urlCentral/api/billetera/borrar_movimiento');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_pedido": idPedido}),
      );
      cargarBilletera();
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
            "¿Deseas vaciar y archivar todo el historial en el servidor?"),
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
    return cargando
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
          )
        : RefreshIndicator(
            onRefresh: cargarBilletera,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
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
                        "\$ $gananciaTotal",
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
                          const Column(
                            children: [
                              Text(
                                "Tipo de Cuenta",
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                "Comercio",
                                style: TextStyle(
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
                                "Ventas Exitosas",
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                "${movimientos.length}",
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        "Configuración de Pago",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                          if (movimientos.isNotEmpty)
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
                      if (movimientos.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              "Aún no tienes ventas entregadas registradas o el historial está limpio.",
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ...movimientos.map((movimiento) {
                        final int idPed =
                            int.tryParse(movimiento['id_pedido'].toString()) ??
                                0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.monetization_on,
                              color: Colors.green,
                            ),
                            title: Text(
                              "Pedido #$idPed - ${movimiento['descripcion']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text("Fecha: ${movimiento['fecha']}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "+\$${double.parse(movimiento['ganancia'].toString()).toStringAsFixed(2)}",
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
