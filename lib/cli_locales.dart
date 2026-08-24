import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cli_menu_local.dart';
import 'red.dart';

class CliLocales extends StatefulWidget {
  final VoidCallback onIrARastreo;
  final VoidCallback onActualizar;
  const CliLocales({
    super.key,
    required this.onIrARastreo,
    required this.onActualizar,
  });

  @override
  State<CliLocales> createState() => _CliLocalesState();
}

class _CliLocalesState extends State<CliLocales> {
  String _textoBusqueda = "";
  List<dynamic> _comercios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarComercios();
  }

  // 🔥 NUEVA FUNCIÓN: Permite refrescar la lista a demanda
  Future<void> _cargarComercios() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final url = Uri.parse('$urlCentral/comercios_activos');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 5));
      if (respuesta.statusCode == 200) {
        if (mounted) {
          setState(() {
            _comercios = json.decode(utf8.decode(respuesta.bodyBytes));
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      debugPrint("🚨 Error cargando comercios: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado en vivo de los comercios abiertos
    final comerciosFiltrados = _comercios.where((c) {
      final n =
          (c['nombre'] ?? c['nombre_local'] ?? '').toString().toLowerCase();
      return n.contains(_textoBusqueda.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _textoBusqueda = val),
            decoration: InputDecoration(
              labelText: "¿Qué se te antoja hoy?",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  // 🔥 MAGIA: Deslizar hacia abajo refresca la base de datos y desaparece locales cerrados
                  onRefresh: _cargarComercios,
                  child: comerciosFiltrados.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 50),
                            Center(
                              child: Text(
                                "No hay locales abiertos en este momento.",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: comerciosFiltrados.length,
                          itemBuilder: (context, index) {
                            final comercio = comerciosFiltrados[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.storefront,
                                      color: Color(0xFF1E3A8A), size: 35),
                                ),
                                title: Text(
                                  comercio['nombre'] ??
                                      comercio['nombre_local'] ??
                                      'Local',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(comercio['direccion'] ??
                                    'Comercio General'),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF1E3A8A),
                                  size: 20,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CliMenuLocal(
                                        idComercio: comercio['id'].toString(),
                                        nombreComercio:
                                            comercio['nombre'] ?? 'Local',
                                      ),
                                    ),
                                  ).then((pagado) {
                                    if (pagado == true) {
                                      widget.onIrARastreo();
                                    } else {
                                      widget.onActualizar();
                                    }
                                  });
                                },
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
