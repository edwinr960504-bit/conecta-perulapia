import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'gps_service.dart';
import 'red.dart';

class LogisticaService {
  static const String baseUrl = urlCentral;

  // 1. ACCIÓN DEL COMERCIO: Aceptar pedido y definir tiempo
  static Future<bool> comercioAcepta(int idPedido, String tiempoPrep) async {
    try {
      final url = Uri.parse('$baseUrl/comercio_acepta');
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_pedido": idPedido, "tiempo": tiempoPrep}),
      );

      if (res.statusCode == 200) {
        debugPrint("🍳 Comercio aceptó pedido #$idPedido ($tiempoPrep)");
        return true;
      } else {
        debugPrint("⚠️ Error en cocina: ${res.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error de conexión (Cocina): $e");
      return false;
    }
  }

  // 2. ACCIÓN DEL MOTORISTA: Recoger con PIN del Comercio
  static Future<String> recogerPedido(
    int idPedido,
    String pinRecoleccion,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/recoger_pedido');
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_pedido": idPedido,
          "pin_recoleccion": pinRecoleccion,
        }),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && !data.containsKey("Error")) {
        debugPrint("📦 Pedido #$idPedido recogido. ¡En camino!");

        // 🔥 Enciende el radar GPS en segundo plano automáticamente
        GpsService.iniciarLatidosGps(idPedido);

        return "OK";
      } else {
        return data["Error"] ?? "PIN incorrecto";
      }
    } catch (e) {
      return "Error de conexión con el servidor";
    }
  }

  // 3. ACCIÓN DEL MOTORISTA: Entregar con PIN del Cliente
  static Future<String> entregarPedido(
    int idPedido,
    String pinSeguridad,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/entregar_pedido');
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_pedido": idPedido, "pin": pinSeguridad}),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && !data.containsKey("Error")) {
        debugPrint("🏁 Pedido #$idPedido ENTREGADO con éxito.");
        GpsService.apagarGps();
        return "OK";
      } else {
        return data["Error"] ?? "PIN incorrecto";
      }
    } catch (e) {
      return "Error de conexión con el servidor";
    }
  }
}
