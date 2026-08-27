import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import 'red.dart';

class VistaAjustesLocal extends StatefulWidget {
  final String idComercio;
  final String nombreActual;

  const VistaAjustesLocal({
    super.key,
    required this.idComercio,
    required this.nombreActual,
  });

  @override
  State<VistaAjustesLocal> createState() => _VistaAjustesLocalState();
}

class _VistaAjustesLocalState extends State<VistaAjustesLocal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _horariosCtrl = TextEditingController();

  bool _aceptaBitcoin = true;
  String _planPago = "Comisión 10%";
  bool _guardando = false;

  File? _logoLocal;
  String? _urlLogoRemoto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreActual);
    _cargarDatosActualesComercio();
  }

  // 🔥 CARGA DIRECTA DESDE EL ENDPOINT EXCLUSIVO DEL COMERCIO
  Future<void> _cargarDatosActualesComercio() async {
    try {
      final url =
          Uri.parse('$urlCentral/api/comercio/perfil/${widget.idComercio}');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data['status'] == 'ok') {
          setState(() {
            _direccionCtrl.text = data['direccion'] ?? '';
            _horariosCtrl.text = data['horarios'] ?? '';
            if (data['logo'] != null &&
                data['logo'].toString().isNotEmpty &&
                data['logo'] != 'Sin logo') {
              final String logoPath = data['logo'];
              _urlLogoRemoto = logoPath.startsWith('http')
                  ? logoPath
                  : '$urlCentral$logoPath';
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando perfil del comercio: $e");
    }
  }

  Future<void> _cambiarLogo() async {
    final XFile? fotoSeleccionada = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (fotoSeleccionada != null) {
      setState(() => _logoLocal = File(fotoSeleccionada.path));

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$urlCentral/subir_foto_comercio/'),
        );
        request.fields['id_comercio'] = widget.idComercio.toString();
        request.files.add(
          await http.MultipartFile.fromPath('file', fotoSeleccionada.path),
        );

        var res = await request.send();
        if (res.statusCode == 200) {
          var responseData = await res.stream.bytesToString();
          var jsonData = json.decode(responseData);
          String rutaServidor = jsonData['url'] ?? '';

          if (!mounted) return;

          setState(() {
            if (rutaServidor.isNotEmpty) {
              _urlLogoRemoto = rutaServidor.startsWith('http')
                  ? rutaServidor
                  : '$urlCentral$rutaServidor';
            }
            _logoLocal =
                null; // Limpiamos la local para priorizar la red sincronizada
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("📸 Logo del local actualizado y guardado"),
              backgroundColor: Colors.green,
            ),
          );
          _cargarDatosActualesComercio();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al subir la foto al servidor"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error subiendo logo: $e");
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final url = Uri.parse('$urlCentral/api/comercio/actualizar_perfil');
      final respuesta = await http.post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: json.encode({
          'id_comercio': widget.idComercio,
          'nombre_local': _nombreCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
          'horarios': _horariosCtrl.text.trim(),
          'acepta_bitcoin': _aceptaBitcoin,
          'plan_pago': _planPago,
        }),
      );

      if (respuesta.statusCode == 200 || respuesta.statusCode == 404) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Ajustes guardados correctamente"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
            context, true); // Retornamos true para refrescar la vista principal
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
        title: const Text("Configuración del Negocio"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: _cambiarLogo,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(15),
                          image: _logoLocal != null
                              ? DecorationImage(
                                  image: FileImage(_logoLocal!),
                                  fit: BoxFit.cover,
                                )
                              : (_urlLogoRemoto != null
                                  ? DecorationImage(
                                      image: NetworkImage(_urlLogoRemoto!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: (_logoLocal == null && _urlLogoRemoto == null)
                            ? const Icon(Icons.store,
                                size: 60, color: Colors.white)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E3A8A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "Toca para cambiar el logo",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 30),
              const Text("Datos Públicos",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: "Nombre del Local",
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v!.isEmpty ? "El nombre es obligatorio" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _direccionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Dirección Exacta",
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                  hintText: "Ej. Frente al parque municipal",
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _horariosCtrl,
                decoration: const InputDecoration(
                  labelText: "Horario de Atención",
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                  hintText: "Ej. Lunes a Domingo: 8:00 AM - 9:00 PM",
                ),
              ),
              const Divider(height: 40, thickness: 2),
              const Text("Planes y Formas de Pago",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
              const SizedBox(height: 15),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: SwitchListTile(
                  secondary:
                      const Icon(Icons.currency_bitcoin, color: Colors.orange),
                  title: const Text("Aceptar pagos en Bitcoin"),
                  subtitle: const Text("A través de Chivo Wallet"),
                  value: _aceptaBitcoin,
                  activeThumbColor: Colors.orange,
                  onChanged: (v) => setState(() => _aceptaBitcoin = v),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _planPago,
                decoration: const InputDecoration(
                  labelText: "Plan de Suscripción",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.star, color: Colors.amber),
                ),
                items: ["Comisión 10%", "Pago Mensual Fijo", "Plan Premium"]
                    .map((String v) {
                  return DropdownMenuItem(value: v, child: Text(v));
                }).toList(),
                onChanged: (val) {
                  setState(() => _planPago = val!);
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _guardando ? null : _guardarCambios,
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
