import 'package:flutter/material.dart';
import 'package:techstore_carrito/models/item_carrito.dart';
import 'package:techstore_carrito/models/producto.dart';
import 'package:techstore_carrito/service/api_service.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final ApiService apiService = ApiService();
  List<Producto> productos = [];
  List<ItemCarrito> carrito = [];
  bool cargandoProductos = true;
  bool generandoFactura = false;
  String resultadoXML = "";
  String mensajeError = "";
  @override
  void initState() {
    super.initState();
    cargarProductos();
  }

  Future<void> cargarProductos() async {
    setState(() {
      cargandoProductos = true;
      mensajeError = "";
    });
    try {
      final data = await apiService.obtenerProductos();
      if (!mounted) return;
      setState(() {
        productos = data;
        cargandoProductos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        //para produccion no se puede mandar asi
        mensajeError = e.toString();
        cargandoProductos = false;
      });
    }
  }
  void agregarAlCarrito(Producto producto) {
    final cantidadActual = carrito.indexWhere((item) => item.producto.id == producto.id);
    if(cantidadActual >= producto.stock){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay suficiente stock disponible.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
  
  }
}
