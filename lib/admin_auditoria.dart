import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';
import 'chat_soporte.dart';

class AdminAuditoria extends StatelessWidget {
  const AdminAuditoria({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Auditoría de Red",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Panel de Auditoría y Caja Negra del Sistema.\nRegistros de seguridad al corriente.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class AdminSoporte extends StatefulWidget {
  const AdminSoporte({super.key});

  @override
  State<AdminSoporte> createState() => _AdminSoporteState();
}

class _AdminSoporteState extends State<AdminSoporte> {
  List<dynamic> _tickets = [];
  bool _cargando = true;
  String _errorMsg = "";

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

  Future<void> _resolverTicket(int idTicket) async {
    try {
      final res = await http
          .post(Uri.parse('$urlCentral/api/admin/resolver_ticket/$idTicket'));
      if (res.statusCode == 200 && mounted) _cargarTickets();
    } catch (e) {
      debugPrint("Error al resolver: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Central de Soporte",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarTickets)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Text(_errorMsg,
                      style: const TextStyle(color: Colors.red)))
              : _tickets.isEmpty
                  ? const Center(
                      child: Text("No hay casos activos.",
                          style: TextStyle(color: Colors.grey, fontSize: 18)))
                  : RefreshIndicator(
                      onRefresh: _cargarTickets,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tickets.length,
                        itemBuilder: (context, index) {
                          final t = _tickets[index] ?? {};
                          return TarjetaTicketCompacta(
                            ticket: t,
                            onResolver: () {
                              final int idTicket = int.tryParse(
                                      t['id_ticket']?.toString() ?? '0') ??
                                  0;
                              _resolverTicket(idTicket);
                            },
                            onRecargar: _cargarTickets,
                          );
                        },
                      ),
                    ),
    );
  }
}

class TarjetaTicketCompacta extends StatefulWidget {
  final Map<dynamic, dynamic> ticket;
  final VoidCallback onResolver;
  final VoidCallback onRecargar;

  const TarjetaTicketCompacta(
      {super.key,
      required this.ticket,
      required this.onResolver,
      required this.onRecargar});

  @override
  State<TarjetaTicketCompacta> createState() => _TarjetaTicketCompactaState();
}

class _TarjetaTicketCompactaState extends State<TarjetaTicketCompacta> {
  bool _chatCliente = true;
  bool _chatVendedor = false;
  bool _chatRepartidor = false;
  bool _chatGrupal = false;

  void _gestionarGrupal(bool valor) {
    setState(() {
      _chatGrupal = valor;
      if (valor) {
        _chatCliente = true;
        _chatVendedor = true;
        _chatRepartidor = true;
      }
    });
  }

  void _verificarGrupal() {
    setState(() {
      _chatGrupal = (_chatCliente && _chatVendedor && _chatRepartidor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final String estado = t['estado']?.toString() ?? 'abierto';
    final String codigo = t['codigo_rastreo']?.toString() ?? 'CP-0000';
    final String cliente = t['nombre_cliente']?.toString() ?? 'Desconocido';
    final String comercio = t['nombre_comercio']?.toString() ?? 'Desconocido';
    final String motorista =
        t['nombre_repartidor']?.toString() ?? 'Desconocido';
    final String mensaje = t['queja']?.toString() ?? 'Sin mensaje';
    final int idPedido = int.tryParse(t['id_pedido']?.toString() ?? '0') ?? 0;

    final bool esAbierto = estado == 'abierto';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          side: BorderSide(
              color: esAbierto ? Colors.orange : Colors.green, width: 2),
          borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        title: Text(
          "Rastreo: $codigo",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  esAbierto ? Colors.orange.shade900 : Colors.green.shade900),
        ),
        subtitle: Text(
          "Mensaje: $mensaje",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Icon(
          esAbierto ? Icons.warning_amber_rounded : Icons.check_circle,
          color: esAbierto ? Colors.orange : Colors.green,
        ),
        children: [
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("👤 Cliente: $cliente",
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text("🏪 Vendedor: $comercio",
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text("🛵 Repartidor: $motorista",
                    style: const TextStyle(fontSize: 14)),
                const Divider(height: 20),
                const Text("Selecciona los involucrados para el chat:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 5),
                SwitchListTile(
                  title: Text("Cliente: $cliente",
                      style: const TextStyle(fontSize: 13)),
                  value: _chatCliente,
                  dense: true,
                  activeThumbColor: const Color(0xFF1E3A8A),
                  onChanged: (val) {
                    setState(() => _chatCliente = val);
                    _verificarGrupal();
                  },
                ),
                SwitchListTile(
                  title: Text("Vendedor: $comercio",
                      style: const TextStyle(fontSize: 13)),
                  value: _chatVendedor,
                  dense: true,
                  activeThumbColor: const Color(0xFF1E3A8A),
                  onChanged: (val) {
                    setState(() => _chatVendedor = val);
                    _verificarGrupal();
                  },
                ),
                SwitchListTile(
                  title: Text("Repartidor: $motorista",
                      style: const TextStyle(fontSize: 13)),
                  value: _chatRepartidor,
                  dense: true,
                  activeThumbColor: const Color(0xFF1E3A8A),
                  onChanged: (val) {
                    setState(() => _chatRepartidor = val);
                    _verificarGrupal();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text("CHAT GRUPAL (Todos)",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  value: _chatGrupal,
                  dense: true,
                  activeThumbColor: Colors.orange,
                  onChanged: _gestionarGrupal,
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (esAbierto)
                      TextButton.icon(
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.green),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Resolver"),
                        onPressed: widget.onResolver,
                      ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text("Entrar al Chat"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatSoporte(
                              idPedido: idPedido,
                              remitente: "Admin Central",
                              canal: "admin_cliente",
                            ),
                          ),
                        ).then((_) => widget.onRecargar());
                      },
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
