import 'package:flutter/material.dart';

class VistaDirecciones extends StatefulWidget {
  const VistaDirecciones({super.key});

  @override
  State<VistaDirecciones> createState() => _VistaDireccionesState();
}

class _VistaDireccionesState extends State<VistaDirecciones> {
  // Lista de direcciones (puedes empezar con una vacía o dejar la que tenías)
  final List<Map<String, String>> _direcciones = [
    {
      "titulo": "Casa",
      "detalle": "Centro de San Bartolomé Perulapía, frente al parque",
      "referencia": "Casa de portón negro",
    },
  ];

  // Función para abrir la ventanita y agregar la dirección real
  void _mostrarFormulario() {
    final TextEditingController tituloCtrl = TextEditingController();
    final TextEditingController detalleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Dirección"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl,
              decoration: const InputDecoration(
                labelText: "Alias (ej. Trabajo, Casa)",
              ),
            ),
            TextField(
              controller: detalleCtrl,
              decoration: const InputDecoration(labelText: "Dirección exacta"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            onPressed: () {
              if (tituloCtrl.text.isNotEmpty && detalleCtrl.text.isNotEmpty) {
                setState(() {
                  _direcciones.add({
                    "titulo": tituloCtrl.text,
                    "detalle": detalleCtrl.text,
                    "referencia": "Sin referencia",
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Direcciones"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _direcciones.isEmpty
          ? const Center(child: Text("No tienes direcciones guardadas."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _direcciones.length,
              itemBuilder: (context, index) {
                final dir = _direcciones[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Color(0xFF1E3A8A),
                      size: 30,
                    ),
                    title: Text(
                      dir['titulo']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(dir['detalle']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          setState(() => _direcciones.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A8A),
        onPressed: _mostrarFormulario,
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: const Text(
          "Nueva Dirección",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
