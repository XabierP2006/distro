#api
from flask import Flask, Response, request, jsonify
from pathlib import Path
import xml.etree.ElementTree as ET
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

iva_general=0.15

def generar_factura_xml(datos):
    subtotal_real = 0.0

    factura = ET.Element("Factura")
    cabecera = ET.SubElement(factura, "Cabecera")

    ET.SubElement(cabecera,"Numero").text = datos["factura"]["numero"]

    ET.SubElement(cabecera,"Fecha").text = datos["factura"]["fecha"]

    cliente = ET.SubElement(factura,"Cliente")

    ET.SubElement(cliente, "Nombre").text = datos["cliente"]["nombre"]
    ET.SubElement(cliente, "CedulaRUC").text = datos["cliente"]["cedula_ruc"]

    detalle = ET.SubElement(factura, "Detalle")
    productos = datos["detalles"]
    for producto in productos:
        nombre = producto["nombre"]
        cantidad = producto["cantidad"]
        precio = producto["precio_unitario"]
        subtotal_producto = cantidad*precio
        subtotal_real +=  subtotal_producto

        producto = ET.SubElement(detalle, "Producto")
        ET.SubElement(producto, "Nombre").text = nombre
        ET.SubElement(producto,"Cantidad").text = str(cantidad)
        ET.SubElement(producto, "Preciounitario").text = f"{precio:.2f}"
        ET.SubElement(producto, "Subtotal").text = f"{subtotal_producto:.2f}"

    iva_total = (subtotal_real*iva_general)
    total = subtotal_real + iva_total
    totales = ET.SubElement(factura, "Totales")
    ET.SubElement(totales, "Subtotal").text = f"{subtotal_real:.2f}"
    ET.SubElement(totales, "IVA").text = f"{iva_total:.2f}"
    ET.SubElement(totales, "Total").text = f"{total:.2f}"

    ET.SubElement(factura, "Estado").text = "Generada"
 
    ET.indent(factura, space=" ", level=0)
 
    xml = ET.tostring(factura, encoding="UTF-8", xml_declaration=True)
    Path(f'{datos["factura"]["numero"]}.xml').write_bytes(xml)
    return xml

def validar_datos(datos):
    errores = []
    if datos is None or len(datos) == 0:
        errores.append(
            {
                "campo":"body",
                "error":"Json esta vacío o no es válido"
            }
        )
        return errores
    factura = datos.get("factura")
    if not isinstance(factura, dict):
        errores.append({
            "campo": "factura",
            "error": "La factura es requerida"
        })
    else:
        if not factura.get("numero"):
            errores.append(
                {
                    "campo":"numero",
                    "error": "El numero de factura es requerido"
                }
            )

        if not factura.get("fecha"):
            errores.append(
                {
                    "campo":"fecha",
                    "error": "La fecha de la factura es requerida"
                }
            )

    cliente = datos.get("cliente")

    if not isinstance(cliente, dict):
        errores.append(
            {
                "campo": "cliente",
                "error": "Ël cliente es requerido y debe ser un objeto"
            }
        )
    else:
        if not cliente.get("nombre"):
            errores.append(
                {
                    "campo": "cliente.name",
                    "error": "El nombre del cliente es requerido"
                }
            )
        if not cliente.get("cedula_ruc"):
            errores.append(
                {
                    "campo": "cliente.cedula_ruc",
                    "error": "La cedula u RUC del cliente es requerido"
                }
            )

    productos = datos.get("detalles")
    if not isinstance(productos,list) or len(productos) == 0:
        errores.append(
            {
                "campo": "productos",
                "error": "La lista de productos es requerida y tiene que tener almenos un producto"
            }
        )
    else:
        for i, producto in enumerate(productos):
            if not producto.get("nombre"):
                errores.append(
                    {
                        "campo": f"producto[{i}].nombre",
                        "error": "El nombre del producto es requerido"
                    }
                )

            try:
                cantidad = float(producto.get("cantidad", 0))
                if cantidad <= 0:
                    errores.append(
                        {
                            "campo":f"producto[{i}].cantidad",
                            "error":"La cantidad del producto debe ser mayor a 0"
                        }
                    )
            except ValueError:
                errores.append(
                    {
                        "campo":f"producto[{i}].cantidad",
                        "error":"La cantidad debe ser numérica"
                    }
                )
            try:
                precio_unitario = float(producto.get("precio_unitario", 0))
                if precio_unitario <= 0:
                    errores.append(
                        {
                            "campo":f"producto[{i}].precio_unitario",
                            "error":"El precio_unitario del producto debe ser mayor a 0"
                        }
                    )
            except ValueError:
                errores.append(
                    {
                        "campo":f"producto[{i}].precio_unitario",
                        "error":"El precio_unitario debe ser numérica"
                    }
                )

    return errores


#endpoint
@app.route("/")
def inicio(): 
    return "Bienvenido a TeschStore Facturacion"

@app.route("/api/facturas", methods=["POST"])
def generar_factura():
    datos = request.get_json()
    errores = validar_datos(datos)
    if errores:
        return jsonify(
            {
                "errores": errores,
                "estado": "Error",
                "mensaje": "Datos Inválidos"
            }
        ), 400
    xml = generar_factura_xml(datos)
    if request.accept_mimetypes.best_match(["application/json", "application/xml"]) == "application/xml":
        return Response(xml, content_type="application/xml; charset=utf-8")
    return datos


@app.route('/api/productos', methods=['GET'])
def obtener_productos():
    
    return jsonify(
            {"id": 1, "nombre": "Producto A", "precio": 10.0, "stock": 100, "imageURL": "https://example.com/producto_a.jpg"},
            {"id": 2, "nombre": "Producto B", "precio": 20.0, "stock": 50, "imageURL": "https://example.com/producto_b.jpg"},
            {"id": 3, "nombre": "Producto C", "precio": 30.0, "stock": 25, "imageURL": "https://example.com/producto_c.jpg"})
if __name__ == "__main__":
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True)