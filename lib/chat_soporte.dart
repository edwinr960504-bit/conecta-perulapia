import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'red.dart'; // Tu archivo de conexión

class ChatSoporte extends StatefulWidget {
  final int idPedido;
  final String remitente;
  final String canal;

  const ChatSoporte({
    super.key,
    required this.idPedido,
    required this.remitente,
    this.canal = "admin_cliente",
  });

  @override
  State<ChatSoporte> createState() => _ChatSoporteState();
}

class _ChatSoporteState extends State<ChatSoporte> {
  final TextEditingController _msjCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<dynamic> _mensajes = [];
  Timer? _latido;
  bool _cargando = true;

  // MULTIMEDIA
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _estaGrabando = false;
  bool _escribiendo = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _latido = Timer.periodic(
        const Duration(seconds: 3), (t) => _cargarHistorial(silencioso: true));
  }

  @override
  void dispose() {
    _latido?.cancel();
    _msjCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial({bool silencioso = false}) async {
    try {
      final res = await http
          .get(Uri.parse('$urlCentral/api/chat/historial/${widget.idPedido}'));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _mensajes = data['mensajes'] ?? [];
          _cargando = false;
        });
        if (!silencioso) _bajarScroll();
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _bajarScroll() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // --- 1. ENVIAR TEXTO ---
  Future<void> _enviarTexto() async {
    final texto = _msjCtrl.text.trim();
    if (texto.isEmpty) return;

    _msjCtrl.clear();
    setState(() => _escribiendo = false);
    await _enviarMensajeBD(texto, "");
  }

  // --- 2. ENVIAR FOTO ---
  Future<void> _tomarFoto() async {
    final XFile? foto =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (foto != null) {
      await _subirArchivo(File(foto.path), "📷 Foto enviada");
    }
  }

  // --- 3. GRABAR Y ENVIAR AUDIO ---
  Future<void> _gestionarGrabacion() async {
    if (_estaGrabando) {
      // Detener grabación
      final path = await _recorder.stop();
      setState(() => _estaGrabando = false);
      if (path != null) {
        await _subirArchivo(File(path), "🎤 Nota de voz");
      }
    } else {
      // Iniciar grabación
      if (await Permission.microphone.request().isGranted) {
        final dir = Directory.systemTemp;
        _audioPath =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
            path: _audioPath!);
        setState(() => _estaGrabando = true);
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permiso de micrófono denegado")));
      }
    }
  }

  // --- 4. MOTOR DE SUBIDA DE ARCHIVOS A PYTHON ---
  Future<void> _subirArchivo(File archivo, String mensajeDescriptivo) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Subiendo archivo..."), duration: Duration(seconds: 1)));
    try {
      var peticion = http.MultipartRequest(
          'POST', Uri.parse('$urlCentral/api/chat/subir_evidencia'));
      peticion.files
          .add(await http.MultipartFile.fromPath('archivo', archivo.path));

      var respuesta = await peticion.send();
      if (respuesta.statusCode == 200) {
        var resData = await http.Response.fromStream(respuesta);
        var jsonRes = json.decode(resData.body);
        if (jsonRes['status'] == 'ok') {
          // El archivo subió, ahora enviamos el mensaje con la ruta
          await _enviarMensajeBD(mensajeDescriptivo, jsonRes['ruta']);
        }
      }
    } catch (e) {
      debugPrint("Error subiendo archivo: $e");
    }
  }

  // --- 5. GUARDAR MENSAJE FINAL EN LA BASE DE DATOS ---
  Future<void> _enviarMensajeBD(String mensaje, String evidencia) async {
    try {
      await http.post(
        Uri.parse('$urlCentral/api/chat/enviar_mensaje'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "id_pedido": widget.idPedido,
          "remitente": widget.remitente,
          "mensaje": mensaje,
          "evidencia": evidencia,
          "canal": widget.canal
        }),
      );
      _cargarHistorial();
      _bajarScroll();
    } catch (e) {
      debugPrint("Error enviando: $e");
    }
  }

  void _reproducirAudio(String rutaWeb) async {
    final urlCompleta = "$urlCentral$rutaWeb";
    await _audioPlayer.play(UrlSource(urlCompleta));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text("Chat - Rastreo #${widget.idPedido}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ZONA DE MENSAJES
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(15),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, index) {
                      final m = _mensajes[index];
                      final bool soyYo = m['remitente'] == widget.remitente;
                      final String evidencia = m['evidencia'] ?? '';
                      final bool tieneEvidencia = evidencia.isNotEmpty;

                      final bool esImagen =
                          evidencia.toLowerCase().endsWith('.jpg') ||
                              evidencia.toLowerCase().endsWith('.png') ||
                              evidencia.toLowerCase().endsWith('.jpeg');
                      final bool esAudio =
                          evidencia.toLowerCase().endsWith('.m4a');

                      return Align(
                        alignment: soyYo
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color:
                                soyYo ? const Color(0xFF1E3A8A) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: soyYo
                                  ? const Radius.circular(15)
                                  : const Radius.circular(0),
                              bottomRight: soyYo
                                  ? const Radius.circular(0)
                                  : const Radius.circular(15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['remitente'],
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        soyYo ? Colors.blue[200] : Colors.grey),
                              ),
                              const SizedBox(height: 5),

                              // RENDERIZADO DE MULTIMEDIA
                              if (tieneEvidencia && esImagen)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                        "$urlCentral$evidencia",
                                        fit: BoxFit.cover),
                                  ),
                                )
                              else if (tieneEvidencia && esAudio)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: soyYo
                                        ? Colors.white
                                        : const Color(0xFF1E3A8A),
                                    foregroundColor: soyYo
                                        ? const Color(0xFF1E3A8A)
                                        : Colors.white,
                                  ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text("Reproducir Audio"),
                                  onPressed: () => _reproducirAudio(evidencia),
                                ),

                              // TEXTO NORMAL
                              Text(
                                m['mensaje'],
                                style: TextStyle(
                                    fontSize: 15,
                                    color:
                                        soyYo ? Colors.white : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // BARRA INFERIOR (TECLADO, FOTO Y AUDIO)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // BOTÓN DE CÁMARA
                IconButton(
                  icon: const Icon(Icons.camera_alt,
                      color: Colors.blueGrey, size: 28),
                  onPressed: _tomarFoto,
                ),

                // CAMPO DE TEXTO
                Expanded(
                  child: TextField(
                    controller: _msjCtrl,
                    onChanged: (val) {
                      setState(() => _escribiendo = val.trim().isNotEmpty);
                    },
                    decoration: InputDecoration(
                      hintText: _estaGrabando
                          ? "Grabando audio..."
                          : "Escribe un mensaje...",
                      filled: true,
                      fillColor:
                          _estaGrabando ? Colors.red.shade50 : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                    ),
                    readOnly: _estaGrabando,
                  ),
                ),

                const SizedBox(width: 8),

                // BOTÓN DINÁMICO (ENVIAR TEXTO O GRABAR AUDIO)
                GestureDetector(
                  onTap: _escribiendo ? _enviarTexto : _gestionarGrabacion,
                  child: CircleAvatar(
                    backgroundColor:
                        _estaGrabando ? Colors.red : const Color(0xFF1E3A8A),
                    radius: 24,
                    child: Icon(
                      _escribiendo
                          ? Icons.send
                          : (_estaGrabando ? Icons.stop : Icons.mic),
                      color: Colors.white,
                      size: 24,
                    ),
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
