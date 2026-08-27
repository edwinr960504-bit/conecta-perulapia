import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'carrito_service.dart';
import 'cli_carrito.dart';
import 'cli_burbuja_flotante.dart';
import 'red.dart';

class CliMenuLocal extends StatefulWidget {
  final String idComercio;
  final String nombreComercio;
  final int idCliente;

  const CliMenuLocal({
    super.key,
    required this.idComercio,
    required this.nombreComercio,
    required this.idCliente,
  });

  @override
  State<CliMenuLocal> createState() => _CliMenuLocalState();
}

class _CliMenuLocalState extends State<CliMenuLocal> {
  List<dynamic> _productos = [];
  bool _cargando = true;
  Timer? _timerMenu;

  @override
  void initState() {
    super.initState();
    _obtenerProductosSilencioso();
    _timerMenu = Timer.periodic(const Duration(seconds: 4), (_) {
      _obtenerProductosSilencioso();
    });
  }

  @override
  void dispose() {
    _timerMenu?.cancel();
    super.dispose();
  }

  Future<void> _obtenerProductosSilencioso() async {
    final url =
        Uri.parse('$urlCentral/productos_comercio/${widget.idComercio}');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _productos = json.decode(utf8.decode(res.bodyBytes));
            _cargando = false;
          });
        }
      }
    } catch (_) {}
  }

  String _obtenerUrlFoto(String foto) {
    if (foto.isEmpty || foto == 'Sin foto' || foto == 'Sin logo') return '';
    if (foto.startsWith('http')) return foto;
    if (foto.startsWith('/')) return '$urlCentral$foto';
    return '$urlCentral/$foto';
  }

  int _obtenerCantidadDelProducto(int idProducto) {
    if (CarritoService.items.containsKey(idProducto)) {
      return CarritoService.items[idProducto]['cantidad'] ?? 0;
    }
    return 0;
  }

  Widget _iconoPorDefecto() {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.fastfood, color: Colors.orange, size: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.nombreComercio,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (_cargando && _productos.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_productos.isEmpty)
              const Center(child: Text('No hay productos en el menú'))
            else
              ListView.builder(
                padding: const EdgeInsets.only(
                    top: 16, left: 16, right: 16, bottom: 100),
                itemCount: _productos.length,
                itemBuilder: (context, i) {
                  final prod = _productos[i];
                  final int idProd = int.tryParse(prod['id'].toString()) ?? 0;
                  final double precio =
                      double.tryParse(prod['precio'].toString()) ?? 0.0;
                  final bool isAvailable =
                      (prod['disponible'] == 1 || prod['disponible'] == true);
                  final String nombre =
                      prod['nombre'] ?? prod['nombre_producto'] ?? 'Platillo';
                  final String desc = prod['descripcion'] ?? 'Especialidad';
                  final String fotoCruda =
                      prod['foto'] ?? prod['foto_platillo'] ?? '';
                  final String fotoFinal = _obtenerUrlFoto(fotoCruda);
                  final cantidadActual = _obtenerCantidadDelProducto(idProd);

                  return Card(
                    elevation: isAvailable ? 2 : 0,
                    color: isAvailable ? Colors.white : Colors.grey[200],
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Opacity(
                            opacity: isAvailable ? 1.0 : 0.5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: fotoFinal.isNotEmpty
                                  ? Image.network(fotoFinal,
                                      width: 75,
                                      height: 75,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _iconoPorDefecto())
                                  : _iconoPorDefecto(),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nombre,
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: isAvailable
                                            ? Colors.black87
                                            : Colors.grey)),
                                if (!isAvailable)
                                  const Text("Agotado",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))
                                else
                                  Text(desc,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('\$${precio.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: isAvailable
                                            ? Colors.green[700]
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (isAvailable)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (cantidadActual > 0)
                                  IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                          size: 28),
                                      onPressed: () {
                                        CarritoService.quitar(idProd);
                                        setState(() {});
                                      }),
                                if (cantidadActual > 0)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: Text('$cantidadActual',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold))),
                                IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: Color(0xFF1E3A8A), size: 28),
                                    onPressed: () {
                                      CarritoService.agregar({
                                        'id_producto': idProd,
                                        'nombre': nombre,
                                        'precio': precio
                                      });
                                      setState(() {});
                                    }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (CarritoService.items.isNotEmpty)
              CliBurbujaFlotante(
                icono: Icons.shopping_cart,
                color: Colors.orange,
                cantidad: CarritoService.contador.value,
                onTap: () async {
                  final compraConfirmada = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CliCarrito(
                      idComercio: int.tryParse(widget.idComercio) ?? 1,
                      idCliente: widget
                          .idCliente, // 🔥 Parámetro requerido agregado correctamente
                    ),
                  );
                  if (!context.mounted) return;
                  if (compraConfirmada == true) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {});
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
