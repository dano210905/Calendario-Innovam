# Guia de Uso - EntidadesController

Guia practica para consumir el **CRUD generico** de la API desde Swagger, Postman y cualquier frontend.

> **URL base**: `http://localhost:5035`
> **Controlador**: `EntidadesController` → ruta `/api/{tabla}`

---

## Tabla de Contenidos

- [Resumen de Endpoints](#resumen-de-endpoints)
- [Conceptos Clave](#conceptos-clave)
- [1. Listar Registros (GET)](#1-listar-registros-get)
- [2. Filtrar por Clave (GET)](#2-filtrar-por-clave-get)
- [3. Crear Registro (POST)](#3-crear-registro-post)
- [4. Actualizar Registro (PUT)](#4-actualizar-registro-put)
- [5. Eliminar Registro (DELETE)](#5-eliminar-registro-delete)
- [6. Verificar Contrasena (POST)](#6-verificar-contrasena-post)
- [7. Informacion de la API (GET)](#7-informacion-de-la-api-get)
- [Desde Blazor Server (C#)](#desde-blazor-server-c)
- [Codigos de Respuesta](#codigos-de-respuesta)
- [Tablas Disponibles](#tablas-disponibles)

---

## Resumen de Endpoints

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/{tabla}` | Listar todos los registros |
| GET | `/api/{tabla}/{nombreClave}/{valor}` | Filtrar por clave primaria o cualquier campo |
| POST | `/api/{tabla}` | Crear un registro nuevo |
| PUT | `/api/{tabla}/{nombreClave}/{valorClave}` | Actualizar un registro existente |
| DELETE | `/api/{tabla}/{nombreClave}/{valorClave}` | Eliminar un registro |
| POST | `/api/{tabla}/verificar-contrasena` | Verificar contrasena hasheada con BCrypt |
| GET | `/api/info` | Informacion y ayuda del controlador |

**Parametros opcionales en query string:**
- `esquema` → Esquema de la BD (por defecto: `public` en Postgres, `dbo` en SQL Server)
- `limite` → Cantidad maxima de registros a retornar
- `camposEncriptar` → Campos a hashear con BCrypt (separados por coma)

---

## Conceptos Clave

### La API es generica

No hay endpoints fijos por tabla. La misma ruta `/api/{tabla}` sirve para **cualquier tabla** de la base de datos. Solo cambia el nombre de la tabla en la URL:

```
/api/producto     → CRUD de productos
/api/empresa      → CRUD de empresas
/api/cliente      → CRUD de clientes
/api/persona      → CRUD de personas
```

### La clave primaria va en la URL

Para filtrar, actualizar o eliminar, la clave va en la ruta:

```
/api/{tabla}/{nombreDelCampo}/{valorDelCampo}
```

Ejemplo: `/api/producto/codigo/PR001` → el campo `codigo` con valor `PR001`.

### El cuerpo va en JSON

Para crear y actualizar, los datos se envian como JSON en el body. Los nombres de las propiedades deben coincidir **exactamente** con los nombres de las columnas de la tabla.

---

## 1. Listar Registros (GET)

Obtiene todos los registros de una tabla.

### Desde Swagger

1. Abrir `http://localhost:5035/swagger`
2. Buscar **GET** `/api/{tabla}`
3. Click en **Try it out**
4. En `tabla` escribir: `producto`
5. (Opcional) En `limite` escribir: `5`
6. Click en **Execute**

### Desde Postman

```
GET http://localhost:5035/api/producto
```

Con limite:

```
GET http://localhost:5035/api/producto?limite=5
```

### Desde un Frontend (JavaScript fetch)

```javascript
// Listar todos los productos
const respuesta = await fetch('http://localhost:5035/api/producto');
const json = await respuesta.json();
const productos = json.datos;  // Array de objetos

console.log(productos);
// [
//   { "codigo": "PR001", "nombre": "Laptop Lenovo IdeaPad", "stock": 20, "valorunitario": 2500000 },
//   { "codigo": "PR002", "nombre": "Monitor Samsung 24\"", "stock": 30, "valorunitario": 450000 },
//   ...
// ]
```

```javascript
// Con limite
const respuesta = await fetch('http://localhost:5035/api/producto?limite=5');
const json = await respuesta.json();
console.log(`Total: ${json.total}, Registros: ${json.datos.length}`);
```

### Desde un Frontend (Python requests)

```python
import requests

respuesta = requests.get('http://localhost:5035/api/producto')
datos = respuesta.json()
productos = datos.get('datos', [])

for p in productos:
    print(f"{p['codigo']} - {p['nombre']} - Stock: {p['stock']}")
```

### Desde Blazor Server (C#)

```csharp
// En el archivo .razor o en un servicio inyectado
@inject HttpClient Http

@code {
    private List<Dictionary<string, object>>? productos;

    protected override async Task OnInitializedAsync()
    {
        // Listar todos los productos
        var respuesta = await Http.GetFromJsonAsync<JsonElement>(
            "http://localhost:5035/api/producto");

        productos = respuesta.GetProperty("datos")
            .Deserialize<List<Dictionary<string, object>>>();
    }
}
```

Usando un servicio dedicado:

```csharp
// Services/ApiService.cs
using System.Text.Json;

public class ApiService
{
    private readonly HttpClient _http;
    private const string BASE_URL = "http://localhost:5035/api";

    public ApiService(HttpClient http)
    {
        _http = http;
    }

    public async Task<List<Dictionary<string, JsonElement>>> ListarAsync(string tabla, int? limite = null)
    {
        var url = $"{BASE_URL}/{tabla}";
        if (limite.HasValue) url += $"?limite={limite}";

        var respuesta = await _http.GetFromJsonAsync<JsonElement>(url);
        return respuesta.GetProperty("datos")
            .Deserialize<List<Dictionary<string, JsonElement>>>() ?? new();
    }
}
```

Registrar en `Program.cs`:

```csharp
builder.Services.AddHttpClient<ApiService>();
```

### Respuesta exitosa (200)

```json
{
  "tabla": "producto",
  "esquema": "por defecto",
  "limite": "sin limite",
  "total": 7,
  "datos": [
    {
      "codigo": "PR001",
      "nombre": "Laptop Lenovo IdeaPad",
      "stock": 20,
      "valorunitario": 2500000.00
    },
    {
      "codigo": "PR002",
      "nombre": "Monitor Samsung 24\"",
      "stock": 30,
      "valorunitario": 450000.00
    }
  ]
}
```

---

## 2. Filtrar por Clave (GET)

Obtiene registros que coincidan con un campo y valor especifico.

### Desde Swagger

1. Buscar **GET** `/api/{tabla}/{nombreClave}/{valor}`
2. Click en **Try it out**
3. `tabla`: `producto`
4. `nombreClave`: `codigo`
5. `valor`: `PR001`
6. Click en **Execute**

### Desde Postman

```
GET http://localhost:5035/api/producto/codigo/PR001
```

Filtrar por otro campo (no solo clave primaria):

```
GET http://localhost:5035/api/persona/tipodocumento/CC
```

### Desde un Frontend (JavaScript fetch)

```javascript
// Obtener un producto por su codigo
const respuesta = await fetch('http://localhost:5035/api/producto/codigo/PR001');
const json = await respuesta.json();
const producto = json.datos[0];  // Primer (y unico) resultado

console.log(producto.nombre);         // "Laptop Lenovo IdeaPad"
console.log(producto.valorunitario);   // 2500000
```

```javascript
// Filtrar personas por tipo de documento
const respuesta = await fetch('http://localhost:5035/api/persona/tipodocumento/CC');
const json = await respuesta.json();
console.log(`${json.total} personas con CC`);
```

### Desde un Frontend (Python requests)

```python
import requests

# Obtener producto por codigo
resp = requests.get('http://localhost:5035/api/producto/codigo/PR001')
datos = resp.json()
producto = datos['datos'][0]
print(f"{producto['nombre']} → ${producto['valorunitario']:,.0f}")
```

### Desde Blazor Server (C#)

```csharp
// Obtener un producto por su codigo
public async Task<Dictionary<string, JsonElement>?> ObtenerPorClaveAsync(
    string tabla, string nombreClave, string valor)
{
    var url = $"{BASE_URL}/{tabla}/{nombreClave}/{valor}";
    var respuesta = await _http.GetAsync(url);

    if (!respuesta.IsSuccessStatusCode) return null;

    var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
    var datos = json.GetProperty("datos")
        .Deserialize<List<Dictionary<string, JsonElement>>>();

    return datos?.FirstOrDefault();
}

// Uso en un componente .razor
var producto = await Api.ObtenerPorClaveAsync("producto", "codigo", "PR001");
if (producto != null)
{
    var nombre = producto["nombre"].GetString();
    var precio = producto["valorunitario"].GetDecimal();
}
```

### Respuesta exitosa (200)

```json
{
  "tabla": "producto",
  "campo": "codigo",
  "valor": "PR001",
  "total": 1,
  "datos": [
    {
      "codigo": "PR001",
      "nombre": "Laptop Lenovo IdeaPad",
      "stock": 20,
      "valorunitario": 2500000.00
    }
  ]
}
```

### Respuesta no encontrado (404)

```json
{
  "mensaje": "No se encontraron registros en 'producto' donde 'codigo' = 'NOEXISTE'."
}
```

---

## 3. Crear Registro (POST)

Crea un nuevo registro en la tabla. Los datos van en el body como JSON.

### Desde Swagger

1. Buscar **POST** `/api/{tabla}`
2. Click en **Try it out**
3. `tabla`: `producto`
4. En el body JSON escribir:

```json
{
  "codigo": "PR999",
  "nombre": "Teclado Mecanico RGB",
  "stock": 15,
  "valorunitario": 350000
}
```

5. Click en **Execute**

### Desde Postman

```
POST http://localhost:5035/api/producto
Content-Type: application/json

{
  "codigo": "PR999",
  "nombre": "Teclado Mecanico RGB",
  "stock": 15,
  "valorunitario": 350000
}
```

**Con encriptacion de contrasena** (para tabla usuario):

```
POST http://localhost:5035/api/usuario?camposEncriptar=contrasena
Content-Type: application/json

{
  "codusuario": "USR999",
  "nombreusuario": "admin",
  "contrasena": "miPassword123",
  "fkcodpersona": "P001"
}
```

> El campo `contrasena` se guardara hasheado con BCrypt automaticamente.

### Desde un Frontend (JavaScript fetch)

```javascript
// Crear un producto nuevo
const nuevoProducto = {
  codigo: "PR999",
  nombre: "Teclado Mecanico RGB",
  stock: 15,
  valorunitario: 350000
};

const respuesta = await fetch('http://localhost:5035/api/producto', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(nuevoProducto)
});

const json = await respuesta.json();

if (respuesta.ok) {
  console.log('Creado:', json.mensaje);
} else {
  console.error('Error:', json.mensaje);
}
```

```javascript
// Crear usuario con contrasena encriptada
const nuevoUsuario = {
  codusuario: "USR999",
  nombreusuario: "admin",
  contrasena: "miPassword123",
  fkcodpersona: "P001"
};

const respuesta = await fetch('http://localhost:5035/api/usuario?camposEncriptar=contrasena', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(nuevoUsuario)
});
```

### Desde un Frontend (Python requests)

```python
import requests

# Crear producto
nuevo = {
    "codigo": "PR999",
    "nombre": "Teclado Mecanico RGB",
    "stock": 15,
    "valorunitario": 350000
}

resp = requests.post('http://localhost:5035/api/producto', json=nuevo)

if resp.ok:
    print("Creado:", resp.json()['mensaje'])
else:
    print("Error:", resp.json()['mensaje'])
```

```python
# Crear usuario con contrasena encriptada
usuario = {
    "codusuario": "USR999",
    "nombreusuario": "admin",
    "contrasena": "miPassword123",
    "fkcodpersona": "P001"
}

resp = requests.post(
    'http://localhost:5035/api/usuario',
    json=usuario,
    params={"camposEncriptar": "contrasena"}
)
```

### Desde Blazor Server (C#)

```csharp
// Crear un registro
public async Task<(bool exito, string mensaje)> CrearAsync(
    string tabla, Dictionary<string, object> datos, string? camposEncriptar = null)
{
    var url = $"{BASE_URL}/{tabla}";
    if (!string.IsNullOrEmpty(camposEncriptar))
        url += $"?camposEncriptar={camposEncriptar}";

    var respuesta = await _http.PostAsJsonAsync(url, datos);
    var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
    var mensaje = json.GetProperty("mensaje").GetString() ?? "";

    return (respuesta.IsSuccessStatusCode, mensaje);
}

// Uso en un componente .razor
var nuevoProducto = new Dictionary<string, object>
{
    ["codigo"] = "PR999",
    ["nombre"] = "Teclado Mecanico RGB",
    ["stock"] = 15,
    ["valorunitario"] = 350000
};

var (exito, mensaje) = await Api.CrearAsync("producto", nuevoProducto);
```

```csharp
// Crear usuario con contrasena encriptada
var usuario = new Dictionary<string, object>
{
    ["codusuario"] = "USR999",
    ["nombreusuario"] = "admin",
    ["contrasena"] = "miPassword123",
    ["fkcodpersona"] = "P001"
};

var (exito, mensaje) = await Api.CrearAsync("usuario", usuario, "contrasena");
```

### Respuesta exitosa (200)

```json
{
  "mensaje": "Registro creado exitosamente en 'producto'.",
  "tabla": "producto",
  "registroCreado": {
    "codigo": "PR999",
    "nombre": "Teclado Mecanico RGB",
    "stock": 15,
    "valorunitario": 350000
  }
}
```

---

## 4. Actualizar Registro (PUT)

Actualiza un registro existente. La clave primaria va en la URL, los datos a modificar en el body.

**Importante**: En el body solo van los campos que se quieren modificar. No es necesario enviar todos los campos.

### Desde Swagger

1. Buscar **PUT** `/api/{tabla}/{nombreClave}/{valorClave}`
2. Click en **Try it out**
3. `tabla`: `producto`
4. `nombreClave`: `codigo`
5. `valorClave`: `PR999`
6. Body:

```json
{
  "nombre": "Teclado Mecanico RGB Pro",
  "valorunitario": 399000
}
```

7. Click en **Execute**

### Desde Postman

```
PUT http://localhost:5035/api/producto/codigo/PR999
Content-Type: application/json

{
  "nombre": "Teclado Mecanico RGB Pro",
  "valorunitario": 399000
}
```

### Desde un Frontend (JavaScript fetch)

```javascript
// Actualizar solo el precio y nombre del producto PR999
const cambios = {
  nombre: "Teclado Mecanico RGB Pro",
  valorunitario: 399000
};

const respuesta = await fetch('http://localhost:5035/api/producto/codigo/PR999', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(cambios)
});

const json = await respuesta.json();

if (respuesta.ok) {
  console.log('Actualizado:', json.mensaje);
} else {
  console.error('Error:', json.mensaje);
}
```

### Desde un Frontend (Python requests)

```python
import requests

cambios = {
    "nombre": "Teclado Mecanico RGB Pro",
    "valorunitario": 399000
}

resp = requests.put(
    'http://localhost:5035/api/producto/codigo/PR999',
    json=cambios
)

if resp.ok:
    print("Actualizado:", resp.json()['mensaje'])
else:
    print("Error:", resp.json()['mensaje'])
```

### Desde Blazor Server (C#)

```csharp
// Actualizar un registro
public async Task<(bool exito, string mensaje)> ActualizarAsync(
    string tabla, string nombreClave, string valorClave, Dictionary<string, object> datos)
{
    var url = $"{BASE_URL}/{tabla}/{nombreClave}/{valorClave}";
    var respuesta = await _http.PutAsJsonAsync(url, datos);
    var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
    var mensaje = json.GetProperty("mensaje").GetString() ?? "";

    return (respuesta.IsSuccessStatusCode, mensaje);
}

// Uso en un componente .razor
var cambios = new Dictionary<string, object>
{
    ["nombre"] = "Teclado Mecanico RGB Pro",
    ["valorunitario"] = 399000
};

var (exito, mensaje) = await Api.ActualizarAsync("producto", "codigo", "PR999", cambios);
```

### Respuesta exitosa (200)

```json
{
  "mensaje": "Registro actualizado exitosamente en 'producto' donde 'codigo' = 'PR999'.",
  "tabla": "producto",
  "campo": "codigo",
  "valor": "PR999"
}
```

### Respuesta no encontrado (404)

```json
{
  "mensaje": "No se encontro el registro en 'producto' donde 'codigo' = 'PR999'."
}
```

---

## 5. Eliminar Registro (DELETE)

Elimina un registro por su clave primaria.

### Desde Swagger

1. Buscar **DELETE** `/api/{tabla}/{nombreClave}/{valorClave}`
2. Click en **Try it out**
3. `tabla`: `producto`
4. `nombreClave`: `codigo`
5. `valorClave`: `PR999`
6. Click en **Execute**

### Desde Postman

```
DELETE http://localhost:5035/api/producto/codigo/PR999
```

### Desde un Frontend (JavaScript fetch)

```javascript
// Eliminar el producto PR999
const respuesta = await fetch('http://localhost:5035/api/producto/codigo/PR999', {
  method: 'DELETE'
});

const json = await respuesta.json();

if (respuesta.ok) {
  console.log('Eliminado:', json.mensaje);
} else {
  console.error('Error:', json.mensaje);
}
```

### Desde un Frontend (Python requests)

```python
import requests

resp = requests.delete('http://localhost:5035/api/producto/codigo/PR999')

if resp.ok:
    print("Eliminado:", resp.json()['mensaje'])
else:
    print("Error:", resp.json()['mensaje'])
```

### Desde Blazor Server (C#)

```csharp
// Eliminar un registro
public async Task<(bool exito, string mensaje)> EliminarAsync(
    string tabla, string nombreClave, string valorClave)
{
    var url = $"{BASE_URL}/{tabla}/{nombreClave}/{valorClave}";
    var respuesta = await _http.DeleteAsync(url);
    var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
    var mensaje = json.GetProperty("mensaje").GetString() ?? "";

    return (respuesta.IsSuccessStatusCode, mensaje);
}

// Uso en un componente .razor
var (exito, mensaje) = await Api.EliminarAsync("producto", "codigo", "PR999");
```

### Respuesta exitosa (200)

```json
{
  "mensaje": "Registro eliminado exitosamente de 'producto' donde 'codigo' = 'PR999'."
}
```

### Error por clave foranea (409 Conflict)

Si otro registro depende del que se intenta borrar:

```json
{
  "mensaje": "No se puede eliminar: el registro tiene datos relacionados en otra tabla (clave foranea)."
}
```

---

## 6. Verificar Contrasena (POST)

Compara una contrasena en texto plano contra el hash BCrypt almacenado en la BD.

### Desde Swagger

1. Buscar **POST** `/api/{tabla}/verificar-contrasena`
2. Click en **Try it out**
3. `tabla`: `usuario`
4. Body:

```json
{
  "campoUsuario": "nombreusuario",
  "campoContrasena": "contrasena",
  "valorUsuario": "admin",
  "valorContrasena": "miPassword123"
}
```

5. Click en **Execute**

### Desde Postman

```
POST http://localhost:5035/api/usuario/verificar-contrasena
Content-Type: application/json

{
  "campoUsuario": "nombreusuario",
  "campoContrasena": "contrasena",
  "valorUsuario": "admin",
  "valorContrasena": "miPassword123"
}
```

### Desde un Frontend (JavaScript fetch)

```javascript
const credenciales = {
  campoUsuario: "nombreusuario",
  campoContrasena: "contrasena",
  valorUsuario: "admin",
  valorContrasena: "miPassword123"
};

const respuesta = await fetch('http://localhost:5035/api/usuario/verificar-contrasena', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(credenciales)
});

if (respuesta.ok) {
  console.log('Login exitoso');
} else if (respuesta.status === 401) {
  console.log('Contrasena incorrecta');
} else if (respuesta.status === 404) {
  console.log('Usuario no encontrado');
}
```

### Desde un Frontend (Python requests)

```python
import requests

credenciales = {
    "campoUsuario": "nombreusuario",
    "campoContrasena": "contrasena",
    "valorUsuario": "admin",
    "valorContrasena": "miPassword123"
}

resp = requests.post(
    'http://localhost:5035/api/usuario/verificar-contrasena',
    json=credenciales
)

if resp.ok:
    print("Login exitoso")
elif resp.status_code == 401:
    print("Contrasena incorrecta")
elif resp.status_code == 404:
    print("Usuario no encontrado")
```

### Desde Blazor Server (C#)

```csharp
// Verificar contrasena
public async Task<(bool autenticado, string mensaje)> VerificarContrasenaAsync(
    string tabla, string campoUsuario, string campoContrasena,
    string valorUsuario, string valorContrasena)
{
    var url = $"{BASE_URL}/{tabla}/verificar-contrasena";
    var datos = new Dictionary<string, string>
    {
        ["campoUsuario"] = campoUsuario,
        ["campoContrasena"] = campoContrasena,
        ["valorUsuario"] = valorUsuario,
        ["valorContrasena"] = valorContrasena
    };

    var respuesta = await _http.PostAsJsonAsync(url, datos);
    var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
    var mensaje = json.GetProperty("mensaje").GetString() ?? "";

    return (respuesta.IsSuccessStatusCode, mensaje);
}

// Uso en un componente .razor
var (autenticado, mensaje) = await Api.VerificarContrasenaAsync(
    "usuario", "nombreusuario", "contrasena", "admin", "miPassword123");

if (autenticado)
    NavigationManager.NavigateTo("/dashboard");
else
    errorMsg = mensaje;
```

### Respuestas

**200 - Autenticado:**

```json
{
  "mensaje": "Contrasena verificada correctamente.",
  "autenticado": true
}
```

**401 - Contrasena incorrecta:**

```json
{
  "mensaje": "Contrasena incorrecta."
}
```

**404 - Usuario no encontrado:**

```json
{
  "mensaje": "No se encontro el usuario 'admin' en el campo 'nombreusuario' de la tabla 'usuario'."
}
```

---

## 7. Informacion de la API (GET)

Retorna metadata sobre los endpoints disponibles.

### Desde cualquier cliente

```
GET http://localhost:5035/api/info
```

---

## Codigos de Respuesta

| Codigo | Significado | Cuando ocurre |
|--------|-------------|---------------|
| 200 | OK | Operacion exitosa |
| 204 | No Content | La tabla existe pero esta vacia (Listar) |
| 400 | Bad Request | Parametros invalidos, JSON mal formado |
| 403 | Forbidden | Tabla prohibida o politica de seguridad |
| 404 | Not Found | Tabla no existe o registro no encontrado |
| 401 | Unauthorized | Contrasena incorrecta (verificar-contrasena) |
| 409 | Conflict | Violacion de clave foranea al eliminar |
| 500 | Server Error | Error interno del servidor |

---

## Tablas Disponibles

Estas son las tablas de la BD `bdfacturas_postgres_local`:

| Tabla | Clave Primaria | Campos |
|-------|---------------|--------|
| empresa | codigo | codigo, nombre, direccion, telefono |
| persona | codigo | codigo, nombre, tipodocumento, documento, telefono |
| producto | codigo | codigo, nombre, stock, valorunitario |
| rol | id | id, nombre, descripcion |
| ruta | id | id, nombre, url |
| usuario | codusuario | codusuario, nombreusuario, contrasena, fkcodpersona |
| cliente | id | id, credito, fkcodpersona, fkcodempresa |
| vendedor | id | id, carnet, direccion, fkcodpersona |
| factura | numero | numero, fecha, total, fkidcliente, fkidvendedor |
| productosporfactura | id | id, cantidad, subtotal, fknumfactura, fkcodproducto |
| rol_usuario | id | id, fkcodusuario, fkidrol |
| rutarol | id | id, fkidruta, fkidrol |

---

## Ejemplo Completo: CRUD de Producto (ciclo completo)

### Paso 1 - Crear

```
POST http://localhost:5035/api/producto

{
  "codigo": "PR999",
  "nombre": "Mouse Gamer Logitech",
  "stock": 25,
  "valorunitario": 180000
}
```

### Paso 2 - Consultar

```
GET http://localhost:5035/api/producto/codigo/PR999
```

### Paso 3 - Actualizar precio

```
PUT http://localhost:5035/api/producto/codigo/PR999

{
  "valorunitario": 195000
}
```

### Paso 4 - Verificar cambio

```
GET http://localhost:5035/api/producto/codigo/PR999
```

### Paso 5 - Eliminar

```
DELETE http://localhost:5035/api/producto/codigo/PR999
```

### Paso 6 - Confirmar eliminacion

```
GET http://localhost:5035/api/producto/codigo/PR999
→ 404 Not Found
```

---

## Ejemplo Completo desde JavaScript (HTML + fetch)

```html
<!DOCTYPE html>
<html>
<head>
    <title>CRUD Productos</title>
</head>
<body>
    <h1>Productos</h1>
    <table id="tabla">
        <thead>
            <tr><th>Codigo</th><th>Nombre</th><th>Stock</th><th>Precio</th><th>Acciones</th></tr>
        </thead>
        <tbody></tbody>
    </table>

    <h2>Nuevo Producto</h2>
    <form id="formCrear">
        <input name="codigo" placeholder="Codigo" required />
        <input name="nombre" placeholder="Nombre" required />
        <input name="stock" type="number" placeholder="Stock" required />
        <input name="valorunitario" type="number" step="0.01" placeholder="Precio" required />
        <button type="submit">Crear</button>
    </form>

    <script>
        const API = 'http://localhost:5035/api/producto';

        // LISTAR
        async function cargar() {
            const resp = await fetch(API);
            const json = await resp.json();
            const tbody = document.querySelector('#tabla tbody');
            tbody.innerHTML = '';
            json.datos.forEach(p => {
                tbody.innerHTML += `
                    <tr>
                        <td>${p.codigo}</td>
                        <td>${p.nombre}</td>
                        <td>${p.stock}</td>
                        <td>$${p.valorunitario.toLocaleString()}</td>
                        <td>
                            <button onclick="eliminar('${p.codigo}')">Eliminar</button>
                        </td>
                    </tr>`;
            });
        }

        // CREAR
        document.getElementById('formCrear').onsubmit = async (e) => {
            e.preventDefault();
            const form = new FormData(e.target);
            const datos = {
                codigo: form.get('codigo'),
                nombre: form.get('nombre'),
                stock: parseInt(form.get('stock')),
                valorunitario: parseFloat(form.get('valorunitario'))
            };
            const resp = await fetch(API, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(datos)
            });
            const json = await resp.json();
            alert(json.mensaje);
            if (resp.ok) { e.target.reset(); cargar(); }
        };

        // ELIMINAR
        async function eliminar(codigo) {
            if (!confirm(`Eliminar ${codigo}?`)) return;
            const resp = await fetch(`${API}/codigo/${codigo}`, { method: 'DELETE' });
            const json = await resp.json();
            alert(json.mensaje);
            cargar();
        }

        cargar();
    </script>
</body>
</html>
```

---

## Ejemplo Completo desde Python (Flask)

```python
import requests

API = 'http://localhost:5035/api'

# Listar todos los productos
def listar_productos():
    resp = requests.get(f'{API}/producto')
    return resp.json().get('datos', [])

# Obtener un producto por codigo
def obtener_producto(codigo):
    resp = requests.get(f'{API}/producto/codigo/{codigo}')
    if resp.ok:
        return resp.json()['datos'][0]
    return None

# Crear producto
def crear_producto(codigo, nombre, stock, precio):
    datos = {
        "codigo": codigo,
        "nombre": nombre,
        "stock": stock,
        "valorunitario": precio
    }
    resp = requests.post(f'{API}/producto', json=datos)
    return (resp.ok, resp.json().get('mensaje', ''))

# Actualizar producto
def actualizar_producto(codigo, cambios):
    resp = requests.put(f'{API}/producto/codigo/{codigo}', json=cambios)
    return (resp.ok, resp.json().get('mensaje', ''))

# Eliminar producto
def eliminar_producto(codigo):
    resp = requests.delete(f'{API}/producto/codigo/{codigo}')
    return (resp.ok, resp.json().get('mensaje', ''))
```

---

## Desde Blazor Server (C#)

### Configuracion inicial del proyecto

```bash
# Crear proyecto Blazor Server
dotnet new blazorserver -n FrontBlazor
cd FrontBlazor

# No se necesitan paquetes adicionales, HttpClient viene incluido
```

### Servicio completo: Services/ApiService.cs

```csharp
using System.Net.Http.Json;
using System.Text.Json;

namespace FrontBlazor.Services;

/// <summary>
/// Servicio generico para consumir la API REST desde Blazor Server.
/// Equivale a api_service.py en Flask o a fetch() en JavaScript.
/// </summary>
public class ApiService
{
    private readonly HttpClient _http;
    private const string BASE_URL = "http://localhost:5035/api";

    public ApiService(HttpClient http)
    {
        _http = http;
    }

    // ──────────────────────────────────────────────
    // LISTAR: GET /api/{tabla}
    // ──────────────────────────────────────────────
    public async Task<List<Dictionary<string, JsonElement>>> ListarAsync(
        string tabla, int? limite = null)
    {
        var url = $"{BASE_URL}/{tabla}";
        if (limite.HasValue) url += $"?limite={limite}";

        var respuesta = await _http.GetAsync(url);
        if (!respuesta.IsSuccessStatusCode) return new();

        var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
        return json.GetProperty("datos")
            .Deserialize<List<Dictionary<string, JsonElement>>>() ?? new();
    }

    // ──────────────────────────────────────────────
    // OBTENER POR CLAVE: GET /api/{tabla}/{clave}/{valor}
    // ──────────────────────────────────────────────
    public async Task<Dictionary<string, JsonElement>?> ObtenerPorClaveAsync(
        string tabla, string nombreClave, string valor)
    {
        var url = $"{BASE_URL}/{tabla}/{nombreClave}/{valor}";
        var respuesta = await _http.GetAsync(url);
        if (!respuesta.IsSuccessStatusCode) return null;

        var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
        var datos = json.GetProperty("datos")
            .Deserialize<List<Dictionary<string, JsonElement>>>();
        return datos?.FirstOrDefault();
    }

    // ──────────────────────────────────────────────
    // CREAR: POST /api/{tabla}
    // ──────────────────────────────────────────────
    public async Task<(bool exito, string mensaje)> CrearAsync(
        string tabla, Dictionary<string, object> datos, string? camposEncriptar = null)
    {
        var url = $"{BASE_URL}/{tabla}";
        if (!string.IsNullOrEmpty(camposEncriptar))
            url += $"?camposEncriptar={camposEncriptar}";

        var respuesta = await _http.PostAsJsonAsync(url, datos);
        var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
        var mensaje = json.GetProperty("mensaje").GetString() ?? "";
        return (respuesta.IsSuccessStatusCode, mensaje);
    }

    // ──────────────────────────────────────────────
    // ACTUALIZAR: PUT /api/{tabla}/{clave}/{valor}
    // ──────────────────────────────────────────────
    public async Task<(bool exito, string mensaje)> ActualizarAsync(
        string tabla, string nombreClave, string valorClave,
        Dictionary<string, object> datos, string? camposEncriptar = null)
    {
        var url = $"{BASE_URL}/{tabla}/{nombreClave}/{valorClave}";
        if (!string.IsNullOrEmpty(camposEncriptar))
            url += $"?camposEncriptar={camposEncriptar}";

        var respuesta = await _http.PutAsJsonAsync(url, datos);
        var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
        var mensaje = json.GetProperty("mensaje").GetString() ?? "";
        return (respuesta.IsSuccessStatusCode, mensaje);
    }

    // ──────────────────────────────────────────────
    // ELIMINAR: DELETE /api/{tabla}/{clave}/{valor}
    // ──────────────────────────────────────────────
    public async Task<(bool exito, string mensaje)> EliminarAsync(
        string tabla, string nombreClave, string valorClave)
    {
        var url = $"{BASE_URL}/{tabla}/{nombreClave}/{valorClave}";
        var respuesta = await _http.DeleteAsync(url);
        var json = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
        var mensaje = json.GetProperty("mensaje").GetString() ?? "";
        return (respuesta.IsSuccessStatusCode, mensaje);
    }
}
```

### Registro en Program.cs

```csharp
// Registrar HttpClient y ApiService en el contenedor de DI
builder.Services.AddHttpClient<ApiService>();
```

### Componente Blazor: Pages/Productos.razor

```razor
@page "/productos"
@using FrontBlazor.Services
@using System.Text.Json
@inject ApiService Api

<h3>Productos</h3>

@* ───────── ALERTA ───────── *@
@if (!string.IsNullOrEmpty(alerta))
{
    <div class="alert alert-@tipoAlerta alert-dismissible fade show">
        @alerta
        <button type="button" class="btn-close" @onclick="() => alerta = null"></button>
    </div>
}

@* ───────── BOTON NUEVO ───────── *@
@if (!mostrarFormulario)
{
    <button class="btn btn-primary mb-3" @onclick="NuevoProducto">Nuevo Producto</button>
}

@* ───────── FORMULARIO ───────── *@
@if (mostrarFormulario)
{
    <div class="card mb-3">
        <div class="card-header">@(editando ? "Editar Producto" : "Nuevo Producto")</div>
        <div class="card-body">
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Codigo</label>
                    <input class="form-control" @bind="formCodigo" readonly="@editando" />
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Nombre</label>
                    <input class="form-control" @bind="formNombre" />
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Stock</label>
                    <input class="form-control" type="number" @bind="formStock" />
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Valor Unitario</label>
                    <input class="form-control" type="number" step="0.01" @bind="formPrecio" />
                </div>
            </div>
            <button class="btn btn-success me-2" @onclick="Guardar">Guardar</button>
            <button class="btn btn-secondary" @onclick="Cancelar">Cancelar</button>
        </div>
    </div>
}

@* ───────── TABLA ───────── *@
@if (productos != null && productos.Any())
{
    <table class="table table-striped table-hover">
        <thead class="table-dark">
            <tr>
                <th>Codigo</th>
                <th>Nombre</th>
                <th>Stock</th>
                <th>Valor Unitario</th>
                <th>Acciones</th>
            </tr>
        </thead>
        <tbody>
            @foreach (var p in productos)
            {
                <tr>
                    <td>@p["codigo"]</td>
                    <td>@p["nombre"]</td>
                    <td>@p["stock"]</td>
                    <td>$@p["valorunitario"]</td>
                    <td>
                        <button class="btn btn-warning btn-sm me-1"
                                @onclick="() => EditarProducto(p)">Editar</button>
                        <button class="btn btn-danger btn-sm"
                                @onclick="() => EliminarProducto(p[&quot;codigo&quot;].GetString()!)">
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
    <div class="alert alert-warning">No se encontraron productos.</div>
}

@code {
    // Datos
    private List<Dictionary<string, JsonElement>>? productos;
    private string? alerta;
    private string tipoAlerta = "success";

    // Formulario
    private bool mostrarFormulario;
    private bool editando;
    private string formCodigo = "";
    private string formNombre = "";
    private int formStock;
    private decimal formPrecio;

    // Cargar al iniciar
    protected override async Task OnInitializedAsync()
    {
        await CargarProductos();
    }

    private async Task CargarProductos()
    {
        productos = await Api.ListarAsync("producto");
    }

    // Nuevo
    private void NuevoProducto()
    {
        editando = false;
        mostrarFormulario = true;
        formCodigo = ""; formNombre = ""; formStock = 0; formPrecio = 0;
    }

    // Editar
    private void EditarProducto(Dictionary<string, JsonElement> p)
    {
        editando = true;
        mostrarFormulario = true;
        formCodigo = p["codigo"].GetString()!;
        formNombre = p["nombre"].GetString()!;
        formStock = p["stock"].GetInt32();
        formPrecio = p["valorunitario"].GetDecimal();
    }

    // Guardar (crear o actualizar)
    private async Task Guardar()
    {
        bool exito; string mensaje;

        if (editando)
        {
            var cambios = new Dictionary<string, object>
            {
                ["nombre"] = formNombre,
                ["stock"] = formStock,
                ["valorunitario"] = formPrecio
            };
            (exito, mensaje) = await Api.ActualizarAsync("producto", "codigo", formCodigo, cambios);
        }
        else
        {
            var nuevo = new Dictionary<string, object>
            {
                ["codigo"] = formCodigo,
                ["nombre"] = formNombre,
                ["stock"] = formStock,
                ["valorunitario"] = formPrecio
            };
            (exito, mensaje) = await Api.CrearAsync("producto", nuevo);
        }

        alerta = mensaje;
        tipoAlerta = exito ? "success" : "danger";
        if (exito) { mostrarFormulario = false; await CargarProductos(); }
    }

    // Cancelar
    private void Cancelar()
    {
        mostrarFormulario = false;
    }

    // Eliminar
    private async Task EliminarProducto(string codigo)
    {
        var (exito, mensaje) = await Api.EliminarAsync("producto", "codigo", codigo);
        alerta = mensaje;
        tipoAlerta = exito ? "success" : "danger";
        if (exito) await CargarProductos();
    }
}
```

### Estructura del proyecto Blazor Server

```
FrontBlazor/
|-- Pages/
|   |-- Index.razor
|   +-- Productos.razor        ← Componente CRUD
|
|-- Services/
|   +-- ApiService.cs           ← Servicio generico HTTP
|
|-- Shared/
|   |-- MainLayout.razor
|   +-- NavMenu.razor           ← Agregar link a /productos
|
|-- Program.cs                   ← Registrar ApiService
+-- _Imports.razor
```

---

Autor: Carlos Arturo Castro Castro
