import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';
import 'chat_soporte.dart';

class AdminSoporte extends StatefulWidget {
  const AdminSoporte({super.key});

  @override
  State<AdminSoporte> createState() => _AdminSoporteState();
}

class _AdminSoporteState extends State<AdminSoporte> {
  List<dynamic> _tickets = [];
  bool _cargando = true;
  String _errorMsg = "";

  String _filtroEstado = "todos"; // 'todos', 'abierto', 'resuelto'
  String _filtroRol = "todos"; // 'todos', 'cliente', 'repartidor', 'local'
  String _filtroTipoIncidencia = "todos"; // 'todos', 'pedido', 'personal'

  @override
  void initState() {
    super.initState();
    _cargarTickets();
  }

  Future<void> _cargarTickets() async {
    if (mounted) {
      setState(() {
        _cargando = true;
        _errorMsg = "";
      });
    }
    try {
      final res =
          await http.get(Uri.parse('$urlCentral/api/admin/tickets_soporte'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data is List) {
          setState(() {
            _tickets = data;
            _cargando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = "Error de conexión: $e";
          _cargando = false;
        });
      }
    }
  }

  Future<void> _resolverTicket(int idTicket, BuildContext dialogContext) async {
    try {
      final res = await http
          .post(Uri.parse('$urlCentral/api/admin/resolver_ticket/$idTicket'));
      if (res.statusCode == 200 && mounted) {
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }
        _cargarTickets();
      }
    } catch (e) {
      debugPrint("Error al resolver: $e");
    }
  }

  // Identifica si es personal (id negativo) y a qué rol pertenece el usuario
  bool _esPersonal(Map<dynamic, dynamic> t) {
    final int idPedido = int.tryParse(t['id_pedido']?.toString() ?? '0') ?? 0;
    final String canal = t['canal']?.toString().toLowerCase() ?? '';
    return idPedido < 0 || canal.contains('personal');
  }

  String _obtenerTipoRol(Map<dynamic, dynamic> t) {
    final String tipo = t['tipo_usuario']?.toString().toLowerCase() ?? '';
    final String comercio = t['nombre_comercio']?.toString() ?? '';
    final String motorista = t['nombre_repartidor']?.toString() ?? '';

    if (tipo.contains('comercio') ||
        tipo.contains('local') ||
        tipo.contains('vendedor') ||
        (comercio.isNotEmpty &&
            comercio != 'Sin Comercio' &&
            comercio != 'Desconocido' &&
            t['remitente_es_comercio'] == true)) {
      return 'local';
    }
    if (tipo.contains('repartidor') ||
        tipo.contains('motorista') ||
        (motorista.isNotEmpty &&
            motorista != 'Sin Motorista' &&
            motorista != 'Desconocido' &&
            t['remitente_es_repartidor'] == true)) {
      return 'repartidor';
    }
    return 'cliente';
  }

  @override
  Widget build(BuildContext context) {
    // Contadores para las tarjetas superiores (basados estrictamente en el rol del emisor)
    final int totalClientes =
        _tickets.where((t) => _obtenerTipoRol(t) == 'cliente').length;
    final int totalRepartidores =
        _tickets.where((t) => _obtenerTipoRol(t) == 'repartidor').length;
    final int totalLocales =
        _tickets.where((t) => _obtenerTipoRol(t) == 'local').length;

    // Filtrado avanzado combinado (Rol + Estado + Tipo de Incidencia: Pedido o Personal)
    final ticketsFiltrados = _tickets.where((t) {
      final estado = t['estado']?.toString() ?? 'abierto';

      // 1. Filtro por Estado
      bool pasaEstado = true;
      if (_filtroEstado == 'abierto') pasaEstado = (estado == 'abierto');
      if (_filtroEstado == 'resuelto') pasaEstado = (estado == 'resuelto');

      // 2. Filtro por Rol Superior (Clientes, Repartidores, Locales)
      bool pasaRol = true;
      if (_filtroRol != 'todos') {
        pasaRol = (_obtenerTipoRol(t) == _filtroRol);
      }

      // 3. Filtro por Tipo de Incidencia (Pedidos vs. Personal)
      bool pasaTipo = true;
      final bool personal = _esPersonal(t);
      if (_filtroTipoIncidencia == 'pedido') pasaTipo = !personal;
      if (_filtroTipoIncidencia == 'personal') pasaTipo = personal;

      return pasaEstado && pasaRol && pasaTipo;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("Central de Soporte",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarTickets,
            tooltip: "Actualizar lista",
          )
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(_errorMsg,
                        style: const TextStyle(color: Colors.red, fontSize: 15),
                        textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    // CONTADORES SUPERIORES POR ROL
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 10),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ContadorHeader(
                            titulo: "Clientes",
                            cantidad: totalClientes,
                            color: Colors.blue.shade700,
                            icono: Icons.person_rounded,
                            activo: _filtroRol == 'cliente',
                            onTap: () => setState(() => _filtroRol =
                                _filtroRol == 'cliente' ? 'todos' : 'cliente'),
                          ),
                          _ContadorHeader(
                            titulo: "Repartidores",
                            cantidad: totalRepartidores,
                            color: Colors.orange.shade800,
                            icono: Icons.two_wheeler_rounded,
                            activo: _filtroRol == 'repartidor',
                            onTap: () => setState(() => _filtroRol =
                                _filtroRol == 'repartidor'
                                    ? 'todos'
                                    : 'repartidor'),
                          ),
                          _ContadorHeader(
                            titulo: "Locales",
                            cantidad: totalLocales,
                            color: Colors.green.shade700,
                            icono: Icons.storefront_rounded,
                            activo: _filtroRol == 'local',
                            onTap: () => setState(() => _filtroRol =
                                _filtroRol == 'local' ? 'todos' : 'local'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // SUB-FILTROS DE TIPO DE INCIDENCIA (Todo, Por Pedido, Personal)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.white,
                      child: Row(
                        children: [
                          const Text("Tipo:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12)),
                          const SizedBox(width: 10),
                          _ChipFiltroTipo(
                              label: "Todos",
                              seleccionado: _filtroTipoIncidencia == 'todos',
                              onTap: () => setState(
                                  () => _filtroTipoIncidencia = 'todos')),
                          const SizedBox(width: 6),
                          _ChipFiltroTipo(
                              label: "📦 Pedidos",
                              seleccionado: _filtroTipoIncidencia == 'pedido',
                              onTap: () => setState(
                                  () => _filtroTipoIncidencia = 'pedido')),
                          const SizedBox(width: 6),
                          _ChipFiltroTipo(
                              label: "👤 Personal",
                              seleccionado: _filtroTipoIncidencia == 'personal',
                              onTap: () => setState(
                                  () => _filtroTipoIncidencia = 'personal')),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // BOTONES DE FILTRO INFERIOR DE ESTADO (Todos, Pendientes, Solucionados)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: const Color(0xFFF4F6F9),
                      child: Row(
                        children: [
                          _BotonFiltro(
                            texto: "Todos",
                            icono: Icons.done_all,
                            activo: _filtroEstado == 'todos',
                            onTap: () =>
                                setState(() => _filtroEstado = 'todos'),
                          ),
                          const SizedBox(width: 8),
                          _BotonFiltro(
                            texto: "Pendientes",
                            icono: Icons.hourglass_top_rounded,
                            activo: _filtroEstado == 'abierto',
                            onTap: () =>
                                setState(() => _filtroEstado = 'abierto'),
                          ),
                          const SizedBox(width: 8),
                          _BotonFiltro(
                            texto: "Solucionados",
                            icono: Icons.check_box_rounded,
                            activo: _filtroEstado == 'resuelto',
                            onTap: () =>
                                setState(() => _filtroEstado = 'resuelto'),
                          ),
                        ],
                      ),
                    ),

                    // LISTA DE TICKETS
                    Expanded(
                      child: ticketsFiltrados.isEmpty
                          ? const Center(
                              child: Text(
                                  "No hay casos con los filtros seleccionados.",
                                  style: TextStyle(
                                      color: Colors.blueGrey, fontSize: 15)))
                          : RefreshIndicator(
                              color: const Color(0xFF1E3A8A),
                              onRefresh: _cargarTickets,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                itemCount: ticketsFiltrados.length,
                                itemBuilder: (context, index) {
                                  final t = ticketsFiltrados[index] ?? {};
                                  final String estado =
                                      t['estado']?.toString() ?? 'abierto';
                                  final String codigo =
                                      t['codigo_rastreo']?.toString() ??
                                          'CP-0000';
                                  final String mensaje =
                                      t['queja']?.toString() ?? 'Sin mensaje';
                                  final String fecha =
                                      t['fecha']?.toString() ?? '';
                                  final String fotoPerfil =
                                      t['foto_perfil']?.toString() ?? '';
                                  final int idPedido = int.tryParse(
                                          t['id_pedido']?.toString() ?? '0') ??
                                      0;
                                  final bool esAbierto = estado == 'abierto';
                                  final bool personal = _esPersonal(t);

                                  final String rol = _obtenerTipoRol(t);
                                  String etiquetaRol = "Cliente";
                                  String nombrePersona =
                                      t['nombre_cliente']?.toString() ??
                                          'Usuario';
                                  IconData iconoRol = Icons.person;

                                  if (rol == 'local') {
                                    etiquetaRol = "Local";
                                    nombrePersona =
                                        t['nombre_comercio']?.toString() ??
                                            'Comercio';
                                    iconoRol = Icons.storefront;
                                  } else if (rol == 'repartidor') {
                                    etiquetaRol = "Repartidor";
                                    nombrePersona =
                                        t['nombre_repartidor']?.toString() ??
                                            'Motorista';
                                    iconoRol = Icons.two_wheeler;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: esAbierto
                                            ? Colors.orange
                                                .withValues(alpha: 0.4)
                                            : Colors.green
                                                .withValues(alpha: 0.4),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatSoporte(
                                                idPedido: idPedido,
                                                remitente: "Admin Central",
                                                canal: personal
                                                    ? "admin_comercio_personal"
                                                    : "admin_cliente",
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: personal
                                                      ? Colors.purple.shade50
                                                      : Colors.grey.shade100,
                                                  child: fotoPerfil.isNotEmpty
                                                      ? Image.network(
                                                          "$urlCentral$fotoPerfil",
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  Icon(
                                                            iconoRol,
                                                            color: personal
                                                                ? Colors.purple
                                                                    .shade700
                                                                : const Color(
                                                                    0xFF1E3A8A),
                                                            size: 28,
                                                          ),
                                                        )
                                                      : Icon(
                                                          iconoRol,
                                                          color: personal
                                                              ? Colors.purple
                                                                  .shade700
                                                              : const Color(
                                                                  0xFF1E3A8A),
                                                          size: 28,
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            "$etiquetaRol: $nombrePersona",
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                              color: Color(
                                                                  0xFF1E3A8A),
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          fecha,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: personal
                                                                ? Colors.purple
                                                                    .shade100
                                                                : Colors.blue
                                                                    .shade100,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          child: Text(
                                                            personal
                                                                ? "👤 PERSONAL"
                                                                : "📦 PEDIDO ($codigo)",
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: personal
                                                                  ? Colors
                                                                      .purple
                                                                      .shade900
                                                                  : Colors.blue
                                                                      .shade900,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          esAbierto
                                                              ? "PENDIENTE"
                                                              : "SOLICIONADO",
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: esAbierto
                                                                ? Colors.orange
                                                                    .shade800
                                                                : Colors.green
                                                                    .shade800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      mensaje,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: Colors.black54,
                                                          fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                    Icons.more_vert_rounded,
                                                    color: Colors.grey),
                                                onSelected: (value) {
                                                  if (value == 'expediente') {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            DetalleTicketScreen(
                                                          ticket: t,
                                                          onResolver: (id) =>
                                                              _resolverTicket(
                                                                  id, context),
                                                        ),
                                                      ),
                                                    ).then((_) =>
                                                        _cargarTickets());
                                                  }
                                                },
                                                itemBuilder:
                                                    (BuildContext context) => [
                                                  const PopupMenuItem<String>(
                                                    value: 'expediente',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .folder_open_rounded,
                                                            size: 18,
                                                            color: Color(
                                                                0xFF1E3A8A)),
                                                        SizedBox(width: 10),
                                                        Text("Ver Expediente",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
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

// Widget pequeño para los chips de selección "Pedido" vs "Personal"
class _ChipFiltroTipo extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipFiltroTipo(
      {required this.label, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: seleccionado
                  ? const Color(0xFF1E3A8A)
                  : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color:
                seleccionado ? const Color(0xFF1E3A8A) : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _ContadorHeader extends StatelessWidget {
  final String titulo;
  final int cantidad;
  final Color color;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _ContadorHeader({
    required this.titulo,
    required this.cantidad,
    required this.color,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: activo ? color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 2),
            Text("$cantidad",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(titulo,
                style: TextStyle(
                    fontSize: 11,
                    color: activo ? color : Colors.grey,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BotonFiltro extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _BotonFiltro(
      {required this.texto,
      required this.icono,
      required this.activo,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? const Color(0xFF1E3A8A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: activo ? const Color(0xFF1E3A8A) : Colors.grey.shade300),
            boxShadow: [
              if (activo)
                BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono,
                  size: 16,
                  color: activo ? Colors.white : Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: activo ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetalleTicketScreen extends StatelessWidget {
  final Map<dynamic, dynamic> ticket;
  final Function(int) onResolver;

  const DetalleTicketScreen({
    super.key,
    required this.ticket,
    required this.onResolver,
  });

  @override
  Widget build(BuildContext context) {
    final String estado = ticket['estado']?.toString() ?? 'abierto';
    final String codigo = ticket['codigo_rastreo']?.toString() ?? 'CP-0000';
    final String cliente =
        ticket['nombre_cliente']?.toString() ?? 'Desconocido';
    final String comercio =
        ticket['nombre_comercio']?.toString() ?? 'Desconocido';
    final String motorista =
        ticket['nombre_repartidor']?.toString() ?? 'Desconocido';
    final String mensaje = ticket['queja']?.toString() ?? 'Sin mensaje';
    final String fecha = ticket['fecha']?.toString() ?? 'Fecha no disponible';
    final int idTicket =
        int.tryParse(ticket['id_ticket']?.toString() ?? '0') ?? 0;
    final int idPedido =
        int.tryParse(ticket['id_pedido']?.toString() ?? '0') ?? 0;

    final bool esAbierto = estado == 'abierto';
    final bool personal = idPedido < 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
            personal ? "Expediente: Soporte Personal" : "Expediente: $codigo",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Reporte del: $fecha",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: esAbierto
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          esAbierto ? "PENDIENTE" : "SOLICIONADO",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: esAbierto
                                  ? Colors.orange.shade900
                                  : Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text("Detalle de la Consulta / Mensaje:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: Text(mensaje,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!personal)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Involucrados del Pedido",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E3A8A))),
                    const Divider(height: 20),
                    Text("Cliente: $cliente",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text("Comercio: $comercio",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text("Repartidor: $motorista",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (esAbierto) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text("Marcar como Solucionado",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: () =>
                    onResolver(idTicket), // <--- Llamado directo sin "widget."
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: const Text("Ir al Chat de la Consulta",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatSoporte(
                      idPedido: idPedido,
                      remitente: "Admin Central",
                      canal: personal
                          ? "admin_comercio_personal"
                          : "admin_cliente",
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
