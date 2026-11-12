import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void cambiarCantidad(ItemCarrito item, int cantidad) {
    if (cantidad == item.cantidad) return;
    setState(() {
      item.cantidad = cantidad;
      resultadoXML = '';
      mensajeError = '';
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

  int cantidadEnCarrito(Producto producto) {
    final index = carrito.indexWhere((item) => item.producto.id == producto.id);
    return index < 0 ? 0 : carrito[index].cantidad;
  }

  Future<void> actualizarStock() async {
    try {
      final catalogo = await apiService.obtenerProductos();
      if (!mounted) return;
      final porId = {for (final producto in catalogo) producto.id: producto};
      setState(() {
        productos = catalogo;
        carrito = [
          for (final item in carrito)
            if ((porId[item.producto.id]?.stock ?? 0) > 0)
              ItemCarrito(
                producto: porId[item.producto.id]!,
                cantidad: item.cantidad.clamp(1, porId[item.producto.id]!.stock).toInt(),
              ),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        mensajeError = [
          if (mensajeError.isNotEmpty) mensajeError,
          "No se pudo actualizar el stock.",
        ].join(" ");
      });
    }
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
        carrito.clear();
      });
      await actualizarStock();
    }catch(e){
       if(!mounted) return;
       setState(() => mensajeError = e.toString());
       if (e is ApiException && e.statusCode == 409) {
         await actualizarStock();
       }
    } finally {
      if (mounted) {
        setState(() => generandoFactura = false);
      }
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
                        onPressed: !generandoFactura && cantidadEnCarrito(producto) < producto.stock
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
                        key: ValueKey(item.producto.id),
                        child: ListTile(
                          title: Text(item.producto.nombre),

                          subtitle: Text(
                            "Subtotal: \$${item.subtotal.toStringAsFixed(2)}",
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Disminuir cantidad',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: generandoFactura
                                    ? null
                                    : () => quitarDelCarrito(item),
                              ),
                              _CampoCantidad(
                                cantidad: item.cantidad,
                                stock: item.producto.stock,
                                habilitado: !generandoFactura,
                                onChanged: (cantidad) => cambiarCantidad(item, cantidad),
                              ),
                              IconButton(
                                tooltip: 'Aumentar cantidad',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: !generandoFactura &&
                                        item.cantidad < item.producto.stock
                                    ? () => agregarAlCarrito(item.producto)
                                    : null,
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

class _CampoCantidad extends StatefulWidget {
  const _CampoCantidad({
    required this.cantidad,
    required this.stock,
    required this.habilitado,
    required this.onChanged,
  });

  final int cantidad;
  final int stock;
  final bool habilitado;
  final ValueChanged<int> onChanged;

  @override
  State<_CampoCantidad> createState() => _CampoCantidadState();
}

class _CampoCantidadState extends State<_CampoCantidad> {
  late final _texto = TextEditingController(text: widget.cantidad.toString());
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _sincronizar();
    });
  }

  @override
  void didUpdateWidget(covariant _CampoCantidad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cantidad != oldWidget.cantidad || !widget.habilitado) {
      _sincronizar();
    }
  }

  void _sincronizar() {
    if (int.tryParse(_texto.text) != widget.cantidad) {
      _texto.text = widget.cantidad.toString();
    }
  }

  @override
  void dispose() {
    _foco.dispose();
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: _texto,
        focusNode: _foco,
        enabled: widget.habilitado,
        selectAllOnFocus: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Cantidad',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((anterior, nuevo) {
            if (nuevo.text.isEmpty) return nuevo;
            final cantidad = int.tryParse(nuevo.text);
            return cantidad != null && cantidad >= 1 && cantidad <= widget.stock
                ? nuevo
                : anterior;
          }),
        ],
        onTapOutside: (_) => _foco.unfocus(),
        onChanged: (texto) {
          final cantidad = int.tryParse(texto);
          if (cantidad != null) widget.onChanged(cantidad);
        },
      ),
    );
  }
}
