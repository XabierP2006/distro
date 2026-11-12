import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:techstore_carrito/models/item_carrito.dart';
import 'package:techstore_carrito/models/producto.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.mensaje);

  final int statusCode;
  final String mensaje;

  @override
  String toString() => mensaje;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.5:5000',
  );

  String? _compraPendiente;
  String? _clavePendiente;

  Future<List<Producto>> obtenerProductos() async {
    final response = await http.get(Uri.parse('$baseUrl/api/productos'));
    if (response.statusCode != 200) {
      throw _error(response, 'No se pudieron obtener los productos.');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data.map((item) => Producto.fromJson(item)).toList();
  }

  Future<String> generarFactura(List<ItemCarrito> items) async {
    final body = jsonEncode({
      'cliente': {'nombre': 'Cliente de prueba', 'cedula_ruc': '0000000000'},
      'detalles': items.map((item) => item.toJson()).toList(),
    });
    if (_compraPendiente != body) {
      _compraPendiente = body;
      _clavePendiente = _nuevaClave();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/facturas'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/xml',
        'Idempotency-Key': _clavePendiente!,
      },
      body: body,
    );

    if (response.statusCode < 500) {
      _compraPendiente = null;
      _clavePendiente = null;
    }
    if (response.statusCode != 200) {
      throw _error(response, 'No se pudo generar la factura.');
    }
    return utf8.decode(response.bodyBytes);
  }

  ApiException _error(http.Response response, String mensaje) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic> && data['mensaje'] is String) {
        mensaje = data['mensaje'] as String;
      }
    } on FormatException { 
    }
    return ApiException(response.statusCode, mensaje);
  }

  String _nuevaClave() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
