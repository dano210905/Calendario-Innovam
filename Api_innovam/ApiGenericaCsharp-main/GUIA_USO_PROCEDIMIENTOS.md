# Guia de Uso - ProcedimientosController

Guia practica para ejecutar **stored procedures y funciones** de base de datos a traves de la API, desde Swagger, Postman, JavaScript, Python y Blazor Server.

> **URL base**: `http://localhost:5035`
> **Controlador**: `ProcedimientosController` → ruta `/api/procedimientos`

---

## Tabla de Contenidos

- [Endpoint](#endpoint)
- [Conceptos Clave](#conceptos-clave)
- [Formato del Request](#formato-del-request)
- [Formato del Response](#formato-del-response)
- [Desde Swagger](#desde-swagger)
- [Desde Postman](#desde-postman)
- [Desde JavaScript (fetch)](#desde-javascript-fetch)
- [Desde Python (requests)](#desde-python-requests)
- [Desde Blazor Server (C#)](#desde-blazor-server-c)
- [Ejemplos con los 5 SPs de Facturas](#ejemplos-con-los-5-sps-de-facturas)
- [Parametro camposEncriptar](#parametro-camposencriptar)
- [Deteccion Automatica FUNCTION vs PROCEDURE](#deteccion-automatica-function-vs-procedure)
- [Codigos de Respuesta](#codigos-de-respuesta)
- [Errores Comunes y Soluciones](#errores-comunes-y-soluciones)

---

## Endpoint

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| POST | `/api/procedimientos/ejecutarsp` | Ejecutar cualquier stored procedure o function |

**Parametro query opcional:**
- `camposEncriptar` → Campos a hashear con BCrypt antes de enviar al SP (separados por coma)

---

## Conceptos Clave

### Un solo endpoint para todo

No importa si es un stored procedure o una function, ni cuantos parametros tenga. Siempre se usa el mismo endpoint:

```
POST /api/procedimientos/ejecutarsp
```

### La API detecta automaticamente si es FUNCTION o PROCEDURE

La API consulta `information_schema.routines` en la base de datos para determinar si el objeto es una funcion o un procedimiento y genera el SQL correcto:

- **PROCEDURE** → ejecuta con `CALL nombre_sp(param1, param2, ...)`
- **FUNCTION** → ejecuta con `SELECT * FROM nombre_funcion(param1, param2, ...)`

### El nombre del SP va dentro del JSON

El campo `nombreSP` es obligatorio y siempre va en el body, junto con los parametros del procedimiento:

```json
{
  "nombreSP": "nombre_del_procedimiento",
  "parametro1": valor1,
  "parametro2": valor2
}
```

### Los parametros INOUT JSON deben ser null

Para procedimientos PostgreSQL que usan `INOUT p_resultado JSON`, ese parametro debe enviarse como `null` (no como string vacio `""`):

```json
{
  "nombreSP": "mi_sp",
  "p_resultado": null
}
```

---

## Formato del Request

### Body (JSON)

```json
{
  "nombreSP": "nombre_del_procedimiento_o_funcion",
  "param1": "valor_texto",
  "param2": 123,
  "param3": null,
  "param_json": "[{\"campo\": \"valor\"}]"
}
```

**Reglas:**
- `nombreSP` es **obligatorio**
- Los demas campos son los parametros del SP (nombre exacto como en la BD)
- Los parametros JSON se envian como **string** (texto JSON escapado)
- Los parametros `INOUT` de tipo JSON se envian como `null`
- Los valores numericos van sin comillas: `123`, no `"123"`
- Los valores booleanos van como: `true` / `false`

### Query params opcionales

```
POST /api/procedimientos/ejecutarsp?camposEncriptar=contrasena
```

---

## Formato del Response

### Respuesta exitosa (200)

```json
{
  "procedimiento": "nombre_del_sp",
  "resultados": [
    {
      "columna1": "valor1",
      "columna2": 123,
      "p_resultado": "{\"dato\": \"valor\"}"
    }
  ],
  "total": 1,
  "mensaje": "Procedimiento ejecutado correctamente"
}
```

**Notas:**
- `resultados` es un array con los registros retornados
- Para SPs con `INOUT p_resultado JSON`, el resultado viene en `resultados[0].p_resultado` como **string JSON** que hay que parsear
- `total` indica cuantos registros se retornaron
- Todos los nombres de columna se convierten a **minusculas**

---

## Desde Swagger

### Paso a paso

1. Abrir `http://localhost:5035/swagger`
2. Buscar **POST** `/api/procedimientos/ejecutarsp`
3. Click en **Try it out**
4. En el body JSON escribir:

```json
{
  "nombreSP": "sp_listar_facturas_y_productosporfactura",
  "p_resultado": null
}
```

5. Click en **Execute**
6. Ver la respuesta en la seccion "Response body"

### Ejemplo: Consultar una factura especifica

```json
{
  "nombreSP": "sp_consultar_factura_y_productosporfactura",
  "p_numero": 1,
  "p_resultado": null
}
```

### Ejemplo: Insertar una factura con productos

```json
{
  "nombreSP": "sp_insertar_factura_y_productosporfactura",
  "p_fkidcliente": 1,
  "p_fkidvendedor": 2,
  "p_productos": "[{\"codigo\":\"PR003\",\"cantidad\":2},{\"codigo\":\"PR005\",\"cantidad\":1}]",
  "p_resultado": null
}
```

---

## Desde Postman

### Listar todas las facturas

```
POST http://localhost:5035/api/procedimientos/ejecutarsp
Content-Type: application/json

{
  "nombreSP": "sp_listar_facturas_y_productosporfactura",
  "p_resultado": null
}
```

### Consultar factura #1

```
POST http://localhost:5035/api/procedimientos/ejecutarsp
Content-Type: application/json

{
  "nombreSP": "sp_consultar_factura_y_productosporfactura",
  "p_numero": 1,
  "p_resultado": null
}
```

### Insertar factura con productos

```
POST http://localhost:5035/api/procedimientos/ejecutarsp
Content-Type: application/json

{
  "nombreSP": "sp_insertar_factura_y_productosporfactura",
  "p_fkidcliente": 1,
  "p_fkidvendedor": 2,
  "p_productos": "[{\"codigo\":\"PR003\",\"cantidad\":2},{\"codigo\":\"PR005\",\"cantidad\":1}]",
  "p_resultado": null
}
```

### Actualizar factura #1

```
POST http://localhost:5035/api/procedimientos/ejecutarsp
Content-Type: application/json

{
  "nombreSP": "sp_actualizar_factura_y_productosporfactura",
  "p_numero": 1,
  "p_fkidcliente": 2,
  "p_fkidvendedor": 1,
  "p_productos": "[{\"codigo\":\"PR002\",\"cantidad\":3}]",
  "p_resultado": null
}
```

### Eliminar factura #1

```
POST http://localhost:5035/api/procedimientos/ejecutarsp
Content-Type: application/json

{
  "nombreSP": "sp_borrar_factura_y_productosporfactura",
  "p_numero": 1,
  "p_resultado": null
}
```

---

## Desde JavaScript (fetch)

### Funcion generica para llamar SPs

```javascript
const API_SP = 'http://localhost:5035/api/procedimientos/ejecutarsp';

/**
 * Ejecuta un stored procedure via la API.
 * @param {string} nombreSP - Nombre del procedimiento
 * @param {object} parametros - Parametros del SP (sin nombreSP)
 * @returns {object} {exito, datos, mensaje}
 */
async function ejecutarSP(nombreSP, parametros = {}) {
    const payload = { nombreSP, ...parametros };

    const resp = await fetch(API_SP, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    });

    const json = await resp.json();

    if (!resp.ok) {
        return { exito: false, datos: null, mensaje: json.mensaje || 'Error' };
    }

    // Extraer p_resultado si existe (SPs con INOUT JSON)
    const resultados = json.resultados || [];
    if (resultados.length > 0 && resultados[0].p_resultado) {
        const parsed = typeof resultados[0].p_resultado === 'string'
            ? JSON.parse(resultados[0].p_resultado)
            : resultados[0].p_resultado;
        return { exito: true, datos: parsed, mensaje: json.mensaje };
    }

    return { exito: true, datos: resultados, mensaje: json.mensaje };
}
```

### Listar facturas

```javascript
const { exito, datos } = await ejecutarSP(
    'sp_listar_facturas_y_productosporfactura',
    { p_resultado: null }
);

if (exito) {
    datos.forEach(fac => {
        console.log(`Factura #${fac.numero} - ${fac.nombre_cliente} - $${fac.total}`);
        fac.productos.forEach(prod => {
            console.log(`  ${prod.codigo_producto}: ${prod.cantidad} x $${prod.valorunitario}`);
        });
    });
}
```

### Consultar factura especifica

```javascript
const { exito, datos } = await ejecutarSP(
    'sp_consultar_factura_y_productosporfactura',
    { p_numero: 1, p_resultado: null }
);

if (exito) {
    console.log('Factura:', datos.factura);
    console.log('Productos:', datos.productos);
}
```

### Insertar factura con productos

```javascript
const { exito, datos, mensaje } = await ejecutarSP(
    'sp_insertar_factura_y_productosporfactura',
    {
        p_fkidcliente: 1,
        p_fkidvendedor: 2,
        p_productos: JSON.stringify([
            { codigo: 'PR003', cantidad: 2 },
            { codigo: 'PR005', cantidad: 1 }
        ]),
        p_resultado: null
    }
);

if (exito) {
    console.log('Factura creada:', datos);
} else {
    console.error('Error:', mensaje);
}
```

### Actualizar factura

```javascript
const { exito } = await ejecutarSP(
    'sp_actualizar_factura_y_productosporfactura',
    {
        p_numero: 1,
        p_fkidcliente: 2,
        p_fkidvendedor: 1,
        p_productos: JSON.stringify([
            { codigo: 'PR002', cantidad: 3 }
        ]),
        p_resultado: null
    }
);
```

### Eliminar factura

```javascript
const { exito, mensaje } = await ejecutarSP(
    'sp_borrar_factura_y_productosporfactura',
    { p_numero: 1, p_resultado: null }
);

console.log(exito ? 'Eliminada' : `Error: ${mensaje}`);
```

### Ejemplo completo: HTML con tabla de facturas

```html
<!DOCTYPE html>
<html>
<head>
    <title>Facturas (SPs)</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" />
</head>
<body class="container mt-4">
    <h1>Facturas</h1>
    <table class="table table-striped" id="tabla">
        <thead class="table-dark">
            <tr>
                <th>Numero</th><th>Cliente</th><th>Vendedor</th>
                <th>Fecha</th><th>Total</th><th>Productos</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>

    <script>
        const API_SP = 'http://localhost:5035/api/procedimientos/ejecutarsp';

        async function ejecutarSP(nombreSP, parametros = {}) {
            const resp = await fetch(API_SP, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ nombreSP, ...parametros })
            });
            const json = await resp.json();
            if (!resp.ok) return { exito: false, datos: null };
            const res = json.resultados || [];
            if (res.length && res[0].p_resultado) {
                const parsed = typeof res[0].p_resultado === 'string'
                    ? JSON.parse(res[0].p_resultado) : res[0].p_resultado;
                return { exito: true, datos: parsed };
            }
            return { exito: true, datos: res };
        }

        async function cargar() {
            const { exito, datos } = await ejecutarSP(
                'sp_listar_facturas_y_productosporfactura', { p_resultado: null });
            if (!exito) return;

            const tbody = document.querySelector('#tabla tbody');
            tbody.innerHTML = '';
            datos.forEach(f => {
                const prods = f.productos.map(p =>
                    `${p.codigo_producto} x${p.cantidad}`).join(', ');
                tbody.innerHTML += `<tr>
                    <td>${f.numero}</td>
                    <td>${f.nombre_cliente}</td>
                    <td>${f.nombre_vendedor}</td>
                    <td>${f.fecha.substring(0, 10)}</td>
                    <td>$${Number(f.total).toLocaleString()}</td>
                    <td>${prods}</td>
                </tr>`;
            });
        }

        cargar();
    </script>
</body>
</html>
```

---

## Desde Python (requests)

### Funcion generica para llamar SPs

```python
import requests
import json

API_SP = 'http://localhost:5035/api/procedimientos/ejecutarsp'

def ejecutar_sp(nombre_sp, parametros=None):
    """
    Ejecuta un stored procedure via la API.

    Args:
        nombre_sp: nombre del procedimiento
        parametros: dict con los parametros (sin nombreSP)

    Returns:
        tupla (exito, datos_o_mensaje)
    """
    payload = {"nombreSP": nombre_sp}
    if parametros:
        payload.update(parametros)

    resp = requests.post(API_SP, json=payload)
    contenido = resp.json()

    if not resp.ok:
        return (False, contenido.get("mensaje", "Error"))

    resultados = contenido.get("resultados", [])
    if resultados and "p_resultado" in resultados[0]:
        p_resultado = resultados[0]["p_resultado"]
        if isinstance(p_resultado, str):
            return (True, json.loads(p_resultado))
        return (True, p_resultado)

    return (True, contenido)
```

### Listar facturas

```python
exito, datos = ejecutar_sp("sp_listar_facturas_y_productosporfactura", {
    "p_resultado": None
})

if exito:
    for fac in datos:
        print(f"Factura #{fac['numero']} - {fac['nombre_cliente']} - ${fac['total']:,.0f}")
        for prod in fac['productos']:
            print(f"  {prod['codigo_producto']}: {prod['cantidad']} x ${prod['valorunitario']:,.0f}")
```

### Consultar factura especifica

```python
exito, datos = ejecutar_sp("sp_consultar_factura_y_productosporfactura", {
    "p_numero": 1,
    "p_resultado": None
})

if exito:
    fac = datos['factura']
    print(f"Factura #{fac['numero']} - Cliente: {fac['nombre_cliente']}")
    for prod in datos['productos']:
        print(f"  {prod['nombre_producto']}: {prod['cantidad']} unidades")
```

### Insertar factura con productos

```python
exito, datos = ejecutar_sp("sp_insertar_factura_y_productosporfactura", {
    "p_fkidcliente": 1,
    "p_fkidvendedor": 2,
    "p_productos": json.dumps([
        {"codigo": "PR003", "cantidad": 2},
        {"codigo": "PR005", "cantidad": 1}
    ]),
    "p_resultado": None
})

if exito:
    print("Factura creada:", datos)
else:
    print("Error:", datos)
```

### Actualizar factura

```python
exito, datos = ejecutar_sp("sp_actualizar_factura_y_productosporfactura", {
    "p_numero": 1,
    "p_fkidcliente": 2,
    "p_fkidvendedor": 1,
    "p_productos": json.dumps([
        {"codigo": "PR002", "cantidad": 3}
    ]),
    "p_resultado": None
})

print("Actualizada" if exito else f"Error: {datos}")
```

### Eliminar factura

```python
exito, datos = ejecutar_sp("sp_borrar_factura_y_productosporfactura", {
    "p_numero": 1,
    "p_resultado": None
})

print("Eliminada" if exito else f"Error: {datos}")
```

---

## Desde Blazor Server (C#)

### Servicio para ejecutar SPs: Services/SpService.cs

```csharp
using System.Net.Http.Json;
using System.Text.Json;

namespace FrontBlazor.Services;

/// <summary>
/// Servicio para ejecutar stored procedures via la API.
/// </summary>
public class SpService
{
    private readonly HttpClient _http;
    private const string URL = "http://localhost:5035/api/procedimientos/ejecutarsp";

    public SpService(HttpClient http)
    {
        _http = http;
    }

    /// <summary>
    /// Ejecuta un stored procedure y retorna el resultado parseado.
    /// </summary>
    public async Task<(bool exito, JsonElement? datos, string mensaje)> EjecutarSpAsync(
        string nombreSP, Dictionary<string, object?>? parametros = null)
    {
        var payload = new Dictionary<string, object?> { ["nombreSP"] = nombreSP };
        if (parametros != null)
        {
            foreach (var kvp in parametros)
                payload[kvp.Key] = kvp.Value;
        }

        var respuesta = await _http.PostAsJsonAsync(URL, payload);
        var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();

        if (!respuesta.IsSuccessStatusCode)
        {
            var msg = json.TryGetProperty("mensaje", out var m) ? m.GetString() ?? "Error" : "Error";
            return (false, null, msg);
        }

        var mensaje = json.TryGetProperty("mensaje", out var mens)
            ? mens.GetString() ?? "" : "";

        // Extraer p_resultado si existe
        if (json.TryGetProperty("resultados", out var resultados)
            && resultados.GetArrayLength() > 0)
        {
            var primero = resultados[0];
            if (primero.TryGetProperty("p_resultado", out var pResultado))
            {
                // p_resultado puede ser string JSON o ya un objeto
                if (pResultado.ValueKind == JsonValueKind.String)
                {
                    var parsed = JsonDocument.Parse(pResultado.GetString()!).RootElement;
                    return (true, parsed, mensaje);
                }
                return (true, pResultado, mensaje);
            }
        }

        return (true, json, mensaje);
    }
}
```

### Registrar en Program.cs

```csharp
builder.Services.AddHttpClient<SpService>();
```

### Listar facturas

```csharp
var (exito, datos, mensaje) = await Sp.EjecutarSpAsync(
    "sp_listar_facturas_y_productosporfactura",
    new() { ["p_resultado"] = null }
);

if (exito && datos.HasValue)
{
    // datos es un JsonElement (array de facturas)
    foreach (var fac in datos.Value.EnumerateArray())
    {
        var numero = fac.GetProperty("numero").GetInt32();
        var cliente = fac.GetProperty("nombre_cliente").GetString();
        var total = fac.GetProperty("total").GetDecimal();
        Console.WriteLine($"Factura #{numero} - {cliente} - ${total:N0}");
    }
}
```

### Consultar factura especifica

```csharp
var (exito, datos, _) = await Sp.EjecutarSpAsync(
    "sp_consultar_factura_y_productosporfactura",
    new() { ["p_numero"] = 1, ["p_resultado"] = null }
);

if (exito && datos.HasValue)
{
    var factura = datos.Value.GetProperty("factura");
    var productos = datos.Value.GetProperty("productos");

    Console.WriteLine($"Factura #{factura.GetProperty("numero").GetInt32()}");
    Console.WriteLine($"Cliente: {factura.GetProperty("nombre_cliente").GetString()}");

    foreach (var prod in productos.EnumerateArray())
    {
        Console.WriteLine($"  {prod.GetProperty("nombre_producto").GetString()}: " +
                          $"{prod.GetProperty("cantidad").GetInt32()} unidades");
    }
}
```

### Insertar factura con productos

```csharp
using System.Text.Json;

var productos = JsonSerializer.Serialize(new[]
{
    new { codigo = "PR003", cantidad = 2 },
    new { codigo = "PR005", cantidad = 1 }
});

var (exito, datos, mensaje) = await Sp.EjecutarSpAsync(
    "sp_insertar_factura_y_productosporfactura",
    new()
    {
        ["p_fkidcliente"] = 1,
        ["p_fkidvendedor"] = 2,
        ["p_productos"] = productos,
        ["p_resultado"] = null
    }
);

Console.WriteLine(exito ? $"Creada: {datos}" : $"Error: {mensaje}");
```

### Actualizar factura

```csharp
var productos = JsonSerializer.Serialize(new[]
{
    new { codigo = "PR002", cantidad = 3 }
});

var (exito, _, mensaje) = await Sp.EjecutarSpAsync(
    "sp_actualizar_factura_y_productosporfactura",
    new()
    {
        ["p_numero"] = 1,
        ["p_fkidcliente"] = 2,
        ["p_fkidvendedor"] = 1,
        ["p_productos"] = productos,
        ["p_resultado"] = null
    }
);
```

### Eliminar factura

```csharp
var (exito, _, mensaje) = await Sp.EjecutarSpAsync(
    "sp_borrar_factura_y_productosporfactura",
    new() { ["p_numero"] = 1, ["p_resultado"] = null }
);

Console.WriteLine(exito ? "Eliminada" : $"Error: {mensaje}");
```

### Componente Blazor: Pages/Facturas.razor

```razor
@page "/facturas"
@using System.Text.Json
@inject SpService Sp

<h3>Facturas (Stored Procedures)</h3>

@if (!string.IsNullOrEmpty(alerta))
{
    <div class="alert alert-@tipoAlerta alert-dismissible fade show">
        @alerta
        <button type="button" class="btn-close" @onclick="() => alerta = null"></button>
    </div>
}

@if (facturas != null && facturas.Count > 0)
{
    <table class="table table-striped table-hover">
        <thead class="table-dark">
            <tr>
                <th>Numero</th><th>Cliente</th><th>Vendedor</th>
                <th>Fecha</th><th>Total</th><th>Productos</th><th>Acciones</th>
            </tr>
        </thead>
        <tbody>
            @foreach (var fac in facturas)
            {
                <tr>
                    <td>@fac.GetProperty("numero").GetInt32()</td>
                    <td>@fac.GetProperty("nombre_cliente").GetString()</td>
                    <td>@fac.GetProperty("nombre_vendedor").GetString()</td>
                    <td>@fac.GetProperty("fecha").GetString()?[..10]</td>
                    <td>$@fac.GetProperty("total").GetDecimal().ToString("N0")</td>
                    <td>@fac.GetProperty("productos").GetArrayLength()</td>
                    <td>
                        <button class="btn btn-danger btn-sm"
                                @onclick="() => Eliminar(fac.GetProperty(nameof(numero)).GetInt32())">
                            Eliminar
                        </button>
                    </td>
                </tr>
            }
        </tbody>
    </table>
}
else
{
    <div class="alert alert-warning">No se encontraron facturas.</div>
}

@code {
    private List<JsonElement>? facturas;
    private string? alerta;
    private string tipoAlerta = "success";
    private string numero = "numero";

    protected override async Task OnInitializedAsync()
    {
        await Cargar();
    }

    private async Task Cargar()
    {
        var (exito, datos, _) = await Sp.EjecutarSpAsync(
            "sp_listar_facturas_y_productosporfactura",
            new() { ["p_resultado"] = null });

        if (exito && datos.HasValue && datos.Value.ValueKind == JsonValueKind.Array)
            facturas = datos.Value.EnumerateArray().ToList();
        else
            facturas = new();
    }

    private async Task Eliminar(int num)
    {
        var (exito, _, mensaje) = await Sp.EjecutarSpAsync(
            "sp_borrar_factura_y_productosporfactura",
            new() { ["p_numero"] = num, ["p_resultado"] = null });

        alerta = exito ? "Factura eliminada" : $"Error: {mensaje}";
        tipoAlerta = exito ? "success" : "danger";
        if (exito) await Cargar();
    }
}
```

---

## Ejemplos con los 5 SPs de Facturas

Resumen rapido de los 5 stored procedures disponibles para facturas y productosporfactura:

| SP | Parametros IN | Retorna |
|----|--------------|---------|
| `sp_listar_facturas_y_productosporfactura` | (ninguno) | Array de facturas con productos anidados |
| `sp_consultar_factura_y_productosporfactura` | `p_numero` (int) | Objeto {factura, productos} |
| `sp_insertar_factura_y_productosporfactura` | `p_fkidcliente` (int), `p_fkidvendedor` (int), `p_productos` (JSON string), `p_minimo_detalle` (int, opcional, default 1) | Factura creada con productos |
| `sp_actualizar_factura_y_productosporfactura` | `p_numero` (int), `p_fkidcliente` (int), `p_fkidvendedor` (int), `p_productos` (JSON string), `p_minimo_detalle` (int, opcional, default 1) | Factura actualizada |
| `sp_borrar_factura_y_productosporfactura` | `p_numero` (int) | Confirmacion de eliminacion |

> Todos tienen `INOUT p_resultado JSON` que se envia como `null`.

### Formato de p_productos (JSON string)

```json
"[{\"codigo\":\"PR001\",\"cantidad\":2},{\"codigo\":\"PR003\",\"cantidad\":5}]"
```

Cada objeto del array requiere:
- `codigo` → codigo del producto (debe existir en tabla producto)
- `cantidad` → cantidad a facturar (debe haber stock suficiente)

### Parametro p_minimo_detalle (opcional)

Controla el numero minimo de productos que debe tener la factura. Si no se envia, por defecto exige al menos 1 producto.

| Valor enviado | Comportamiento |
|---|---|
| No se envia | Exige minimo 1 producto (default) |
| `"p_minimo_detalle": 3` | Exige minimo 3 productos |
| `"p_minimo_detalle": 5` | Exige minimo 5 productos |

**Ejemplo: Exigir minimo 3 productos**

```json
{
  "nombreSP": "sp_insertar_factura_y_productosporfactura",
  "p_fkidcliente": 1,
  "p_fkidvendedor": 2,
  "p_productos": "[{\"codigo\":\"PR003\",\"cantidad\":2}]",
  "p_minimo_detalle": 3,
  "p_resultado": null
}
```

Respuesta (error porque solo hay 1 producto):

```json
{
  "estado": 500,
  "detalle": "P0001: La factura requiere minimo 3 producto(s)."
}
```

> **Nota tecnica:** La API envia `0` cuando no se incluye `p_minimo_detalle` en el payload. El SP usa `COALESCE(NULLIF(p_minimo_detalle, 0), 1)` para tratar `0` como `1` (default).

### Validacion de stock

El trigger `actualizar_totales_y_stock()` valida automaticamente que haya stock suficiente antes de descontar. Si la cantidad solicitada supera el stock disponible:

```json
{
  "estado": 500,
  "detalle": "P0001: Stock insuficiente para producto PR007. Stock disponible: 9, cantidad solicitada: 100"
}
```

La factura no se crea y el stock queda intacto (transaccion atomica).

### Estructura de respuesta del SP listar

```json
[
  {
    "numero": 1,
    "fecha": "2025-12-03T12:57:19.27592",
    "total": 5000000.00,
    "fkidcliente": 1,
    "nombre_cliente": "Ana Torres",
    "fkidvendedor": 1,
    "nombre_vendedor": "Carlos Perez",
    "productos": [
      {
        "codigo_producto": "PR001",
        "nombre_producto": "Laptop Lenovo IdeaPad",
        "cantidad": 2,
        "valorunitario": 2500000.00,
        "subtotal": 5000000.00
      }
    ]
  }
]
```

### Estructura de respuesta del SP consultar

```json
{
  "factura": {
    "numero": 1,
    "fecha": "2025-12-03T12:57:19.27592",
    "total": 5000000.00,
    "fkidcliente": 1,
    "nombre_cliente": "Ana Torres",
    "fkidvendedor": 1,
    "nombre_vendedor": "Carlos Perez"
  },
  "productos": [
    {
      "codigo_producto": "PR001",
      "nombre_producto": "Laptop Lenovo IdeaPad",
      "cantidad": 2,
      "valorunitario": 2500000.00,
      "subtotal": 5000000.00
    }
  ]
}
```

---

## Parametro camposEncriptar

Permite hashear campos con BCrypt antes de ejecutar el SP. Util para SPs que insertan o actualizan contrasenas.

### Uso

```
POST /api/procedimientos/ejecutarsp?camposEncriptar=contrasena
Content-Type: application/json

{
  "nombreSP": "sp_crear_usuario",
  "p_nombre": "admin",
  "p_contrasena": "miPassword123"
}
```

El campo `p_contrasena` se hasheara automaticamente con BCrypt antes de enviarse al SP.

**Multiples campos:**

```
?camposEncriptar=contrasena,password_confirm
```

---

## Deteccion Automatica FUNCTION vs PROCEDURE

La API consulta `information_schema.routines` para detectar el tipo:

| Tipo | Como ejecuta la API | Ejemplo SQL generado |
|------|---------------------|---------------------|
| **PROCEDURE** | `CALL` (PostgreSQL) / `EXEC` (SQL Server) | `CALL sp_listar_facturas(p_resultado => null)` |
| **FUNCTION** | `SELECT * FROM` | `SELECT * FROM fn_obtener_total(1)` |

**No se necesita indicar el tipo**. La API lo detecta automaticamente.

Si el SP tiene esquema (ej: `public.mi_sp`), tambien lo maneja correctamente.

---

## Codigos de Respuesta

| Codigo | Significado | Cuando ocurre |
|--------|-------------|---------------|
| 200 | OK | SP ejecutado correctamente |
| 400 | Bad Request | Falta `nombreSP`, parametros invalidos, SP no existe en la BD |
| 500 | Server Error | Error en la BD, error de tipos, stock insuficiente, minimo de productos |

### Ejemplo error 400

```json
{
  "error": "El parametro 'nombreSP' es requerido."
}
```

### Ejemplo error 500

```json
{
  "estado": 500,
  "mensaje": "Error interno del servidor al ejecutar procedimiento almacenado.",
  "tipoError": "NpgsqlException",
  "detalle": "function sp_inexistente does not exist",
  "timestamp": "2026-03-12T15:30:45Z",
  "sugerencia": "Revise los logs del servidor para mas detalles."
}
```

---

## Errores Comunes y Soluciones

### 1. "El parametro 'nombreSP' es requerido"

**Causa:** No se envio `nombreSP` en el body o el body esta vacio.

**Solucion:** Asegurarse de incluir `"nombreSP": "nombre_del_sp"` en el JSON.

### 2. "El procedimiento o funcion 'X' no existe en la base de datos"

**Codigo:** 400 Bad Request

**Causa:** El nombre del SP no coincide con lo que existe en la BD.

**Solucion:** Verificar el nombre exacto del SP. Los nombres son case-sensitive en PostgreSQL.

### 3. Error al pasar p_resultado como "" en vez de null

**Causa:** Los parametros `INOUT JSON` de PostgreSQL no aceptan string vacio.

**Solucion:** Enviar `null` (sin comillas), no `""`:

```json
"p_resultado": null     ← CORRECTO
"p_resultado": ""       ← INCORRECTO
```

### 4. Error de stock insuficiente

**Causa:** Se intenta facturar mas cantidad de la que hay en stock.

**Solucion:** Verificar stock antes de insertar/actualizar. El trigger de la BD valida esto automaticamente.

### 5. Error de minimo de productos

**Causa:** La factura no tiene suficientes productos segun `p_minimo_detalle`.

**Solucion:** Agregar mas productos al array `p_productos`, o no enviar `p_minimo_detalle` (default: 1).

### 6. Error de tipo de dato

**Causa:** Se envio un string donde se esperaba un numero, o viceversa.

**Solucion:** Verificar que los tipos coincidan:
- Numeros sin comillas: `"p_numero": 1`
- Textos con comillas: `"p_nombre": "texto"`
- JSON como string: `"p_productos": "[{\"codigo\":\"PR001\"}]"`
- INOUT JSON como null: `"p_resultado": null`

---

Autor: Carlos Arturo Castro Castro
