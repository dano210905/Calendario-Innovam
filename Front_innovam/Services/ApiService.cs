//esto hace referencia a un servicio llamado ApiService que se utiliza para interactuar con una API RESTful. Este servicio proporciona métodos para realizar operaciones CRUD (Crear, Leer, Actualizar, Eliminar) en una tabla específica de la API, así como un método para obtener información de diagnóstico sobre la conexión al servidor. El servicio utiliza HttpClient para realizar solicitudes HTTP y JsonSerializerOptions para configurar la deserialización de las respuestas JSON. Cada método maneja posibles excepciones relacionadas con la conexión y devuelve resultados que indican el éxito de la operación y mensajes asociados.
using System.Net.Http.Json;
using System.Text.Json;


// esto hace referencia al espacio de nombres FrontBlazorTutorial.Services, que es donde se define la clase ApiService. Este espacio de nombres se utiliza para organizar el código relacionado con los servicios de la aplicación, en este caso, el servicio que interactúa con la API RESTful.
namespace FrontBlazorTutorial.Services
{
    public class ApiService
    {
        private readonly HttpClient _http;

        private readonly JsonSerializerOptions _jsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        public ApiService(HttpClient http)
        {
            _http = http;
        }

        // este metodo realiza una solicitud HTTP GET a la API para obtener una lista de registros de una tabla específica. Toma como parámetros el nombre de la tabla y un parámetro opcional para limitar la cantidad de registros devueltos. La respuesta esperada es un objeto JSON que contiene una propiedad "datos" con un array de registros. El método convierte ese array en una lista de diccionarios, donde cada diccionario representa un registro con sus propiedades y valores correspondientes. Si ocurre algún error durante la solicitud, se captura la excepción y se devuelve una lista vacía.
        public async Task<List<Dictionary<string, object?>>> ListarAsync(
            string tabla, int? limite = null)
        {
            try
            {
                string url = $"/api/{tabla}";
                if (limite.HasValue)
                    url += $"?limite={limite.Value}";

                var respuesta = await _http.GetFromJsonAsync<JsonElement>(url, _jsonOptions);

                if (respuesta.TryGetProperty("datos", out JsonElement datos))
                {
                    return ConvertirDatos(datos);
                }

                return new List<Dictionary<string, object?>>();
            }
            catch (HttpRequestException ex)
            {
                Console.WriteLine($"Error al listar {tabla}: {ex.Message}");
                return new List<Dictionary<string, object?>>();
            }
        }

        // este metodo crea un nuevo registro en una tabla específica de la API. Toma como parámetros el nombre de la tabla, un diccionario con los datos del nuevo registro y un parámetro opcional para especificar campos que deben ser encriptados. Realiza una solicitud HTTP POST a la ruta correspondiente en la API y espera recibir una respuesta JSON que contenga un mensaje sobre el resultado de la operación. El método devuelve una tupla que indica si la operación fue exitosa y el mensaje recibido de la API. Si ocurre algún error durante la solicitud, se captura la excepción y se devuelve un mensaje de error relacionado con la conexión.
        public async Task<(bool exito, string mensaje)> CrearAsync(
            string tabla, Dictionary<string, object?> datos,
            string? camposEncriptar = null)
        {
            try
            {
                string url = $"/api/{tabla}";
                if (!string.IsNullOrEmpty(camposEncriptar))
                    url += $"?camposEncriptar={camposEncriptar}";

                var respuesta = await _http.PostAsJsonAsync(url, datos);
                var contenido = await respuesta.Content.ReadFromJsonAsync<JsonElement>(
                    _jsonOptions);

                string mensaje = contenido.TryGetProperty("mensaje", out JsonElement msg)
                    ? msg.GetString() ?? "Operacion completada."
                    : "Operacion completada.";

                return (respuesta.IsSuccessStatusCode, mensaje);
            }
            catch (HttpRequestException ex)
            {
                return (false, $"Error de conexión: {ex.Message}");
            }
        }

        // este metodo actualiza un registro existente en una tabla específica de la API. Toma como parámetros el nombre de la tabla, el nombre de la clave primaria, el valor de la clave primaria para identificar el registro a actualizar, un diccionario con los datos a actualizar y un parámetro opcional para especificar campos que deben ser encriptados. Realiza una solicitud HTTP PUT a la ruta correspondiente en la API y espera recibir una respuesta JSON que contenga un mensaje sobre el resultado de la operación. El método devuelve una tupla que indica si la operación fue exitosa y el mensaje recibido de la API. Si ocurre algún error durante la solicitud, se captura la excepción y se devuelve un mensaje de error relacionado con la conexión.
        public async Task<(bool exito, string mensaje)> ActualizarAsync(
            string tabla, string nombreClave, string valorClave,
            Dictionary<string, object?> datos,
            string? camposEncriptar = null)
        {
            try
            {
                string url = $"/api/{tabla}/{nombreClave}/{valorClave}";
                if (!string.IsNullOrEmpty(camposEncriptar))
                    url += $"?camposEncriptar={camposEncriptar}";

                var respuesta = await _http.PutAsJsonAsync(url, datos);
                var contenido = await respuesta.Content.ReadFromJsonAsync<JsonElement>(
                    _jsonOptions);

                string mensaje = contenido.TryGetProperty("mensaje", out JsonElement msg)
                    ? msg.GetString() ?? "Operacion completada."
                    : "Operacion completada.";

                return (respuesta.IsSuccessStatusCode, mensaje);
            }
            catch (HttpRequestException ex)
            {
                return (false, $"Error de conexión: {ex.Message}");
            }
        }

        // este metodo elimina un registro de una tabla específica en la API. Toma como parámetros el nombre de la tabla, el nombre de la clave primaria y el valor de la clave primaria para identificar el registro a eliminar. Realiza una solicitud HTTP DELETE a la ruta correspondiente en la API y espera recibir una respuesta JSON que contenga un mensaje sobre el resultado de la operación. El método devuelve una tupla que indica si la operación fue exitosa y el mensaje recibido de la API. Si ocurre algún error durante la solicitud, se captura la excepción y se devuelve un mensaje de error relacionado con la conexión.
        public async Task<(bool exito, string mensaje)> EliminarAsync(
            string tabla, string nombreClave, string valorClave)
        {
            try
            {
                var respuesta = await _http.DeleteAsync(
                    $"/api/{tabla}/{nombreClave}/{valorClave}");
                var contenido = await respuesta.Content.ReadFromJsonAsync<JsonElement>(
                    _jsonOptions);

                string mensaje = contenido.TryGetProperty("mensaje", out JsonElement msg)
                    ? msg.GetString() ?? "Operacion completada."
                    : "Operacion completada.";

                return (respuesta.IsSuccessStatusCode, mensaje);
            }
            catch (HttpRequestException ex)
            {
                return (false, $"Error de conexión: {ex.Message}");
            }
        }

        // este metodo obtiene información de diagnóstico sobre la conexión al servidor. Realiza una solicitud HTTP GET a la ruta "/api/diagnostico/conexión" y espera recibir un objeto JSON que contenga información sobre el servidor. Si la respuesta es exitosa y contiene la propiedad "servidor", se convierte esa información en un diccionario de cadenas y se devuelve. Si ocurre algún error durante la solicitud o si la respuesta no contiene la información esperada, el método devuelve null.
        public async Task<Dictionary<string, string>?> ObtenerDiagnosticoAsync()
        {
            try
            {
                var respuesta = await _http.GetFromJsonAsync<JsonElement>(
                    "/api/diagnostico/conexión", _jsonOptions);

                if (respuesta.TryGetProperty("servidor", out JsonElement servidor))
                {
                    var info = new Dictionary<string, string>();
                    foreach (var prop in servidor.EnumerateObject())
                    {
                        info[prop.Name] = prop.Value.ToString();
                    }
                    return info;
                }

                return null;
            }
            catch
            {
                return null;
            }
        }

        // este metodo convierte un JsonElement que representa un array de objetos JSON en una lista de diccionarios, donde cada diccionario representa un objeto con sus propiedades y valores correspondientes. El método itera sobre cada elemento del array, luego sobre cada propiedad de ese elemento, y asigna el valor de la propiedad al diccionario utilizando el nombre de la propiedad como clave. El valor se convierte al tipo adecuado según su tipo JSON (cadena, número, booleano, nulo). Finalmente, la lista de diccionarios resultante se devuelve.
        private List<Dictionary<string, object?>> ConvertirDatos(JsonElement datos)
        {
            var lista = new List<Dictionary<string, object?>>();

            foreach (var fila in datos.EnumerateArray())
            {
                var diccionario = new Dictionary<string, object?>();

                foreach (var propiedad in fila.EnumerateObject())
                {
                    diccionario[propiedad.Name] = propiedad.Value.ValueKind switch
                    {
                        JsonValueKind.String => propiedad.Value.GetString(),
                        JsonValueKind.Number => propiedad.Value.TryGetInt32(out int i)
                            ? i : propiedad.Value.GetDouble(),
                        JsonValueKind.True => true,
                        JsonValueKind.False => false,
                        JsonValueKind.Null => null,
                        _ => propiedad.Value.GetRawText()
                    };
                }

                lista.Add(diccionario);
            }

            return lista;
        }
    }
}