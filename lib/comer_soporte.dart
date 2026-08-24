import 'package:flutter/material.dart';
import 'package:perulapia_connect/chat_soporte.dart';

// ========================================================
// PANTALLA DE SOPORTE INTEGRADA PARA EL COMERCIO
// ========================================================
class SoporteComercioPantalla extends StatelessWidget {
  final String idComercio;
  final String nombreComercio;

  const SoporteComercioPantalla({
    super.key,
    required this.idComercio,
    required this.nombreComercio,
  });

  @override
  Widget build(BuildContext context) {
    const Color colorTema = Color(0xFFD97706);

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
              "Centro de Soporte para Comercios",
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
                "¿Tienes problemas con tus ventas, pagos o el menú? Comunícate de inmediato con la central.",
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
                  final pedidoCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Soporte por Pedido"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                              "Ingresa el ID o número del pedido con el que tienes inconvenientes:",
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: pedidoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: "Número de Pedido",
                                border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancelar")),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: colorTema),
                          onPressed: () {
                            final idPed =
                                int.tryParse(pedidoCtrl.text.trim()) ?? 0;
                            if (idPed > 0) {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatSoporte(
                                    idPedido: idPed,
                                    remitente: nombreComercio,
                                    canal: "admin_comercio",
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text("Abrir Chat",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
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
                                "Reporta incidencias con la entrega, pagos o dirección.",
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
                  final int idComercioInt = int.tryParse(idComercio) ?? 1;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatSoporte(
                        idPedido: -idComercioInt,
                        remitente: nombreComercio,
                        canal: "admin_comercio_personal",
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
                            Text("Dudas sobre tu perfil, comisiones o cuenta.",
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
                    Text("Identidad en Sistema (Comercio)",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Text("COM-$idComercio",
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
