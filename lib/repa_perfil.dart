import 'package:flutter/material.dart';

class RepaPerfil extends StatefulWidget {
  final int idRepartidor;
  const RepaPerfil({super.key, required this.idRepartidor});

  @override
  State<RepaPerfil> createState() => _RepaPerfilState();
}

class _RepaPerfilState extends State<RepaPerfil> {
  // === DATOS SIMULADOS (Esto vendrá de tu base de datos en Python) ===
  final String nombre = "Edwin Castillo";
  final String dui = "00000000-0"; // Blindado

  // Campos editables
  final TextEditingController telefonoCtrl = TextEditingController(
    text: "7777-7777",
  );
  final TextEditingController correoCtrl = TextEditingController(
    text: "repartidor@email.com",
  );
  final TextEditingController colorVehiculoCtrl = TextEditingController(
    text: "",
  );
  final TextEditingController placaCtrl = TextEditingController(text: "");

  // Lógica de evolución de vehículo
  String tipoVehiculoOriginal =
      'Bicicleta'; // El que tiene registrado actualmente
  late String tipoVehiculoSeleccionado;

  @override
  void initState() {
    super.initState();
    tipoVehiculoSeleccionado = tipoVehiculoOriginal;
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
              // Aquí iría la lógica para borrar de la base de datos
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Cuenta eliminada"),
                  backgroundColor: Colors.red,
                ),
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
    // Verificamos si está intentando hacer el "Upgrade" a un vehículo motorizado
    bool requierePapeles =
        (tipoVehiculoSeleccionado == 'Motocicleta' ||
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
            // === 1. ZONA BLINDADA (Foto, Nombre, DUI) ===
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey,
                    // Aquí iría la NetworkImage de la foto real del motorista
                    child: Icon(Icons.person, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "🔒 Foto de seguridad bloqueada",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "DUI: $dui",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),

            // === 2. DATOS DE CONTACTO (Editables) ===
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
                      onPressed: () {}, // Lógica para abrir cámara/galería
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Tomar foto de Licencia"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {}, // Lógica para abrir cámara/galería
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Datos actualizados correctamente"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                "GUARDAR CAMBIOS",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
