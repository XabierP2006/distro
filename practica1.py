from contextlib import closing
from decimal import Decimal, ROUND_HALF_UP
from hashlib import sha256
import json
import os
from urllib.parse import urljoin
from uuid import UUID, uuid4
import xml.etree.ElementTree as ET

from flask import Flask, Response, jsonify, request
from flask_cors import CORS
import pyodbc

app = Flask(__name__)
CORS(app)

IVA = Decimal("0.15")
CENTAVO = Decimal("0.01")


def conectar():
    cadena = os.environ.get(
        "TECHSTORE_DB_CONNECTION",
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost;"
        "DATABASE=TechStore360;Trusted_Connection=yes;TrustServerCertificate=yes;",
    )
    return pyodbc.connect(cadena, timeout=5)


def url_imagen(ruta):
    return urljoin(request.url_root, ruta) if ruta else ""


def generar_factura_xml(numero, fecha, nombre, cedula, detalles, subtotal, iva):
    factura = ET.Element("Factura")
    cabecera = ET.SubElement(factura, "Cabecera")
    ET.SubElement(cabecera, "Numero").text = f"F001-{numero:06d}"
    ET.SubElement(cabecera, "Fecha").text = fecha

    cliente = ET.SubElement(factura, "Cliente")
    ET.SubElement(cliente, "Nombre").text = nombre
    ET.SubElement(cliente, "CedulaRUC").text = cedula

    detalle = ET.SubElement(factura, "Detalle")
    for _, nombre_producto, cantidad, precio, imagen in detalles:
        producto = ET.SubElement(detalle, "Producto")
        ET.SubElement(producto, "Nombre").text = nombre_producto
        ET.SubElement(producto, "Cantidad").text = str(cantidad)
        ET.SubElement(producto, "PrecioUnitario").text = f"{precio:.2f}"
        ET.SubElement(producto, "Subtotal").text = f"{cantidad * precio:.2f}"
        if imagen:
            ET.SubElement(producto, "ImagenUrl").text = url_imagen(imagen)

    totales = ET.SubElement(factura, "Totales")
    ET.SubElement(totales, "Subtotal").text = f"{subtotal:.2f}"
    ET.SubElement(totales, "IVA").text = f"{iva:.2f}"
    ET.SubElement(totales, "Total").text = f"{subtotal + iva:.2f}"
    ET.SubElement(factura, "Estado").text = "Generada"
    return ET.tostring(factura, encoding="unicode")


def validar_compra(datos):
    if not isinstance(datos, dict):
        raise ValueError("Envía un objeto JSON con cliente y detalles.")

    cliente = datos.get("cliente")
    if not isinstance(cliente, dict):
        raise ValueError("Los datos del cliente son obligatorios.")

    nombre = cliente.get("nombre")
    cedula = cliente.get("cedula_ruc")
    if not isinstance(nombre, str) or not 1 <= len(nombre.strip()) <= 150:
        raise ValueError("El nombre del cliente es obligatorio.")
    if not isinstance(cedula, str) or not 1 <= len(cedula.strip()) <= 30:
        raise ValueError("La cédula o RUC del cliente es obligatoria.")

    detalles = datos.get("detalles")
    if not isinstance(detalles, list) or not detalles:
        raise ValueError("Agrega al menos un producto.")

    cantidades = {}
    for item in detalles:
        if not isinstance(item, dict):
            raise ValueError("Cada detalle debe incluir producto_id y cantidad.")
        producto_id = item.get("producto_id")
        cantidad = item.get("cantidad")
        if type(producto_id) is not int or not 1 <= producto_id <= 2147483647:
            raise ValueError("El ID de producto debe ser un entero positivo.")
        if type(cantidad) is not int or not 1 <= cantidad <= 2147483647:
            raise ValueError("La cantidad debe ser un entero positivo.")
        if producto_id in cantidades:
            raise ValueError("Envía una sola cantidad por producto.")
        cantidades[producto_id] = cantidad

    return nombre.strip(), cedula.strip(), sorted(cantidades.items())


class ConflictoCompra(Exception):
    pass


def guardar_factura(solicitud_id, nombre, cedula, cantidades):
    huella = sha256(json.dumps([nombre, cedula, cantidades]).encode()).hexdigest()
    with closing(conectar()) as conexion:
        cursor = conexion.cursor()
        cursor.execute("SET XACT_ABORT ON;")
        try:
            numero, fecha = cursor.execute(
                """
                INSERT dbo.Facturas (SolicitudId, Huella, ClienteNombre, ClienteCedulaRuc)
                OUTPUT inserted.Id, CONVERT(varchar(10), inserted.Fecha, 23)
                VALUES (?, ?, ?, ?)
                """,
                solicitud_id, huella, nombre, cedula,
            ).fetchone()
        except pyodbc.IntegrityError:
            conexion.rollback()
            anterior = cursor.execute(
                """
                SELECT Huella, CONVERT(nvarchar(max), Documento)
                FROM dbo.Facturas WHERE SolicitudId = ?
                """,
                solicitud_id,
            ).fetchone()
            if anterior is None:
                raise
            if anterior[0] != huella:
                raise ConflictoCompra("El identificador ya se usó para otra compra.")
            return anterior[1]

        detalles = []
        subtotal = Decimal("0.00")
        for producto_id, cantidad in cantidades:
            # El descuento y la comprobación de stock son una sola operación.
            producto = cursor.execute(
                """
                UPDATE dbo.Productos
                SET Stock = Stock - ?
                OUTPUT inserted.Nombre, inserted.Precio, inserted.ImagenUrl
                WHERE Id = ? AND Activo = 1 AND Stock >= ?
                """,
                cantidad, producto_id, cantidad,
            ).fetchone()
            if producto is None:
                conexion.rollback()
                raise ConflictoCompra(
                    "Ya no hay suficientes unidades de uno de tus productos. Es posible que alguien más lo haya comprado. Revisa tu carrito e inténtalo de nuevo."
                )
            detalles.append((
                producto_id, producto.Nombre, cantidad, producto.Precio, producto.ImagenUrl,
            ))
            subtotal += cantidad * producto.Precio

        cursor.executemany(
            """
            INSERT dbo.FacturaDetalle
                (FacturaId, ProductoId, Nombre, Cantidad, PrecioUnitario)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                (numero, producto_id, nombre_producto, cantidad, precio)
                for producto_id, nombre_producto, cantidad, precio, _ in detalles
            ],
        )
        iva = (subtotal * IVA).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        xml = generar_factura_xml(numero, fecha, nombre, cedula, detalles, subtotal, iva)
        documento = cursor.execute(
            """
            UPDATE dbo.Facturas
            SET Subtotal = ?, Iva = ?, Total = ?, Documento = CONVERT(xml, ?, 1)
            OUTPUT CONVERT(nvarchar(max), inserted.Documento)
            WHERE Id = ?
            """,
            subtotal, iva, subtotal + iva, xml, numero,
        ).fetchone()[0]
        conexion.commit()
        return documento


@app.get("/")
def inicio():
    return "Servicio de Facturación TechStore 360"


@app.get("/api/productos")
def obtener_productos():
    with closing(conectar()) as conexion:
        filas = conexion.cursor().execute(
            """
            SELECT Id, Nombre, Precio, Stock, ImagenUrl
            FROM dbo.Productos WHERE Activo = 1 ORDER BY Id
            """
        ).fetchall()
    return jsonify([
        dict(id=fila.Id, nombre=fila.Nombre, precio=float(fila.Precio),
             stock=fila.Stock, imagen_url=url_imagen(fila.ImagenUrl))
        for fila in filas
    ])


@app.post("/api/facturas")
def generar_factura():
    try:
        compra = validar_compra(request.get_json(silent=True))
        clave = request.headers.get("Idempotency-Key")
        try:
            solicitud_id = str(UUID(clave)) if clave else str(uuid4())
        except ValueError:
            raise ValueError("Idempotency-Key debe ser un UUID válido.") from None
        xml = guardar_factura(solicitud_id, *compra)
    except ValueError as error:
        return jsonify(mensaje=str(error)), 400
    except ConflictoCompra as error:
        return jsonify(mensaje=str(error)), 409
    factura = ET.fromstring(xml)
    ET.indent(factura, space="  ")
    return Response(ET.tostring(factura, encoding="utf-8"),
                    content_type="application/xml; charset=utf-8")


@app.errorhandler(pyodbc.Error)
def error_base_de_datos(error):
    app.logger.error("SQL Server: %s", error)
    return jsonify(mensaje="No se pudo completar la operación en SQL Server."), 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
