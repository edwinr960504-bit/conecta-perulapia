import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'red.dart'; // <--- Cerebro de red

class GpsService {
  static Timer? _timerLatido;

  // 🔥 NUEVA FUNCIÓN: PIDE PERMISO DE GPS EXPLÍCITAMENTE AL ENTRAR
  static Future<bool> solicitarPermisosGps() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    // 1. Verifica si el GPS general del celular está encendido
    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      debugPrint("⚠️ El GPS del dispositivo está desactivado.");
      return false;
    }

    // 2. Revisa el estado actual de los permisos
    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        debugPrint("❌ Permiso de ubicación denegado por el usuario.");
        return false;
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      debugPrint("❌ Permiso de ubicación denegado permanentemente.");
      return false;
    }

    return true;
  }

  // 🔥 INICIA LOS LATIDOS AUTOMÁTICOS EN SEGUNDO PLANO
  static void iniciarLatidosGps(int idPedido,
      {int segundosIntervalo = 10}) async {
    // Validamos permisos antes de arrancar los latidos
    bool tienePermiso = await solicitarPermisosGps();
    if (!tienePermiso) {
      debugPrint(
          "❌ No se pudieron iniciar los latidos GPS por falta de permisos.");
      return;
    }

    // Si ya había uno corriendo, lo matamos para evitar duplicados
    detenerLatidosGps();

    debugPrint(
        "🚀 Iniciando radar GPS en segundo plano para el pedido #$idPedido...");

    // Primer envío inmediato al arrancar
    _enviarCoordenadaUnica(idPedido);

    // Latido periódico cada X segundos
    _timerLatido =
        Timer.periodic(Duration(seconds: segundosIntervalo), (timer) async {
      await _enviarCoordenadaUnica(idPedido);
    });
  }

  // 🛑 DETIENE LOS LATIDOS (Cuando se entrega el pedido o se cancela)
  static void detenerLatidosGps() {
    if (_timerLatido != null) {
      _timerLatido?.cancel();
      _timerLatido = null;
      debugPrint("🛑 Radar GPS detenido.");
    }
  }

  // FUNCIÓN INTERNA QUE HACE EL TRABAJO SUCIO DE LEER EL GPS Y MANDARLO A PYTHON
  static Future<void> _enviarCoordenadaUnica(int idPedido) async {
    try {
      Position posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint(
          "📍 GPS Real capturado: Lat ${posicion.latitude}, Lon ${posicion.longitude}");

      final url = Uri.parse('$urlCentral/actualizar_gps');

      final respuesta = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'id_pedido': idPedido,
          'latitud': posicion.latitude,
          'longitud': posicion.longitude,
        }),
      );

      if (respuesta.statusCode == 200) {
        debugPrint("✅ ¡Ubicación guardada en Python con éxito!");
      } else {
        debugPrint(
            "⚠️ Python rechazó el paquete: ${respuesta.statusCode} - ${respuesta.body}");
      }
    } catch (e) {
      debugPrint("❌ Error crítico en el servicio de GPS: $e");
    }
  }

  // Método de compatibilidad por si lo llaman suelto
  static Future<void> enviarUbicacion(int idPedido) async {
    await _enviarCoordenadaUnica(idPedido);
  }

  static void apagarGps() {
    detenerLatidosGps();
  }
}
