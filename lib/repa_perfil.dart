import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import 'red.dart';
import 'vista_login.dart';
import 'carrito_service.dart';

class RepaPerfil extends StatefulWidget {
  final int idRepartidor;
  const RepaPerfil({super.key, required this.idRepartidor});

  @override
  State<RepaPerfil> createState() => _RepaPerfilState();
}

class _RepaPerfilState extends State<RepaPerfil> {
  bool _cargando = true;
  bool _guardando = false;

  // === Datos Reales de la BD (Adiós a la clonación) ===
  String _nombre = "Cargando...";
  final String _dui = "Protegido"; // 🔥 Corregido: Agregado 'final'
  String _fotoPerfil = "";

  // === Campos editables originales tuyos ===
  final TextEditingController telefonoCtrl = TextEditingController();
  final TextEditingController correoCtrl = TextEditingController();
  final TextEditingController colorVehiculoCtrl = TextEditingController();
  final TextEditingController placaCtrl = TextEditingController();

  // Campo adicional para guardar la dirección en BD
  final TextEditingController direccionCtrl = TextEditingController();

  // === Lógica de evolución de vehículo (Mantenida intacta) ===
  String tipoVehiculoOriginal = 'Bicicleta';
  late String tipoVehiculoSeleccionado;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    tipoVehiculoSeleccionado = tipoVehiculoOriginal;
    _cargarPerfilReal();
  }

  // 🔥 DESCARGA LA IDENTIDAD ÚNICA DEL MOTORISTA
  Future<void> _cargarPerfilReal() async {
    try {
      final res = await http
          .get(Uri.parse('$urlCentral/api/perfil/${widget.idRepartidor}'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _nombre = data['nombre'] ?? 'Repartidor';
          telefonoCtrl.text =
              data['telefono'] == 'Sin teléfono' ? '' : data['telefono'];
          correoCtrl.text =
              data['correo'] == 'Sin correo' ? '' : data['correo'];
          direccionCtrl.text =
              data['direccion'] == 'Sin dirección' ? '' : data['direccion'];
          _fotoPerfil = data['foto_perfil'] ?? '';
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // 🔥 SUBIR FOTO DE PERFIL DE MANERA INDIVIDUAL
  Future<void> _cambiarFotoPerfil() async {
    final XFile? fotoSeleccionada = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (fotoSeleccionada != null) {
      setState(() => _cargando = true);
      try {
        var request = http.MultipartRequest(
            'POST', Uri.parse('$urlCentral/api/subir_foto_cliente'));
        request.fields['id_cliente'] = widget.idRepartidor.toString();
        request.files.add(
            await http.MultipartFile.fromPath('file', fotoSeleccionada.path));

        var res = await request.send();
        if (res.statusCode == 200) {
          if (!mounted) return; // 🔥 Corregido: Validación de context síncrono
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("📸 Foto de perfil actualizada"),
                backgroundColor: Colors.green),
          );
          _cargarPerfilReal();
        } else {
          setState(() => _cargando = false);
        }
      } catch (e) {
        debugPrint("Error al subir foto: $e");
        setState(() => _cargando = false);
      }
    }
  }

  // 🔥 GUARDAR LOS CAMBIOS EN EL SERVIDOR
  Future<void> _guardarCambios() async {
    setState(() => _guardando = true);
    try {
      final res = await http.post(
        Uri.parse('$urlCentral/api/actualizar_perfil/${widget.idRepartidor}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_usuario": widget.idRepartidor,
          "telefono": telefonoCtrl.text.trim(),
          "correo": correoCtrl.text.trim(),
          "direccion": direccionCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("✅ Datos actualizados correctamente"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error guardando datos: $e");
    }
    setState(() => _guardando = false);
  }

  String _obtenerUrlFoto() {
    if (_fotoPerfil.isEmpty || _fotoPerfil == 'Sin foto') return '';
    return _fotoPerfil.startsWith('http')
        ? _fotoPerfil
        : '$urlCentral$_fotoPerfil';
  }

  // Confirmación para eliminar cuenta
  void _mostrarDialogoEliminar() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar cuenta?"),
        content: const Text(
          "Esta acción es irreversible. Perderás tu historial de viajes y ganancias. ¿Estás seguro?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              CarritoService.limpiar();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPantalla()),
                (route) => false,
              );
            },
            child: const Text(
              "Sí, Eliminar",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(
            title: const Text("Mi Perfil"),
            backgroundColor: const Color(0xFF0F766E)),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F766E))),
      );
    }

    final urlFoto = _obtenerUrlFoto();
    bool requierePapeles = (tipoVehiculoSeleccionado == 'Motocicleta' ||
            tipoVehiculoSeleccionado == 'Vehículo') &&
        tipoVehiculoOriginal == 'Bicicleta';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil y Datos"),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 1. ZONA BLINDADA REAL (Foto conectada a BD) ===
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _cambiarFotoPerfil,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage:
                              urlFoto.isNotEmpty ? NetworkImage(urlFoto) : null,
                          child: urlFoto.isEmpty
                              ? const Icon(Icons.person,
                                  size: 80, color: Colors.white)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: Color(0xFF0F766E), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Toca la cámara para cambiar tu foto",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(
                    _nombre,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "DUI: $_dui",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text("ID Sistema: REPA-${widget.idRepartidor}",
                      style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 40),

            // === 2. DATOS DE CONTACTO ===
            const Text(
              "Datos de Contacto",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: telefonoCtrl,
              decoration: const InputDecoration(
                labelText: "Número de Teléfono",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: correoCtrl,
              decoration: const InputDecoration(
                labelText: "Correo Electrónico",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: direccionCtrl,
              decoration: const InputDecoration(
                  labelText: "Dirección Personal",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home)),
              maxLines: 2,
            ),
            const Divider(height: 40),

            // === 3. SECCIÓN DE VEHÍCULO Y EVOLUCIÓN ===
            const Text(
              "Mi Vehículo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: tipoVehiculoSeleccionado,
              decoration: const InputDecoration(
                labelText: "Tipo de Vehículo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.two_wheeler),
              ),
              items: ['Bicicleta', 'Motocicleta', 'Vehículo'].map((String val) {
                return DropdownMenuItem<String>(value: val, child: Text(val));
              }).toList(),
              onChanged: (nuevoValor) {
                if (nuevoValor != null) {
                  setState(() => tipoVehiculoSeleccionado = nuevoValor);
                }
              },
            ),

            // Detalles extra del vehículo (Color, Placas)
            if (tipoVehiculoSeleccionado != 'Bicicleta') ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: colorVehiculoCtrl,
                      decoration: const InputDecoration(
                        labelText: "Color",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: placaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nº Placa",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // === 4. EL UPGRADE (Sube de Bici a Moto/Carro) ===
            if (requierePapeles) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Actualización a Vehículo Motorizado",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Para activar este vehículo, necesitamos validar tus documentos oficiales.",
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Tomar foto de Licencia"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.credit_card),
                      label: const Text("Tomar foto de Tarjeta de Circulación"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),

            // === 5. BOTONES DE ACCIÓN ===
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text("GUARDAR CAMBIOS",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              onPressed: _guardando ? null : _guardarCambios,
            ),
            const SizedBox(height: 20),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.red,
              ),
              onPressed: _mostrarDialogoEliminar,
              child: const Text(
                "ELIMINAR MI CUENTA",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
