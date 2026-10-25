// Archivo: chat_pedido.dart
import 'package:flutter/material.dart';
import 'api_http.dart' as http;
import 'package:image_picker/image_picker.dart'; // 🔥 Para elegir fotos o cámara
import 'dart:convert';
import 'dart:async';
import 'red.dart';

class ChatPedidoScreen extends StatefulWidget {
  final int idPedido;
  final String remitente; // "Motorista", "Cliente", o "Local"
  final String canal; // 'motorista_comercio' o 'motorista_consumidor'
  final String nombreDestino;

  const ChatPedidoScreen({
    super.key,
    required this.idPedido,
    required this.remitente,
    required this.canal,
    required this.nombreDestino,
  });

  @override
  State<ChatPedidoScreen> createState() => _ChatPedidoScreenState();
}

class _ChatPedidoScreenState extends State<ChatPedidoScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<dynamic> _mensajes = [];
  Timer? _timerRecarga;
  bool _cargando = true;
  bool _enviandoArchivo = false;

  @override
  void initState() {
    super.initState();
    _cargarMensajes();
    _timerRecarga = Timer.periodic(
        const Duration(seconds: 3), (_) => _cargarMensajesSilencioso());
  }

  @override
  void dispose() {
    _timerRecarga?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    await _cargarMensajesSilencioso();
    if (mounted) setState(() => _cargando = false);
    _bajarScroll();
  }

  Future<void> _cargarMensajesSilencioso() async {
    try {
      final url = Uri.parse(
          '$urlCentral/api/chat/historial/${widget.idPedido}?canal=${widget.canal}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (mounted) {
          final int cantidadAnterior = _mensajes.length;
          setState(() {
            _mensajes = data['mensajes'] ?? [];
          });
          if (_mensajes.length > cantidadAnterior) {
            _bajarScroll();
          }
        }
      }
    } catch (_) {}
  }

  void _bajarScroll() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 🔥 ENVÍO DE TEXTO NORMAL
  Future<void> _enviarTexto() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty) return;

    _msgCtrl.clear();
    setState(() {
      _mensajes.add({
        "remitente": widget.remitente,
        "mensaje": texto,
        "tipo": "texto",
        "canal": widget.canal,
      });
    });
    _bajarScroll();

    try {
      final url = Uri.parse('$urlCentral/api/chat/enviar_mensaje');
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_pedido": widget.idPedido,
          "remitente": widget.remitente,
          "mensaje": texto,
          "tipo": "texto",
          "canal": widget.canal
        }),
      );
      _cargarMensajesSilencioso();
    } catch (_) {}
  }

  // 🔥 ENVÍO DE FOTOS (CÁMARA O GALERÍA)
  Future<void> _seleccionarYEnviarFoto(ImageSource origen) async {
    try {
      final picker = ImagePicker();
      final XFile? imagen =
          await picker.pickImage(source: origen, imageQuality: 70);

      if (imagen == null) return;

      setState(() => _enviandoArchivo = true);

      // Leemos los bytes y los convertimos a Base64 para subirlos de forma segura por API HTTP
      final bytes = await imagen.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse('$urlCentral/api/chat/enviar_archivo');
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_pedido": widget.idPedido,
          "remitente": widget.remitente,
          "archivo_base64": base64Image,
          "tipo": "imagen",
          "canal": widget.canal
        }),
      );

      if (res.statusCode == 200) {
        _cargarMensajesSilencioso();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Error al enviar la imagen"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoArchivo = false);
    }
  }

  // 📷 MENÚ PARA ELEGIR CÁMARA O GALERÍA
  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Tomar una foto"),
              onTap: () {
                Navigator.pop(context);
                _seleccionarYEnviarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text("Elegir de la galería"),
              onTap: () {
                Navigator.pop(context);
                _seleccionarYEnviarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color colorTema = widget.canal == 'motorista_comercio'
        ? Colors.orange.shade800
        : Colors.blue.shade800;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.nombreDestino),
        backgroundColor: colorTema,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargando
                ? Center(child: CircularProgressIndicator(color: colorTema))
                : _mensajes.isEmpty
                    ? const Center(
                        child: Text("Envía el primer mensaje o una foto...",
                            style: TextStyle(color: Colors.grey, fontSize: 14)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _mensajes.length,
                        itemBuilder: (context, index) {
                          final msg = _mensajes[index];
                          final bool soyYo =
                              msg['remitente'] == widget.remitente;
                          final bool esSistema =
                              msg['remitente'] == 'Sistema Automático';
                          final String tipo = msg['tipo'] ?? 'texto';

                          if (esSistema) {
                            return Center(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.amber.shade300)),
                                child: Text(msg['mensaje'],
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                        fontSize: 12)),
                              ),
                            );
                          }

                          return Align(
                            alignment: soyYo
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: soyYo
                                    ? (widget.canal == 'motorista_comercio'
                                        ? Colors.orange.shade100
                                        : Colors.blue.shade100)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!soyYo)
                                    Text(msg['remitente'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: colorTema)),
                                  if (!soyYo) const SizedBox(height: 3),

                                  // RENDERIZAR IMAGEN O TEXTO SEGÚN EL TIPO
                                  tipo == 'imagen'
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            msg['mensaje']
                                                    .toString()
                                                    .startsWith('http')
                                                ? msg['mensaje']
                                                : "$urlCentral${msg['mensaje']}",
                                            width: 200,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return const SizedBox(
                                                width: 200,
                                                height: 200,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2)),
                                              );
                                            },
                                          ),
                                        )
                                      : Text(msg['mensaje'] ?? '',
                                          style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          if (_enviandoArchivo)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("Enviando archivo...",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                ],
              ),
            ),

          // BARRA DE TEXTO INFERIOR CON BOTÓN DE CÁMARA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 5, offset: Offset(0, -2))
            ]),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt, color: colorTema),
                  onPressed: _enviandoArchivo ? null : _mostrarOpcionesFoto,
                  tooltip: "Enviar foto",
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorTema,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _enviandoArchivo ? null : _enviarTexto,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
