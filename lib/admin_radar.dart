import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';

class AdminRadar extends StatefulWidget {
  const AdminRadar({super.key});

  @override
  State<AdminRadar> createState() => _AdminRadarState();
}

class _AdminRadarState extends State<AdminRadar> {
  List<dynamic> _pedidosActivos = [];
  bool _cargandoRadar = true;

  @override
  void initState() {
    super.initState();
    _cargarRadar();
  }

  Future<void> _cargarRadar() async {
    setState(() => _cargandoRadar = true);
    try {
      final res =
          await http.get(Uri.parse('$urlCentral/api/admin/radar_despacho'));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _pedidosActivos = json.decode(utf8.decode(res.bodyBytes));
          _cargandoRadar = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoRadar = false);
    }
  }

  Future<void> _matarPedidoFantasma(int idPedido) async {
    final res = await http.post(
      // 🔥 CORREGIDO: Se eliminó la pleca (/) al final de cancelar_pedido
      Uri.parse('$urlCentral/api/cancelar_pedido'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_pedido': idPedido}),
    );
    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Pedido eliminado de raíz"),
          backgroundColor: Colors.red));
      _cargarRadar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Radar de Pedidos en Vivo"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarRadar)
        ],
      ),
      body: _cargandoRadar
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarRadar,
              child: _pedidosActivos.isEmpty
                  ? const Center(
                      child: Text(
                          "Radar limpio. Cero pedidos activos en este momento."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _pedidosActivos.length,
                      itemBuilder: (ctx, i) {
                        final p = _pedidosActivos[i];
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.delivery_dining,
                                color: Colors.blue, size: 30),
                            title: Text(
                                "Orden #${p['id_pedido']} - ${p['comercio']}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                "Estado: ${p['estado']}\nMotorista: ${p['repartidor']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.red, size: 30),
                              onPressed: () =>
                                  _matarPedidoFantasma(p['id_pedido']),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
