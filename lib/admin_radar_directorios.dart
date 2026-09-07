// ========================================================
// ARCHIVO: admin_radar_directorios.dart
// PROPÓSITO: Barra inferior y menús de Flota y Locales
// ========================================================
import 'package:flutter/material.dart';
import 'red.dart'; // Para urlCentral

class AdminRadarDirectorios extends StatelessWidget {
  final List<dynamic> flota;
  final List<dynamic> comercios;

  const AdminRadarDirectorios({
    super.key,
    required this.flota,
    required this.comercios,
  });

  void _mostrarListaFlota(BuildContext context) {
    final activos = flota.where((c) => c['activo_app'] == true).toList();
    final inactivos = flota.where((c) => c['activo_app'] == false).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _PlantillaListado(
          titulo: "Control de Motoristas",
          colorTema: Colors.blue.shade800,
          activos: activos,
          inactivos: inactivos,
          iconoTipo: Icons.two_wheeler,
          etiquetaActivo: "En línea",
        );
      },
    );
  }

  void _mostrarListaLocales(BuildContext context) {
    final activos = comercios.where((c) => c['activo_app'] == true).toList();
    final inactivos = comercios.where((c) => c['activo_app'] == false).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _PlantillaListado(
          titulo: "Control de Negocios",
          colorTema: Colors.orange.shade800,
          activos: activos,
          inactivos: inactivos,
          iconoTipo: Icons.storefront,
          etiquetaActivo: "Abierto",
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 15,
      bottom: 20,
      child: Row(
        children: [
          FloatingActionButton.extended(
            heroTag: "btnFlota",
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.two_wheeler),
            label: Text(
                "${flota.where((c) => c['activo_app'] == true).length} Flota"),
            onPressed: () => _mostrarListaFlota(context),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: "btnLocales",
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.storefront),
            label: Text(
                "${comercios.where((c) => c['activo_app'] == true).length} Locales"),
            onPressed: () => _mostrarListaLocales(context),
          ),
        ],
      ),
    );
  }
}

// 🔥 PLANTILLA PARA REUTILIZARLA EN AMBAS LISTAS
class _PlantillaListado extends StatelessWidget {
  final String titulo;
  final Color colorTema;
  final List<dynamic> activos;
  final List<dynamic> inactivos;
  final IconData iconoTipo;
  final String etiquetaActivo;

  const _PlantillaListado({
    required this.titulo,
    required this.colorTema,
    required this.activos,
    required this.inactivos,
    required this.iconoTipo,
    required this.etiquetaActivo,
  });

  @override
  Widget build(BuildContext context) {
    final todos = [...activos, ...inactivos];
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.only(top: 15),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 15),
          Text(titulo,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: colorTema)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgeConteoDirectorio(
                  label: "Activos",
                  cantidad: activos.length,
                  color: Colors.green),
              const SizedBox(width: 15),
              _BadgeConteoDirectorio(
                  label: "Inactivos",
                  cantidad: inactivos.length,
                  color: Colors.grey),
            ],
          ),
          const Divider(height: 25),
          Expanded(
            child: todos.isEmpty
                ? const Center(
                    child: Text("No hay registros en esta categoría"))
                : ListView.builder(
                    itemCount: todos.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (ctx, i) {
                      final c = todos[i];
                      final foto = c['foto']?.toString() ?? '';
                      final tieneFoto = foto.isNotEmpty &&
                          foto != 'Sin foto' &&
                          foto != 'Sin logo';
                      final bool estaActivo = c['activo_app'] ?? false;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    colorTema.withValues(alpha: 0.1),
                                backgroundImage: tieneFoto
                                    ? NetworkImage("$urlCentral$foto")
                                    : null,
                                child: !tieneFoto
                                    ? Icon(iconoTipo, color: colorTema)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color:
                                        estaActivo ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(c['nombre'] ?? 'Desconocido',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Tel: ${c['telefono'] ?? 'N/A'}"),
                          trailing: Chip(
                            label: Text(
                              estaActivo ? etiquetaActivo : "Inactivo",
                              style: TextStyle(
                                  color: estaActivo
                                      ? Colors.green.shade800
                                      : Colors.grey.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: estaActivo
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

class _BadgeConteoDirectorio extends StatelessWidget {
  final String label;
  final int cantidad;
  final Color color;

  const _BadgeConteoDirectorio(
      {required this.label, required this.cantidad, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text("$cantidad $label",
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
