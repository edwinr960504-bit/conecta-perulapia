import 'package:flutter/material.dart';

class CliBurbujaFlotante extends StatefulWidget {
  final IconData icono;
  final Color color;
  final VoidCallback onTap;
  final int cantidad;

  const CliBurbujaFlotante({
    super.key,
    required this.icono,
    required this.color,
    required this.onTap,
    this.cantidad = 0,
  });

  @override
  State<CliBurbujaFlotante> createState() => _CliBurbujaFlotanteState();
}

class _CliBurbujaFlotanteState extends State<CliBurbujaFlotante> {
  double x = 20.0;
  double y = 500.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          x += d.delta.dx;
          y += d.delta.dy;
        }),
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                // Aquí está el cambio:
                // Usamos directamente widget.color, así que si le mandas Colors.green,
                // será verde sin importar la cantidad.
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
              child: Icon(widget.icono, color: Colors.white, size: 30),
            ),

            // El circulito rojo del número solo aparece si cantidad > 0
            if (widget.cantidad > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${widget.cantidad}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
