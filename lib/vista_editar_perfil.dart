import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'red.dart';
import 'vista_direcciones.dart';


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

  bool _cargando = true;
  bool _guardando = false;

  File? _imagenLocal;
  String _fotoPerfilUrl =
      ""; // 🔥 NUEVO: Memoria para la foto actual del servidor
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
          _fotoPerfilUrl = datos['foto_perfil'] ??
              ''; // 🔥 Jalamos la foto de la base de datos
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
        }),
      );


      if (respuesta.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Perfil actualizado exitosamente"),
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
    // 🔥 Lógica para saber si usamos la foto del servidor
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
                    // 🔥 CÍRCULO CON LA FOTO CARGADA Y EL LAPICITO
                    GestureDetector(
                      onTap: _cambiarFoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey.shade300,
                            // Si acaba de elegir una foto de galería, la muestra. Si no, muestra la del servidor.
                            backgroundImage: _imagenLocal != null
                                ? FileImage(_imagenLocal!)
                                : (tieneFotoRed
                                    ? NetworkImage(urlCompleta)
                                    : null) as ImageProvider?,
                            // Si no hay ninguna de las dos, muestra el ícono por defecto
                            child: (_imagenLocal == null && !tieneFotoRed)
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                          // EL LAPICITO EN LA ESQUINITA
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
                      decoration: const InputDecoration(
                        labelText: "Dirección de Entrega",
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
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
                    const SizedBox(height: 30),
                    const Divider(),

                    ListTile(
                      leading: const Icon(Icons.map, color: Color(0xFF1E3A8A)),
                      title: const Text("Ver Mi Dirección",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Revisa dónde llegarán tus pedidos"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VistaDirecciones(
                              idUsuario: widget.idUsuario,
                              direccionActual: _direccionCtrl.text,
                            ),
                          ),
                        ).then((_) => _cargarDatosActuales());
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
