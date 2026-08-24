import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';

class AdminPublicidad extends StatefulWidget {
  const AdminPublicidad({super.key});

  @override
  State<AdminPublicidad> createState() => _AdminPublicidadState();
}

class _AdminPublicidadState extends State<AdminPublicidad> {
  final TextEditingController _mensajeAnuncioCtrl = TextEditingController();
  final TextEditingController _imagenAnuncioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _mensajeAnuncioCtrl.dispose();
    _imagenAnuncioCtrl.dispose();
    super.dispose();
  }

  Future<void> _publicarAnuncioGlobal() async {
    if (_mensajeAnuncioCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Escribe un mensaje para el anuncio"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final url = Uri.parse('$urlCentral/api/admin/publicar_anuncio');
      final cuerpo = json.encode({
        'mensaje': _mensajeAnuncioCtrl.text.trim(),
        'imagen_url': _imagenAnuncioCtrl.text.trim().isEmpty
            ? ""
            : _imagenAnuncioCtrl.text.trim()
      });

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: cuerpo,
      );

      if (!mounted) return;
      setState(() => _enviando = false);

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡Anuncio publicado con éxito en la red!"),
              backgroundColor: Colors.green),
        );
        _mensajeAnuncioCtrl.clear();
        _imagenAnuncioCtrl.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Error del servidor: ${res.statusCode} - ${res.body}"),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Fallo de conexión: $e"),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Centro de Publicidad Global"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              "Manda un aviso o banner que aparecerá en toda la plataforma al instante.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _mensajeAnuncioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Mensaje del Anuncio / Alerta",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _imagenAnuncioCtrl,
              decoration: const InputDecoration(
                labelText: "URL de la Imagen o Banner (Opcional)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _enviando ? "ENVIANDO A LA RED..." : "LANZAR ANUNCIO A LA RED",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: _enviando ? null : _publicarAnuncioGlobal,
            ),
          ],
        ),
      ),
    );
  }
}
