import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:techstore_carrito/models/item_carrito.dart';
import 'package:techstore_carrito/models/producto.dart';

class ApiService {
  static const String baseUrl ='http://10.79.31.185:5000';
  Future<List<Producto>> obtenerProductos() async {
    final url =  Uri.parse('$baseUrl/productos');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Producto.fromJson(item)).toList();
    } else {
      throw Exception(
        'Error al obtener los productos');
    }
  }
  Future<String> generarFactura(List<ItemCarrito> items) async {
    final url = Uri.parse('$baseUrl/factura');
    final datosCompra = {
      "factura": {
        "numero": "F0001",
      "fecha": "2026-11-09"
      },    
      "cliente": {
        "nombre": "Xabi Perez",
        "cedula_ruc": "1756402432" 
        },
      "detalles": items.map((item) => item.toJson()).toList(),
    };
    final response = await http.post(url, 
    headers: {'Content-Type': 'application/json',"Accept":"application/xml" },
    body: json.encode(datosCompra));

    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('Error al generar la factura');
    }
  }
} 