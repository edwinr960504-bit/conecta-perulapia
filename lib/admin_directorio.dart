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
      if (resMet.statusCode == 200 && mounted) {
        setState(() {
          _metricas = json.decode(utf8.decode(resMet.bodyBytes));
        });
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
                                    _mostrarExpedienteCompleto(u);
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
                                  trailing: const Icon(Icons.remove_red_eye,
                                      color: Color(0xFF1E3A8A)),
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

  void _mostrarExpedienteCompleto(Map<dynamic, dynamic> u) {
    bool cargandoSwitch = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setStateDialog) {
            final bool esActivo =
                u['estado'].toString().toLowerCase() == 'activo';
            final bool esPendiente =
                u['estado'].toString().toLowerCase() == 'pendiente';

            final String fotoPath = u['foto'] ?? '';
            final bool tieneFoto = fotoPath.isNotEmpty &&
                fotoPath != 'Sin foto' &&
                fotoPath != 'Sin logo';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Text("Expediente: ${u['nombre']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(15),
                          image: tieneFoto
                              ? DecorationImage(
                                  image: NetworkImage("$urlCentral$fotoPath"),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(color: Colors.blueGrey, width: 2),
                        ),
                        child: !tieneFoto
                            ? Icon(
                                u['rol'] == 'comercio'
                                    ? Icons.store
                                    : (u['rol'] == 'repartidor'
                                        ? Icons.motorcycle
                                        : Icons.person),
                                size: 60,
                                color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      color:
                          esActivo ? Colors.green.shade50 : Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: esActivo ? Colors.green : Colors.red,
                              width: 2)),
                      child: SwitchListTile(
                        title: Text(
                            esActivo ? "CUENTA ACTIVA" : "CUENTA SUSPENDIDA",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esActivo
                                    ? Colors.green.shade900
                                    : Colors.red.shade900)),
                        subtitle: Text(esActivo
                            ? "Visible y operando en la app"
                            : "Castigado/Oculto del sistema"),
                        value: esActivo,
                        activeThumbColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: cargandoSwitch
                            ? null
                            : (bool activar) async {
                                setStateDialog(() => cargandoSwitch = true);
                                String nuevoEstatus =
                                    activar ? 'activo' : 'suspendido';
                                await _cambiarEstado(
                                    u['id'], u['tipo'], nuevoEstatus, u['rol']);
                                setStateDialog(() {
                                  u['estado'] = nuevoEstatus;
                                  cargandoSwitch = false;
                                });
                                setState(() {});
                              },
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text("DATOS DE CONTACTO",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A))),
                    const Divider(),
                    _FilaDato(
                        icono: Icons.phone,
                        titulo: "Teléfono",
                        valor: u['telefono']),
                    _FilaDato(
                        icono: Icons.email,
                        titulo: "Correo",
                        valor: u['correo']),
                    _FilaDato(
                        icono: Icons.location_on,
                        titulo: "Dirección",
                        valor: u['direccion']),
                    if (u['rol'] == 'repartidor') ...[
                      const SizedBox(height: 15),
                      const Text("DATOS LEGALES Y VEHÍCULO",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A))),
                      const Divider(),
                      _FilaDato(
                          icono: Icons.badge, titulo: "DUI", valor: u['dui']),
                      _FilaDato(
                          icono: Icons.two_wheeler,
                          titulo: "Vehículo",
                          valor: u['vehiculo']),
                      _FilaDato(
                          icono: Icons.credit_card,
                          titulo: "Placa/Tarjeta",
                          valor: u['placa']),
                      _FilaDato(
                          icono: Icons.assignment_ind,
                          titulo: "Licencia",
                          valor: u['licencia']),
                    ],
                    if (u['rol'] == 'comercio') ...[
                      const SizedBox(height: 15),
                      const Text("DATOS DEL NEGOCIO",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A))),
                      const Divider(),
                      _FilaDato(
                          icono: Icons.star,
                          titulo: "Tipo de Plan",
                          valor: u['plan'] ?? 'comision'),
                    ],
                  ],
                ),
              ),
              actions: [
                if (esPendiente)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_circle),
                    label: const Text("APROBAR AHORA"),
                    onPressed: () async {
                      await _cambiarEstado(
                          u['id'], u['tipo'], 'activo', u['rol']);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Eliminar Raíz"),
                  onPressed: () async {
                    await _eliminarRegistro(u['id'], u['tipo']);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ],
            );
          });
        });
  }
}

class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final dynamic valor;

  const _FilaDato(
      {required this.icono, required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                      text: "$titulo: ",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: "${valor ?? 'No registrado'}"),
                ],
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
