import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'carrito_service.dart';
import 'cli_carrito.dart';
import 'cli_burbuja_flotante.dart';
import 'red.dart';

class CliMenuLocal extends StatefulWidget {
  final String idComercio;
  final String nombreComercio;
  const CliMenuLocal({
    super.key,
    required this.idComercio,
    required this.nombreComercio,
  });

  @override
  State<CliMenuLocal> createState() => _CliMenuLocalState();
}

class _CliMenuLocalState extends State<CliMenuLocal> {
  late Future<List<dynamic>> _productosFuture;

  @override
  void initState() {
    super.initState();
    _productosFuture = _obtenerProductos();
  }

  Future<List<dynamic>> _obtenerProductos() async {
    final url =
        Uri.parse('$urlCentral/productos_comercio/${widget.idComercio}');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes));
    } catch (_) {}
    return [];
  }

  int _obtenerCantidadDelProducto(int idProducto) {
    if (CarritoService.items.containsKey(idProducto)) {
      return CarritoService.items[idProducto]['cantidad'] ?? 0;
    }
    return 0;
  }

  Widget _iconoPorDefecto() {
    return Container(
      width: 65,
      height: 65,
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
            FutureBuilder<List<dynamic>>(
              future: _productosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No hay productos en el menú'));
                }

                final productos = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 16, left: 16, right: 16, bottom: 100),
                  itemCount: productos.length,
                  itemBuilder: (context, i) {
                    final prod = productos[i];
                    final int idProd = int.tryParse(prod['id'].toString()) ?? 0;
                    final double precio =
                        double.tryParse(prod['precio'].toString()) ?? 0.0;
                    final bool isAvailable =
                        (prod['disponible'] == 1 || prod['disponible'] == true);
                    final String nombre = prod['nombre'] ?? 'Platillo';
                    final String desc = prod['descripcion'] ?? 'Especialidad';
                    final String foto =
                        prod['foto'] ?? prod['foto_platillo'] ?? '';
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
                                child:
                                    foto.isNotEmpty && foto.startsWith('http')
                                        ? Image.network(foto,
                                            width: 65,
                                            height: 65,
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('\$$precio',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: isAvailable
                                              ? Colors.black87
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600)),
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
                      idComercio: int.tryParse(widget.idComercio) ??
                          1, // <-- LE PASA EL ID AL CARRITO
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
