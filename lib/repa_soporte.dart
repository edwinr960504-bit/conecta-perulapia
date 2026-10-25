import 'package:flutter/material.dart';
import 'acceso_soporte.dart';
import 'chat_soporte.dart'; // Importamos el chat maestro de la app

// ========================================================
// PANTALLA DE SOPORTE INTEGRADA PARA EL REPARTIDOR
// ========================================================
class RepaSoporte extends StatelessWidget {
  final int idRepartidor;
  const RepaSoporte({super.key, this.idRepartidor = 1});

  @override
  Widget build(BuildContext context) {
    const Color colorTema = Color(0xFF0F766E);
    final String remitente = "Repartidor #$idRepartidor";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.support_agent_rounded, size: 80, color: colorTema),
            const SizedBox(height: 15),
            const Text(
              "Centro de Soporte para Motoristas",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "¿Tienes problemas con una entrega, la ruta o tus pagos? Ingresa el código de rastreo del pedido para reportarlo.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 35),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccesoSoporte(
                        idUsuario: idRepartidor,
                        nombre: remitente,
                        rol: 'repartidor',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTema.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: colorTema, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Soporte por Pedido",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 4),
                            Text(
                                "Ingresa el código de rastreo para levantar reporte.",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatSoporte(
                        // ID negativo único para consultas generales del motorista
                        idPedido: -idRepartidor,
                        remitente: remitente,
                        canal: "admin_repartidor_personal",
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTema.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            color: colorTema, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Soporte Personal / General",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 4),
                            Text(
                                "Dudas sobre tu perfil, vehículo, ganancias o bloqueos.",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("ID de Motorista en Sistema",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Text("#$idRepartidor",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
