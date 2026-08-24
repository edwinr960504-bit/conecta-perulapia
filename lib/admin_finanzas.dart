import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';

class AdminFinanzas extends StatefulWidget {
  const AdminFinanzas({super.key});

  @override
  State<AdminFinanzas> createState() => _AdminFinanzasState();
}

class _AdminFinanzasState extends State<AdminFinanzas> {
  Map<String, dynamic> _finanzas = {};
  bool _cargandoFinanzas = true;

  @override
  void initState() {
    super.initState();
    _cargarFinanzas();
  }

  Future<void> _cargarFinanzas() async {
    setState(() => _cargandoFinanzas = true);
    try {
      final res =
          await http.get(Uri.parse('$urlCentral/api/admin/finanzas_caja'));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _finanzas = json.decode(utf8.decode(res.bodyBytes));
          _cargandoFinanzas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoFinanzas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finanzas y Corte de Caja"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _cargarFinanzas)
        ],
      ),
      body: _cargandoFinanzas
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarFinanzas,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.account_balance,
                      size: 80, color: Color(0xFF1E3A8A)),
                  const SizedBox(height: 20),
                  const Text("Corte de Caja Oficial",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Card(
                      child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.point_of_sale, color: Colors.white)),
                    title: const Text("Volumen de Ventas"),
                    trailing: Text(
                        "\$ ${_finanzas['volumen_total_ventas'] ?? '0.00'}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  )),
                  Card(
                      child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.trending_up, color: Colors.white)),
                    title: const Text("Ganancia de la App"),
                    trailing: Text(
                        "\$ ${_finanzas['ganancia_comisiones_app'] ?? '0.00'}",
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  )),
                  Card(
                      child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.two_wheeler, color: Colors.white)),
                    title: const Text("Pago a Motoristas"),
                    trailing: Text(
                        "\$ ${_finanzas['pago_total_motoristas'] ?? '0.00'}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  )),
                ],
              ),
            ),
    );
  }
}
