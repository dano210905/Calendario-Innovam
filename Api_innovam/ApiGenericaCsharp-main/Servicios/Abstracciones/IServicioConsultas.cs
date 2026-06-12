// IServicioConsultas.cs — Interface que define el contrato para ejecutar consultas SQL parametrizadas
// Ubicacion: Servicios/Abstracciones/IServicioConsultas.cs
//
// Principios SOLID aplicados:
// - SRP: Solo define operaciones de consultas SQL parametrizadas
// - DIP: Permite que el controlador dependa de esta abstraccion, no de implementaciones concretas
// - ISP: Interface especifica y pequena, solo metodos relacionados con consultas SQL

using System.Collections.Generic;
using System.Threading.Tasks;
using System.Data;
using Microsoft.Data.SqlClient;

namespace ApiGenericaCsharp.Servicios.Abstracciones
{
    /// <summary>
    /// Contrato para ejecutar consultas SQL parametrizadas de forma segura.
    /// Usado por ConsultasController y ProcedimientosController.
    /// </summary>
    public interface IServicioConsultas
    {
        /// <summary>
        /// Valida que una consulta SQL sea segura (solo SELECT, sin tablas prohibidas).
        /// </summary>
        (bool esValida, string? mensajeError) ValidarConsultaSQL(string consulta, string[] tablasProhibidas);

        /// <summary>
        /// Ejecuta consulta SQL parametrizada con Dictionary generico.
        /// </summary>
        Task<DataTable> EjecutarConsultaParametrizadaAsync(
            string consulta,
            Dictionary<string, object?> parametros,
            int maximoRegistros,
            string? esquema);

        /// <summary>
        /// Ejecuta consulta SQL parametrizada con SqlParameter (compatibilidad legacy).
        /// </summary>
        Task<DataTable> EjecutarConsultaParametrizadaAsync(
            string consulta,
            List<SqlParameter> parametros,
            int maximoRegistros,
            string? esquema);

        /// <summary>
        /// Ejecuta consulta SQL recibiendo parametros en formato Dictionary JSON.
        /// Punto de entrada desde ConsultasController.
        /// </summary>
        Task<DataTable> EjecutarConsultaParametrizadaDesdeJsonAsync(
            string consulta,
            Dictionary<string, object?>? parametros);

        /// <summary>
        /// Ejecuta un procedimiento almacenado con parametros Dictionary JSON.
        /// Soporta encriptacion BCrypt de campos especificos.
        /// </summary>
        Task<DataTable> EjecutarProcedimientoAlmacenadoAsync(
            string nombreSP,
            Dictionary<string, object?>? parametros,
            List<string>? camposAEncriptar);
    }
}
