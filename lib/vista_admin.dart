import 'package:flutter/material.dart';

// Importamos los submódulos de la central asignando un prefijo a soporte para evitar choques
import 'admin_radar.dart';
import 'admin_directorio.dart';
import 'admin_finanzas.dart';
import 'admin_auditoria.dart';
import 'admin_publicidad.dart';
import 'admin_soporte.dart' as soporte;

class VistaAdmin extends StatefulWidget {
  const VistaAdmin({super.key});

  @override
  State<VistaAdmin> createState() => _VistaAdminState();
}

class _VistaAdminState extends State<VistaAdmin> {
  void _abrirModulo(BuildContext context, Widget pantallaDestino) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => pantallaDestino));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Central de Mando - Conecta",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          children: [
            _BotonMenuCentral(
              titulo: "Radar de Pedidos",
              subtitulo: "Seguimiento en vivo",
              icono: Icons.radar,
              color: Colors.blue.shade800,
              onTap: () => _abrirModulo(context, const AdminRadar()),
            ),
            _BotonMenuCentral(
              titulo: "Cuentas y Usuarios",
              subtitulo: "Aprobación de expedientes",
              icono: Icons.people_alt,
              color: Colors.indigo.shade700,
              onTap: () => _abrirModulo(context, const AdminDirectorio()),
            ),
            _BotonMenuCentral(
              titulo: "Finanzas y Caja",
              subtitulo: "Cortes e ingresos",
              icono: Icons.attach_money,
              color: Colors.green.shade700,
              onTap: () => _abrirModulo(context, const AdminFinanzas()),
            ),
            _BotonMenuCentral(
              titulo: "Auditoría de Red",
              subtitulo: "Caja negra y seguridad",
              icono: Icons.security,
              color: Colors.purple.shade700,
              onTap: () => _abrirModulo(context, const AdminAuditoria()),
            ),
            _BotonMenuCentral(
              titulo: "Publicidad Global",
              subtitulo: "Alertas y banners masivos",
              icono: Icons.campaign,
              color: Colors.orange.shade800,
              onTap: () => _abrirModulo(context, const AdminPublicidad()),
            ),
            _BotonMenuCentral(
              titulo: "Central de Soporte",
              subtitulo: "Resolución de problemas",
              icono: Icons.support_agent,
              color: Colors.teal.shade700,
              onTap: () => _abrirModulo(context, const soporte.AdminSoporte()),
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta de diseño para el menú
class _BotonMenuCentral extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _BotonMenuCentral({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                radius: 24,
                child: Icon(icono, color: color, size: 28),
              ),
              const Spacer(),
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitulo,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
