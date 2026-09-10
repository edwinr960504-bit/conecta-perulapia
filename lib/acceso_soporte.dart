// Archivo: acceso_soporte.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';
import 'chat_soporte.dart';

class AccesoSoporte extends StatefulWidget {
  final int idCliente;
  final String nombreCliente;

  const AccesoSoporte({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
  });

  @override
  State<AccesoSoporte> createState() => _AccesoSoporteState();
}

class _AccesoSoporteState extends State<AccesoSoporte> {
  final TextEditingController _codigoCtrl = TextEditingController();
  bool _cargando = true;
  bool _validando = false;

  @override
  void initState() {
    super.initState();
    _buscarChatPendiente();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarChatPendiente() async {
    try {
      final url =
          Uri.parse('$urlCentral/api/cliente/chat_activo/${widget.idCliente}');
      // Le bajamos el tiempo de espera a 2 segundos para que si el servidor no responde, pase rápido
      final res = await http.get(url).timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));

        if (data['tiene_chat'] == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatSoporte(
                idPedido: data['id_pedido'],
                remitente: widget.nombreCliente,
                canal: "admin_cliente",
              ),
            ),
          );
          return;
        }
      }
    } catch (_) {
      // Si falla o la ruta no existe, ignoramos el error para no bloquear al usuario
    }

    // 🔥 Garantizamos que SIEMPRE quite el indicador de carga y muestre la interfaz
    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _validarIngreso() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Por favor, ingresa el código de tu pedido (Ej. CP-12345)")),
      );
      return;
    }

    setState(() => _validando = true);

    try {
      final url = Uri.parse('$urlCentral/api/cliente/validar_soporte/$codigo');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      final data = json.decode(utf8.decode(res.bodyBytes));

      if (mounted) setState(() => _validando = false);

      if (data['status'] == 'ok') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatSoporte(
              idPedido: data['id_pedido'],
              remitente: widget.nombreCliente,
              canal: "admin_cliente",
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensaje'] ?? "Código inválido."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _validando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Error de conexión. Intenta de nuevo."),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0055A4)),
              SizedBox(height: 16),
              Text("Buscando casos pendientes...",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Soporte de Pedidos"),
        backgroundColor: const Color(0xFF0055A4),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.support_agent_rounded,
                size: 80, color: Color(0xFF0055A4)),
            const SizedBox(height: 20),
            const Text(
              "¿Tienes algún inconveniente?",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0055A4)),
            ),
            const SizedBox(height: 10),
            const Text(
              "Ingresa el código de rastreo (Ej. CP-12345) de tu compra. Recuerda que tienes un máximo de 3 horas después de finalizado para levantar un reporte.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _codigoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: "Código de Rastreo",
                hintText: "CP-XXXXX",
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.blue.shade50,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0055A4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _validando ? null : _validarIngreso,
              child: _validando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("VALIDAR Y ENTRAR AL CHAT",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
