// Archivo: cli_rastreo.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:async';
import 'red.dart';
import 'mapa_consumidor.dart';
import 'chat_pedido.dart';

// ========================================================
// BOTÓN ANIMADO (PARPADEANTE) PARA EL CLIENTE
// ========================================================
class BotonMapaParpadeante extends StatefulWidget {
  final VoidCallback onPressed;
  const BotonMapaParpadeante({super.key, required this.onPressed});

  @override
  State<BotonMapaParpadeante> createState() => _BotonMapaParpadeanteState();
}

class _BotonMapaParpadeanteState extends State<BotonMapaParpadeante>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.map, size: 20),
        label: const Text(
          "VER MAPA",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

// ========================================================
// VISTA RASTREO
// ========================================================
class CliRastreo extends StatefulWidget {
  final int idCliente;
  final Function(bool)? onEstadoPedidos;
  const CliRastreo({super.key, this.idCliente = 1, this.onEstadoPedidos});

  @override
  State<CliRastreo> createState() => _CliRastreoState();
}

class _CliRastreoState extends State<CliRastreo> {
  List<dynamic> _listaPedidos = [];
  bool _cargando = true;

  Timer? _latidosClienteTimer;
  Timer? _timerMonitoreoPedidos;

  LatLng? _miUbicacionReal;

  // 🔥 Variables para rastrear notificaciones rojas por cada pedido activo
  final Map<int, int> _cantidadMensajesAnterior = {};
  final Map<int, bool> _hayMensajeNuevo = {};

  @override
  void initState() {
    super.initState();
    _cargarPedidosSilencioso();

    _timerMonitoreoPedidos =
        Timer.periodic(const Duration(seconds: 4), (timer) {
      _cargarPedidosSilencioso();
    });
  }

  @override
  void dispose() {
    _latidosClienteTimer?.cancel();
    _timerMonitoreoPedidos?.cancel();
    super.dispose();
  }

  void _iniciarLatidosCliente(int idPedido) {
    _latidosClienteTimer?.cancel();
    _latidosClienteTimer =
        Timer.periodic(const Duration(seconds: 8), (timer) async {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }

        Position pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );

        if (mounted) {
          setState(() {
            _miUbicacionReal = LatLng(pos.latitude, pos.longitude);
          });
        }

        final url = Uri.parse('$urlCentral/actualizar_gps_cliente');
        await http
            .post(
              url,
              headers: {"Content-Type": "application/json"},
              body: json.encode({
                "id_pedido": idPedido,
                "latitud": pos.latitude,
                "longitud": pos.longitude,
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint("Error enviando GPS del cliente: $e");
      }
    });
  }

  Future<void> _cargarPedidosSilencioso() async {
    final url = Uri.parse(
        '$urlCentral/api/pedidos_activos/cliente/${widget.idCliente}');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List lista = json.decode(utf8.decode(res.bodyBytes));

        final listaActivos = lista.where((p) {
          final estado = (p['estado_codigo'] ?? '').toString().toLowerCase();
          return estado != 'entregado' &&
              estado != 'cancelado' &&
              estado != 'archivado';
        }).toList();

        final listaOrdenada = listaActivos.reversed.toList();

        if (listaOrdenada.isNotEmpty) {
          final int primerIdPedido = listaOrdenada.first['id_pedido'] ?? 0;
          if (primerIdPedido > 0 && _latidosClienteTimer == null) {
            _iniciarLatidosCliente(primerIdPedido);
          }
        } else {
          _latidosClienteTimer?.cancel();
          _latidosClienteTimer = null;
        }

        if (widget.onEstadoPedidos != null) {
          widget.onEstadoPedidos!(listaOrdenada.isNotEmpty);
        }

        if (mounted) {
          setState(() {
            _listaPedidos = listaOrdenada;
            _cargando = false;
          });
        }

        // 🔥 Llama al revisor de mensajes para encender los focos rojos si aplica
        _verificarMensajesNuevos(listaOrdenada);
      }
    } catch (e) {
      debugPrint("Error rastreo: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // 🔥 NUEVA FUNCIÓN: Revisa mensajes en segundo plano
  Future<void> _verificarMensajesNuevos(List pedidos) async {
    for (var p in pedidos) {
      final estadoCodigo = p['estado_codigo'] ?? '';
      final bool enCamino =
          (p['en_camino'] == true || estadoCodigo == 'en_camino');
      final int idPedido = p['id_pedido'];

      // Solo gastamos recursos buscando mensajes si el motorista ya va en camino
      if (enCamino) {
        try {
          final url = Uri.parse(
              '$urlCentral/api/chat/historial/$idPedido?canal=motorista_consumidor');
          final res = await http.get(url).timeout(const Duration(seconds: 2));

          if (res.statusCode == 200) {
            final data = json.decode(utf8.decode(res.bodyBytes));
            List mensajes = data['mensajes'] ?? [];

            int cantidadAnterior = _cantidadMensajesAnterior[idPedido] ?? 0;

            if (mensajes.length > cantidadAnterior) {
              final ultimoMsj = mensajes.last;
              // Encendemos el punto rojo solo si el mensaje no es nuestro ni del sistema
              if (ultimoMsj['remitente'] != 'Cliente' &&
                  ultimoMsj['remitente'] != 'Sistema Automático') {
                if (mounted) {
                  setState(() {
                    _hayMensajeNuevo[idPedido] = true;
                  });
                }
              }
              _cantidadMensajesAnterior[idPedido] = mensajes.length;
            }
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _cancelarPedido(int idPedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cancelar Pedido?"),
        content: const Text(
            "El local aún no ha aceptado tu orden. ¿Deseas eliminar este pedido para buscar otro comercio?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, eliminar",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        final url = Uri.parse('$urlCentral/api/cancelar_pedido/$idPedido');
        final res = await http.post(url);

        if (res.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Pedido eliminado con éxito",
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.orange),
          );
          _latidosClienteTimer?.cancel();
          _latidosClienteTimer = null;
          _cargarPedidosSilencioso();
        }
        // ignore: empty_catches
      } catch (e) {}
    }
  }

  void _mostrarDetalleCompra(
      BuildContext context, List<dynamic> fotos, String descripcion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Detalle del Pedido",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF0055A4)),
            textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Lo que ordenaste:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(descripcion,
                    style:
                        const TextStyle(fontSize: 15, color: Colors.black87)),
              ),
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text("Galería:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: fotos.map((f) {
                      final rutaLimpia = f['foto'].toString().startsWith('http')
                          ? f['foto']
                          : "$urlCentral${f['foto']}"
                              .replaceAll('//fotos', '/fotos')
                              .replaceAll('//static', '/static');

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          rutaLimpia,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 110,
                              height: 110,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.fastfood,
                                  color: Colors.grey, size: 30)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0055A4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _construirGaleriaProductos(
      BuildContext context, List<dynamic>? productos, String descripcion) {
    if (productos == null || productos.isEmpty) {
      return GestureDetector(
        onTap: () => _mostrarDetalleCompra(context, [], descripcion),
        child: const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFF0055A4),
            child: Icon(Icons.receipt_long, color: Colors.white, size: 24)),
      );
    }

    final fotosAMostrar = productos.take(3).toList();

    return GestureDetector(
      onTap: () => _mostrarDetalleCompra(context, productos, descripcion),
      child: SizedBox(
        width: 60,
        height: 50,
        child: Stack(
          children: [
            for (int i = 0; i < fotosAMostrar.length; i++)
              Positioned(
                left: (i * 16).toDouble(),
                top: (i * 4).toDouble(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2)
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      fotosAMostrar[i]['foto'].toString().startsWith('http')
                          ? fotosAMostrar[i]['foto']
                          : "$urlCentral${fotosAMostrar[i]['foto']}"
                              .replaceAll('//fotos', '/fotos')
                              .replaceAll('//static', '/static'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, ___) {
                        return Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.fastfood,
                                size: 16, color: Colors.grey));
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Rastreo de Pedidos Activos"),
        backgroundColor: const Color(0xFF0055A4),
        foregroundColor: Colors.white,
      ),
      body: _cargando && _listaPedidos.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0055A4)))
          : _listaPedidos.isEmpty
              ? RefreshIndicator(
                  onRefresh: _cargarPedidosSilencioso,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Icon(Icons.delivery_dining, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Center(
                          child: Text(
                              "No tienes pedidos activos en este momento.",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey))),
                      Center(
                          child: Text(
                              "Buscando actualizaciones automáticamente...",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarPedidosSilencioso,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _listaPedidos.length,
                    itemBuilder: (context, index) {
                      final p = _listaPedidos[index];
                      final estadoCodigo = p['estado_codigo'] ?? '';
                      final int idPedido = p['id_pedido'] ?? 0;

                      final int numCompra = p['numero_orden'] ?? idPedido;
                      final bool enCamino = (p['en_camino'] == true ||
                          estadoCodigo == 'en_camino');

                      final String codigoRastreoTexto =
                          p['codigo_rastreo'] ?? 'CP-0000';
                      final String descripcionPedido =
                          p['descripcion'] ?? 'Sin detalle';
                      final List<dynamic>? productosPedido = p['productos'];

                      String textoLlegadaExtra = "";
                      if (enCamino &&
                          _miUbicacionReal != null &&
                          p['lat'] != null &&
                          p['lon'] != null) {
                        double latRep =
                            double.tryParse(p['lat'].toString()) ?? 0.0;
                        double lonRep =
                            double.tryParse(p['lon'].toString()) ?? 0.0;

                        if (latRep != 0.0 && lonRep != 0.0) {
                          const Distance dist = Distance();
                          double km = dist.as(LengthUnit.Meter,
                                  _miUbicacionReal!, LatLng(latRep, lonRep)) /
                              1000;
                          int minutos = (km * 3).ceil();
                          textoLlegadaExtra = " • Llega en aprox. $minutos min";
                        }
                      }

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _construirGaleriaProductos(context,
                                          productosPedido, descripcionPedido),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("Mi Compra del Día #$numCompra",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      "Código de Pedido"),
                                                  content: Text(
                                                      "¿Deseas copiar el código $codigoRastreoTexto al portapapeles para usarlo en soporte?"),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                            "Cancelar")),
                                                    ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                      0xFF0055A4)),
                                                      onPressed: () {
                                                        Clipboard.setData(
                                                            ClipboardData(
                                                                text:
                                                                    codigoRastreoTexto));
                                                        Navigator.pop(ctx);
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(SnackBar(
                                                                content: Text(
                                                                    "¡Código $codigoRastreoTexto copiado con éxito!"),
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2)));
                                                      },
                                                      child: const Text(
                                                          "Copiar Código",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                Text(
                                                    "Serial: $codigoRastreoTexto",
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF0055A4))),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.copy_rounded,
                                                    size: 14,
                                                    color: Color(0xFF0055A4)),
                                              ],
                                            ),
                                          ),
                                          Text("${p['fecha'] ?? 'Hoy'}",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text("PIN",
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold)),
                                      Text("${p['pin_seguridad'] ?? '---'}",
                                          style: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2)),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text("${p['estado']}$textoLlegadaExtra",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0055A4),
                                        fontSize: 14)),
                              ),
                              const SizedBox(height: 12),
                              if (enCamino)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: BotonMapaParpadeante(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MapaConsumidorScreen(
                                                  idPedido: idPedido,
                                                  codigoRastreo:
                                                      p['codigo_rastreo'] ??
                                                          'CP-0000',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blueAccent.shade700,
                                            foregroundColor: Colors.white,
                                            minimumSize:
                                                const Size(double.infinity, 45),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          // 🔥 AQUÍ SE IMPLEMENTA EL BADGE (PUNTO ROJO)
                                          icon: Badge(
                                            isLabelVisible:
                                                _hayMensajeNuevo[idPedido] ??
                                                    false,
                                            backgroundColor: Colors.red,
                                            child: const Icon(
                                                Icons.chat_bubble_outline,
                                                size: 20),
                                          ),
                                          label: const Text("CHAT MOTORISTA",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                          onPressed: () {
                                            // Apagamos la luz roja al entrar al chat
                                            setState(() {
                                              _hayMensajeNuevo[idPedido] =
                                                  false;
                                            });
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ChatPedidoScreen(
                                                  idPedido: idPedido,
                                                  remitente: "Cliente",
                                                  canal: "motorista_consumidor",
                                                  nombreDestino:
                                                      "Chat con Motorista",
                                                ),
                                              ),
                                            ).then((_) =>
                                                _cargarPedidosSilencioso());
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      "Total a pagar: \$${double.parse((p['total'] ?? 0).toString()).toStringAsFixed(2)}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  if (estadoCodigo == 'pendiente')
                                    IconButton(
                                      onPressed: () =>
                                          _cancelarPedido(idPedido),
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 26),
                                      tooltip: "Eliminar pedido",
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
