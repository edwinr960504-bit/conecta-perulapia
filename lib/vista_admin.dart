import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart';

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
  int _pedidosActivos = 0;
  int _cuentasPendientes = 0;
  int _ticketsPendientes = 0;
  Timer? _timerNotificaciones;

  @override
  void initState() {
    super.initState();
    _obtenerAlertasGlobales();
    // 🔥 LATIDO: Actualiza las 3 notificaciones cada 4 segundos
    _timerNotificaciones = Timer.periodic(const Duration(seconds: 4), (_) {
      _obtenerAlertasGlobales();
    });
  }

  @override
  void dispose() {
    _timerNotificaciones?.cancel();
    super.dispose();
  }

  Future<void> _obtenerAlertasGlobales() async {
    try {
      final res =
          await http.get(Uri.parse('$urlCentral/api/admin/alertas_dashboard'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _pedidosActivos = data['pedidos_activos'] ?? 0;
          _cuentasPendientes = data['cuentas_pendientes'] ?? 0;
          _ticketsPendientes = data['tickets_abiertos'] ?? 0;
        });
      }
    } catch (e) {
      // Falla silenciosa
    }
  }

  void _abrirModulo(BuildContext context, Widget pantallaDestino) {
    Navigator.push(
            context, MaterialPageRoute(builder: (context) => pantallaDestino))
        .then((_) {
      _obtenerAlertasGlobales();
    });
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
              notificaciones: _pedidosActivos, // 🔥 ALERTA DE PEDIDOS
              onTap: () => _abrirModulo(context, const AdminRadar()),
            ),
            _BotonMenuCentral(
              titulo: "Cuentas y Usuarios",
              subtitulo: "Aprobación de expedientes",
              icono: Icons.people_alt,
              color: Colors.indigo.shade700,
              notificaciones: _cuentasPendientes, // 🔥 ALERTA DE CUENTAS
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
              subtitulo: "Alertas masivas",
              icono: Icons.campaign,
              color: Colors.orange.shade800,
              onTap: () => _abrirModulo(context, const AdminPublicidad()),
            ),
            _BotonMenuCentral(
              titulo: "Central de Soporte",
              subtitulo: "Chats y resolución",
              icono: Icons.support_agent,
              color: Colors.teal.shade700,
              notificaciones: _ticketsPendientes, // 🔥 ALERTA DE TICKETS
              onTap: () => _abrirModulo(context, const soporte.AdminSoporte()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonMenuCentral extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;
  final int notificaciones;

  const _BotonMenuCentral({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.onTap,
    this.notificaciones = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        ),
        // 🔥 GLOBO ROJO ESTILO WHATSAPP 🔥
        if (notificaciones > 0)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child: Text(
                notificaciones > 9 ? "9+" : "$notificaciones",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}
