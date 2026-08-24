import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar el código de rastreo al portapapeles
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart'; // <-- Tubería central

class VistaHistorial extends StatefulWidget {
  final int idCliente; // Recibe el ID real del cliente logueado[cite: 14]
  const VistaHistorial({super.key, this.idCliente = 1});

  @override
  State<VistaHistorial> createState() => _VistaHistorialState();
}

class _VistaHistorialState extends State<VistaHistorial> {
  List<dynamic> _historialPedidos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorialReal();
  }

  Future<void> _cargarHistorialReal() async {
    setState(() => _cargando = true);
    try {
      final url =
          Uri.parse('$urlCentral/api/historial_cliente/${widget.idCliente}');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 5));

      if (respuesta.statusCode == 200 && mounted) {
        setState(() {
          _historialPedidos = json.decode(utf8.decode(respuesta.bodyBytes));
          _cargando = false;
        });
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      debugPrint("🚨 Error cargando historial: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // 🔥 MINI VENTANITA DE DETALLES Y RASTREO
  void _mostrarDetallesPedido(Map<String, dynamic> pedido) {
    final int idPed = pedido['id_pedido'] ?? pedido['id'] ?? 0;
    final String codigoRastreo = pedido['codigo_rastreo'] ?? 'CP-0000';
    final String nombreLocal =
        pedido['nombre_local'] ?? pedido['comercio'] ?? 'Comercio Local';
    final String fecha = pedido['fecha'] ?? 'Fecha desconocida';
    final double total =
        double.tryParse((pedido['total'] ?? 0).toString()) ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF1E3A8A), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Orden #$idPed",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            _FilaDetalle(
                icono: Icons.storefront,
                titulo: "Comercio:",
                valor: nombreLocal),
            const SizedBox(height: 10),
            _FilaDetalle(
                icono: Icons.calendar_today, titulo: "Fecha:", valor: fecha),
            const SizedBox(height: 10),
            _FilaDetalle(
                icono: Icons.payments,
                titulo: "Total Pagado:",
                valor: "\$${total.toStringAsFixed(2)}"),
            const SizedBox(height: 15),

            // CAJA DESTACADA PARA EL CÓDIGO DE RASTREO (LISTO PARA COPIAR)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Código de Rastreo:",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        codigoRastreo,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Color(0xFF1E3A8A)),
                        tooltip: "Copiar Código",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: codigoRastreo));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("¡Código de rastreo copiado!"),
                                backgroundColor: Colors.green),
                          );
                        },
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  // Función para borrar un solo pedido del historial[cite: 14]
  Future<void> _borrarPedido(int idPedido) async {
    try {
      final url = Uri.parse('$urlCentral/api/cliente/borrar_historial');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_pedido': idPedido}),
      );
      if (res.statusCode == 200) {
        _cargarHistorialReal();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pedido eliminado del historial"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error borrando pedido: $e");
    }
  }

  // Función para limpiar todo el historial[cite: 14]
  Future<void> _borrarTodo() async {
    try {
      final url =
          Uri.parse('$urlCentral/api/cliente/limpiar_todo/${widget.idCliente}');
      final res = await http.post(url);
      if (res.statusCode == 200) {
        _cargarHistorialReal();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Historial limpiado por completo"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error borrando todo: $e");
    }
  }

  // Ventana de confirmación antes de borrar todo[cite: 14]
  void _mostrarDialogoBorrarTodo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Limpiar historial?"),
        content: const Text(
            "Se eliminarán de tu vista todos los pedidos pasados. Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _borrarTodo();
            },
            child: const Text("Sí, limpiar todo",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Pedidos",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          if (_historialPedidos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 28),
              tooltip: "Limpiar historial",
              onPressed: _mostrarDialogoBorrarTodo,
            )
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _historialPedidos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No tienes pedidos en tu historial.",
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarHistorialReal,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _historialPedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = _historialPedidos[index];
                      final int idPed =
                          pedido['id_pedido'] ?? pedido['id'] ?? 0;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        // 🔥 AL TOCAR LA TARJETA SE ABRE LA VENTANA CON EL RASTREO
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _mostrarDetallesPedido(pedido),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Orden #$idPed",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A8A)),
                                    ),
                                    Text(
                                      pedido['fecha'] ?? 'Fecha desconocida',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  children: [
                                    const Icon(Icons.fastfood,
                                        color: Colors.orange),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        pedido['articulos'] ?? 'Sin detalle',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        (pedido['estado'] ?? 'Entregado')
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total: \$${double.tryParse((pedido['total'] ?? 0).toString())?.toStringAsFixed(2) ?? '0.00'}",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      tooltip: "Eliminar este pedido",
                                      onPressed: () => _borrarPedido(idPed),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Widget auxiliar para formatear filas en la mini ventanita
class _FilaDetalle extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const _FilaDetalle(
      {required this.icono, required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                    text: "$titulo ",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
