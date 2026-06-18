# Calendario-Innovam 
creacion de un calendario dinamico para la gestion de eventos

USE master; 
GO

IF DB_ID('ApiGenericaDB') IS NOT NULL BEGIN ALTER DATABASE ApiGenericaDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ApiGenericaDB; 
END
GO

CREATE DATABASE ApiGenericaDB;
GO

USE ApiGenericaDB; 
GO

--SEGURIDAD BASE 
CREATE TABLE usuario ( email VARCHAR(200) PRIMARY KEY, contrasena VARCHAR(200) NOT NULL );

CREATE TABLE rol ( id INT IDENTITY(1,1) PRIMARY KEY, nombre VARCHAR(100) NOT NULL );

CREATE TABLE rol_usuario ( id INT IDENTITY(1,1) PRIMARY KEY, fkemail VARCHAR(200), fkidrol INT, FOREIGN KEY (fkemail) REFERENCES usuario(email), FOREIGN KEY (fkidrol) REFERENCES rol(id) );

CREATE TABLE ruta ( id INT IDENTITY(1,1) PRIMARY KEY, ruta VARCHAR(200), descripcion VARCHAR(MAX) DEFAULT '' );

CREATE TABLE rutarol ( id INT IDENTITY(1,1) PRIMARY KEY, fkidrol INT, fkidruta INT, FOREIGN KEY (fkidrol) REFERENCES rol(id), FOREIGN KEY (fkidruta) REFERENCES ruta(id) );

CREATE TABLE clientes (cedula int primary key, nombre varchar(50), correo varchar(200), telefono varchar(15));

CREATE TABLE Proovedores (cedula int primary key, nombre varchar(50), descripcion varchar(100), contactos varchar (30), correo varchar(200), telefono varchar(15));

CREATE TABLE Eventos (id INT identity (1,1) primary key, cedulac int foreign key references clientes(cedula),cedulap int foreign key references proovedores(cedula) ,titulo varchar(50), imagen VARBINARY(MAX), descripcion varchar(200), horarioi datetime,horariof datetime,aforomax int, ubicación varchar(250), estado varchar(15) check (upper(estado) in ('confirmado','cancelado','cotizado','finalizado')));

CREATE TABLE notificaciones(idN int identity (1,1) primary key, id int foreign key references eventos(id), descripción varchar(100), leida bit default 0, fecha datetime);

--procedimientos almacenados
go
CREATE or alter PROCEDURE sp_CrearEvento
    @titulo        VARCHAR(50),
    @descripcion   VARCHAR(200),
    @horarioi      DATETIME,
    @horariof      DATETIME,
    @aforomax      INT,
    @ubicacion     VARCHAR(250),
    @cedulac       INT,
    @imagen        VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;


    DECLARE @idEventoNuevo  INT;
    DECLARE @hayConflicto   INT = 0;
    DECLARE @msgNotif       VARCHAR(100);



    -- Horario lógico
    IF @horarioi >= @horariof
    BEGIN
        SELECT 
            -1          AS codigo,
            'El horario de inicio debe ser anterior al horario de fin.' AS mensaje,
            NULL        AS idEvento;
        RETURN;
    END

    -- Cliente existe
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE cedula = @cedulac)
    BEGIN
        SELECT 
            -2          AS codigo,
            'El cliente especificado no existe en el sistema.' AS mensaje,
            NULL        AS idEvento;
        RETURN;
    END

    -- Aforo válido
    IF @aforomax <= 0
    BEGIN
        SELECT 
            -3          AS codigo,
            'El aforo máximo debe ser un número positivo.' AS mensaje,
            NULL        AS idEvento;
        RETURN;
    END


    -- Detecta si ya existe un evento activo que se solape
    -- en el mismo espacio o rango de tiempo
    SELECT @hayConflicto = COUNT(*)
    FROM Eventos
    WHERE estado NOT IN ('cancelado', 'finalizado')
      AND ubicacion = @ubicacion
      AND (
            -- El nuevo evento empieza dentro de uno existente
            (@horarioi >= horarioi AND @horarioi < horariof)
            OR
            -- El nuevo evento termina dentro de uno existente  
            (@horariof > horarioi AND @horariof <= horariof)
            OR
            -- El nuevo evento envuelve completamente a uno existente
            (@horarioi <= horarioi AND @horariof >= horariof)
          );

    IF @hayConflicto > 0
    BEGIN
        SELECT 
            -4          AS codigo,
            'Conflicto de horario: ya existe un evento activo en esa ubicación durante ese rango de tiempo.' AS mensaje,
            NULL        AS idEvento;
        RETURN;
    END


    BEGIN TRY
        BEGIN TRANSACTION;

            -- Insertar el evento (estado inicial: cotizado, patrón Factory)
            INSERT INTO Eventos (
                cedulac, titulo, imagen, descripcion,
                horarioi, horariof, aforomax, ubicación, estado
            )
            VALUES (
                @cedulac, @titulo, @imagen, @descripcion,
                @horarioi, @horariof, @aforomax, @ubicacion, 'cotizado'
            );

            SET @idEventoNuevo = SCOPE_IDENTITY();

            -- Construir mensaje de notificación
            SET @msgNotif = 'Nuevo evento creado: ' + @titulo;

            -- Disparar notificación (patrón Observer)
            INSERT INTO notificaciones (id, descripción, leida, fecha)
            VALUES (@idEventoNuevo, @msgNotif, 0, GETDATE());

        COMMIT TRANSACTION;

        -- Respuesta exitosa
        SELECT 
            0               AS codigo,
            'Evento creado exitosamente.' AS mensaje,
            @idEventoNuevo  AS idEvento;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT 
            -99             AS codigo,
            'Error interno: ' + ERROR_MESSAGE() AS mensaje,
            NULL            AS idEvento;
    END CATCH;
END;

go

CREATE or alter PROCEDURE sp_EditarEvento
    @id          INT,
    @titulo      VARCHAR(50)    = NULL,
    @descripcion VARCHAR(200)   = NULL,
    @horarioi    DATETIME       = NULL,
    @horariof    DATETIME       = NULL,
    @aforomax    INT            = NULL,
    @ubicacion   VARCHAR(250)   = NULL,
    @imagen      VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @estadoActual  VARCHAR(15);
    DECLARE @hayConflicto  INT = 0;
    DECLARE @msgNotif      VARCHAR(100);

   
    SELECT @estadoActual = estado
    FROM Eventos
    WHERE id = @id;

    IF @estadoActual IS NULL
    BEGIN
        SELECT 
            -1   AS codigo,
            'El evento especificado no existe.' AS mensaje;
        RETURN;
    END

    -- Finalizado y cancelado nunca se pueden editar
    IF @estadoActual IN ('finalizado', 'cancelado')
    BEGIN
        SELECT 
            -2   AS codigo,
            'No se puede editar un evento ' + @estadoActual + '.' AS mensaje;
        RETURN;
    END

    -- Confirmado: solo permite editar titulo y descripcion
    -- Los campos logísticos quedan bloqueados (patrón State)
    IF @estadoActual = 'confirmado'
    BEGIN
        IF @horarioi  IS NOT NULL OR
           @horariof  IS NOT NULL OR
           @aforomax  IS NOT NULL OR
           @ubicacion IS NOT NULL OR
           @imagen    IS NOT NULL
        BEGIN
            SELECT 
                -3   AS codigo,
                'Evento confirmado: solo se permite editar título y descripción. Los campos logísticos están bloqueados.' AS mensaje;
            RETURN;
        END
    END

  

    -- Horario lógico
    DECLARE @horarioiActual DATETIME;
    DECLARE @horariofActual DATETIME;
    DECLARE @ubicacionActual VARCHAR(250);

    SELECT 
        @horarioiActual  = horarioi,
        @horariofActual  = horariof,
        @ubicacionActual = ubicación
    FROM Eventos
    WHERE id = @id;

    -- Usar valor actual si no se envía el parámetro
    DECLARE @horarioiEval  DATETIME  = ISNULL(@horarioi,  @horarioiActual);
    DECLARE @horariofEval  DATETIME  = ISNULL(@horariof,  @horariofActual);
    DECLARE @ubicacionEval VARCHAR(250) = ISNULL(@ubicacion, @ubicacionActual);

    IF @horarioiEval >= @horariofEval
    BEGIN
        SELECT 
            -4   AS codigo,
            'El horario de inicio debe ser anterior al horario de fin.' AS mensaje;
        RETURN;
    END

    IF @aforomax IS NOT NULL AND @aforomax <= 0
    BEGIN
        SELECT 
            -5   AS codigo,
            'El aforo máximo debe ser un número positivo.' AS mensaje;
        RETURN;
    END

   
    -- Solo si cambia horario o ubicación
    IF @horarioi IS NOT NULL OR @horariof IS NOT NULL OR @ubicacion IS NOT NULL
    BEGIN
        SELECT @hayConflicto = COUNT(*)
        FROM Eventos
        WHERE id != @id  -- excluir el evento que se está editando
          AND estado NOT IN ('cancelado', 'finalizado')
          AND ubicacion = @ubicacionEval
          AND (
                (@horarioiEval >= horarioi AND @horarioiEval < horariof)
                OR
                (@horariofEval > horarioi  AND @horariofEval <= horariof)
                OR
                (@horarioiEval <= horarioi AND @horariofEval >= horariof)
              );

        IF @hayConflicto > 0
        BEGIN
            SELECT 
                -6   AS codigo,
                'Conflicto de horario: ya existe un evento activo en esa ubicación durante ese rango de tiempo.' AS mensaje;
            RETURN;
        END
    END

  
    BEGIN TRY
        BEGIN TRANSACTION;

            UPDATE Eventos
            SET
                titulo      = ISNULL(@titulo,      titulo),
                descripcion = ISNULL(@descripcion, descripcion),
                horarioi    = ISNULL(@horarioi,    horarioi),
                horariof    = ISNULL(@horariof,    horariof),
                aforomax    = ISNULL(@aforomax,    aforomax),
                ubicación   = ISNULL(@ubicacion,   ubicación),
                imagen      = ISNULL(@imagen,      imagen)
            WHERE id = @id;

            -- Notificación Observer
            SET @msgNotif = 'Evento modificado: ' + 
                            (SELECT titulo FROM Eventos WHERE id = @id);

            INSERT INTO notificaciones (id, descripción, leida, fecha)
            VALUES (@id, @msgNotif, 0, GETDATE());

        COMMIT TRANSACTION;

        SELECT 
            0    AS codigo,
            'Evento actualizado exitosamente.' AS mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT 
            -99  AS codigo,
            'Error interno: ' + ERROR_MESSAGE() AS mensaje;
    END CATCH;
END;
