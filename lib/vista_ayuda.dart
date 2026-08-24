import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'chat_soporte.dart';

class VistaAyuda extends StatefulWidget {
  final int idCliente;
  const VistaAyuda({super.key, this.idCliente = 1});

  @override
  State<VistaAyuda> createState() => _VistaAyudaState();
}

class _VistaAyudaState extends State<VistaAyuda> {
  List<dynamic> _misCasos = [];
  bool _cargando = true;
  Timer? _latido;

  @override
  void initState() {
    super.initState();
    _cargarMisCasos();
    _latido = Timer.periodic(
        const Duration(seconds: 5), (t) => _cargarMisCasos(silencioso: true));
  }

  @override
  void dispose() {
    _latido?.cancel();
    super.dispose();
  }

  Future<void> _cargarMisCasos({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final res = await http.get(
          Uri.parse('$urlCentral/api/cliente/mis_tickets/${widget.idCliente}'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _misCasos = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // 🔥 NUEVA FUNCIÓN PARA BORRAR EL CASO RESUELTO
  Future<void> _borrarCasoResuelto(int idPedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Borrar caso resuelto?"),
        content: const Text(
            "Se eliminará este ticket y su chat de tu historial. ¿Estás seguro?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, borrar",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        final url =
            Uri.parse('$urlCentral/api/cliente/borrar_ticket/$idPedido');
        final res = await http.post(url);

        if (res.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Caso eliminado de tu historial"),
              backgroundColor: Colors.orange,
            ),
          );
          _cargarMisCasos(); // Recarga la lista para que desaparezca
        }
      } catch (e) {
        debugPrint("Error borrando caso: $e");
      }
    }
  }

  Future<void> _llamarCentral() async {
    final Uri url = Uri.parse('tel:+50322222222');
    if (!await launchUrl(url)) {
      debugPrint('No se pudo abrir el teclado telefónico');
    }
  }

  void _abrirNuevoCaso() {
    final TextEditingController rastreoCtrl = TextEditingController();
    bool verificando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text("Nuevo Ticket de Soporte"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ingresa el código de rastreo de tu pedido (Ej. CP-0001) para recibir ayuda:",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: rastreoCtrl,
                textCapitalization:
                    TextCapitalization.characters, // Auto-mayúsculas
                decoration: const InputDecoration(
                  labelText: "Código de Rastreo",
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: verificando
                  ? null
                  : () async {
                      final codigo = rastreoCtrl.text.trim().toUpperCase();
                      if (codigo.isEmpty) return;

                      setStateDialog(() => verificando = true);

                      try {
                        // Le pregunta a Python si ese código de rastreo existe
                        final url = Uri.parse(
                            '$urlCentral/api/cliente/validar_rastreo/$codigo');
                        final res = await http.get(url);
                        final data = json.decode(utf8.decode(res.bodyBytes));

                        if (data['status'] == 'ok') {
                          if (!context.mounted) return;
                          Navigator.pop(context); // Cierra el cuadro

                          // Abre el chat usando el id_pedido real que nos devolvió Python
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatSoporte(
                                idPedido: data['id_pedido'],
                                remitente: "Cliente",
                                canal: "admin_cliente",
                              ),
                            ),
                          ).then((_) => _cargarMisCasos());
                        } else {
                          setStateDialog(() => verificando = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Rastreo no encontrado. Verifica el código."),
                                backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => verificando = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Error de conexión con la Central."),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
              child: verificando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("Buscar e Iniciar",
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _cargarMisCasos(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Centro de Soporte",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          if (_cargando && _misCasos.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator())),
          if (_misCasos.isNotEmpty) ...[
            const Text("Tus Casos",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey)),
            const SizedBox(height: 10),
            ..._misCasos.map((caso) {
              final bool esAbierto = caso['estado'] == 'abierto';

              return Card(
                elevation: esAbierto ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    side: BorderSide(
                        color:
                            esAbierto ? Colors.orange : Colors.green.shade300,
                        width: esAbierto ? 2 : 1),
                    borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: esAbierto
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        radius: 25,
                        child: Icon(
                            esAbierto
                                ? Icons.support_agent
                                : Icons.check_circle,
                            color: esAbierto ? Colors.orange : Colors.green,
                            size: 28),
                      ),
                      if (esAbierto)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                          ),
                        )
                    ],
                  ),
                  title: const Text("Seguimiento de Caso",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Orden #${caso['id_pedido']} • Rastreo: ${caso['codigo_rastreo']}\nEstado: ${esAbierto ? 'En revisión' : 'Resuelto'}"),
                  // 🔥 AQUÍ ESTÁ LA MAGIA DEL BOTÓN DE BORRAR
                  trailing: esAbierto
                      ? const Icon(Icons.arrow_forward_ios, size: 16)
                      : IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 28),
                          onPressed: () =>
                              _borrarCasoResuelto(caso['id_pedido']),
                        ),
                  isThreeLine: true,
                  onTap: () {
                    // Solo deja entrar al chat si el caso sigue abierto
                    if (esAbierto) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatSoporte(
                            idPedido: caso['id_pedido'],
                            remitente: "Cliente",
                            canal: "admin_cliente",
                          ),
                        ),
                      ).then((_) => _cargarMisCasos());
                    }
                  },
                ),
              );
            }),
            const Divider(height: 30, thickness: 1),
          ],
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.chat, color: Colors.white),
              ),
              title: const Text("Abrir Nuevo Caso",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Reporta un problema con otra orden."),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: _abrirNuevoCaso,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.phone, color: Colors.white),
              ),
              title: const Text("Llamada de Emergencia",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Solo para cancelaciones urgentes."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _llamarCentral,
            ),
          ),
        ],
      ),
    );
  }
}
