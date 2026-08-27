import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'vista_login.dart';
import 'carrito_service.dart';
import 'red.dart';

import 'comer_cocina.dart';
import 'comer_menu.dart';
import 'comer_billetera.dart';
import 'comer_soporte.dart';
import 'comer_ajustes.dart';

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
  String? _urlLogoComercio;

  @override
  void initState() {
    super.initState();
    _sincronizarEstadoReal();
    _cargarLogoComercio();
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

  Future<void> _cargarLogoComercio() async {
    try {
      final url =
          Uri.parse('$urlCentral/api/comercio/perfil/${widget.idComercio}');
      // Sin límite estricto de timeout para evitar errores de red prematuros
      final res = await http.get(url);
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data['status'] == 'ok' &&
            data['logo'] != null &&
            data['logo'].toString().isNotEmpty &&
            data['logo'] != 'Sin logo') {
          final String logoPath = data['logo'];
          setState(() {
            _urlLogoComercio =
                logoPath.startsWith('http') ? logoPath : '$urlCentral$logoPath';
          });
          debugPrint(
              "✅ Logo cargado con éxito en la portada: $_urlLogoComercio");
        } else {
          debugPrint(
              "⚠️ El servidor respondió pero el logo viene vacío o como 'Sin logo'");
        }
      } else {
        debugPrint("❌ Error del servidor al buscar perfil: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("🚨 Excepción al cargar el logo del comercio: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // 🔥 DISEÑO DE PORTADA CON LA FOTO DE FONDO DEL NEGOCIO
            DrawerHeader(
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                image: _urlLogoComercio != null
                    ? DecorationImage(
                        image: NetworkImage(_urlLogoComercio!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.45),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.nombreComercio,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4.0,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID Sistema: COM-${widget.idComercio}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2.0,
                          color: Colors.black,
                        ),
                      ],
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
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VistaAjustesLocal(
                      idComercio: widget.idComercio,
                      nombreActual: widget.nombreComercio,
                    ),
                  ),
                );
                // Al volver de ajustes, refrescamos la portada de inmediato
                _cargarLogoComercio();
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
