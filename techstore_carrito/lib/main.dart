import 'package:flutter/material.dart';
import 'package:techstore_carrito/pages/carrito_page.dart';

void main() {
  runApp(const TechStoreApp());
}

class TechStoreApp extends StatelessWidget {
  const TechStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechStore',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CarritoPage(),
    );
  }
}