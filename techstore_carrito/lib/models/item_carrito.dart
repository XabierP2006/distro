import 'package:techstore_carrito/models/producto.dart';

class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({
    required this.producto,
    this.cantidad=1,
  });
  double get subtotal => producto.precio * cantidad;

  Map<String, dynamic> toJson() {
    return {  
      'producto_id': producto.id,
      'cantidad': cantidad,
    };
  }
}