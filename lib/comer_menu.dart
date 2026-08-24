import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'producto_service.dart';
import 'red.dart';

// ========================================================
// VISTA MENÚ
// ========================================================
class VistaMenu extends StatefulWidget {
  final String idComercio;
  const VistaMenu({super.key, required this.idComercio});
  @override
  State<VistaMenu> createState() => _VistaMenuState();
}

class _VistaMenuState extends State<VistaMenu> {
  final ProductoService _productoService = ProductoService();
  List<dynamic> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargando = true);
    try {
      final prods = await _productoService.obtenerProductos(widget.idComercio);
      if (mounted) {
        setState(() {
          _productos = prods.map((p) {
            bool disp = false;
            if (p['disponible'] == 1 || p['disponible'] == true) disp = true;
            return {...p, 'disponible': disp};
          }).toList();
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoAgregar() {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo Producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del Platillo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: precioCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Precio (\$)', prefixText: '\$ '),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.isNotEmpty && precioCtrl.text.isNotEmpty) {
                  final mensajero = ScaffoldMessenger.of(context);
                  final navegador = Navigator.of(context);

                  navegador.pop();
                  setState(() => _cargando = true);

                  final exito = await _productoService.agregarProducto({
                    'id_comercio': int.tryParse(widget.idComercio) ?? 1,
                    'nombre_producto': nombreCtrl.text,
                    'precio': double.tryParse(precioCtrl.text) ?? 0.0,
                  });

                  if (exito) {
                    _cargarProductos();
                  } else {
                    setState(() => _cargando = false);
                    mensajero.showSnackBar(
                      const SnackBar(
                          content: Text('Error al guardar en el servidor')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding:
                  const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 80),
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final prod = _productos[index];
                bool isAvailable = prod['disponible'];

                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.fastfood,
                      color: isAvailable ? Colors.orange : Colors.grey,
                    ),
                    title: Text(
                      prod['nombre'] ?? prod['nombre_producto'] ?? 'Sin nombre',
                      style: TextStyle(
                        decoration:
                            isAvailable ? null : TextDecoration.lineThrough,
                        color: isAvailable ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text("\$${prod['precio']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: isAvailable,
                          activeTrackColor: Colors.green,
                          onChanged: (bool val) async {
                            setState(() {
                              _productos[index]['disponible'] = val;
                            });
                            try {
                              final idProd = prod['id'] ?? prod['id_producto'];
                              final precio =
                                  double.tryParse(prod['precio'].toString()) ??
                                      0.0;
                              final url = Uri.parse(
                                  '$urlCentral/api/actualizar_producto');
                              await http.post(
                                url,
                                headers: {"Content-Type": "application/json"},
                                body: json.encode({
                                  "id_producto": idProd,
                                  "disponible": val ? 1 : 0,
                                  "precio": precio
                                }),
                              );
                            } catch (e) {
                              debugPrint(
                                  "Error al actualizar estado en Python: $e");
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final exito =
                                await _productoService.eliminarProducto(
                              prod['id'] ?? prod['id_producto'],
                            );
                            if (exito) _cargarProductos();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAgregar,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
