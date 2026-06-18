// es el punto de entrada de la aplicación, donde se configura y se inicia la aplicación web. 
//Aquí se pueden agregar servicios, configurar middleware y definir rutas para la aplicación.
using Front_innovam.Components;
var builder = WebApplication.CreateBuilder(args);

//esto agrega servicios de Razor Components al contenedor de servicios de la aplicación, lo que permite utilizar componentes interactivos en la aplicación web.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();


// esto agrega un servicio HttpClient al contenedor de servicios de la aplicación, configurando su base URL a partir de la configuración de la aplicación (appsettings.json) o utilizando una URL predeterminada si no se encuentra en la configuración.
var apiBaseUrl = builder.Configuration["ApiBaseUrl"] ?? "http://localhost:5035";
builder.Services.AddScoped(sp => new HttpClient { BaseAddress = new Uri(apiBaseUrl) });

// esto hace que el servicio ApiService esté disponible para inyección de dependencias en toda la aplicación, lo que permite a los componentes y otros servicios utilizarlo para realizar llamadas a la API o manejar la lógica relacionada con la API.
builder.Services.AddScoped<Front_innovam.Services.ApiService>();

var app = builder.Build();


//esto configura el middleware de manejo de excepciones para la aplicación. Si la aplicación no está en modo de desarrollo, se utilizará un controlador de excepciones personalizado que redirige a una página de error ("/Error") cuando ocurre una excepción no controlada. 
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    
}

// esto hace que la aplicación utilice HTTPS para todas las solicitudes, lo que mejora la seguridad al cifrar la comunicación entre el cliente y el servidor.
app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();