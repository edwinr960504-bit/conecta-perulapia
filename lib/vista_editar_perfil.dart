// Archivo: vista_editar_perfil.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'red.dart';
import 'selector_mapa.dart'; // Selector de mapa interactivo

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
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();

  double? _latitudSeleccionada;
  double? _longitudSeleccionada;

  bool _cargando = true;
  bool _guardando = false;

  File? _imagenLocal;
  String _fotoPerfilUrl = "";
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  Future<void> _cargarDatosActuales() async {
    try {
      final url = Uri.parse('$urlCentral/api/perfil/${widget.idUsuario}');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 5));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(utf8.decode(respuesta.bodyBytes));
        setState(() {
          _nombreCtrl.text = datos['nombre'] ?? '';
          _telefonoCtrl.text = datos['telefono'] ?? '';
          _correoCtrl.text = datos['correo'] ?? '';
          _direccionCtrl.text = datos['direccion'] ?? '';
          _fotoPerfilUrl = datos['foto_perfil'] ?? '';

          _latitudSeleccionada =
              double.tryParse(datos['latitud']?.toString() ?? '');
          _longitudSeleccionada =
              double.tryParse(datos['longitud']?.toString() ?? '');

          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Error al cargar: $e");
      setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarFoto() async {
    final XFile? fotoSeleccionada = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (fotoSeleccionada != null) {
      setState(() => _imagenLocal = File(fotoSeleccionada.path));

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$urlCentral/api/subir_foto_cliente'),
        );
        request.fields['id_cliente'] = widget.idUsuario.toString();
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
      final url = Uri.parse('$urlCentral/api/actualizar_contacto');
      final respuesta = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'id_usuario': widget.idUsuario,
          'nombre': _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'correo': _correoCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
          'latitud': _latitudSeleccionada,
          'longitud': _longitudSeleccionada,
        }),
      );

      if (respuesta.statusCode == 200) {
        final datosRes = json.decode(utf8.decode(respuesta.bodyBytes));
        if (!mounted) return;

        if (datosRes['status'] == 'ok' || datosRes['status'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Perfil y ubicación guardados permanentemente"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Error al guardar en el servidor."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint("🚨 Error al guardar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error de conexión con la central."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    bool tieneFotoRed =
        _fotoPerfilUrl.isNotEmpty && _fotoPerfilUrl != "Sin foto";
    String urlCompleta = "$urlCentral$_fotoPerfilUrl";

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
                    GestureDetector(
                      onTap: _cambiarFoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: _imagenLocal != null
                                ? FileImage(_imagenLocal!)
                                : (tieneFotoRed
                                    ? NetworkImage(urlCompleta)
                                    : null) as ImageProvider?,
                            child: (_imagenLocal == null && !tieneFotoRed)
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit,
                                size: 20, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre Completo",
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
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Correo Electrónico",
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _direccionCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Dirección de Entrega Exacta",
                        prefixIcon: const Icon(Icons.location_on),
                        border: const OutlineInputBorder(),
                        hintText: "Ej. Casa color azul frente al parque",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.map_rounded,
                              color: Color(0xFF1E3A8A), size: 28),
                          tooltip: "Marcar ubicación exacta en el mapa",
                          onPressed: () async {
                            final resultadoUbicacion = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SelectorMapaPantalla(
                                  initialLat: _latitudSeleccionada,
                                  initialLon: _longitudSeleccionada,
                                ),
                              ),
                            );

                            if (resultadoUbicacion != null) {
                              setState(() {
                                _direccionCtrl.text =
                                    resultadoUbicacion['direccion'];
                                _latitudSeleccionada =
                                    resultadoUbicacion['latitud'];
                                _longitudSeleccionada =
                                    resultadoUbicacion['longitud'];
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      onPressed: _guardando ? null : _guardarCambios,
                      child: _guardando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("GUARDAR CAMBIOS",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
