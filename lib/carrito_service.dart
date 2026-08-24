import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'red.dart';

class CarritoService {
  // Mapa para guardar los productos por su ID
  static Map<int, dynamic> items = {};

  // Notificador para que la UI se entere cuando el carrito cambia
  static final ValueNotifier<int> contador = ValueNotifier<int>(0);

  // Función para agregar productos
  static void agregar(dynamic producto) {
    int id = producto['id_producto'];

    // Aseguramos que el precio sea un número real
    double precio = 0.0;
    if (producto['precio'] is String) {
      precio = double.tryParse(producto['precio'] as String) ?? 0.0;
    } else {
      precio = (producto['precio'] as num).toDouble();
    }

    if (items.containsKey(id)) {
      items[id]['cantidad']++;
    } else {
      producto['precio'] = precio;
      producto['cantidad'] = 1;
      items[id] = producto;
    }

    contador.value++;
  }

  // Función para quitar productos
  static void quitar(int id) {
    if (items.containsKey(id)) {
      if (items[id]['cantidad'] > 1) {
        items[id]['cantidad']--;
      } else {
        items.remove(id);
      }
      contador.value--;
    }
  }

  // Función para limpiar todo el carrito
  static void limpiar() {
    items.clear();
    contador.value = 0;
  }

  // Función para obtener el total a pagar
  static double obtenerTotal() {
    return items.values.fold(0.0, (sum, item) {
      double precio = (item['precio'] as num).toDouble();
      int cantidad = item['cantidad'] as int;
      return sum + (precio * cantidad);
    });
  }

  static List<dynamic> obtenerLista() {
    return items.values.toList();
  }

  // =========================================================
  // FUNCIÓN BLINDADA PARA ENVIAR EL PEDIDO A PYTHON (AHORA CON GPS)
  // =========================================================
  static Future<bool> confirmarPedido(
    int idCliente,
    int idComercio,
    String metodoPago,
    double distanciaKm,
    double latitudCliente, // <-- NUEVO: Recibe GPS
    double longitudCliente, // <-- NUEVO: Recibe GPS
  ) async {
    if (items.isEmpty) return false;

    // 1. Convertimos la lista en texto simple
    String descripcionPedido = items.values.map((item) {
      return "${item['cantidad']}x ${item['nombre'] ?? 'Producto'}";
    }).join(", ");

    // 2. Empaquetamos exactamente lo que espera PedidoNuevo en FastAPI
    final paquete = {
      "id_cliente": idCliente,
      "id_comercio": idComercio,
      "descripcion": descripcionPedido,
      "precio_comida": obtenerTotal(),
      "distancia_km": distanciaKm,
      "metodo_pago": metodoPago,
      "latitud_cliente": latitudCliente, // <-- Enviamos el GPS del cliente
      "longitud_cliente": longitudCliente, // <-- Enviamos el GPS del cliente
    };

    try {
      final url = Uri.parse('$urlCentral/api/crear_pedido/');

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(paquete),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint("✅ ¡PEDIDO REAL GUARDADO! Respuesta de Python: ${res.body}");
        limpiar(); // Vaciamos el carrito local
        return true;
      } else {
        debugPrint(
            "⚠️ El servidor rechazó el pedido: HTTP ${res.statusCode} - ${res.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error fatal de conexión: $e");
      return false;
    }
  }
}
