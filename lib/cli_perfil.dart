import 'package:flutter/material.dart';
import 'vista_editar_perfil.dart';
import 'vista_historial.dart';
import 'red.dart';

class CliPerfil extends StatelessWidget {
  final String nombreUsuario;
  final int idCliente;
  final String fotoPerfil;

  const CliPerfil(
      {super.key,
      required this.nombreUsuario,
      required this.idCliente,
      this.fotoPerfil = "Sin foto"});

  @override
  Widget build(BuildContext context) {
    String urlImagen = (fotoPerfil != "Sin foto" && fotoPerfil.isNotEmpty)
        ? "$urlCentral$fotoPerfil"
        : "";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: CircleAvatar(
              radius: 55,
              backgroundColor: const Color(0xFF1E3A8A),
              backgroundImage:
                  urlImagen.isNotEmpty ? NetworkImage(urlImagen) : null,
              child: urlImagen.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
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
                  builder: (context) => VistaEditarPerfil(idUsuario: idCliente),
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
                MaterialPageRoute(
                    builder: (context) => VistaHistorial(idCliente: idCliente)),
              );
            },
          ),
        ],
      ),
    );
  }
}
