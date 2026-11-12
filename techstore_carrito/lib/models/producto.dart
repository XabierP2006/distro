class Producto{
  final int id;
  final String nombre;
  final double precio;
  final int stock;
  final String imageURL;

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.stock,
    required this.imageURL,
  });
  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'],
      nombre: json['nombre'],
      precio: json['precio'].toDouble(),
      stock: json['stock'],
      imageURL: (json['imageURL'] ?? json['imagen_url']) as String? ?? '',
    );
  }
}