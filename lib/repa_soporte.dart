import 'package:flutter/material.dart';
import 'chat_soporte.dart'; // Importamos el chat maestro de la app

class RepaSoporte extends StatelessWidget {
  final int idRepartidor;
  const RepaSoporte({super.key, this.idRepartidor = 1});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.support_agent_rounded,
            size: 80, color: Color(0xFF0F766E)),
        const SizedBox(height: 15),
        const Text(
          "Centro de Soporte para Motoristas",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Text(
          "¿Tienes problemas con una entrega, la ruta o tus pagos? Comunícate de inmediato con la central.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 30),

        // 1. SOPORTE POR PEDIDO ESPECÍFICO (CONECTADO AL CHAT)
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF0F766E),
              child: Icon(Icons.receipt_long_rounded, color: Colors.white),
            ),
            title: const Text("Soporte por Pedido",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text(
                "Reporta incidencias con la entrega, dirección o cliente."),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              final pedidoCtrl = TextEditingController();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Soporte de Pedido"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          "Ingresa el ID o número del pedido con el que tienes inconvenientes:",
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                          backgroundColor: const Color(0xFF0F766E)),
                      onPressed: () {
                        final idPed = int.tryParse(pedidoCtrl.text.trim()) ?? 0;
                        if (idPed > 0) {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatSoporte(
                                idPedido: idPed,
                                remitente: "Repartidor #$idRepartidor",
                                canal: "admin_repartidor",
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
          ),
        ),
        const SizedBox(height: 15),

        // 2. SOPORTE PERSONAL / GENERAL CON LA CENTRAL
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child:
                  Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
            ),
            title: const Text("Soporte Personal / General",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text(
                "Dudas sobre tu perfil, vehículo, ganancias o bloqueos."),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatSoporte(
                    idPedido:
                        -idRepartidor, // ID único negativo para consultas generales del motorista
                    remitente: "Repartidor #$idRepartidor",
                    canal: "admin_repartidor_personal",
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 30),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.grey),
          title: const Text("ID de Motorista en Sistema"),
          trailing: Text("#$idRepartidor",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
