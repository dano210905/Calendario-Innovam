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

-- Seguridad: crear tabla usuario (se había quedado comentada)
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

-- Procedimientos almacenados
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

    -- Horario lógico
    IF @horarioi >= @horariof
    BEGIN
        SELECT -1 AS codigo, 'El horario de inicio debe ser anterior al horario de fin.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    -- Cliente existe
    IF NOT EXISTS (SELECT 1 FROM dbo.clientes WHERE cedula = @cedulac)
    BEGIN
        SELECT -2 AS codigo, 'El cliente especificado no existe en el sistema.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    -- Aforo válido
    IF @aforomax <= 0
    BEGIN
        SELECT -3 AS codigo, 'El aforo máximo debe ser un número positivo.' AS mensaje, NULL AS idEvento;
        RETURN;
    END

    -- Detecta conflicto en misma ubicación y rango de tiempo
    SELECT @hayConflicto = COUNT(*)
    FROM dbo.Eventos
    WHERE estado NOT IN ('cancelado', 'finalizado')
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
                @horarioi, @horariof, @aforomax, @ubicacion, 'cotizado'
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

    SELECT @estadoActual = estado FROM dbo.Eventos WHERE id = @id;

    IF @estadoActual IS NULL
    BEGIN
        SELECT -1 AS codigo, 'El evento especificado no existe.' AS mensaje;
        RETURN;
    END

    IF @estadoActual IN ('finalizado', 'cancelado')
    BEGIN
        SELECT -2 AS codigo, 'No se puede editar un evento ' + @estadoActual + '.' AS mensaje;
        RETURN;
    END

    IF @estadoActual = 'confirmado'
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
          AND estado NOT IN ('cancelado', 'finalizado')
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
                titulo = ISNULL(@titulo, titulo),
                descripcion = ISNULL(@descripcion, descripcion),
                horarioi = ISNULL(@horarioi, horarioi),
                horariof = ISNULL(@horariof, horariof),
                aforomax = ISNULL(@aforomax, aforomax),
                ubicacion = ISNULL(@ubicacion, ubicacion),
                imagen = ISNULL(@imagen, imagen)
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