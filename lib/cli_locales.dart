import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'cli_menu_local.dart';
import 'red.dart';

class CliLocales extends StatefulWidget {
  final int idCliente; // 🔥 NUEVO: Recibe la identidad real del consumidor
  final VoidCallback onIrARastreo;
  final VoidCallback onActualizar;
  const CliLocales({
    super.key,
    required this.idCliente,
    required this.onIrARastreo,
    required this.onActualizar,
  });

  @override
  State<CliLocales> createState() => _CliLocalesState();
}

class _CliLocalesState extends State<CliLocales> {
  String _textoBusqueda = "";
  List<dynamic> _comercios = [];
  bool _cargando = true;
  Timer? _timerLocales;

  @override
  void initState() {
    super.initState();
    _cargarComercios();
    _timerLocales = Timer.periodic(const Duration(seconds: 5), (timer) {
      _cargarComerciosSilencioso();
    });
  }

  @override
  void dispose() {
    _timerLocales?.cancel();
    super.dispose();
  }

  Future<void> _cargarComercios() async {
    if (mounted) setState(() => _cargando = true);
    await _cargarComerciosSilencioso();
  }

  Future<void> _cargarComerciosSilencioso() async {
    try {
      final url = Uri.parse('$urlCentral/comercios_activos');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 5));
      if (respuesta.statusCode == 200) {
        if (mounted) {
          setState(() {
            _comercios = json.decode(utf8.decode(respuesta.bodyBytes));
            _cargando = false;
          });
        }
      }
    } catch (e) {
      debugPrint("🚨 Error silencioso cargando comercios: $e");
    }
  }

  String _obtenerUrlImagen(String ruta) {
    if (ruta.isEmpty || ruta == 'Sin foto' || ruta == 'Sin logo') return '';
    if (ruta.startsWith('http')) return ruta;
    if (ruta.startsWith('/')) {
      return '$urlCentral$ruta';
    }
    return '$urlCentral/$ruta';
  }

  Widget _iconoLocalPorDefecto() {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)
        ],
      ),
      child: const Icon(Icons.storefront, color: Color(0xFF1E3A8A), size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comerciosFiltrados = _comercios.where((c) {
      final n =
          (c['nombre'] ?? c['nombre_local'] ?? '').toString().toLowerCase();
      return n.contains(_textoBusqueda.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _textoBusqueda = val),
            decoration: InputDecoration(
              labelText: "¿Qué se te antoja hoy?",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        Expanded(
          child: _cargando && _comercios.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargarComercios,
                  child: comerciosFiltrados.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 50),
                            Center(
                              child: Text(
                                "No hay locales abiertos en este momento.",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: comerciosFiltrados.length,
                          itemBuilder: (context, index) {
                            final comercio = comerciosFiltrados[index];
                            final String logoCrudo = comercio['logo'] ?? '';
                            final String logoFinal =
                                _obtenerUrlImagen(logoCrudo);

                            // Fotos dinámicas del menú del local para armar el fondo collage
                            final List<dynamic> fotosProds =
                                comercio['fotos_productos'] ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  children: [
                                    // 🎨 FONDO COLLAGE CON LOS PLATOS TÍPICOS DEL LOCAL
                                    Positioned.fill(
                                      child: fotosProds.isNotEmpty
                                          ? Row(
                                              children: fotosProds.map((foto) {
                                                return Expanded(
                                                  child: Image.network(
                                                    _obtenerUrlImagen(
                                                        foto.toString()),
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            Container(
                                                                color: Colors
                                                                    .grey[200]),
                                                  ),
                                                );
                                              }).toList(),
                                            )
                                          : Container(
                                              color: Colors.grey.shade100),
                                    ),

                                    // 🛡️ CAPA TRANSLÚCIDA (OVERLAY) ORIGINAL
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.white
                                            .withValues(alpha: 0.32),
                                      ),
                                    ),

                                    // 📋 CONTENIDO PRINCIPAL DE LA TARJETA
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CliMenuLocal(
                                              idComercio:
                                                  comercio['id'].toString(),
                                              nombreComercio:
                                                  comercio['nombre'] ?? 'Local',
                                              idCliente: widget
                                                  .idCliente, // 🔥 SE LE PASA EL ID AL MENÚ CORRECTAMENTE
                                            ),
                                          ),
                                        ).then((pagado) {
                                          if (pagado == true) {
                                            widget.onIrARastreo();
                                          } else {
                                            widget.onActualizar();
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            // LOGO DEL LOCAL
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: logoFinal.isNotEmpty
                                                  ? Image.network(
                                                      logoFinal,
                                                      width: 75,
                                                      height: 75,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          _iconoLocalPorDefecto(),
                                                    )
                                                  : _iconoLocalPorDefecto(),
                                            ),
                                            const SizedBox(width: 14),

                                            // TEXTOS CON MÁXIMO GROSOR Y RESPLANDOR BLANCO
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    comercio['nombre'] ??
                                                        comercio[
                                                            'nombre_local'] ??
                                                        'Local',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight
                                                          .w900, // Súper negrita
                                                      color: Color.fromARGB(
                                                          255,
                                                          12,
                                                          0,
                                                          0), // Negro puro
                                                      shadows: [
                                                        Shadow(
                                                          offset: Offset(0, 0),
                                                          blurRadius: 3.0,
                                                          color: Colors
                                                              .white, // Halo blanco alrededor
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    comercio['direccion'] ??
                                                        'Comercio General',
                                                    style: const TextStyle(
                                                      color: Color(
                                                          0xDD000000), // Tono más oscuro y firme
                                                      fontSize: 15,
                                                      fontWeight: FontWeight
                                                          .w800, // Letra gruesa
                                                      shadows: [
                                                        Shadow(
                                                          offset: Offset(0, 0),
                                                          blurRadius: 2.5,
                                                          color: Colors
                                                              .white, // Halo blanco para la dirección
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // FLECHA DE ACCESO
                                            const Icon(
                                              Icons.arrow_forward_ios,
                                              color: Color(0xFF1E3A8A),
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
