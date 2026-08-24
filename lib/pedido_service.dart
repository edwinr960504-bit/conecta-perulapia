import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'red.dart';

class PedidoService {
  static const String baseUrl = urlCentral;

  // ==========================================================
  // 1. OBTENER PEDIDOS DEL COMERCIO
  // ==========================================================
  Future<List<dynamic>> obtenerPedidos(String idComercio) async {
    final url = Uri.parse('$baseUrl/pedidos_comercio/$idComercio');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> datos =
            json.decode(utf8.decode(response.bodyBytes));
        return datos;
      }
      return [];
    } catch (e) {
      debugPrint('🚨 [GET] Fallo crítico: $e');
      return [];
    }
  }

  // ==========================================================
  // 2. ACEPTAR PEDIDO (El comercio confirma la preparación)
  // ==========================================================
  Future<bool> aceptarPedido(int idPedido, String tiempoPrep) async {
    final url = Uri.parse('$baseUrl/comercio_acepta/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'id_pedido': idPedido, 'tiempo': tiempoPrep}),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 [POST] Fallo crítico al conectar: $e');
      return false;
    }
  }

  // ==========================================================
  // 3. CANCELAR PEDIDO (Opción para el comercio y cliente)
  // ==========================================================
  Future<bool> cancelarPedido(int idPedido) async {
    final url = Uri.parse('$baseUrl/cancelar_pedido/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'id_pedido': idPedido}),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 [POST] Fallo crítico al cancelar: $e');
      return false;
    }
  }
}
