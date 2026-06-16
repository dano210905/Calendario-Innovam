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

CREATE TABLE Eventos (id INT identity (1,1) primary key, cedulac int foreign key references clientes(cedula) ,titulo varchar(50), imagen VARBINARY(MAX), descripcion varchar(200), horarioi datetime,horariof datetime,aforomax int, ubicación varchar(250), estado varchar(15) check (upper(estado) in ('confirmado','cancelado','cotizado','finalizado')));

CREATE TABLE notificaciones(idN int identity (1,1) primary key, id int foreign key references eventos(id), descripción varchar(100), leida bit default 0, fecha datetime);
