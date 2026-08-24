import 'package:flutter/material.dart';
import 'vista_editar_perfil.dart';
import 'vista_direcciones.dart';
import 'vista_historial.dart';

class CliPerfil extends StatelessWidget {
  final String nombreUsuario;
  const CliPerfil({super.key, required this.nombreUsuario});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF1E3A8A),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            nombreUsuario,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
            title: const Text("Editar Información"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VistaEditarPerfil(idUsuario: 1),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: Color(0xFF1E3A8A)),
            title: const Text("Mis Direcciones"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VistaDirecciones(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF1E3A8A)),
            title: const Text("Historial de Pedidos"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VistaHistorial()),
              );
            },
          ),
        ],
      ),
    );
  }
}
