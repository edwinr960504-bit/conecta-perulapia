import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'carrito_service.dart';

class CliCarrito extends StatefulWidget {
  final int idComercio;
  final int idCliente; // 🔥 Atrapa la identidad real del consumidor
  const CliCarrito({
    super.key,
    required this.idComercio,
    required this.idCliente,
  });

  @override
  State<CliCarrito> createState() => _CliCarritoState();
}

class _CliCarritoState extends State<CliCarrito> {
  String metodoPago = "Efectivo";
  bool _procesandoPedido = false;

  Future<Position?> _obtenerUbicacionActual() async {
    try {
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) return null;
      }
      if (permiso == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Tu Pedido",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
              IconButton(
                icon:
                    const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
                onPressed: () {
                  CarritoService.limpiar();
                  Navigator.pop(context, false);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CarritoService.items.isEmpty
                ? const Center(
                    child: Text("El carrito está vacío",
                        style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.separated(
                    itemCount: CarritoService.items.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, i) {
                      final id = CarritoService.items.keys.toList()[i];
                      final item = CarritoService.items[id];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['nombre'] ?? 'Producto',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Cantidad: ${item['cantidad']}",
                            style: TextStyle(color: Colors.grey[600])),
                        trailing: Text(
                            "\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      );
                    },
                  ),
          ),
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total a Pagar:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("\$${CarritoService.obtenerTotal().toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Método de Pago",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: metodoPago,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFF1E3A8A)),
                items: const [
                  DropdownMenuItem(
                      value: "Efectivo",
                      child: Row(children: [
                        Icon(Icons.money, color: Colors.green),
                        SizedBox(width: 10),
                        Text("Efectivo")
                      ])),
                  DropdownMenuItem(
                      value: "Chivo Wallet",
                      child: Row(children: [
                        Icon(Icons.currency_bitcoin, color: Colors.orange),
                        SizedBox(width: 10),
                        Text("Chivo Wallet (Bitcoin/USD)")
                      ])),
                  DropdownMenuItem(
                      value: "Tarjeta",
                      child: Row(children: [
                        Icon(Icons.credit_card, color: Colors.blue),
                        SizedBox(width: 10),
                        Text("Tarjeta")
                      ])),
                ],
                onChanged: (v) => setState(() => metodoPago = v!),
              ),
            ),
          ),
          if (metodoPago == "Chivo Wallet")
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange)),
                child: const Row(children: [
                  Icon(Icons.qr_code_scanner, color: Colors.orange, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          "Al confirmar, el motorista presentará el código QR para la transferencia.",
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.bold))),
                ]),
              ),
            ),
          const SizedBox(height: 25),

          // 🔥 BOTÓN INTELIGENTE: ENVÍA EL PEDIDO CON EL ID REAL DEL CLIENTE
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    _procesandoPedido ? Colors.grey : const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 5),
            onPressed: (CarritoService.items.isEmpty || _procesandoPedido)
                ? null
                : () async {
                    setState(() => _procesandoPedido = true);

                    final mensajero = ScaffoldMessenger.of(context);
                    final navegador = Navigator.of(context);

                    mensajero.showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 15),
                            Text("Detectando tu ubicación exacta..."),
                          ],
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    Position? pos = await _obtenerUbicacionActual();
                    double latActual = pos?.latitude ?? 13.7333;
                    double lonActual = pos?.longitude ?? -89.1167;

                    // 🔥 AQUÍ ESTÁ EL CAMBIO CLAVE: Se usa widget.idCliente en lugar del '1'
                    bool exito = await CarritoService.confirmarPedido(
                      widget.idCliente,
                      widget.idComercio,
                      metodoPago,
                      1.5,
                      latActual,
                      lonActual,
                    );

                    if (!context.mounted) return;
                    setState(() => _procesandoPedido = false);

                    if (exito) {
                      navegador.pop(true);
                      mensajero.showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 10),
                          Text("¡Pedido enviado a cocina!",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16))
                        ]),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.only(
                            bottom: 20, left: 20, right: 20),
                      ));
                    } else {
                      mensajero.showSnackBar(SnackBar(
                        content:
                            const Text("Error de conexión. Intenta de nuevo."),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
            child: _procesandoPedido
                ? const Text("UBICANDO Y ENVIANDO...",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1))
                : const Text("CONFIRMAR COMPRA",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }
}
