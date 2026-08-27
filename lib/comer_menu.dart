import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import 'producto_service.dart';
import 'red.dart';

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

  String _obtenerUrlFoto(String foto) {
    if (foto.isEmpty || foto == 'Sin foto' || foto == 'Sin logo') return '';
    if (foto.startsWith('http')) return foto;
    if (foto.startsWith('/')) {
      return '$urlCentral$foto';
    }
    return '$urlCentral/$foto';
  }

  // Sube la foto enviando explícitamente el ID del producto al servidor
  Future<String> _subirImagenPlatilloServidor(
      File imagenFile, int idProducto) async {
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('$urlCentral/api/subir_foto_producto'));
      request.fields['id_producto'] = idProducto.toString();
      request.files
          .add(await http.MultipartFile.fromPath('file', imagenFile.path));
      var res = await request.send();
      if (res.statusCode == 200) {
        var responseData = await res.stream.bytesToString();
        var jsonData = json.decode(responseData);
        return jsonData['url'] ?? jsonData['path'] ?? '';
      }
    } catch (e) {
      debugPrint("Error subiendo foto del platillo: $e");
    }
    return '';
  }

  void _mostrarDialogoAgregar() {
    final nombreCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    File? imagenSeleccionada;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nuevo Platillo Pro',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final XFile? imagen =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (imagen != null) {
                          setStateDialog(() {
                            imagenSeleccionada = File(imagen.path);
                          });
                        }
                      },
                      child: Container(
                        height: 75,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade400),
                          image: imagenSeleccionada != null
                              ? DecorationImage(
                                  image: FileImage(imagenSeleccionada!),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: imagenSeleccionada == null
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      size: 24, color: Color(0xFF1E3A8A)),
                                  SizedBox(width: 8),
                                  Text("Toca para elegir foto",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold))
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Platillo',
                        prefixIcon: Icon(Icons.fastfood,
                            color: Color(0xFF1E3A8A), size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descripcionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description,
                            color: Color(0xFF1E3A8A), size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: precioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Precio',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.attach_money,
                            color: Colors.green, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () async {
                    if (nombreCtrl.text.isNotEmpty &&
                        precioCtrl.text.isNotEmpty) {
                      final mensajero = ScaffoldMessenger.of(context);
                      final navegador = Navigator.of(context);

                      navegador.pop();
                      setState(() => _cargando = true);

                      // 1. PRIMERO CREAMOS EL PLATILLO SIN FOTO PARA OBTENER SU ID REAL
                      final bool exitoCreacion =
                          await _productoService.agregarProducto({
                        'id_comercio': int.tryParse(widget.idComercio) ?? 1,
                        'nombre_producto': nombreCtrl.text.trim(),
                        'descripcion': descripcionCtrl.text.trim(),
                        'precio': double.tryParse(precioCtrl.text) ?? 0.0,
                        'foto': 'Sin foto',
                        'disponible': 1,
                      });

                      if (exitoCreacion) {
                        // Si se seleccionó una foto, necesitamos el ID del último producto creado para asociarla
                        if (imagenSeleccionada != null) {
                          try {
                            // Consultamos rápidamente los productos del comercio para ubicar el ID recién creado
                            final prodsActualizados = await _productoService
                                .obtenerProductos(widget.idComercio);
                            if (prodsActualizados.isNotEmpty) {
                              // Tomamos el primero de la lista (que por orden de ID reciente es el nuevo)
                              final ultimoProd = prodsActualizados.last;
                              final int idRecienCreado = int.tryParse(
                                      ultimoProd['id']?.toString() ??
                                          ultimoProd['id_producto']
                                              ?.toString() ??
                                          '0') ??
                                  0;

                              if (idRecienCreado > 0) {
                                await _subirImagenPlatilloServidor(
                                    imagenSeleccionada!, idRecienCreado);
                              }
                            }
                          } catch (e) {
                            debugPrint(
                                "Error asociando foto al nuevo producto: $e");
                          }
                        }
                        _cargarProductos();
                      } else {
                        setState(() => _cargando = false);
                        mensajero.showSnackBar(
                          const SnackBar(
                              content: Text('Error al guardar en el servidor'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar Platillo',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cambiarFotoPlatillo(Map prod) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? imagen = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (imagen != null) {
        setState(() => _cargando = true);
        final int idProd = int.tryParse(prod['id']?.toString() ??
                prod['id_producto']?.toString() ??
                '0') ??
            0;

        String nuevaRutaFoto =
            await _subirImagenPlatilloServidor(File(imagen.path), idProd);

        if (nuevaRutaFoto.isNotEmpty) {
          final precio = double.tryParse(prod['precio'].toString()) ?? 0.0;
          final disponibleVal =
              (prod['disponible'] == true || prod['disponible'] == 1) ? 1 : 0;

          final url = Uri.parse('$urlCentral/api/actualizar_producto');
          await http.post(
            url,
            headers: {"Content-Type": "application/json"},
            body: json.encode({
              "id_producto": idProd,
              "disponible": disponibleVal,
              "precio": precio,
              "foto": nuevaRutaFoto,
            }),
          );
          _cargarProductos();
        } else {
          setState(() => _cargando = false);
          mensajero.showSnackBar(
            const SnackBar(
                content: Text("El servidor no devolvió la ruta de la foto"),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _cargando = false);
      debugPrint("🚨 Error al abrir galería o subir foto: $e");
      mensajero.showSnackBar(
        SnackBar(
            content: Text("Error al abrir galería: $e"),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _productos.isEmpty
              ? const Center(
                  child: Text(
                      "Aún no tienes platillos en tu menú.\nToca el botón '+' para agregar el primero.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 12, left: 12, right: 12, bottom: 80),
                  itemCount: _productos.length,
                  itemBuilder: (context, index) {
                    final prod = _productos[index];
                    bool isAvailable = prod['disponible'];
                    final String nombre = prod['nombre'] ??
                        prod['nombre_producto'] ??
                        'Sin nombre';
                    final String desc =
                        prod['descripcion'] ?? 'Especialidad de la casa';
                    final double precio =
                        double.tryParse(prod['precio'].toString()) ?? 0.0;
                    final String fotoCruda =
                        prod['foto'] ?? prod['foto_platillo'] ?? '';
                    final String fotoFinal = _obtenerUrlFoto(fotoCruda);

                    return Card(
                      elevation: isAvailable ? 2 : 0,
                      color: isAvailable ? Colors.white : Colors.grey[200],
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      decoration: isAvailable
                                          ? null
                                          : TextDecoration.lineThrough,
                                      color: isAvailable
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${precio.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable
                                          ? Colors.green[700]
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (!isAvailable)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text("AGOTADO",
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () => _cambiarFotoPlatillo(prod),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: fotoFinal.isNotEmpty
                                            ? Image.network(
                                                fotoFinal,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: Colors.orange.shade100,
                                                  child: const Icon(
                                                      Icons.fastfood,
                                                      color: Colors.orange,
                                                      size: 30),
                                                ),
                                              )
                                            : Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.orange.shade100,
                                                child: const Icon(
                                                    Icons.fastfood,
                                                    color: Colors.orange,
                                                    size: 30),
                                              ),
                                      ),
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.black
                                              .withValues(alpha: 0.35),
                                        ),
                                        child: const Center(
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.black87,
                                            child: Icon(Icons.camera_alt,
                                                color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
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
                                          final idProd =
                                              prod['id'] ?? prod['id_producto'];
                                          final url = Uri.parse(
                                              '$urlCentral/api/actualizar_producto');
                                          await http.post(
                                            url,
                                            headers: {
                                              "Content-Type": "application/json"
                                            },
                                            body: json.encode({
                                              "id_producto": idProd,
                                              "disponible": val ? 1 : 0,
                                              "precio": precio,
                                            }),
                                          );
                                        } catch (e) {
                                          debugPrint(
                                              "Error al actualizar estado: $e");
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red, size: 22),
                                      onPressed: () async {
                                        final exito = await _productoService
                                            .eliminarProducto(
                                          prod['id'] ?? prod['id_producto'],
                                        );
                                        if (exito) _cargarProductos();
                                      },
                                    ),
                                  ],
                                ),
                              ],
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
