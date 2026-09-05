import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Agregado para llamar a la API
import 'dart:convert'; // Agregado para leer JSON
import 'red.dart'; // Agregado para usar urlCentral

import 'carrito_service.dart';
import 'vista_login.dart';
import 'cli_locales.dart';
import 'cli_rastreo.dart';
import 'cli_carrito.dart';
import 'chat_soporte.dart';
import 'vista_editar_perfil.dart';
import 'vista_historial.dart';

class VistaConsumidor extends StatefulWidget {
  final String nombre;
  final String rol;
  final int idCliente;

  const VistaConsumidor(
      {super.key, required this.nombre, required this.rol, this.idCliente = 1});

  @override
  State<VistaConsumidor> createState() => _VistaConsumidorState();
}

class _VistaConsumidorState extends State<VistaConsumidor> {
  int _indiceActual = 0;
  int _llaveRecargaRastreo = 0;
  double _carritoX = 20.0;
  double _carritoY = 500.0;
  bool _hayPedidoActivo = false;
  double _rastreoX = 20.0;
  double _rastreoY = 100.0;

  // Variable para almacenar la ruta de la foto descargada
  String _urlFotoPerfil = "";

  @override
  void initState() {
    super.initState();
    _cargarFotoDrawer();
  }

  // Lógica silenciosa para traer la foto y ponerla en el menú
  Future<void> _cargarFotoDrawer() async {
    try {
      final url = Uri.parse('$urlCentral/api/perfil/${widget.idCliente}');
      final respuesta = await http.get(url);
      if (respuesta.statusCode == 200) {
        final datos = json.decode(utf8.decode(respuesta.bodyBytes));
        if (mounted) {
          setState(() {
            _urlFotoPerfil = datos['foto_perfil'] ?? "";
          });
        }
      }
    } catch (e) {
      // Si falla, se queda con el ícono por defecto
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const double buttonSize = 70.0;

    final vistas = [
      CliLocales(
        idCliente: widget.idCliente,
        onIrARastreo: () => setState(() {
          _indiceActual = 1;
          _hayPedidoActivo = true;
          _llaveRecargaRastreo++;
        }),
        onActualizar: () => setState(() {}),
      ),
      CliRastreo(
        key: ValueKey(_llaveRecargaRastreo),
        idCliente: widget.idCliente,
        onEstadoPedidos: (tienePedidos) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _hayPedidoActivo != tienePedidos) {
              setState(() {
                _hayPedidoActivo = tienePedidos;
              });
            }
          });
        },
      ),
      SoporteConsumidorPantalla(
        idCliente: widget.idCliente,
        nombreCliente: widget.nombre,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Bienvenido, ${widget.nombre}"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      drawer: _crearDrawer(context),
      body: Stack(
        children: [
          IndexedStack(index: _indiceActual, children: vistas),
          if (CarritoService.items.isNotEmpty)
            Positioned(
              left: _carritoX,
              top: _carritoY,
              child: GestureDetector(
                onPanUpdate: (detalles) => setState(() {
                  _carritoX = (_carritoX + detalles.delta.dx)
                      .clamp(10.0, screenSize.width - buttonSize - 10);
                  _carritoY = (_carritoY + detalles.delta.dy)
                      .clamp(10.0, screenSize.height - 220.0);
                }),
                child: _crearContenedorCarrito(),
              ),
            ),
          if (CarritoService.items.isEmpty &&
              _hayPedidoActivo &&
              _indiceActual != 1)
            Positioned(
              left: _rastreoX,
              top: _rastreoY,
              child: GestureDetector(
                onPanUpdate: (detalles) => setState(() {
                  _rastreoX = (_rastreoX + detalles.delta.dx)
                      .clamp(10.0, screenSize.width - buttonSize - 10);
                  _rastreoY = (_rastreoY + detalles.delta.dy)
                      .clamp(10.0, screenSize.height - 220.0);
                }),
                child: _crearContenedorRastreo(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
            if (index == 1) {
              _llaveRecargaRastreo++;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Locales'),
          BottomNavigationBarItem(
              icon: Icon(Icons.location_on), label: 'Rastreo'),
          BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: false,
                child: Icon(Icons.support_agent),
              ),
              label: 'Soporte'),
        ],
      ),
    );
  }

  Widget _crearContenedorCarrito() {
    return GestureDetector(
      onTap: () async {
        final pagado = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CliCarrito(
            idComercio: 1,
            idCliente: widget.idCliente,
          ),
        );

        if (!mounted) return;

        if (pagado == true) {
          setState(() {
            _hayPedidoActivo = true;
            _indiceActual = 1;
            _llaveRecargaRastreo++;
          });
        } else {
          setState(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
            const SizedBox(width: 4),
            Text(
              "${CarritoService.items.length}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _crearContenedorRastreo() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _indiceActual = 1;
          _llaveRecargaRastreo++;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.delivery_dining, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _crearDrawer(BuildContext context) {
    bool tieneFoto = _urlFotoPerfil.isNotEmpty && _urlFotoPerfil != "Sin foto";
    String urlCompleta = "$urlCentral$_urlFotoPerfil";

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
            accountName: Text(widget.nombre,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text('Rol: ${widget.rol.toUpperCase()}'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: tieneFoto ? NetworkImage(urlCompleta) : null,
              child: !tieneFoto
                  ? const Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A))
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
            title: const Text('Editar Información',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VistaEditarPerfil(idUsuario: widget.idCliente),
                ),
              ).then((_) {
                _cargarFotoDrawer();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF1E3A8A)),
            title: const Text('Historial de Pedidos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VistaHistorial(idCliente: widget.idCliente),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Cerrar Sesión',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              CarritoService.limpiar();
              setState(() {
                _hayPedidoActivo = false;
              });
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPantalla()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ========================================================
// PANTALLA DE SOPORTE INTEGRADA PARA EL CONSUMIDOR
// ========================================================
class SoporteConsumidorPantalla extends StatelessWidget {
  final int idCliente;
  final String nombreCliente;

  const SoporteConsumidorPantalla({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
  });

  @override
  Widget build(BuildContext context) {
    const Color colorTema = Color(0xFF1E3A8A);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.support_agent_rounded, size: 80, color: colorTema),
            const SizedBox(height: 15),
            const Text(
              "Centro de Soporte para Consumidores",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "¿Tienes problemas con tu pedido, la entrega o necesitas ayuda? Comunícate de inmediato con la central.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 35),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  // 🔥 Indicador de carga mientras la app detecta el pedido automáticamente
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(
                        child: CircularProgressIndicator(color: colorTema)),
                  );

                  int idPedidoFinal = 0;
                  bool tieneTicketAbierto = false;

                  try {
                    // 1. Revisar si ya hay un chat/ticket abierto guardado
                    final resTickets = await http.get(Uri.parse(
                        '$urlCentral/api/cliente/mis_tickets/$idCliente'));
                    if (resTickets.statusCode == 200) {
                      final List tickets =
                          json.decode(utf8.decode(resTickets.bodyBytes));
                      for (var t in tickets) {
                        if (t['estado'] != 'resuelto') {
                          tieneTicketAbierto = true;
                          idPedidoFinal = t['id_pedido'];
                          break;
                        }
                      }
                    }

                    // 2. Si no hay ticket abierto, buscar automáticamente el pedido activo actual
                    if (!tieneTicketAbierto) {
                      final resPedidos = await http.get(Uri.parse(
                          '$urlCentral/api/pedidos_activos/cliente/$idCliente'));
                      if (resPedidos.statusCode == 200) {
                        final List pedidos =
                            json.decode(utf8.decode(resPedidos.bodyBytes));
                        if (pedidos.isNotEmpty) {
                          idPedidoFinal = pedidos[0]['id_pedido'];
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint("Error buscando pedido automático: $e");
                  }

                  // Quitar el indicador de carga
                  if (context.mounted) Navigator.pop(context);

                  // 3. Abrir el chat automáticamente si se encontró el pedido, sin pedir números
                  if (idPedidoFinal > 0 && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatSoporte(
                          idPedido: idPedidoFinal,
                          remitente: nombreCliente,
                          canal: "admin_cliente",
                        ),
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "⚠️ No tienes ningún pedido activo en este momento para reportar."),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTema.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: colorTema, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Soporte por Pedido",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 4),
                            Text(
                                "Reporta incidencias con el platillo, entrega o local.",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatSoporte(
                        idPedido: -idCliente,
                        remitente: nombreCliente,
                        canal: "admin_cliente_personal",
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTema.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            color: colorTema, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Soporte Personal / General",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 4),
                            Text("Dudas sobre tu perfil, direcciones o cuenta.",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("ID de Consumidor en Sistema",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Text("#$idCliente",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
