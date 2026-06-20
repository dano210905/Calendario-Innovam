USE master;
GO

IF DB_ID('ApiGenericaDB') IS NOT NULL
BEGIN
    ALTER DATABASE ApiGenericaDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ApiGenericaDB;
END
GO

CREATE DATABASE ApiGenericaDB;
GO

USE ApiGenericaDB;
GO

--tablas

CREATE TABLE dbo.usuario (
    email VARCHAR(200) PRIMARY KEY,
    contrasena VARCHAR(200) NOT NULL
);
GO

CREATE TABLE dbo.rol (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);
GO

CREATE TABLE dbo.rol_usuario (
    id INT IDENTITY(1,1) PRIMARY KEY,
    fkemail VARCHAR(200),
    fkidrol INT,
    FOREIGN KEY (fkemail) REFERENCES dbo.usuario(email),
    FOREIGN KEY (fkidrol) REFERENCES dbo.rol(id)
);
GO

CREATE TABLE dbo.ruta (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ruta VARCHAR(200),
    descripcion VARCHAR(MAX) DEFAULT ''
);
GO

CREATE TABLE dbo.rutarol (
    id INT IDENTITY(1,1) PRIMARY KEY,
    fkidrol INT,
    fkidruta INT,
    FOREIGN KEY (fkidrol) REFERENCES dbo.rol(id),
    FOREIGN KEY (fkidruta) REFERENCES dbo.ruta(id)
);
GO

CREATE TABLE dbo.clientes (
    cedula INT PRIMARY KEY,
    nombre VARCHAR(50),
    correo VARCHAR(200),
    telefono VARCHAR(15)
);
GO

CREATE TABLE dbo.proveedores (
    cedula INT PRIMARY KEY,
    nombre VARCHAR(50),
    descripcion VARCHAR(100),
    contactos VARCHAR(30),
    correo VARCHAR(200),
    telefono VARCHAR(15)
);
GO

CREATE TABLE dbo.Eventos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    cedulac INT FOREIGN KEY REFERENCES dbo.clientes(cedula),
    cedulap INT FOREIGN KEY REFERENCES dbo.proveedores(cedula),
    titulo VARCHAR(50),
    imagen VARBINARY(MAX),
    descripcion VARCHAR(200),
    horarioi DATETIME,
    horariof DATETIME,
    aforomax INT,
    ubicacion VARCHAR(250),
    estado VARCHAR(15) CHECK (UPPER(estado) IN ('CONFIRMADO','CANCELADO','COTIZADO','FINALIZADO'))
);
GO

CREATE TABLE dbo.notificaciones (
    idN INT IDENTITY(1,1) PRIMARY KEY,
    id INT FOREIGN KEY REFERENCES dbo.Eventos(id),
    descripcion VARCHAR(100),
    leida BIT DEFAULT 0,
    fecha DATETIME
);
GO

--procedimientos almacenados

--modulo de eventos

CREATE OR ALTER PROCEDURE dbo.sp_CrearEvento
    @titulo VARCHAR(50),
    @descripcion VARCHAR(200),
    @horarioi DATETIME,
    @horariof DATETIME,
    @aforomax INT,
    @ubicacion VARCHAR(250),
    @cedulac INT,
    @imagen VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idEventoNuevo INT;
    DECLARE @hayConflicto INT = 0;
    DECLARE @msgNotif VARCHAR(100);

    IF @horarioi >= @horariof
    BEGIN
        SELECT -1 AS codigo, 'El horario de inicio debe ser anterior al horario de fin.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.clientes WHERE cedula = @cedulac)
    BEGIN
        SELECT -2 AS codigo, 'El cliente especificado no existe en el sistema.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    IF @aforomax <= 0
    BEGIN
        SELECT -3 AS codigo, 'El aforo máximo debe ser un número positivo.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    SELECT @hayConflicto = COUNT(*)
    FROM dbo.Eventos
    WHERE UPPER(estado) NOT IN ('CANCELADO', 'FINALIZADO')
      AND ubicacion = @ubicacion
      AND (
            (@horarioi >= horarioi AND @horarioi < horariof)
            OR
            (@horariof > horarioi AND @horariof <= horariof)
            OR
            (@horarioi <= horarioi AND @horariof >= horariof)
          );

    IF @hayConflicto > 0
    BEGIN
        SELECT -4 AS codigo, 'Conflicto de horario: ya existe un evento activo en esa ubicación durante ese rango de tiempo.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            INSERT INTO dbo.Eventos (
                cedulac, titulo, imagen, descripcion,
                horarioi, horariof, aforomax, ubicacion, estado
            )
            VALUES (
                @cedulac, @titulo, @imagen, @descripcion,
                @horarioi, @horariof, @aforomax, @ubicacion, 'COTIZADO'
            );

            SET @idEventoNuevo = SCOPE_IDENTITY();
            SET @msgNotif = 'Nuevo evento creado: ' + @titulo;

            INSERT INTO dbo.notificaciones (id, descripcion, leida, fecha)
            VALUES (@idEventoNuevo, @msgNotif, 0, GETDATE());

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Evento creado exitosamente.' AS mensaje, @idEventoNuevo AS idEvento;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje, NULL AS idEvento;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_EditarEvento
    @id INT,
    @titulo VARCHAR(50) = NULL,
    @descripcion VARCHAR(200) = NULL,
    @horarioi DATETIME = NULL,
    @horariof DATETIME = NULL,
    @aforomax INT = NULL,
    @ubicacion VARCHAR(250) = NULL,
    @imagen VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @estadoActual VARCHAR(15);
    DECLARE @hayConflicto INT = 0;
    DECLARE @msgNotif VARCHAR(100);

    SELECT @estadoActual = UPPER(estado) FROM dbo.Eventos WHERE id = @id;

    IF @estadoActual IS NULL
    BEGIN
        SELECT -1 AS codigo, 'El evento especificado no existe.' AS mensaje;
        RETURN;
    END

    IF @estadoActual IN ('FINALIZADO', 'CANCELADO')
    BEGIN
        SELECT -2 AS codigo, 'No se puede editar un evento ' + @estadoActual + '.' AS mensaje;
        RETURN;
    END

    IF @estadoActual = 'CONFIRMADO'
    BEGIN
        IF @horarioi IS NOT NULL OR @horariof IS NOT NULL OR @aforomax IS NOT NULL OR @ubicacion IS NOT NULL OR @imagen IS NOT NULL
        BEGIN
            SELECT -3 AS codigo, 'Evento confirmado: solo se permite editar título y descripción. Los campos logísticos están bloqueados.' AS mensaje;
            RETURN;
        END
    END

    DECLARE @horarioiActual DATETIME;
    DECLARE @horariofActual DATETIME;
    DECLARE @ubicacionActual VARCHAR(250);

    SELECT @horarioiActual = horarioi, @horariofActual = horariof, @ubicacionActual = ubicacion
    FROM dbo.Eventos
    WHERE id = @id;

    DECLARE @horarioiEval DATETIME = ISNULL(@horarioi, @horarioiActual);
    DECLARE @horariofEval DATETIME = ISNULL(@horariof, @horariofActual);
    DECLARE @ubicacionEval VARCHAR(250) = ISNULL(@ubicacion, @ubicacionActual);

    IF @horarioiEval >= @horariofEval
    BEGIN
        SELECT -4 AS codigo, 'El horario de inicio debe ser anterior al horario de fin.' AS mensaje;
        RETURN;
    END

    IF @aforomax IS NOT NULL AND @aforomax <= 0
    BEGIN
        SELECT -5 AS codigo, 'El aforo máximo debe ser un número positivo.' AS mensaje;
        RETURN;
    END

    IF @horarioi IS NOT NULL OR @horariof IS NOT NULL OR @ubicacion IS NOT NULL
    BEGIN
        SELECT @hayConflicto = COUNT(*)
        FROM dbo.Eventos
        WHERE id != @id
          AND UPPER(estado) NOT IN ('CANCELADO', 'FINALIZADO')
          AND ubicacion = @ubicacionEval
          AND (
                (@horarioiEval >= horarioi AND @horarioiEval < horariof)
                OR
                (@horariofEval > horarioi AND @horariofEval <= horariof)
                OR
                (@horarioiEval <= horarioi AND @horariofEval >= horariof)
              );

        IF @hayConflicto > 0
        BEGIN
            SELECT -6 AS codigo, 'Conflicto de horario: ya existe un evento activo en esa ubicación durante ese rango de tiempo.' AS mensaje;
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            UPDATE dbo.Eventos
            SET
                titulo      = ISNULL(@titulo, titulo),
                descripcion = ISNULL(@descripcion, descripcion),
                horarioi    = ISNULL(@horarioi, horarioi),
                horariof    = ISNULL(@horariof, horariof),
                aforomax    = ISNULL(@aforomax, aforomax),
                ubicacion   = ISNULL(@ubicacion, ubicacion),
                imagen      = ISNULL(@imagen, imagen)
            WHERE id = @id;

            SET @msgNotif = 'Evento modificado: ' + (SELECT titulo FROM dbo.Eventos WHERE id = @id);

            INSERT INTO dbo.notificaciones (id, descripcion, leida, fecha)
            VALUES (@id, @msgNotif, 0, GETDATE());

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Evento actualizado exitosamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_BorrarEvento
    @id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @estadoActual VARCHAR(15);
    DECLARE @tituloEvento VARCHAR(50);
    DECLARE @msgNotif VARCHAR(100);

    SELECT @estadoActual = UPPER(estado), @tituloEvento = titulo
    FROM dbo.Eventos
    WHERE id = @id;

    IF @estadoActual IS NULL
    BEGIN
        SELECT -1 AS codigo, 'El evento especificado no existe.' AS mensaje;
        RETURN;
    END

    IF @estadoActual IN ('FINALIZADO', 'CANCELADO')
    BEGIN
        SELECT -2 AS codigo, 'No se puede eliminar un evento ' + @estadoActual + '.' AS mensaje;
        RETURN;
    END

    IF @estadoActual = 'CONFIRMADO'
    BEGIN
        SELECT -3 AS codigo, 'No se puede eliminar un evento confirmado. Use la opción de cancelación.' AS mensaje;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            SET @msgNotif = 'Evento eliminado: ' + @tituloEvento;

            INSERT INTO dbo.notificaciones (id, descripcion, leida, fecha)
            VALUES (@id, @msgNotif, 0, GETDATE());

            DELETE FROM dbo.Eventos WHERE id = @id;

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Evento eliminado exitosamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerEventos
    @mes INT = NULL,
    @anio INT = NULL,
    @estado VARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @mesEval INT = ISNULL(@mes, MONTH(GETDATE()));
    DECLARE @anioEval INT = ISNULL(@anio, YEAR(GETDATE()));

    IF @mesEval < 1 OR @mesEval > 12
    BEGIN
        SELECT -1 AS codigo, 'El mes debe estar entre 1 y 12.' AS mensaje;
        RETURN;
    END

    IF @estado IS NOT NULL AND UPPER(@estado) NOT IN ('COTIZADO', 'CONFIRMADO', 'FINALIZADO', 'CANCELADO')
    BEGIN
        SELECT -2 AS codigo, 'Estado no válido.' AS mensaje;
        RETURN;
    END

    SELECT
        id,
        titulo,
        descripcion,
        horarioi,
        horariof,
        aforomax,
        ubicacion,
        estado,
        CASE UPPER(estado)
            WHEN 'COTIZADO'   THEN '#4CAF50'
            WHEN 'CONFIRMADO' THEN '#2196F3'
            WHEN 'CANCELADO'  THEN '#F44336'
            WHEN 'FINALIZADO' THEN '#9E9E9E'
        END AS colorCalendario
    FROM dbo.Eventos
    WHERE
        MONTH(horarioi) = @mesEval
        AND YEAR(horarioi) = @anioEval
        AND (@estado IS NULL OR UPPER(estado) = UPPER(@estado))
    ORDER BY horarioi ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerEventoPorId
    @id INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Eventos WHERE  id = @id)
    BEGIN
        SELECT -1 AS codigo, 'El evento especificado no existe.' AS mensaje;
        RETURN;
    END

    SELECT
        e.id,
        e.titulo,
        e.descripcion,
        e.horarioi,
        e.horariof,
        e.aforomax,
        e.ubicacion,
        e.imagen,
        e.estado,
        e.cedulac,
        e.cedulap,
        CASE UPPER(e.estado)
            WHEN 'COTIZADO'   THEN '#4CAF50'
            WHEN 'CONFIRMADO' THEN '#2196F3'
            WHEN 'CANCELADO'  THEN '#F44336'
            WHEN 'FINALIZADO' THEN '#9E9E9E'
        END AS colorCalendario,
        CASE UPPER(e.estado)
            WHEN 'CONFIRMADO' THEN 1
            WHEN 'FINALIZADO' THEN 1
            WHEN 'CANCELADO'  THEN 1
            ELSE 0
        END AS camposLogisticosBloqueados,
        CASE UPPER(e.estado)
            WHEN 'FINALIZADO' THEN 1
            WHEN 'CANCELADO'  THEN 1
            ELSE 0
        END AS soloLectura
    FROM dbo.Eventos e
    WHERE e.id = @id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoEvento
    @id INT,
    @nuevoEstado VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @estadoActual VARCHAR(15);
    DECLARE @tituloEvento VARCHAR(50);
    DECLARE @msgNotif VARCHAR(100);

    SELECT @estadoActual = UPPER(estado), @tituloEvento = titulo
    FROM dbo.Eventos
    WHERE id = @id;

    IF @estadoActual IS NULL
    BEGIN
        SELECT -1 AS codigo, 'El evento especificado no existe.' AS mensaje;
        RETURN;
    END

    SET @nuevoEstado = UPPER(@nuevoEstado);

    IF @nuevoEstado NOT IN ('COTIZADO', 'CONFIRMADO', 'FINALIZADO', 'CANCELADO')
    BEGIN
        SELECT -2 AS codigo, 'Estado no válido.' AS mensaje;
        RETURN;
    END

    IF @estadoActual = @nuevoEstado
    BEGIN
        SELECT -3 AS codigo, 'El evento ya se encuentra en ese estado.' AS mensaje;
        RETURN;
    END

    IF @estadoActual IN ('FINALIZADO', 'CANCELADO')
    BEGIN
        SELECT -4 AS codigo, 'No se puede cambiar el estado de un evento ' + @estadoActual + '.' AS mensaje;
        RETURN;
    END

    IF @estadoActual = 'COTIZADO' AND @nuevoEstado NOT IN ('CONFIRMADO', 'CANCELADO')
    BEGIN
        SELECT -5 AS codigo, 'Transición no permitida: un evento COTIZADO solo puede pasar a CONFIRMADO o CANCELADO.' AS mensaje;
        RETURN;
    END

    IF @estadoActual = 'CONFIRMADO' AND @nuevoEstado NOT IN ('FINALIZADO', 'CANCELADO')
    BEGIN
        SELECT -6 AS codigo, 'Transición no permitida: un evento CONFIRMADO solo puede pasar a FINALIZADO o CANCELADO.' AS mensaje;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            UPDATE dbo.Eventos
            SET estado = @nuevoEstado
            WHERE id = @id;

            SET @msgNotif = 'Evento "' + @tituloEvento + '" cambió a estado: ' + @nuevoEstado;

            INSERT INTO dbo.notificaciones (id, descripcion, leida, fecha)
            VALUES (@id, @msgNotif, 0, GETDATE());

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Estado actualizado exitosamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje;
    END CATCH;
END;
GO

--modulo de clientes

CREATE OR ALTER PROCEDURE dbo.sp_CrearProveedor
    @cedula INT,
    @nombre VARCHAR(50),
    @descripcion VARCHAR(100),
    @contactos VARCHAR(30),
    @correo VARCHAR(200),
    @telefono VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.proveedores WHERE cedula = @cedula)
    BEGIN
        SELECT -1 AS codigo, 'Ya existe un proveedor con esa cédula.' AS mensaje;
        RETURN;
    END

    IF LTRIM(RTRIM(@nombre)) = ''
    BEGIN
        SELECT -2 AS codigo, 'El nombre es obligatorio.' AS mensaje;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            INSERT INTO dbo.proveedores (cedula, nombre, descripcion, contactos, correo, telefono)
            VALUES (@cedula, @nombre, @descripcion, @contactos, @correo, @telefono);

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Proveedor agregado exitosamente.' AS mensaje, @cedula AS cedula;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje, NULL AS cedula;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_EditarProveedor
    @cedulap     INT,
    @nombre      VARCHAR(50)  = NULL,
    @descripcion VARCHAR(200) = NULL,
    @contactos   VARCHAR(30)  = NULL,
    @correo      VARCHAR(200) = NULL,
    @telefono    VARCHAR(15)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @msgNotif VARCHAR(100);

    IF NOT EXISTS (SELECT 1 FROM dbo.proveedores WHERE cedula = @cedulap)
    BEGIN
        SELECT -1 AS codigo, 'El proveedor no existe' AS mensaje;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            
            UPDATE dbo.proveedores
            SET
                nombre      = ISNULL(@nombre,      nombre),
                descripcion = ISNULL(@descripcion, descripcion),
                contactos   = ISNULL(@contactos,   contactos),
                correo      = ISNULL(@correo,       correo),
                telefono    = ISNULL(@telefono,     telefono)
            WHERE cedula = @cedulap;

           
            SET @msgNotif = 'Proveedor modificado: ' + (
                SELECT nombre + ' - ' + CAST(cedula AS VARCHAR(10))
                FROM dbo.proveedores
                WHERE cedula = @cedulap
            );

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Proveedor editado exitosamente.' AS mensaje, @cedulap AS cedula;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje, NULL AS cedula;
    END CATCH;

END;
GO


CREATE OR ALTER PROCEDURE dbo.sp_BorrarProveedor
    @cedulap     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.proveedores WHERE cedula = @cedulap)
    BEGIN
        SELECT -1 AS codigo, 'El proveedor no existe' AS mensaje;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            DELETE FROM dbo.proveedores WHERE cedula = @cedulap;

        COMMIT TRANSACTION;

        SELECT 0 AS codigo, 'Proveedor eliminado exitosamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT -99 AS codigo, 'Error interno: ' + ERROR_MESSAGE() AS mensaje;
    END CATCH;
END;
GO


