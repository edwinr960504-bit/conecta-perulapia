import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'vista_login.dart';
import 'carrito_service.dart';
import 'red.dart';

// === AQUÍ IMPORTAMOS TODOS TUS ARCHIVOS SEPARADOS ===
import 'comer_cocina.dart';
import 'comer_menu.dart';
import 'comer_billetera.dart'; // Este ya lo tenías creado
import 'comer_soporte.dart';
import 'comer_ajustes.dart';

// ========================================================
// PANTALLA PRINCIPAL DEL COMERCIANTE (CONTENEDOR)
// ========================================================
class VistaComerciante extends StatefulWidget {
  final String nombreComercio;
  final String idComercio;

  const VistaComerciante({
    super.key,
    required this.nombreComercio,
    required this.idComercio,
  });

  @override
  State<VistaComerciante> createState() => _VistaComercianteState();
}

class _VistaComercianteState extends State<VistaComerciante> {
  int _indiceActual = 0;
  bool _localAbierto = false;

  @override
  void initState() {
    super.initState();
    _sincronizarEstadoReal();
  }

  Future<void> _sincronizarEstadoReal() async {
    try {
      final url = Uri.parse('$urlCentral/comercios_activos');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        final List comerciosAbiertos = json.decode(utf8.decode(res.bodyBytes));
        final bool realmenteAbierto = comerciosAbiertos
            .any((c) => c['id'].toString() == widget.idComercio);
        setState(() {
          _localAbierto = realmenteAbierto;
        });
      }
    } catch (e) {
      debugPrint("Error sincronizando estado del local: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // LLAMAMOS A TUS CLASES INDEPENDIENTES
    final List<Widget> paginas = [
      VistaCocina(
        idComercio: widget.idComercio,
        localAbierto: _localAbierto,
        onLocalAbiertoChanged: (v) => setState(() => _localAbierto = v),
      ),
      VistaMenu(idComercio: widget.idComercio),
      ComerBilletera(
        idComercio: int.parse(widget.idComercio.toString()),
      ),
      SoporteComercioPantalla(
        idComercio: widget.idComercio,
        nombreComercio: widget.nombreComercio,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Panel: ${widget.nombreComercio}"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(Icons.storefront,
                        size: 35, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.nombreComercio,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ID Sistema: COM-${widget.idComercio}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFF1E3A8A)),
              title: const Text(
                'Ajustes del Local',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Fotos, Nombre, Horarios...'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VistaAjustesLocal(
                      // Viene de comer_ajustes.dart
                      idComercio: widget.idComercio,
                      nombreActual: widget.nombreComercio,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                CarritoService.limpiar();
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginPantalla(),
                  ),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: paginas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) => setState(() => _indiceActual = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Cocina',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Menú'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Billetera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Soporte',
          ),
        ],
      ),
    );
  }
}
