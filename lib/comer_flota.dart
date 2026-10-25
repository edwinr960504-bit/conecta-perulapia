import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_http.dart' as http;
import 'red.dart';

class RepartidorPropio {
  final int id;
  final String nombre;
  final String telefono;
  final bool ocupado;

  RepartidorPropio(this.id, this.nombre, this.telefono, this.ocupado);
}

class FlotaService {
  static Future<List<RepartidorPropio>> listar(int idComercio) async {
    try {
      final res = await http.get(
        Uri.parse('$urlCentral/api/comercio/repartidores_propios/$idComercio'),
      );
      if (res.statusCode != 200) return [];
      final datos = json.decode(utf8.decode(res.bodyBytes));
      return (datos['repartidores'] as List)
          .map((r) => RepartidorPropio(
                r['id_repartidor'],
                r['nombre'] ?? '',
                r['telefono'] ?? '',
                r['ocupado'] == true,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> _post(
      String ruta, Map<String, dynamic> cuerpo) async {
    try {
      final res = await http.post(
        Uri.parse('$urlCentral$ruta'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cuerpo),
      );
      final datos = json.decode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && datos is Map<String, dynamic>) return datos;
      if (res.statusCode == 401) {
        return {
          'status': 'error',
          'mensaje': 'Tu sesión venció. Cierra sesión y entra de nuevo.'
        };
      }
      if (datos is Map && datos['detail'] is String) {
        return {'status': 'error', 'mensaje': datos['detail']};
      }
      return {'status': 'error', 'mensaje': 'No se pudo completar la acción.'};
    } catch (_) {
      return {'status': 'error', 'mensaje': 'Error de conexión.'};
    }
  }

  static Future<Map<String, dynamic>> crear(
          int idComercio, String nombre, String telefono, String correo) =>
      _post('/api/comercio/repartidores_propios', {
        'id_comercio': idComercio,
        'nombre': nombre,
        'telefono': telefono,
        'correo': correo,
      });

  static Future<Map<String, dynamic>> quitar(
          int idComercio, int idRepartidor) =>
      _post('/api/comercio/repartidores_propios/quitar',
          {'id_comercio': idComercio, 'id_repartidor': idRepartidor});

  static Future<Map<String, dynamic>> asignar(
          int idPedido, int idRepartidor) =>
      _post('/api/comercio/asignar_repartidor',
          {'id_pedido': idPedido, 'id_repartidor': idRepartidor});

  static Future<Map<String, dynamic>> lanzarRadar(int idPedido) =>
      _post('/api/comercio/lanzar_radar', {'id_pedido': idPedido});
}

class ComerFlota extends StatefulWidget {
  final int idComercio;
  const ComerFlota({super.key, required this.idComercio});

  @override
  State<ComerFlota> createState() => _ComerFlotaState();
}

class _ComerFlotaState extends State<ComerFlota> {
  List<RepartidorPropio> _repartidores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await FlotaService.listar(widget.idComercio);
    if (!mounted) return;
    setState(() {
      _repartidores = lista;
      _cargando = false;
    });
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _agregar() async {
    final nombre = TextEditingController();
    final telefono = TextEditingController();
    final correo = TextEditingController();
    final enviar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo repartidor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              TextField(
                controller: telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono (será su usuario)'),
              ),
              TextField(
                controller: correo,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'Correo (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar')),
        ],
      ),
    );
    if (enviar != true) return;

    final res = await FlotaService.crear(widget.idComercio, nombre.text.trim(),
        telefono.text.trim(), correo.text.trim());
    if (!mounted) return;
    if (res['status'] != 'ok') {
      _avisar(res['mensaje'] ?? 'No se pudo registrar.', error: true);
      return;
    }
    await _cargar();
    if (!mounted) return;
    await _mostrarCredenciales(res['usuario'], res['contrasena']);
  }

  Future<void> _mostrarCredenciales(String usuario, String contrasena) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Credenciales del repartidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Entrégaselas ahora. No se volverán a mostrar; usará la app de repartidor con ellas.'),
            const SizedBox(height: 12),
            SelectableText('Usuario: $usuario',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            SelectableText('Contraseña: $contrasena',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(
                ClipboardData(text: 'Usuario: $usuario\nContraseña: $contrasena')),
            child: const Text('Copiar'),
          ),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
        ],
      ),
    );
  }

  Future<void> _quitar(RepartidorPropio r) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar repartidor'),
        content: Text('¿Quitar a ${r.nombre}? Ya no podrá iniciar sesión.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;
    final res = await FlotaService.quitar(widget.idComercio, r.id);
    if (!mounted) return;
    _avisar(res['mensaje'] ?? '', error: res['status'] != 'ok');
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Repartidores'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _repartidores.isEmpty
                  ? ListView(children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aún no tienes repartidores propios.\n\nRegistra a los tuyos y, al preparar un pedido, podrás asignárselo directo o lanzarlo al radar de la app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: _repartidores.length,
                      itemBuilder: (context, i) {
                        final r = _repartidores[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                r.ocupado ? Colors.orange : Colors.green,
                            child: const Icon(Icons.two_wheeler,
                                color: Colors.white),
                          ),
                          title: Text(r.nombre),
                          subtitle: Text(
                              '${r.telefono} · ${r.ocupado ? 'En viaje' : 'Libre'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _quitar(r),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
