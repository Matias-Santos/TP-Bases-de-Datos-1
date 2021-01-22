-- Created by Vertabelo (http://vertabelo.com)
-- Last modification date: 2020-10-21 20:03:10.015

-- tables
-- Table: G04_Billetera
CREATE TABLE G04_Billetera (
    id_usuario int  NOT NULL,
    moneda varchar(10)  NOT NULL,
    saldo decimal(20,10)  NOT NULL,
    CONSTRAINT PK_G04_Billetera PRIMARY KEY (id_usuario,moneda)
);

-- Table: G04_ComposicionOrden
CREATE TABLE G04_ComposicionOrden (
    id_o int8  NOT NULL,
    id_d int8  NOT NULL,
    cantidad numeric(20,10)  NOT NULL,
    CONSTRAINT PK_G04_ComposicionOrden PRIMARY KEY (id_o,id_d)
);

-- Table: G04_Mercado
CREATE TABLE G04_Mercado (
    nombre varchar(20)  NOT NULL,
    moneda_o varchar(10)  NOT NULL,
    moneda_d varchar(10)  NOT NULL,
    precio_mercado numeric(20,10)  NOT NULL,
    CONSTRAINT PK_G04_Mercado  PRIMARY KEY (nombre)
);

-- Table: G04_Moneda
CREATE TABLE G04_Moneda (
    moneda varchar(10)  NOT NULL,
    nombre varchar(80)  NOT NULL,
    descripcion varchar(2048)  NOT NULL,
    alta timestamp  NOT NULL,
    estado char(1)  NOT NULL,
    fiat char(1)  NOT NULL,
    CONSTRAINT PK_G04_Moneda PRIMARY KEY (moneda)
);

-- Table: G04_Movimiento
CREATE TABLE G04_Movimiento (
    id_usuario int  NOT NULL,
    moneda varchar(10)  NOT NULL,
    fecha timestamp  NOT NULL,
    tipo char(1)  NOT NULL,
    comision decimal(20,10)  NOT NULL,
    valor decimal(20,10)  NOT NULL,
    bloque int  NULL,
    direccion varchar(100)  NULL,
    CONSTRAINT PK_G04_Movimiento PRIMARY KEY (id_usuario,moneda,fecha)
);

-- Table: G04_Orden
CREATE TABLE G04_Orden (
    id bigserial  NOT NULL,
    mercado varchar(20)  NOT NULL,
    id_usuario int  NOT NULL,
    tipo char(10)  NOT NULL,
    fecha_creacion timestamp  NOT NULL,
    fecha_ejec timestamp  NULL,
    valor decimal(20,10)  NOT NULL,
    cantidad decimal(20,10)  NOT NULL,
    estado char(10)  NOT NULL,
    CONSTRAINT PK_G04_Orden PRIMARY KEY (id)
);

-- Table: G04_Pais
CREATE TABLE G04_Pais (
    id_pais int  NOT NULL,
    nombre varchar(40)  NOT NULL,
    cod_telef int  NOT NULL,
    CONSTRAINT PK_G04_Pais PRIMARY KEY (id_pais)
);

-- Table: G04_RelMoneda
CREATE TABLE G04_RelMoneda (
    moneda varchar(10)  NOT NULL,
    monedaf varchar(10)  NOT NULL,
    fecha timestamp  NOT NULL,
    valor numeric(20,10)  NOT NULL,
    CONSTRAINT PK_G04_RelMoneda PRIMARY KEY (moneda,monedaf,fecha)
);

-- Table: G04_Usuario
CREATE TABLE G04_Usuario (
    id_usuario int  NOT NULL,
    apellido varchar(40)  NOT NULL,
    nombre varchar(40)  NOT NULL,
    fecha_alta date  NOT NULL,
    estado char(10)  NOT NULL,
    email varchar(120)  NOT NULL,
    password varchar(120)  NOT NULL,
    telefono bigint  NOT NULL,
    id_pais int  NOT NULL,
    CONSTRAINT PK_G04_Usuario PRIMARY KEY (id_usuario)
);

-- foreign keys
-- Reference: fk_Billetera_Moneda (table: G04_Billetera)
ALTER TABLE G04_Billetera ADD CONSTRAINT FK_G04_Billetera_Moneda
    FOREIGN KEY (moneda)
    REFERENCES G04_Moneda (moneda)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_Billetera_Usuario (table: G04_Billetera)
ALTER TABLE G04_Billetera ADD CONSTRAINT FK_G04_Billetera_Usuario
    FOREIGN KEY (id_usuario)
    REFERENCES G04_Usuario (id_usuario)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_CompOp_Op_d (table: G04_ComposicionOrden)
ALTER TABLE G04_ComposicionOrden ADD CONSTRAINT FK_G04_CompOp_Op_d
    FOREIGN KEY (id_d)
    REFERENCES G04_Orden (id)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_CompOp_Op_o (table: G04_ComposicionOrden)
ALTER TABLE G04_ComposicionOrden ADD CONSTRAINT FK_G04_CompOp_Op_o
    FOREIGN KEY (id_o)
    REFERENCES G04_Orden (id)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_Movimiento_Billetera (table: G04_Movimiento)
ALTER TABLE G04_Movimiento ADD CONSTRAINT FK_G04_Movimiento_Billetera
    FOREIGN KEY (id_usuario, moneda)
    REFERENCES G04_Billetera (id_usuario, moneda)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_Operacion_Mercado (table: G04_Orden)
ALTER TABLE G04_Orden ADD CONSTRAINT FK_G04_Operacion_Mercado
    FOREIGN KEY (mercado)
    REFERENCES G04_Mercado (nombre)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_Operacion_Usuario (table: G04_Orden)
ALTER TABLE G04_Orden ADD CONSTRAINT FK_G04_Operacion_Usuario
    FOREIGN KEY (id_usuario)
    REFERENCES G04_Usuario (id_usuario)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_RelMoneda_Moneda (table: G04_RelMoneda)
ALTER TABLE G04_RelMoneda ADD CONSTRAINT FK_G04_RelMoneda_Moneda
    FOREIGN KEY (monedaf)
    REFERENCES G04_Moneda (moneda)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_RelMoneda_Monedaf (table: G04_RelMoneda)
ALTER TABLE G04_RelMoneda ADD CONSTRAINT FK_G04_RelMoneda_Monedaf
    FOREIGN KEY (moneda)
    REFERENCES G04_Moneda (moneda)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_Usuario_Pais (table: G04_Usuario)
ALTER TABLE G04_Usuario ADD CONSTRAINT FK_G04_Usuario_Pais
    FOREIGN KEY (id_pais)
    REFERENCES G04_Pais (id_pais)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_mercado_moneda_d (table: G04_Mercado)
ALTER TABLE G04_Mercado ADD CONSTRAINT FK_G04_mercado_moneda_d
    FOREIGN KEY (moneda_d)
    REFERENCES G04_Moneda (moneda)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- Reference: fk_mercado_moneda_o (table: G04_Mercado)
ALTER TABLE G04_Mercado ADD CONSTRAINT FK_G04_mercado_moneda_o
    FOREIGN KEY (moneda_o)
    REFERENCES G04_Moneda (moneda)  
    NOT DEFERRABLE 
    INITIALLY IMMEDIATE
;

-- End of file.

