# ApiGenericaCsharp - API REST Generica Multi-Base de Datos

![.NET Version](https://img.shields.io/badge/.NET-9.0-blue?logo=dotnet)
![Database](https://img.shields.io/badge/DB-SQL_Server_%7C_Postgres_%7C_MySQL-brightgreen?logo=databricks)
![Auth](https://img.shields.io/badge/Auth-JWT_&_BCrypt-gold?logo=jsonwebtokens)
![Architecture](https://img.shields.io/badge/Architecture-Clean_%26_SOLID-orange)
![License](https://img.shields.io/badge/License-Educativo-lightgrey)

API REST generica para operaciones CRUD sobre cualquier tabla de base de datos. Soporta multiples motores con una sola configuracion.

---

## Analisis de Seguridad, Rendimiento y Buenas Practicas

> Este apartado documenta las vulnerabilidades, problemas de rendimiento y mejoras pendientes
> detectadas en la API. Cada item explica **que es el concepto**, **donde esta el problema**
> y **como se debe solucionar**. Sirve como hoja de ruta para llevar la API a produccion.

---

### 1. Claves y Secretos Expuestos

#### 1.1 JWT Key hardcodeada en appsettings.json

**Que es JWT (JSON Web Token):** Es un estandar para transmitir informacion de autenticacion entre cliente y servidor. El servidor firma el token con una clave secreta; si alguien conoce esa clave, puede crear tokens falsos y hacerse pasar por cualquier usuario.

**Problema:** La clave secreta esta escrita directamente en `appsettings.json`:
```json
"Key": "MySuperSecretKey1234567890!@#$%^&*()"
```
Cualquier persona con acceso al repositorio (publico o privado comprometido) puede forjar tokens y tener acceso total a la API.

**Solucion:** Mover la clave a una **variable de entorno** del sistema operativo, que nunca se sube al repositorio:
```bash
# En el servidor o maquina de desarrollo, definir la variable:
set JWT_SECRET_KEY=MiClaveSecretaReal123456789!@#$
```
```csharp
// En Program.cs, leer desde el entorno:
var jwtKey = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
    ?? throw new InvalidOperationException("JWT_SECRET_KEY no configurada");
```

#### 1.2 Credenciales de base de datos en texto plano

**Que es una connection string:** Es la cadena de texto que contiene servidor, base de datos, usuario y contrasena para conectarse a la BD. Si queda expuesta, cualquiera puede conectarse directamente.

**Problema:** Las connection strings en `appsettings.json` contienen usuarios y contrasenas visibles:
```
"Postgres": "...Username=postgres;Password=postgres;..."
"MariaDB": "...Uid=root;Pwd=;..."
```
Ademas incluyen el nombre de la maquina (`LAPTOP-PRP44KEV`), exponiendo informacion de infraestructura.

**Solucion:** Usar variables de entorno para cada connection string:
```bash
set CONNSTR_SQLSERVER=Server=miservidor;Database=mibd;...
set CONNSTR_POSTGRES=Host=localhost;Port=5432;...
```
```csharp
var connStr = Environment.GetEnvironmentVariable("CONNSTR_SQLSERVER");
```
En entornos cloud, usar servicios de secretos como **Azure Key Vault**, **AWS Secrets Manager** o **Docker Secrets**.

#### 1.3 appsettings.Development.json en el historial de Git

**Que es .gitignore:** Es un archivo que le dice a Git cuales archivos NO debe incluir en el repositorio. Los archivos de configuracion con secretos deben estar en `.gitignore`.

**Problema:** Aunque `appsettings.Development.json` esta en `.gitignore` actualmente, si alguna vez fue commiteado, las credenciales permanecen en el historial de Git para siempre.

**Solucion:**
```bash
# Eliminar del tracking de Git (sin borrar el archivo local):
git rm --cached appsettings.Development.json
# Verificar que .gitignore lo incluya (ya lo tiene)
# Usar: git filter-branch o BFG Repo-Cleaner para limpiar el historial si fue commiteado
```

---

### 2. Endpoints sin Autenticacion

#### Que es un endpoint protegido

**Que es `[Authorize]`:** Es un atributo de ASP.NET que obliga al cliente a enviar un token JWT valido en la cabecera `Authorization: Bearer {token}` para poder acceder al endpoint. Sin el, cualquier persona puede hacer peticiones.

**Que es `[AllowAnonymous]`:** Es el atributo opuesto: permite acceso sin token. Solo debe usarse en endpoints publicos como login o informacion basica.

**Problema actual:**

| Endpoint | Estado actual | Riesgo |
|----------|--------------|--------|
| `POST /api/{tabla}` (crear) | `[AllowAnonymous]` | Cualquiera inserta registros |
| `PUT /api/{tabla}/{clave}/{valor}` (actualizar) | `[AllowAnonymous]` | Cualquiera modifica datos |
| `DELETE /api/{tabla}/{clave}/{valor}` (eliminar) | `[AllowAnonymous]` | Cualquiera borra datos |
| `POST /api/consultas/ejecutarconsultaparametrizada` | `[Authorize]` comentado | Ejecucion libre de SQL |
| `POST /api/procedimientos/ejecutarsp` | `[Authorize]` comentado | Ejecucion libre de SPs |
| `GET /api/diagnostico/conexion` | `[AllowAnonymous]` | Expone version de BD, servidor, usuario |

**Solucion:** Descomentar `[Authorize]` en los endpoints de escritura y consultas. Agregar `[Authorize]` al endpoint de diagnostico o eliminarlo en produccion:
```csharp
[Authorize]  // En vez de [AllowAnonymous]
[HttpPost]
public async Task<IActionResult> CrearAsync(...) { ... }
```

---

### 3. CORS Completamente Abierto

**Que es CORS (Cross-Origin Resource Sharing):** Es un mecanismo de seguridad del navegador que controla desde cuales sitios web se puede llamar a la API. Por ejemplo, si la API esta en `api.miempresa.com`, CORS define si `otraweb.com` puede hacer peticiones.

**Problema:** La politica actual permite peticiones desde **cualquier origen**:
```csharp
opts.AddPolicy("PermitirTodo", politica => politica
    .AllowAnyOrigin()     // Cualquier sitio web del mundo
    .AllowAnyMethod()     // GET, POST, DELETE... todos
    .AllowAnyHeader()     // Cualquier cabecera
);
```
Esto permite que un sitio malicioso haga peticiones a la API desde el navegador de un usuario autenticado.

**Solucion:** Restringir a los origenes conocidos (el frontend real):
```csharp
opts.AddPolicy("MiPolitica", politica => politica
    .WithOrigins("https://mifrontend.com", "http://localhost:3000")  // Solo estos
    .AllowAnyMethod()
    .AllowAnyHeader()
);
```

---

### 4. Problemas de Rendimiento

#### 4.1 Consultas N+1 en metadata de columnas

**Que es el problema N+1:** Ocurre cuando, para procesar N registros, se ejecuta 1 consulta adicional por cada uno. Si se actualizan 10 campos, son 10 consultas extra a `INFORMATION_SCHEMA` para saber el tipo de dato de cada campo.

**Donde ocurre:** En `RepositorioLecturaSqlServer.cs`, el metodo `DetectarTipoColumnaAsync()` se llama una vez por cada campo durante operaciones INSERT y UPDATE.

**Impacto:** Un UPDATE de 10 campos genera 10 queries adicionales solo para saber si cada campo es `int`, `varchar`, `datetime`, etc.

**Solucion:** Cachear los tipos de columna por tabla en memoria, con un tiempo de vida (TTL) de 1 hora:
```csharp
// Cache en memoria: clave = "tabla.columna", valor = tipo de dato
private static ConcurrentDictionary<string, Dictionary<string, string>> _cacheMetadata = new();

// Al inicio del metodo, consultar UNA sola vez todos los tipos:
var tipos = await ObtenerTodosLosTiposAsync(tabla);  // 1 query en vez de N
```

#### 4.2 Sin limite maximo de paginacion

**Que es paginacion:** Es la tecnica de dividir grandes conjuntos de datos en paginas (ej: 50 registros por pagina). Sin paginacion, una tabla de 1 millon de registros se devolveria completa en una sola respuesta, agotando la memoria del servidor.

**Problema:** El limite por defecto es 1000 registros, pero no hay un maximo obligatorio. Un usuario podria solicitar `?limite=999999`.

**Solucion:** Forzar un tope maximo en el controller:
```csharp
if (limite > 500) limite = 500;  // Maximo absoluto
```

#### 4.3 Sin connection pooling en SQL Server y MariaDB

**Que es connection pooling:** Es una tecnica donde se reutilizan conexiones a la BD en vez de crear y destruir una por cada peticion. Crear una conexion es costoso (autenticacion, handshake TCP); el pool mantiene varias abiertas y listas para usar.

**Problema:** Solo PostgreSQL tiene pooling configurado (`Pooling=true;Maximum Pool Size=100`). SQL Server y MariaDB usan el comportamiento por defecto sin limites explicitos.

**Solucion:** Agregar a las connection strings:
```
SQL Server: ...;Max Pool Size=50;
MariaDB:    ...;MaximumPoolSize=50;
```

#### 4.4 Sin cache de respuestas

**Que es response caching:** Es una tecnica donde el servidor guarda en memoria el resultado de una consulta y lo reutiliza durante un tiempo (ej: 5 minutos) sin volver a consultar la BD. Util para datos que cambian poco, como catalogos de productos o roles.

**Problema:** Cada peticion GET golpea la base de datos directamente, incluso si los datos no cambiaron.

**Solucion:** Agregar cache en endpoints de lectura:
```csharp
[ResponseCache(Duration = 300)]  // Cache de 5 minutos
[HttpGet]
public async Task<IActionResult> ObtenerTodosAsync(...) { ... }
```
Para datos que cambian frecuentemente, usar ETags o cache con invalidacion.

#### 4.5 Agotamiento de conexiones bajo carga concurrente

**Que es la concurrencia en una API:** Cuando muchos usuarios hacen peticiones al mismo tiempo, cada peticion necesita una conexion a la BD. Si hay 200 usuarios simultaneos y cada operacion abre 1 conexion + 10 conexiones extra para metadata, son 2.200 conexiones al mismo tiempo. La BD tiene un limite (por defecto ~100-150 conexiones), y cuando se agota, las peticiones empiezan a fallar o quedan en espera.

**Problema:** Cada llamada a `DetectarTipoColumnaAsync()` abre su propia conexion a la BD:

```csharp
// Se ejecuta POR CADA CAMPO en un INSERT o UPDATE
private async Task<SqlDbType?> DetectarTipoColumnaAsync(...)
{
    using var conexion = new SqlConnection(cadena);  // Conexion nueva
    await conexion.OpenAsync();                       // Se abre
    // ... consulta INFORMATION_SCHEMA
}   // Se cierra al salir
```

Si un UPDATE tiene 10 campos, se abren y cierran **11 conexiones** (1 para el UPDATE + 10 para metadata). Con 50 usuarios simultaneos haciendo UPDATE, eso son **550 conexiones** a la vez.

**Escenario critico:**

| Usuarios simultaneos | Operacion | Campos | Conexiones simultaneas |
|---------------------|-----------|--------|----------------------|
| 10 | UPDATE | 10 | 110 |
| 50 | UPDATE | 10 | 550 |
| 100 | INSERT | 8 | 900 |
| 100 | UPDATE | 10 | 1.100 |

SQL Server por defecto permite ~32.767 conexiones, pero el pool por defecto es de 100. MariaDB permite ~151.

**Solucion combinada:**

1. **Cachear metadata** (elimina las 10 conexiones extra por operacion):
```csharp
private static ConcurrentDictionary<string, Dictionary<string, SqlDbType>> _cacheMetadata = new();

private async Task<Dictionary<string, SqlDbType>> ObtenerTiposTablaAsync(string tabla, string esquema)
{
    string cacheKey = $"{esquema}.{tabla}";
    if (_cacheMetadata.TryGetValue(cacheKey, out var cached))
        return cached;  // Ya lo tenemos, 0 conexiones extra

    // Si no esta en cache, consultar UNA vez todos los tipos de la tabla
    string sql = "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE ...";
    // ... una sola conexion para todos los campos
    _cacheMetadata[cacheKey] = resultado;
    return resultado;
}
```

2. **Reutilizar la conexion dentro del mismo metodo** (en vez de abrir una nueva por campo):
```csharp
// ANTES (mal): N+1 conexiones
foreach (var campo in campos)
{
    var tipo = await DetectarTipoColumnaAsync(tabla, esquema, campo);  // Conexion nueva cada vez
}

// DESPUES (bien): 1 conexion compartida
using var conexion = new SqlConnection(cadena);
await conexion.OpenAsync();
var todosLosTipos = await ObtenerTiposTablaAsync(conexion, tabla);  // Reutiliza la conexion
foreach (var campo in campos)
{
    var tipo = todosLosTipos[campo];  // Sin conexion extra
}
```

3. **Configurar pool size** en las connection strings:
```
SQL Server: ...;Max Pool Size=200;Min Pool Size=10;
MariaDB:    ...;MaximumPoolSize=200;MinimumPoolSize=10;
PostgreSQL: ...;Maximum Pool Size=200;Minimum Pool Size=10;
```

Con estas 3 soluciones, los mismos 100 usuarios haciendo UPDATE pasan de **1.100 conexiones** a **100 conexiones** (1 por usuario).

#### 4.6 Timeout de 300 segundos en SPs y consultas

**Que es un CommandTimeout:** Es el tiempo maximo que el servidor espera a que una consulta termine antes de cancelarla. Si una consulta tarda mas, se aborta.

**Problema:** Los stored procedures y consultas parametrizadas tienen un timeout de **300 segundos (5 minutos)**:
```csharp
comando.CommandTimeout = 300;  // 5 minutos esperando
```

Si un SP queda en deadlock o ejecuta una consulta muy pesada, la conexion queda ocupada 5 minutos. Con 20 peticiones atascadas, son 20 conexiones del pool bloqueadas durante 5 minutos, lo que puede agotar el pool para los demas usuarios.

**Solucion:** Reducir a un timeout razonable (30-60 segundos) y hacer el valor configurable:
```json
// En appsettings.json:
"CommandTimeoutSegundos": 30
```
```csharp
comando.CommandTimeout = _config.GetValue<int>("CommandTimeoutSegundos", 30);
```

#### 4.7 Sin limite de peticiones concurrentes (Throttling)

**Que es throttling:** Es limitar la cantidad de peticiones que la API acepta por segundo para proteger la BD. Sin throttling, un solo cliente puede enviar miles de peticiones y saturar el servidor para todos los demas.

**Problema:** La API no tiene ningun limite de concurrencia. Un script automatizado puede enviar 10.000 peticiones por segundo y colapsar la BD.

**Solucion:** Usar el middleware de rate limiting de ASP.NET:
```csharp
builder.Services.AddRateLimiter(options => {
    // Maximo 100 peticiones por minuto por IP
    options.AddFixedWindowLimiter("general", opt => {
        opt.PermitLimit = 100;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueLimit = 10;  // Encolar hasta 10, rechazar el resto
    });
});

app.UseRateLimiter();
```

---

### 5. Informacion Sensible en Errores

**Que es un stack trace:** Es la traza completa del error que muestra nombres de archivos, numeros de linea, nombres de metodos y rutas internas del servidor. Es util para el desarrollador pero peligroso si lo ve un atacante, porque revela la estructura interna del codigo.

**Problema:** Los errores 500 devuelven el stack trace completo al cliente:
```json
{
  "detalleCompleto": "SqlException at ApiGenericaCsharp.Repositorios.RepositorioLectura...",
  "errorInterno": "Inner exception message...",
  "tipoError": "SqlException"
}
```
Esto le dice al atacante que archivos existen, que clases se usan y donde buscar vulnerabilidades.

**Solucion:** Registrar el error completo en los logs del servidor (para que el desarrollador lo vea), pero devolver un mensaje generico al cliente:
```csharp
// En produccion:
_logger.LogError(ex, "Error en {metodo}", nombreMetodo);  // Log interno
return StatusCode(500, new { mensaje = "Error interno del servidor" });  // Cliente
```

---

### 6. Sin Proteccion contra Fuerza Bruta

**Que es un ataque de fuerza bruta:** Es cuando un atacante intenta miles de combinaciones de usuario/contrasena automaticamente hasta encontrar la correcta. Sin limite de intentos, el atacante puede probar indefinidamente.

**Problema:** El endpoint `POST /api/autenticacion/token` no tiene:
- **Rate limiting**: Limitar la cantidad de peticiones por IP por minuto
- **Account lockout**: Bloquear la cuenta despues de N intentos fallidos
- **CAPTCHA**: Verificar que es un humano y no un script automatizado

**Solucion:** Implementar rate limiting con el middleware de ASP.NET:
```csharp
// En Program.cs:
builder.Services.AddRateLimiter(options => {
    options.AddFixedWindowLimiter("login", opt => {
        opt.PermitLimit = 5;           // Maximo 5 intentos
        opt.Window = TimeSpan.FromMinutes(1);  // Por minuto
    });
});

// En el controller:
[EnableRateLimiting("login")]
[HttpPost("token")]
public async Task<IActionResult> Login(...) { ... }
```

---

### 7. Headers de Seguridad HTTP Faltantes

**Que son los security headers:** Son cabeceras HTTP que el servidor envia al navegador para activar protecciones contra ataques comunes como clickjacking, sniffing de tipos MIME o inyeccion de scripts.

**Problema:** La API no envia ninguno de estos headers de proteccion.

| Header | Que previene |
|--------|-------------|
| `X-Content-Type-Options: nosniff` | Evita que el navegador "adivine" el tipo de archivo (MIME sniffing). Sin este header, un archivo malicioso podria ejecutarse como JavaScript |
| `X-Frame-Options: DENY` | Evita **clickjacking**: que un sitio malicioso cargue la API dentro de un iframe invisible para engañar al usuario |
| `X-XSS-Protection: 1; mode=block` | Activa el filtro anti-XSS del navegador que bloquea paginas si detecta inyeccion de scripts |
| `Strict-Transport-Security` | Obliga al navegador a usar siempre HTTPS, evitando que un atacante intercepte la conexion (man-in-the-middle) |
| `Content-Security-Policy` | Define de donde puede cargar scripts, estilos e imagenes. Previene inyeccion de recursos maliciosos |

**Solucion:** Agregar un middleware en `Program.cs`:
```csharp
app.Use(async (context, next) => {
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
    context.Response.Headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
    await next();
});
```

---

### 8. Modelo de Seguridad Generico

#### 8.1 Blacklist vs Whitelist de tablas

**Que es blacklist vs whitelist:**
- **Blacklist (lista negra):** "Todo esta permitido excepto lo que prohibo". Si se crea una tabla nueva, queda automaticamente accesible.
- **Whitelist (lista blanca):** "Todo esta prohibido excepto lo que permito". Si se crea una tabla nueva, no es accesible hasta que se agregue a la lista.

**Problema:** La API usa blacklist (`TablasProhibidas: []` vacia). Esto significa que cualquier tabla nueva queda expuesta automaticamente via los endpoints CRUD.

**Solucion:** Cambiar a whitelist (tablas permitidas):
```json
"TablasPermitidas": ["producto", "cliente", "factura", "persona", "empresa"]
```

#### 8.2 Sin control de acceso por tabla/campo/fila

**Problema actual:**
- Un usuario autenticado puede leer/escribir **cualquier** tabla permitida
- No hay restriccion por campos (ej: ocultar el campo `contrasena`)
- No hay restriccion por filas (ej: un cliente solo ve sus propias facturas)

**Solucion a largo plazo:** Implementar RBAC (Role-Based Access Control) donde cada rol tiene permisos especificos por tabla y operacion. La tabla `rutarol` ya maneja permisos por ruta del frontend; se podria extender para las rutas de la API.

---

### 9. Sin Auditoria Persistente

**Que es una tabla de auditoria:** Es un registro permanente de todas las operaciones importantes: quien hizo que, sobre cual tabla, que valores cambio y cuando. Es fundamental para cumplimiento normativo (GDPR, SOX) y para investigar incidentes.

**Problema:** La API tiene logs en consola (`_logger.LogInformation`), pero no persiste auditoria en la BD. Si se reinicia el servidor, se pierde el historial.

**Solucion:** Crear una tabla de auditoria y registrar cada operacion de escritura:
```sql
CREATE TABLE auditoria (
    id SERIAL PRIMARY KEY,
    usuario VARCHAR(100),
    tabla VARCHAR(100),
    operacion VARCHAR(10),       -- INSERT, UPDATE, DELETE
    datos_anteriores JSON,
    datos_nuevos JSON,
    fecha TIMESTAMP DEFAULT NOW()
);
```

---

### 10. Sin Operaciones Masivas (Bulk)

**Que son las operaciones masivas (bulk):** Son endpoints que permiten crear, actualizar o eliminar **multiples registros en una sola peticion HTTP**. En vez de enviar 100 peticiones para insertar 100 productos, se envia 1 peticion con un array de 100 productos.

**Problema:** La API solo maneja **un registro a la vez**:

| Operacion | Endpoint actual | Registros por peticion |
|-----------|----------------|----------------------|
| Crear | `POST /api/{tabla}` | 1 |
| Actualizar | `PUT /api/{tabla}/{clave}/{valor}` | 1 |
| Eliminar | `DELETE /api/{tabla}/{clave}/{valor}` | 1 |

**Impacto:** Si un frontend necesita insertar 100 productos:

| Enfoque | Peticiones HTTP | Conexiones a BD | Tiempo aprox. |
|---------|----------------|-----------------|---------------|
| Sin bulk (actual) | 100 | 100+ (con N+1 metadata) | ~10-30 seg |
| Con bulk | 1 | 1 | ~0.2 seg |

Cada peticion HTTP tiene overhead: conexion TCP, headers, autenticacion JWT, apertura de conexion a BD, consultas de metadata. Multiplicado por 100, el costo es enorme.

**Solucion:** Agregar 3 endpoints masivos que reciban arrays y ejecuten todo en una sola transaccion:

```
POST   /api/{tabla}/bulk         - Crear multiples registros
PUT    /api/{tabla}/bulk         - Actualizar multiples registros
DELETE /api/{tabla}/bulk         - Eliminar multiples registros
```

**Ejemplo de uso - Crear masivo:**
```http
POST /api/producto/bulk
Authorization: Bearer {token}
Content-Type: application/json

[
  { "codigo": "PR010", "nombre": "Mouse Gamer", "stock": 50, "valorunitario": 120000 },
  { "codigo": "PR011", "nombre": "Teclado Mecanico", "stock": 30, "valorunitario": 250000 },
  { "codigo": "PR012", "nombre": "Monitor 27 pulgadas", "stock": 15, "valorunitario": 900000 }
]
```

**Ejemplo de respuesta:**
```json
{
  "tabla": "producto",
  "operacion": "bulk_insert",
  "total_recibidos": 3,
  "total_insertados": 3,
  "errores": []
}
```

**Ejemplo de uso - Actualizar masivo:**
```http
PUT /api/producto/bulk
Authorization: Bearer {token}
Content-Type: application/json

{
  "clave": "codigo",
  "registros": [
    { "codigo": "PR010", "stock": 45 },
    { "codigo": "PR011", "stock": 28, "valorunitario": 260000 }
  ]
}
```

**Ejemplo de uso - Eliminar masivo:**
```http
DELETE /api/producto/bulk
Authorization: Bearer {token}
Content-Type: application/json

{
  "clave": "codigo",
  "valores": ["PR010", "PR011", "PR012"]
}
```

**Consideraciones de implementacion:**
- Usar una **transaccion** (`BEGIN TRANSACTION / COMMIT / ROLLBACK`) para que si falla uno, se reviertan todos
- Establecer un **limite maximo** de registros por peticion (ej: 1000) para evitar abuse
- Retornar un **reporte detallado** con cuantos se procesaron y cuales fallaron
- En la BD, usar `INSERT INTO ... VALUES (...), (...), (...)` en una sola sentencia en vez de N inserts separados (mucho mas rapido)

**Implementacion sugerida en el repositorio:**
```csharp
// Una sola conexion, una sola transaccion, N registros
public async Task<BulkResult> CrearMasivoAsync(string tabla, List<Dictionary<string, object?>> registros)
{
    using var conexion = new SqlConnection(cadena);
    await conexion.OpenAsync();
    using var transaccion = conexion.BeginTransaction();

    try
    {
        foreach (var registro in registros)
        {
            // INSERT con la misma conexion y transaccion
            await InsertarRegistroAsync(conexion, transaccion, tabla, registro);
        }
        await transaccion.CommitAsync();
        return new BulkResult { Exitosos = registros.Count };
    }
    catch
    {
        await transaccion.RollbackAsync();  // Revertir todo si falla uno
        throw;
    }
}
```

---

### 11. Documentacion Swagger Expuesta en Produccion

**Que es Swagger/OpenAPI:** Es la interfaz grafica que documenta todos los endpoints de la API, como llamarlos y que parametros reciben.

**Problema:** En `Program.cs`, el middleware `app.UseSwaggerUI()` se ejecuta siempre, sin importar el entorno. En produccion, esto le da a cualquier atacante un "mapa" exacto de la API (endpoints, metodos, esquemas), facilitando la busqueda de vulnerabilidades.

**Solucion:** Restringir Swagger y ReDoc solo al entorno de desarrollo:

```csharp
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.UseSwagger();
    app.UseSwaggerUI(c => ...);
    app.UseReDoc(c => ...);
}
```

---

### 12. Inyeccion SQL en Nombres de Tablas/Columnas

**Que es la inyeccion SQL estructural:** Las consultas parametrizadas (`@param`) protegen los valores, pero en SQL estandar no se pueden parametrizar los nombres de tablas ni de columnas.

**Problema:** Al ser una API generica (`/api/{tabla}`), si un atacante envia una peticion a `/api/producto; DROP TABLE usuarios--` y el codigo concatena el nombre directamente en el SQL (`SELECT * FROM {tabla}`), la base de datos podria ejecutar el comando malicioso.

**Relacion con item 8.1:** La whitelist de tablas ya previene este ataque para tablas. Sin embargo, aplicar validacion por regex como defensa adicional (defense-in-depth) sobre todos los identificadores (tablas, columnas, esquemas) es la practica recomendada:

```csharp
// Validar que el nombre solo contenga letras, numeros y guiones bajos:
if (!Regex.IsMatch(tabla, @"^[a-zA-Z0-9_]+$"))
{
    throw new ArgumentException("Nombre de tabla invalido");
}
```

---

### 13. Falta de Endpoints de Salud (Health Checks)

**Que son los Health Checks:** Son endpoints ligeros (usualmente `/health`) que devuelven `200 OK` si la API y la base de datos estan funcionando correctamente.

**Problema:** Si la API se despliega en Docker, Kubernetes o detras de un balanceador de carga, la infraestructura no tiene una forma estandarizada de saber si la aplicacion se cayo o perdio conexion con la BD para reiniciarla automaticamente.

**Solucion:** Habilitar el middleware nativo de ASP.NET Core:

```csharp
// En Program.cs (servicios):
builder.Services.AddHealthChecks()
       .AddSqlServer(builder.Configuration.GetConnectionString("SqlServer"));

// En Program.cs (middleware):
app.MapHealthChecks("/health");
```

---

### 14. Compresion de Respuestas Desactivada

**Que es Response Compression:** Permite que el servidor comprima (usando GZIP o Brotli) el JSON antes de enviarlo por la red, y el cliente lo descomprime al recibirlo.

**Problema:** Un endpoint `/api/productos` que devuelva 10.000 registros puede pesar 5 MB en texto plano. Sin compresion, las respuestas consumen mucho ancho de banda y hacen que la API sea lenta en conexiones moviles o inestables.

**Solucion:** Agregar el middleware de compresion para reducir el tamano hasta en un 80%:

```csharp
// En Program.cs (servicios):
builder.Services.AddResponseCompression(options => {
    options.EnableForHttps = true;
});

// En Program.cs (middleware - antes de los controllers):
app.UseResponseCompression();
```

---

### 15. Sin Soporte para Refresh Tokens

**Que es un Refresh Token:** Los tokens JWT deben tener un tiempo de vida corto (15-60 min) por seguridad. Un Refresh Token permite obtener un nuevo JWT sin que el usuario tenga que volver a escribir su contrasena, mejorando la experiencia de usuario.

**Problema:** La configuracion actual de JWT solo emite un token valido por 60 minutos. Cuando expira, las peticiones del frontend fallan con `401 Unauthorized`, forzando al usuario a iniciar sesion abruptamente en medio de su trabajo.

**Solucion:**

1. Generar un `RefreshToken` (cadena aleatoria larga) en el Login y guardarlo en la BD junto con el usuario y su fecha de expiracion (ej. 7 dias).
2. Crear un endpoint `POST /api/autenticacion/refresh` que reciba el token expirado y el RefreshToken, los valide, y devuelva un nuevo par de tokens.

```csharp
// Estructura de la tabla refresh_tokens:
// CREATE TABLE refresh_tokens (
//     id INT PRIMARY KEY IDENTITY,
//     usuario VARCHAR(100),
//     token VARCHAR(500),
//     expira DATETIME,
//     revocado BIT DEFAULT 0
// );
```

---

### 16. Ausencia de Versionado de API

**Que es el versionado:** Es la practica de incluir la version en la URL (ej. `/api/v1/producto`) o en los headers.

**Problema:** Si en el futuro se cambia la estructura de respuesta JSON o los nombres de las rutas, se romperan todas las aplicaciones frontend o moviles existentes que consumen la API actual.

**Solucion:** Implementar `Microsoft.AspNetCore.Mvc.Versioning` para asegurar compatibilidad hacia atras:

```csharp
builder.Services.AddApiVersioning(config => {
    config.DefaultApiVersion = new ApiVersion(1, 0);
    config.AssumeDefaultVersionWhenUnspecified = true;
});
// Y cambiar los controllers a:
// [Route("api/v{version:apiVersion}/[controller]")]
```

---

### 17. Como Agregar un Nuevo Motor de Base de Datos (ej: Oracle)

**Que es la inyeccion de dependencias (DI):** Es un patron donde las clases no crean sus dependencias directamente, sino que las reciben "inyectadas" desde afuera. En esta API, los controllers no saben si estan hablando con SQL Server, PostgreSQL u Oracle. Solo conocen la **interface** (`IRepositorioLecturaTabla`). Al arrancar la aplicacion, `Program.cs` decide cual implementacion concreta inyectar segun la configuracion.

**Como funciona actualmente:** En `Program.cs` hay un `switch` que lee `DatabaseProvider` del JSON y registra los repositorios correspondientes:

```csharp
switch (proveedorBD.ToLower())
{
    case "postgres":
        builder.Services.AddScoped<IRepositorioLecturaTabla, RepositorioLecturaPostgreSQL>();
        builder.Services.AddScoped<IRepositorioConsultas, RepositorioConsultasPostgreSQL>();
        break;
    case "mariadb":
    case "mysql":
        builder.Services.AddScoped<IRepositorioLecturaTabla, RepositorioLecturaMysqlMariaDB>();
        builder.Services.AddScoped<IRepositorioConsultas, RepositorioConsultasMysqlMariaDB>();
        break;
    case "sqlserver":
    default:
        builder.Services.AddScoped<IRepositorioLecturaTabla, RepositorioLecturaSqlServer>();
        builder.Services.AddScoped<IRepositorioConsultas, RepositorioConsultasSqlServer>();
        break;
}
```

Gracias a este patron, agregar Oracle (o cualquier otro motor) no requiere tocar ningun controller ni servicio existente. Solo se crean archivos nuevos y se agrega un `case` al switch.

#### Paso a paso para agregar Oracle

**Paso 1: Instalar el paquete NuGet de Oracle**

```bash
dotnet add package Oracle.ManagedDataAccess.Core
```

**Paso 2: Agregar la connection string en appsettings.json (y Development.json)**

```json
"ConnectionStrings": {
    "SqlServer": "...",
    "Postgres": "...",
    "MariaDB": "...",
    "Oracle": "Data Source=localhost:1521/XEPDB1;User Id=miusuario;Password=mipassword;"
},
"DatabaseProvider": "Oracle"
```

**Paso 3: Crear el repositorio de lectura** (`Repositorios/RepositorioLecturaOracle.cs`)

Este archivo implementa la interface `IRepositorioLecturaTabla` usando `OracleConnection` en vez de `SqlConnection`:

```csharp
using Oracle.ManagedDataAccess.Client;
using ApiGenericaCsharp.Repositorios.Abstracciones;
using ApiGenericaCsharp.Servicios.Abstracciones;

namespace ApiGenericaCsharp.Repositorios
{
    public class RepositorioLecturaOracle : IRepositorioLecturaTabla
    {
        private readonly IProveedorConexion _proveedorConexion;

        public RepositorioLecturaOracle(IProveedorConexion proveedorConexion)
        {
            _proveedorConexion = proveedorConexion;
        }

        public async Task<IReadOnlyList<Dictionary<string, object?>>> ObtenerFilasAsync(
            string nombreTabla, string? esquema, int? limite)
        {
            var cadena = _proveedorConexion.ObtenerCadenaConexion();
            var resultado = new List<Dictionary<string, object?>>();
            string esquemaFinal = esquema ?? "MI_ESQUEMA";

            // Oracle usa FETCH FIRST en vez de TOP o LIMIT
            string sql = limite.HasValue
                ? $"SELECT * FROM \"{esquemaFinal}\".\"{nombreTabla}\" FETCH FIRST {limite} ROWS ONLY"
                : $"SELECT * FROM \"{esquemaFinal}\".\"{nombreTabla}\"";

            await using var conexion = new OracleConnection(cadena);
            await conexion.OpenAsync();
            await using var comando = new OracleCommand(sql, conexion);
            await using var lector = await comando.ExecuteReaderAsync();

            while (await lector.ReadAsync())
            {
                var fila = new Dictionary<string, object?>();
                for (int i = 0; i < lector.FieldCount; i++)
                    fila[lector.GetName(i)] = lector.IsDBNull(i) ? null : lector.GetValue(i);
                resultado.Add(fila);
            }
            return resultado;
        }

        // ... implementar los demas metodos de IRepositorioLecturaTabla
        // (ObtenerPorClaveAsync, CrearAsync, ActualizarAsync, EliminarAsync, etc.)
    }
}
```

**Paso 4: Crear el repositorio de consultas** (`Repositorios/RepositorioConsultasOracle.cs`)

Implementa `IRepositorioConsultas` para ejecutar SQL parametrizado y stored procedures con sintaxis Oracle:

```csharp
public class RepositorioConsultasOracle : IRepositorioConsultas
{
    // Oracle usa :parametro en vez de @parametro
    // Oracle usa CALL o BEGIN...END para stored procedures
    // Oracle usa USER_TAB_COLUMNS en vez de INFORMATION_SCHEMA
    // ... implementar los metodos de IRepositorioConsultas
}
```

**Paso 5: Registrar en Program.cs** (agregar un case al switch)

```csharp
case "oracle":
    builder.Services.AddScoped<IRepositorioLecturaTabla, RepositorioLecturaOracle>();
    builder.Services.AddScoped<IRepositorioConsultas, RepositorioConsultasOracle>();
    break;
```

**Paso 6: Registrar en ProveedorConexion.cs** (para que resuelva la connection string)

Agregar `"oracle"` al metodo que selecciona la cadena de conexion segun el provider.

#### Diferencias de sintaxis por motor

Al implementar los repositorios de Oracle (o cualquier otro motor), hay que adaptar la sintaxis SQL:

| Concepto | SQL Server | PostgreSQL | MySQL/MariaDB | Oracle |
|----------|-----------|-----------|---------------|--------|
| Paginacion | `TOP N` | `LIMIT N` | `LIMIT N` | `FETCH FIRST N ROWS ONLY` |
| Autoincremental | `IDENTITY(1,1)` | `SERIAL` | `AUTO_INCREMENT` | `GENERATED ALWAYS AS IDENTITY` |
| Parametros | `@nombre` | `$1, $2` | `@nombre` | `:nombre` |
| Concatenar strings | `+` | `\|\|` | `CONCAT()` | `\|\|` |
| Schema por defecto | `dbo` | `public` | (base de datos) | (usuario) |
| Metadata de tablas | `INFORMATION_SCHEMA` | `INFORMATION_SCHEMA` | `INFORMATION_SCHEMA` | `USER_TAB_COLUMNS` |
| Ejecutar SP | `EXEC sp` | `CALL sp()` | `CALL sp()` | `BEGIN sp(); END;` |
| Tipo JSON | `NVARCHAR(MAX)` | `JSON / JSONB` | `JSON` | `CLOB` o `JSON` (21c+) |

#### Que archivos hay que tocar vs cuales NO

| Archivo | Hay que modificar? | Motivo |
|---------|-------------------|--------|
| `appsettings.json` | Si | Agregar connection string de Oracle |
| `Program.cs` | Si | Agregar `case "oracle"` al switch |
| `ProveedorConexion.cs` | Si | Agregar resolucion de la cadena Oracle |
| `RepositorioLecturaOracle.cs` | **Crear nuevo** | Implementar `IRepositorioLecturaTabla` |
| `RepositorioConsultasOracle.cs` | **Crear nuevo** | Implementar `IRepositorioConsultas` |
| Controllers | **No** | No saben que motor se usa (DIP) |
| Servicios | **No** | Dependen de interfaces, no de implementaciones |
| Otros repositorios | **No** | Cada motor es independiente |

Este es el beneficio del **Principio de Abierto/Cerrado (OCP)**: la API esta **abierta para extension** (agregar Oracle) pero **cerrada para modificacion** (no se tocan controllers, servicios ni repositorios existentes).

---

### 18. Uso Empresarial: Arquitectura Hibrida (Generico + Dedicado)

#### Para que sirve esta API hoy

Esta API es un **motor generico CRUD**: recibe el nombre de una tabla, arma el SQL dinamicamente y ejecuta. Esto es muy poderoso para:

- **Prototipos rapidos**: Levantar un backend funcional en minutos sin escribir un controller por cada tabla
- **Paneles de administracion**: Donde se necesita CRUD basico sobre muchas tablas (ABM de roles, rutas, empresas, personas)
- **Tablas auxiliares**: Catálogos, configuraciones, parametros del sistema que cambian poco

Sin embargo, para **tablas criticas del negocio** con alta concurrencia (facturas, pedidos, transacciones financieras), el enfoque generico tiene limitaciones:

| Aspecto | API Generica | Controller Dedicado |
|---------|-------------|-------------------|
| Velocidad de desarrollo | Inmediata (0 codigo) | Requiere escribir controller, servicio, repositorio |
| Validacion de negocio | Solo valida tipos de datos | Puede validar reglas complejas (stock suficiente, credito disponible, fechas validas) |
| Rendimiento | Consulta metadata en cada operacion | Conoce los tipos en tiempo de compilacion, sin queries extra |
| SQL generado | Dinamico, generico | Optimizado para cada caso, puede usar JOINs, subconsultas |
| Transacciones | Una tabla a la vez | Puede abarcar multiples tablas en una transaccion |
| Cache | Dificil (no sabe que datos cambian poco) | Facil (sabe exactamente que cachear) |
| Testing | Dificil de testear reglas de negocio | Unit tests especificos por caso |

#### La solucion: Arquitectura hibrida

La estrategia recomendada es **combinar ambos enfoques** en la misma API:

```
Tablas auxiliares (poco trafico)     -->  API Generica (EntidadesController)
  - empresa, persona, rol, ruta,
    producto, vendedor

Tablas criticas (alto trafico)       -->  Controllers Dedicados
  - factura + productosporfactura    -->  FacturasController
  - usuario + rol_usuario            -->  UsuariosController
  - rutarol                          -->  PermisosController
```

**Es viable y confiable?** Si, es el patron que usan la mayoria de aplicaciones empresariales reales. Se llama **arquitectura hibrida** o **API de dos niveles**:

- El CRUD generico cubre el 80% de las tablas (las que tienen poco trafico y logica simple)
- Los controllers dedicados cubren el 20% restante (las tablas criticas con reglas de negocio complejas)

#### Como se ve un controller dedicado

Ejemplo para facturas, que hoy se maneja con stored procedures pero podria tener su propio controller:

```
Controllers/
    EntidadesController.cs          <-- Generico: empresa, persona, rol, ruta, producto...
    FacturasController.cs           <-- Dedicado: factura + productosporfactura
    UsuariosController.cs           <-- Dedicado: usuario + rol_usuario
    PermisosController.cs           <-- Dedicado: rutarol

Servicios/
    ServicioCrud.cs                 <-- Generico
    IServicioFacturas.cs            <-- Contrato dedicado
    ServicioFacturas.cs             <-- Logica de negocio de facturas

Repositorios/
    RepositorioLecturaSqlServer.cs  <-- Generico
    IRepositorioFacturas.cs         <-- Contrato dedicado
    RepositorioFacturasSqlServer.cs <-- SQL optimizado para facturas
```

**Ventajas del controller dedicado para facturas:**

```csharp
// FacturasController.cs
[Authorize]
[Route("api/facturas")]
public class FacturasController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CrearFactura([FromBody] CrearFacturaRequest request)
    {
        // 1. Validacion de negocio (imposible en el generico)
        if (request.Productos.Count == 0)
            return BadRequest("La factura debe tener al menos un producto");

        if (!await _servicio.ClienteExisteAsync(request.FkIdCliente))
            return BadRequest("El cliente no existe");

        if (!await _servicio.VendedorExisteAsync(request.FkIdVendedor))
            return BadRequest("El vendedor no existe");

        foreach (var item in request.Productos)
        {
            var stock = await _servicio.ObtenerStockAsync(item.Codigo);
            if (stock < item.Cantidad)
                return BadRequest($"Stock insuficiente para {item.Codigo}. Disponible: {stock}");
        }

        // 2. Transaccion atomica (factura + detalle + stock en una sola transaccion)
        var resultado = await _servicio.CrearFacturaConDetalleAsync(request);

        return Created($"/api/facturas/{resultado.Numero}", resultado);
    }
}
```

```csharp
// ServicioFacturas.cs - Logica de negocio separada
public class ServicioFacturas : IServicioFacturas
{
    public async Task<FacturaResponse> CrearFacturaConDetalleAsync(CrearFacturaRequest request)
    {
        using var conexion = new SqlConnection(_cadena);
        await conexion.OpenAsync();
        using var transaccion = await conexion.BeginTransactionAsync();

        try
        {
            // INSERT factura (1 query, sin consultar metadata)
            var numero = await conexion.ExecuteScalarAsync<int>(
                "INSERT INTO factura (fkidcliente, fkidvendedor) VALUES (@cliente, @vendedor); SELECT SCOPE_IDENTITY()",
                new { cliente = request.FkIdCliente, vendedor = request.FkIdVendedor },
                transaccion);

            // INSERT detalle (1 query por producto, sin metadata)
            foreach (var item in request.Productos)
            {
                await conexion.ExecuteAsync(
                    "INSERT INTO productosporfactura (fknumfactura, fkcodproducto, cantidad) VALUES (@num, @cod, @cant)",
                    new { num = numero, cod = item.Codigo, cant = item.Cantidad },
                    transaccion);
            }

            await transaccion.CommitAsync();
            return new FacturaResponse { Numero = numero };
        }
        catch
        {
            await transaccion.RollbackAsync();
            throw;
        }
    }
}
```

**Comparacion de rendimiento:**

| Operacion: Crear factura con 5 productos | API Generica (SP) | Controller Dedicado |
|------------------------------------------|-------------------|-------------------|
| Peticiones HTTP | 1 | 1 |
| Conexiones a BD | 1 (SP) | 1 (transaccion) |
| Queries de metadata | 0 (SP lo maneja) | 0 (tipos conocidos) |
| Validacion de negocio | En la BD (trigger/SP) | En C# antes de tocar la BD |
| Manejo de errores | Error generico de BD | Mensaje especifico ("Stock insuficiente para PR003") |
| Testing | Dificil (depende de la BD) | Unit test con mock del repositorio |

#### Cuando usar cada enfoque

| Criterio | Usar API Generica | Usar Controller Dedicado |
|----------|------------------|------------------------|
| Trafico esperado | Bajo-medio (<50 req/seg) | Alto (>50 req/seg) |
| Reglas de negocio | Ninguna o simples | Complejas (validaciones cruzadas entre tablas) |
| Transacciones | Una tabla | Multiples tablas |
| Tiempo de desarrollo | Necesito algo ya | Puedo invertir 1-2 dias por modulo |
| Mantenimiento | Cero codigo | Requiere mantener controller + servicio + repositorio |
| Ejemplos | empresa, persona, rol, ruta, producto | factura, pedido, transaccion, usuario |

#### Conclusion

Esta API **si puede usarse en aplicaciones empresariales**, pero no como unico punto de acceso a los datos. La estrategia es:

1. **Arrancar con la API generica** para todas las tablas (prototipo rapido)
2. **Identificar las tablas criticas** por trafico o complejidad de negocio
3. **Crear controllers dedicados** solo para esas tablas
4. **Mantener la API generica** para el resto (ABMs, catalogos, configuracion)

Esto da lo mejor de ambos mundos: velocidad de desarrollo del generico + rendimiento y seguridad del dedicado.

---

### 19. Resumen y Prioridades

| Prioridad | Que hacer | Esfuerzo |
|-----------|-----------|----------|
| **Inmediato** | Mover JWT key y passwords de BD a variables de entorno | Bajo |
| **Inmediato** | Descomentar `[Authorize]` en endpoints de escritura, consultas y SPs | Bajo |
| **Inmediato** | Restringir CORS a origenes conocidos | Bajo |
| **Corto plazo** | Cachear metadata de columnas (elimina N+1 y reduce conexiones) | Medio |
| **Corto plazo** | Reutilizar conexion dentro del mismo metodo (no abrir 1 por campo) | Medio |
| **Corto plazo** | Quitar stack traces de las respuestas de error en produccion | Bajo |
| **Corto plazo** | Agregar rate limiting general y al endpoint de login | Medio |
| **Corto plazo** | Reducir CommandTimeout de 300s a 30-60s (configurable) | Bajo |
| **Corto plazo** | Agregar headers de seguridad HTTP | Bajo |
| **Mediano plazo** | Configurar pool size explicito en todas las connection strings | Bajo |
| **Mediano plazo** | Cambiar blacklist por whitelist de tablas | Medio |
| **Mediano plazo** | Implementar tabla de auditoria persistente | Medio |
| **Mediano plazo** | Implementar operaciones masivas (bulk insert/update/delete) | Alto |
| **Largo plazo** | Implementar RBAC por tabla/campo/fila | Alto |
| **Largo plazo** | Agregar response caching con invalidacion | Alto |
| **Inmediato** | Restringir Swagger/ReDoc solo al entorno de desarrollo | Bajo |
| **Inmediato** | Agregar validacion regex a nombres de tabla/columna (defense-in-depth) | Bajo |
| **Corto plazo** | Habilitar Health Checks (`/health`) para Docker/Kubernetes | Bajo |
| **Corto plazo** | Activar compresion de respuestas GZIP/Brotli | Bajo |
| **Mediano plazo** | Implementar Refresh Tokens para evitar re-login forzado | Medio |
| **Mediano plazo** | Agregar versionado de API (`/api/v1/`) | Medio |

---

## Tabla de Contenidos

- [Analisis de Seguridad, Rendimiento y Buenas Practicas](#analisis-de-seguridad-rendimiento-y-buenas-practicas)
- [Caracteristicas](#caracteristicas)
- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Instalacion](#instalacion)
- [Configuracion](#configuracion)
- [Bases de Datos Soportadas](#bases-de-datos-soportadas)
- [Endpoints](#endpoints)
- [Autenticacion JWT](#autenticacion-jwt)
- [Ejemplos de Uso](#ejemplos-de-uso)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Principios SOLID](#principios-solid)
- [Tecnologias Utilizadas](#tecnologias-utilizadas)
- [Solucion de Problemas Comunes](#solucion-de-problemas-comunes)

---

## Caracteristicas

- **CRUD Generico**: Operaciones Create, Read, Update, Delete sobre cualquier tabla
- **Multi-Base de Datos**: SQL Server, PostgreSQL, MySQL, MariaDB
- **Autenticacion JWT**: Tokens seguros con expiracion configurable
- **Swagger UI**: Documentacion interactiva de la API
- **Consultas Parametrizadas**: Ejecucion segura de SQL con parametros
- **Stored Procedures**: Ejecucion dinamica de procedimientos almacenados
- **Introspeccion de BD**: Consultar estructura de tablas y base de datos
- **Encriptacion BCrypt**: Hash seguro de contrasenas
- **CORS Configurado**: Listo para consumir desde frontend
- **Arquitectura Limpia**: Separacion de responsabilidades (Controllers, Services, Repositories)

---

## Arquitectura

```
+-------------------------------------------------------------+
|                        CONTROLLERS                          |
|  EntidadesController | ConsultasController | Autenticacion  |
|  DiagnosticoController | EstructurasController | Procedimientos |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                         SERVICIOS                           |
|         IServicioCrud          |      IServicioConsultas    |
|              |                 |              |             |
|         ServicioCrud           |      ServicioConsultas     |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                       REPOSITORIOS                          |
|  +-------------+  +-------------+  +---------------------+  |
|  |  SQL Server |  |  PostgreSQL |  |  MySQL / MariaDB    |  |
|  +-------------+  +-------------+  +---------------------+  |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                      BASE DE DATOS                          |
+-------------------------------------------------------------+
```

---

## Requisitos

| Requisito | Version |
|-----------|---------|
| .NET SDK | 9.0 o superior |
| Visual Studio / VS Code | 2022 / Ultima version |
| Base de datos | SQL Server, PostgreSQL, MySQL o MariaDB |

> **Nota sobre Dapper**: Esta API utiliza [Dapper](https://github.com/DapperLib/Dapper) como Micro-ORM. A diferencia de Entity Framework, Dapper es extremadamente ligero y rapido porque trabaja directamente con SQL, sin las capas de abstraccion de un ORM completo. Esto lo hace ideal para APIs genericas donde el rendimiento es critico.

---

## Instalacion

### 1. Clonar el repositorio

```bash
git clone <url-del-repositorio>
cd ApiGenericaCsharp
```

### 2. Restaurar paquetes NuGet

```bash
dotnet restore
```

### 3. Compilar el proyecto

```bash
dotnet build
```

### 4. Ejecutar la API

```bash
dotnet run
```

### 5. Abrir Swagger

Navegar a: `https://localhost:5001/swagger` o `http://localhost:5000/swagger`

---

## Configuracion

### Archivo appsettings.json

```json
{
  "Jwt": {
    "Key": "MiClaveSecretaMuyLargaDeAlMenos32Caracteres!",
    "Issuer": "MiApp",
    "Audience": "MiAppUsers",
    "DuracionMinutos": 60
  },
  "TablasProhibidas": [],
  "ConnectionStrings": {
    "SqlServer": "Server=MI_SERVIDOR;Database=mi_bd;Integrated Security=True;TrustServerCertificate=True;",
    "LocalDb": "Server=(localdb)\\MSSQLLocalDB;Database=mi_bd;Integrated Security=True;TrustServerCertificate=True;",
    "Postgres": "Host=localhost;Port=5432;Database=mi_bd;Username=postgres;Password=postgres;",
    "MySQL": "Server=localhost;Port=3306;Database=mi_bd;User=root;Password=mysql;CharSet=utf8mb4;",
    "MariaDB": "Server=localhost;Port=3306;Database=mi_bd;User=root;Password=;"
  },
  "DatabaseProvider": "SqlServer"
}
```

### Cambiar de base de datos

Solo modifica el valor de `DatabaseProvider`:

| Valor | Base de datos |
|-------|---------------|
| `SqlServer` | Microsoft SQL Server |
| `LocalDb` | SQL Server LocalDB (desarrollo) |
| `Postgres` | PostgreSQL |
| `MySQL` | MySQL |
| `MariaDB` | MariaDB |

---

## Bases de Datos Soportadas

| Base de Datos | Paquete NuGet | Puerto Default |
|---------------|---------------|----------------|
| SQL Server | Microsoft.Data.SqlClient | 1433 |
| SQL Server LocalDB | Microsoft.Data.SqlClient | - |
| PostgreSQL | Npgsql | 5432 |
| MySQL | MySqlConnector | 3306 |
| MariaDB | MySqlConnector | 3306 |

---

## Endpoints

### EntidadesController - CRUD Generico

| Metodo | Ruta | Descripcion | Auth |
|--------|------|-------------|------|
| GET | `/api/{tabla}` | Obtener todos los registros | Si |
| GET | `/api/{tabla}/{clave}/{valor}` | Obtener por clave | Si |
| POST | `/api/{tabla}` | Crear registro | Si |
| PUT | `/api/{tabla}/{clave}/{valor}` | Actualizar registro | Si |
| DELETE | `/api/{tabla}/{clave}/{valor}` | Eliminar registro | Si |
| POST | `/api/{tabla}/verificar-contrasena` | Verificar contrasena BCrypt | Si |
| GET | `/api/info` | Informacion del controller | No |

### ConsultasController - SQL Parametrizado

| Metodo | Ruta | Descripcion | Auth |
|--------|------|-------------|------|
| POST | `/api/consultas/ejecutar` | Ejecutar consulta SQL | Si |
| POST | `/api/consultas/validar` | Validar consulta SQL | Si |

### AutenticacionController - JWT

| Metodo | Ruta | Descripcion | Auth |
|--------|------|-------------|------|
| POST | `/api/autenticacion/login` | Iniciar sesion | No |

### DiagnosticoController - Estado del Sistema

| Metodo | Ruta | Descripcion | Auth |
|--------|------|-------------|------|
| GET | `/api/diagnostico/salud` | Verificar estado de la API | No |
| GET | `/api/diagnostico/conexion` | Verificar conexion a BD | No |

### EstructurasController - Introspeccion

| Metodo | Ruta | Descripcion | Auth |
|--------|------|-------------|------|
| GET | `/api/estructuras/{tabla}/modelo` | Estructura de una tabla | No |
| GET | `/api/estructuras/basedatos` | Estructura completa de la BD | No |

### ProcedimientosController - Stored Procedures

| Metodo | Ruta | Descripcion | Auth |
|--------|------|-------------|------|
| POST | `/api/procedimientos/ejecutarsp` | Ejecutar procedimiento almacenado | Si |

---

## Autenticacion JWT

### 1. Obtener token

```http
POST /api/autenticacion/login
Content-Type: application/json

{
  "tabla": "usuarios",
  "campoUsuario": "email",
  "campoContrasena": "password",
  "usuario": "admin@ejemplo.com",
  "contrasena": "miPassword123"
}
```

### 2. Respuesta exitosa

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expira": "2024-01-15T12:00:00Z",
  "usuario": "admin@ejemplo.com"
}
```

### 3. Usar token en peticiones

```http
GET /api/productos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Ejemplos de Uso

### Obtener todos los productos

```http
GET /api/productos?limite=100
Authorization: Bearer {token}
```

### Obtener producto por ID

```http
GET /api/productos/id/42
Authorization: Bearer {token}
```

### Crear un producto

```http
POST /api/productos
Authorization: Bearer {token}
Content-Type: application/json

{
  "nombre": "Laptop HP",
  "precio": 1500.00,
  "stock": 25
}
```

### Actualizar un producto

```http
PUT /api/productos/id/42
Authorization: Bearer {token}
Content-Type: application/json

{
  "precio": 1399.99,
  "stock": 30
}
```

### Eliminar un producto

```http
DELETE /api/productos/id/42
Authorization: Bearer {token}
```

### Ejecutar consulta SQL

```http
POST /api/consultas/ejecutar
Authorization: Bearer {token}
Content-Type: application/json

{
  "consultaSQL": "SELECT * FROM productos WHERE precio > @precio",
  "parametros": {
    "precio": 100.00
  }
}
```

### Ejecutar procedimiento almacenado

```http
POST /api/procedimientos/ejecutarsp
Authorization: Bearer {token}
Content-Type: application/json

{
  "nombreSP": "sp_obtener_ventas_mes",
  "mes": 12,
  "anio": 2024
}
```

---

## Estructura del Proyecto

```
ApiGenericaCsharp/
|-- Controllers/
|   |-- AutenticacionController.cs    # Login y JWT
|   |-- ConsultasController.cs        # SQL parametrizado
|   |-- DiagnosticoController.cs      # Estado del sistema
|   |-- EntidadesController.cs        # CRUD generico
|   |-- EstructurasController.cs      # Introspeccion BD
|   +-- ProcedimientosController.cs   # Stored procedures
|
|-- Servicios/
|   |-- Abstracciones/
|   |   |-- IServicioCrud.cs          # Contrato CRUD (Listar, Crear, Actualizar, Eliminar)
|   |   |-- IServicioConsultas.cs     # Contrato consultas parametrizadas y SP
|   |   |-- IProveedorConexion.cs     # Contrato conexion (cadena + proveedor activo)
|   |   +-- IPoliticaTablasProhibidas.cs  # Contrato tablas prohibidas
|   |-- Conexion/
|   |   +-- ProveedorConexion.cs      # Proveedor de conexion
|   |-- Politicas/
|   |   +-- PoliticaTablasProhibidasDesdeJson.cs
|   |-- Utilidades/
|   |   +-- EncriptacionBCrypt.cs     # Hash de contrasenas
|   |-- ServicioCrud.cs               # Logica CRUD
|   +-- ServicioConsultas.cs          # Logica consultas
|
|-- Repositorios/
|   |-- Abstracciones/
|   |   |-- IRepositorioLecturaTabla.cs
|   |   +-- IRepositorioConsultas.cs
|   |-- RepositorioLecturaSqlServer.cs
|   |-- RepositorioLecturaPostgreSQL.cs
|   |-- RepositorioLecturaMysqlMariaDB.cs
|   |-- RepositorioConsultasSqlServer.cs
|   |-- RepositorioConsultasPostgreSQL.cs
|   +-- RepositorioConsultasMysqlMariaDB.cs
|
|-- Modelos/
|   +-- ConfiguracionJwt.cs           # Configuracion JWT
|
|-- Properties/
|   +-- launchSettings.json           # Puertos y perfiles
|
|-- appsettings.json                  # Configuracion produccion
|-- appsettings.Development.json      # Configuracion desarrollo
|-- Program.cs                        # Punto de entrada y DI
|-- ApiGenericaCsharp.csproj          # Definicion del proyecto y paquetes NuGet
|-- ApiGenericaCsharp.sln             # Solucion de Visual Studio
|-- ApiGenericaCsharp.http            # Archivo de pruebas HTTP (VS Code REST Client)
+-- README.md                         # Este archivo
```

---

## Principios SOLID Aplicados

| Principio | Aplicacion |
|-----------|------------|
| **S** - Single Responsibility | Cada clase tiene una sola responsabilidad (Controller -> coordina, Service -> logica, Repository -> datos) |
| **O** - Open/Closed | Agregar nueva BD sin modificar codigo existente (solo nuevo repositorio) |
| **L** - Liskov Substitution | Cualquier repositorio puede sustituir a otro que implemente la misma interfaz |
| **I** - Interface Segregation | Interfaces especificas (IRepositorioLecturaTabla, IRepositorioConsultas) |
| **D** - Dependency Inversion | Controllers dependen de interfaces, no de implementaciones concretas |

---

## Tecnologias Utilizadas

| Tecnologia | Version | Proposito |
|------------|---------|-----------|
| .NET | 9.0 | Framework principal |
| ASP.NET Core | 9.0 | Framework web |
| Dapper | 2.1.66 | Micro ORM |
| BCrypt.Net-Next | 4.0.3 | Hash de contrasenas |
| Swashbuckle | 9.0.4 | Swagger UI |
| Swashbuckle ReDoc | 10.1.2 | ReDoc UI (documentacion alternativa) |
| Microsoft.Data.SqlClient | 6.1.1 | Conexion SQL Server |
| Npgsql | 9.0.3 | Conexion PostgreSQL |
| MySqlConnector | 2.4.0 | Conexion MySQL/MariaDB |

---

## Paquetes NuGet

```xml
<ItemGroup>
  <PackageReference Include="BCrypt.Net-Next" Version="4.0.3" />
  <PackageReference Include="Dapper" Version="2.1.66" />
  <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="9.0.10" />
  <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="8.0.6" />
  <PackageReference Include="Microsoft.Data.SqlClient" Version="6.1.1" />
  <PackageReference Include="MySqlConnector" Version="2.4.0" />
  <PackageReference Include="Npgsql" Version="9.0.3" />
  <PackageReference Include="Swashbuckle.AspNetCore" Version="9.0.4" />
  <PackageReference Include="Swashbuckle.AspNetCore.ReDoc" Version="10.1.2" />
</ItemGroup>
```

---

## Probar la API

1. Ejecutar: `dotnet run`
2. Abrir Swagger: `http://localhost:5000/swagger`
3. Abrir ReDoc: `http://localhost:5000/redoc`
4. Probar endpoint de diagnostico: `GET /api/diagnostico/conexion`
5. Hacer login para obtener token: `POST /api/autenticacion/token`
6. Usar token en endpoints protegidos (boton "Authorize" en Swagger)

---

## Solucion de Problemas Comunes

A continuacion, se listan los errores mas frecuentes y como solucionarlos:

### 1. Error de Conexion a la Base de Datos

**Sintoma**: `A network-related or instance-specific error occurred...`

**Solucion**:
- Verifica que el servicio de la base de datos este corriendo
- Si usas SQL Server, asegurate de que el nombre del servidor sea correcto (ej. `localhost` o `(localdb)\MSSQLLocalDB`)
- Revisa que el `DatabaseProvider` en `appsettings.json` coincida exactamente con una de las llaves de `ConnectionStrings`

### 2. El Token JWT no funciona (401 Unauthorized)

**Sintoma**: Recibes un error 401 incluso despues de pegar el token.

**Solucion**:
- Asegurate de incluir la palabra `Bearer` seguida de un espacio antes del token: `Bearer eyJhbGci...`
- Verifica que la `Jwt:Key` en tu configuracion tenga al menos 32 caracteres (256 bits)
- Comprueba que el token no haya expirado

### 3. Error con el Puerto (Puerto en uso)

**Sintoma**: `Failed to bind to address http://localhost:5000`

**Solucion**:
- Cambia los puertos en el archivo `Properties/launchSettings.json`
- O cierra la aplicacion que este usando ese puerto
- Puedes buscar el proceso con: `netstat -ano | findstr :5000`

### 4. Errores de Certificado SSL

**Sintoma**: El navegador o Swagger muestran un error de "Conexion no privada".

**Solucion**: Ejecuta el siguiente comando para confiar en el certificado de desarrollo de .NET:

```bash
dotnet dev-certs https --trust
```

### 5. Error CS0234: El tipo o nombre no existe

**Sintoma**: Errores de compilacion relacionados con namespaces o paquetes.

**Solucion**:
- Ejecuta `dotnet restore` para restaurar los paquetes NuGet
- Verifica que las versiones de los paquetes sean compatibles con .NET 9.0
- Limpia y recompila: `dotnet clean && dotnet build`

---

## Registro de Dependencias (Program.cs)

La inyeccion de dependencias se configura en `Program.cs` segun el proveedor activo:

```csharp
// Servicios (siempre los mismos)
builder.Services.AddSingleton<IPoliticaTablasProhibidas>(politica);
builder.Services.AddSingleton<IProveedorConexion, ProveedorConexion>();
builder.Services.AddScoped<IServicioCrud, ServicioCrud>();
builder.Services.AddScoped<IServicioConsultas, ServicioConsultas>();

// Repositorios (cambian segun DatabaseProvider)
// "Postgres"      -> RepositorioLecturaPostgreSQL + RepositorioConsultasPostgreSQL
// "MySQL/MariaDB" -> RepositorioLecturaMysqlMariaDB + RepositorioConsultasMysqlMariaDB
// "SqlServer"     -> RepositorioLecturaSqlServer + RepositorioConsultasSqlServer (default)
```

---

## Equivalencias C# vs Python (FastAPI)

| Concepto | C# (.NET) | Python (FastAPI) |
|----------|-----------|------------------|
| Framework | ASP.NET Core | FastAPI |
| ORM | Dapper (Micro-ORM) | SQLAlchemy async |
| Inyeccion de Dependencias | `builder.Services.AddScoped<>()` | `Depends()` en endpoints |
| Interfaces | `interface IServicioCrud` | `Protocol` (typing) |
| Configuracion | `appsettings.json` | `.env` + pydantic-settings |
| Autenticacion | JWT Bearer middleware | JWT manual con python-jose |
| Servidor web | Kestrel (integrado) | Uvicorn (ASGI) |
| Documentacion API | Swagger + ReDoc (Swashbuckle) | Swagger + ReDoc (integrado en FastAPI) |
| Hash contrasenas | BCrypt.Net-Next | passlib + bcrypt |
| Async/Await | `async Task<>` nativo | `async def` nativo |

---

## Comandos Utiles

```bash
# Restaurar paquetes
dotnet restore

# Compilar
dotnet build

# Ejecutar
dotnet run

# Ejecutar en modo watch (recarga automatica)
dotnet watch run

# Limpiar y recompilar
dotnet clean && dotnet build

# Confiar certificado SSL de desarrollo
dotnet dev-certs https --trust

# Ver version de .NET instalada
dotnet --version
```

---

## Licencia

Este proyecto es de uso educativo.

---

## Autor
Carlos Arturo Castro Castro
Creado como tutorial paso a paso para aprender a construir APIs genericas con .NET 9.


