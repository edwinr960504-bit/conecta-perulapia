import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';

class AdminDirectorio extends StatefulWidget {
  const AdminDirectorio({super.key});

  @override
  State<AdminDirectorio> createState() => _AdminDirectorioState();
}

class _AdminDirectorioState extends State<AdminDirectorio> {
  List<dynamic> _directorioCompleto = [];
  Map<String, dynamic> _metricas = {
    'clientes': 0,
    'repartidores': 0,
    'comercios': 0
  };
  bool _cargando = true;
  String _filtroRol = 'todos';
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _cargarDirectorio();
  }

  Future<void> _cargarDirectorio() async {
    setState(() => _cargando = true);
    try {
      final resMet =
          await http.get(Uri.parse('$urlCentral/api/admin/metricas_globales'));
      if (resMet.statusCode == 200) {
        _metricas = json.decode(utf8.decode(resMet.bodyBytes));
      }

      final resDir = await http
          .get(Uri.parse('$urlCentral/api/admin/directorio_completo'));
      if (resDir.statusCode == 200 && mounted) {
        setState(() {
          _directorioCompleto =
              json.decode(utf8.decode(resDir.bodyBytes))['directorio'];
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(
      int id, String tipo, String nuevoEstado, String rol) async {
    String ruta = tipo == 'comercio'
        ? '/api/admin/juez_comercio'
        : '/api/admin/juez_repartidor';
    await http.post(
      Uri.parse('$urlCentral$ruta'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_objetivo': id, 'nuevo_estado': nuevoEstado}),
    );
    _cargarDirectorio();
  }

  Future<void> _eliminarRegistro(int id, String tipo) async {
    String ruta = tipo == 'comercio'
        ? '/api/admin/eliminar_comercio'
        : '/api/admin/eliminar_usuario';
    await http.post(
      Uri.parse('$urlCentral$ruta'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_objetivo': id}),
    );
    _cargarDirectorio();
  }

  List<dynamic> get _directorioFiltrado {
    return _directorioCompleto.where((u) {
      final String rolUser = u['rol'].toString().toLowerCase();
      final String estadoUser = u['estado'].toString().toLowerCase();
      bool pasaRol = _filtroRol == 'todos' || rolUser == _filtroRol;
      bool pasaEstado = _filtroEstado == 'todos' || estadoUser == _filtroEstado;
      return pasaRol && pasaEstado;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Administración de Cuentas"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _cargarDirectorio)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniMetrica(
                          icono: Icons.person,
                          titulo: "Clientes",
                          valor: _metricas['clientes'].toString(),
                          color: Colors.blue,
                          seleccionado: _filtroRol == 'cliente',
                          onTap: () => setState(() => _filtroRol =
                              _filtroRol == 'cliente' ? 'todos' : 'cliente')),
                      _MiniMetrica(
                          icono: Icons.two_wheeler,
                          titulo: "Motos",
                          valor: _metricas['repartidores'].toString(),
                          color: Colors.orange,
                          seleccionado: _filtroRol == 'repartidor',
                          onTap: () => setState(() => _filtroRol =
                              _filtroRol == 'repartidor'
                                  ? 'todos'
                                  : 'repartidor')),
                      _MiniMetrica(
                          icono: Icons.storefront,
                          titulo: "Locales",
                          valor: _metricas['comercios'].toString(),
                          color: Colors.green,
                          seleccionado: _filtroRol == 'comercio',
                          onTap: () => setState(() => _filtroRol =
                              _filtroRol == 'comercio' ? 'todos' : 'comercio')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.grey.shade200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                          label: const Text("Todos"),
                          selected: _filtroEstado == 'todos',
                          onSelected: (_) =>
                              setState(() => _filtroEstado = 'todos')),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text("⏳ Pendientes"),
                          selected: _filtroEstado == 'pendiente',
                          onSelected: (_) =>
                              setState(() => _filtroEstado = 'pendiente'),
                          selectedColor: Colors.orange.shade300),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text("✅ Activos"),
                          selected: _filtroEstado == 'activo',
                          onSelected: (_) =>
                              setState(() => _filtroEstado = 'activo'),
                          selectedColor: Colors.green.shade300),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarDirectorio,
                    child: _directorioFiltrado.isEmpty
                        ? const Center(
                            child: Text("No hay registros con estos filtros."))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _directorioFiltrado.length,
                            itemBuilder: (ctx, i) {
                              final u = _directorioFiltrado[i];
                              final bool esPendiente =
                                  u['estado'].toString().toLowerCase() ==
                                      'pendiente';
                              final bool esActivo =
                                  u['estado'].toString().toLowerCase() ==
                                      'activo';

                              final String tel =
                                  u['telefono']?.toString() ?? '';
                              final String nombre =
                                  u['nombre']?.toString() ?? '';
                              final bool tieneTel = tel.isNotEmpty &&
                                  tel != 'Sin Tel' &&
                                  tel != 'Sin teléfono';
                              final bool tieneNombre =
                                  nombre.isNotEmpty && nombre != 'Sin Nombre';

                              return Card(
                                elevation: esPendiente ? 4 : 1,
                                shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                        color: esPendiente
                                            ? Colors.orange
                                            : Colors.transparent,
                                        width: esPendiente ? 2 : 0),
                                    borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title:
                                            Text("Expediente: ${u['nombre']}"),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor:
                                                      u['rol'] == 'comercio'
                                                          ? Colors.green
                                                          : (u['rol'] ==
                                                                  'repartidor'
                                                              ? Colors.orange
                                                              : Colors.blue),
                                                  child: Icon(
                                                      u['rol'] == 'comercio'
                                                          ? Icons.store
                                                          : (u['rol'] ==
                                                                  'repartidor'
                                                              ? Icons.motorcycle
                                                              : Icons.person),
                                                      size: 40,
                                                      color: Colors.white),
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              Text(
                                                  "🆔 ID en sistema: ${u['id']}"),
                                              Text(
                                                  "📌 Rol: ${u['rol'].toString().toUpperCase()}"),
                                              Text(
                                                  "⚡ Estado actual: ${u['estado'].toString().toUpperCase()}"),
                                              const Divider(height: 25),
                                              const Text(
                                                  "🔍 VALIDACIÓN DE REQUISITOS:",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 10),
                                              Row(children: [
                                                Icon(
                                                    tieneNombre
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    color: tieneNombre
                                                        ? Colors.green
                                                        : Colors.red,
                                                    size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(
                                                        "Nombre válido: ${u['nombre']}")),
                                              ]),
                                              const SizedBox(height: 8),
                                              Row(children: [
                                                Icon(
                                                    tieneTel
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    color: tieneTel
                                                        ? Colors.green
                                                        : Colors.red,
                                                    size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(
                                                        "Teléfono: ${tieneTel ? u['telefono'] : 'Falta registrar'}")),
                                              ]),
                                              const SizedBox(height: 8),
                                              if (!tieneNombre || !tieneTel)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 10),
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  color: Colors.red.shade50,
                                                  child: const Text(
                                                      "⚠️ Alerta: Faltan datos esenciales. Contáctalo antes de aprobar.",
                                                      style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12)),
                                                )
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("Cerrar")),
                                        ],
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: u['rol'] == 'comercio'
                                        ? Colors.green
                                        : (u['rol'] == 'repartidor'
                                            ? Colors.orange
                                            : Colors.blue),
                                    child: Icon(
                                        u['rol'] == 'comercio'
                                            ? Icons.store
                                            : (u['rol'] == 'repartidor'
                                                ? Icons.motorcycle
                                                : Icons.person),
                                        color: Colors.white),
                                  ),
                                  title: Text("${u['nombre']} (ID: ${u['id']})",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      "Rol: ${u['rol'].toString().toUpperCase()}\nEstado: ${esPendiente ? '⏳ PENDIENTE' : u['estado'].toString().toUpperCase()}"),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (accion) {
                                      if (accion == 'aprobar') {
                                        _cambiarEstado(u['id'], u['tipo'],
                                            'activo', u['rol']);
                                      }
                                      if (accion == 'suspender') {
                                        _cambiarEstado(u['id'], u['tipo'],
                                            'suspendido', u['rol']);
                                      }
                                      if (accion == 'activar') {
                                        _cambiarEstado(u['id'], u['tipo'],
                                            'activo', u['rol']);
                                      }
                                      if (accion == 'eliminar') {
                                        _eliminarRegistro(u['id'], u['tipo']);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      if (esPendiente)
                                        const PopupMenuItem(
                                            value: 'aprobar',
                                            child: Row(children: [
                                              Icon(Icons.check_circle,
                                                  color: Colors.green),
                                              SizedBox(width: 8),
                                              Text("Aprobar")
                                            ])),
                                      if (esActivo)
                                        const PopupMenuItem(
                                            value: 'suspender',
                                            child: Row(children: [
                                              Icon(Icons.pause_circle,
                                                  color: Colors.orange),
                                              SizedBox(width: 8),
                                              Text("Suspender")
                                            ])),
                                      if (!esPendiente && !esActivo)
                                        const PopupMenuItem(
                                            value: 'activar',
                                            child: Row(children: [
                                              Icon(Icons.play_circle,
                                                  color: Colors.green),
                                              SizedBox(width: 8),
                                              Text("Reactivar")
                                            ])),
                                      const PopupMenuItem(
                                          value: 'eliminar',
                                          child: Row(children: [
                                            Icon(Icons.delete,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Eliminar raíz")
                                          ])),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MiniMetrica extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _MiniMetrica(
      {required this.icono,
      required this.titulo,
      required this.valor,
      required this.color,
      required this.seleccionado,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color:
              seleccionado ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
              color: seleccionado ? color : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            Text(valor,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(titulo,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
