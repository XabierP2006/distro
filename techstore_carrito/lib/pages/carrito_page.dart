import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:techstore_carrito/models/item_carrito.dart';
import 'package:techstore_carrito/models/producto.dart';
import 'package:techstore_carrito/service/api_service.dart'; 

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage>{
  final ApiService apiService = ApiService();
  List<Producto> productos = [];
  List<ItemCarrito> carrito = [];
  bool cargandoProductos = true;
  bool generandoFactura = false;
  String resultadoXML = "";
  String mensajeError = "";

  @override
  void initState(){
    super.initState();
    cargarProductos();
  }

  Future<void> cargarProductos () async{
    setState(() {
      cargandoProductos = true;
      mensajeError = "";
    });
    try{
      final data = await apiService.obtenerProductos();
      if(!mounted) return;
      setState(() {
        productos = data;
        cargandoProductos = false;
      });
    }catch(e){
      if(!mounted) return;
      setState(() {
        // para produccion no se puede mandar así
        mensajeError = e.toString();
        cargandoProductos = false;
      });
    }
  }

  void agregarAlCarrito(Producto producto){
    final index = carrito.indexWhere(
      (item) => item.producto.id == producto.id
    );
    final cantidadActual = index>=0 ? carrito[index].cantidad : 0;
    if (cantidadActual >= producto.stock){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No existe stock suficiente"))
      );
      return ;
    }
    setState(() {
      if(index >=0){
        carrito[index].cantidad++;
      }else{
        carrito.add(ItemCarrito(producto: producto));
      }
      resultadoXML = "";
      mensajeError="";
    });
  }

  void quitarDelCarrito(
    ItemCarrito item
  ){
    final index = carrito.indexWhere(
      (elemento)=>elemento.producto.id == item.producto.id);

    if(index == -1) return;
    setState(() {
      if(carrito[index].cantidad> 1){
        carrito[index].cantidad --;
      }else{
        carrito.removeAt(index);
      }
      resultadoXML = "";
      mensajeError = "";
    });
  }

  void limpiarCarrito(){
    setState(() {
      carrito.clear();
      resultadoXML = "";
      mensajeError = "";
    });
  }

  double get subtotal{
    return carrito.fold(0.0, (total, item) => total + item.subtotal);
  }

  double get iva{
    return subtotal * 0.15;
  }
  double get total{
    return subtotal + iva;
  }

  Future<void> generarFactura () async{
    if(carrito.isEmpty){
      setState(() {
        mensajeError = "Debe Ingresar al menos un producto";
        resultadoXML = "";
      });
      return;
    }
    setState(() {
      generandoFactura = true;
      resultadoXML = "";
      mensajeError = "";
    });

    try{
      final respuesta = await apiService.generarFactura(carrito);
      if(!mounted) return;
      setState(() {
        resultadoXML = respuesta;
      });
    }catch(e){
       if(!mounted) return;
       setState(() {
        // esto en producción no vale
         mensajeError = e.toString();
       });
    }finally{
       if(!mounted) return;
       setState(() {
         generandoFactura = false;
       });
    }

  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TechStore 360 - Carrito SOA"),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
            return _vistaMovil();
          }
         return Row(
            children: [
              Expanded( flex: 2, child: _panelProductos(), ),
              Expanded( flex: 2, child: _panelCarrito(), ),
              Expanded( flex: 3, child: _panelFactura(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _vistaMovil() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 380,
            child: _panelProductos(),
          ),
          SizedBox(
            height: 380,
            child: _panelCarrito(),
          ),
          SizedBox(
            height: 420,
            child: _panelFactura(),
          ),
        ],
      ),
    );
  }

Widget _panelProductos() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Productos desde API REST",
            style: TextStyle( fontSize: 20, fontWeight: FontWeight.bold, ), ),
          const SizedBox(height: 12),
          if (cargandoProductos)
            const Expanded( child: Center( child: CircularProgressIndicator(), ), )
          else if (mensajeError.isNotEmpty &&
              productos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text( mensajeError, textAlign: TextAlign.center, ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: cargarProductos,
                      child: const Text("Reintentar"),
                    ),
                  ],
                ),
              ),
            )

          else
            Expanded(
              child: ListView.builder(
                itemCount: productos.length,

                itemBuilder: (context, index) {
                  final producto = productos[index];

                  return Card(
                    child: ListTile(

                      leading: producto.imageURL.isNotEmpty
                          ? Image.network(
                              producto.imageURL,
                              width: 45,
                              height: 45,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return const Icon(
                                  Icons.image_not_supported,
                                );
                              },
                            )
                          : const Icon(Icons.devices),

                      title: Text(producto.nombre),

                      subtitle: Text(
                        "Precio: \$${producto.precio.toStringAsFixed(2)}"
                        " | Stock: ${producto.stock}",
                      ),

                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_shopping_cart,
                        ),
                        onPressed: producto.stock > 0
                            ? () => agregarAlCarrito(producto)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // 14. PANEL DEL CARRITO
  Widget _panelCarrito() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Carrito de compras",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: carrito.isEmpty
                ? const Center(
                    child: Text(
                      "No hay productos en el carrito.",
                    ),
                  )

                : ListView.builder(
                    itemCount: carrito.length,

                    itemBuilder: (context, index) {
                      final item = carrito[index];

                      return Card(
                        child: ListTile(
                          title: Text(item.producto.nombre),

                          subtitle: Text(
                            "Cantidad: ${item.cantidad}"
                            " | Precio: \$${item.producto.precio.toStringAsFixed(2)}",
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "\$${item.subtotal.toStringAsFixed(2)}",
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                ),
                                onPressed: () =>
                                    quitarDelCarrito(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(),

          Text(
            "Subtotal: \$${subtotal.toStringAsFixed(2)}",
          ),

          Text(
            "IVA 15%: \$${iva.toStringAsFixed(2)}",
          ),

          Text(
            "Total: \$${total.toStringAsFixed(2)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: generandoFactura
                      ? null
                      : generarFactura,

                  icon: const Icon(Icons.receipt_long),

                  label: Text(
                    generandoFactura
                        ? "Generando..."
                        : "Generar factura",
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: generandoFactura
                    ? null
                    : limpiarCarrito,

                icon: const Icon(Icons.delete),
                tooltip: "Limpiar carrito",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 15. PANEL DE FACTURA XML
  Widget _panelFactura() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Factura XML",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (mensajeError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                mensajeError,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                ),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                resultadoXML.isEmpty
                    ? "Aquí aparecerá la factura XML "
                      "generada por el servicio REST..."
                    : resultadoXML,

                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: "monospace",
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

