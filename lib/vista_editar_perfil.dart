import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'red.dart'; // <-- IMPORTADO

class VistaEditarPerfil extends StatefulWidget {
  final int idUsuario;
  const VistaEditarPerfil({super.key, required this.idUsuario});

  @override
  State<VistaEditarPerfil> createState() => _VistaEditarPerfilState();
}

class _VistaEditarPerfilState extends State<VistaEditarPerfil> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;

  File? _imagenLocal; // Aquí guardamos la foto que elija el cliente
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  Future<void> _cargarDatosActuales() async {
    try {
      final url = Uri.parse(
        '$urlCentral/perfil/${widget.idUsuario}', // <-- CORREGIDO
      );
      final respuesta = await http.get(url).timeout(const Duration(seconds: 5));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(utf8.decode(respuesta.bodyBytes));
        setState(() {
          _nombreCtrl.text = datos['nombre'] ?? '';
          _telefonoCtrl.text = datos['telefono'] ?? '';
          _direccionCtrl.text = datos['direccion'] ?? '';
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Error al cargar: $e");
      setState(() => _cargando = false);
    }
  }

  // FUNCIÓN NUEVA: Abrir galería y subir foto al motor Python
  Future<void> _cambiarFoto() async {
    final XFile? fotoSeleccionada = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (fotoSeleccionada != null) {
      setState(() => _imagenLocal = File(fotoSeleccionada.path));

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$urlCentral/subir_foto/'), // <-- CORREGIDO
        );
        request.files.add(
          await http.MultipartFile.fromPath('file', fotoSeleccionada.path),
        );

        var res = await request.send();
        if (res.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("📸 Foto subida al servidor con éxito"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint("🚨 Error al subir foto: $e");
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final url = Uri.parse(
        '$urlCentral/actualizar_perfil/${widget.idUsuario}', // <-- CORREGIDO
      );
      final respuesta = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'nombre': _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
        }),
      );

      if (respuesta.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Perfil actualizado"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("🚨 Error al guardar: $e");
    }

    setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Información"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // CÍRCULO INTERACTIVO DE FOTO
                    GestureDetector(
                      onTap: _cambiarFoto,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _imagenLocal != null
                            ? FileImage(_imagenLocal!)
                            : null,
                        child: _imagenLocal == null
                            ? const Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Toca para cambiar foto",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),

                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Teléfono",
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _direccionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Dirección",
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      onPressed: _guardando ? null : _guardarCambios,
                      child: _guardando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "GUARDAR CAMBIOS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
