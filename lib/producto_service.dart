import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'red.dart'; // <-- IMPORTADO

class ProductoService {
  final String baseUrl = urlCentral; // <-- CORREGIDO

  // Obtener la lista de productos
  Future<List<dynamic>> obtenerProductos(String idComercio) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/productos_comercio/$idComercio'),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('Error del servidor: Código ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Fallo de conexión con el motor Python: $e');
      return [];
    }
  }

  // Agregar un producto nuevo
  Future<bool> agregarProducto(Map<String, dynamic> productoData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registrar_producto/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productoData),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error al intentar guardar el producto: $e');
      return false;
    }
  }

  // ==========================================
  // NUEVA TUBERÍA: Eliminar un producto
  // ==========================================
  Future<bool> eliminarProducto(int idProducto) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/eliminar_producto/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_producto': idProducto}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error al eliminar: $e');
      return false;
    }
  }
} // <--- Esta es la llave final que encierra todo
