------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- Delete de todas las tablas en el orden correcto, para poder eliminar todas las relaciones
delete from g04_composicionorden where cantidad >=0;
delete from g04_movimiento where bloque >=0;
delete from g04_billetera where id_usuario >=0;
delete from g04_orden where id>=0;
delete from g04_usuario where id_usuario >=0;
delete from g04_pais where id_pais>=0;
delete from g04_mercado where precio_mercado >=0;
delete from g04_moneda where estado = 'A';

------------------------------------------------------------------------------------------------------------------------
-- Drop de las resoluciones del ejercicio E
------------------------------------------------------------------------------------------------------------------------

drop trigger if exists tr_g04_ejecucionOrden on g04_orden;
drop function if exists trfn_g04_ejecucionOrden();

------------------------------------------------------------------------------------------------------------------------
-- Drop de las resoluciones del ejercicio D
------------------------------------------------------------------------------------------------------------------------

-- Delete de los triggers para las vistas
drop trigger if exists tr_g04_deleteVista10usuariosMasRicos on g04_mostrar10usuariosMasRicos;
drop function if exists trfn_g04_deleteVista10usuariosMasRicos();
drop trigger if exists tr_g04_updateVista10usuariosMasRicos on g04_mostrar10usuariosMasRicos;
drop function if exists trfn_g04_updateVista10usuariosMasRicos();
drop trigger if exists tr_g04_insertVista10usuariosMasRicos on g04_mostrar10usuariosMasRicos;
drop function if exists trfn_g04_insertVista10usuariosMasRicos();
drop view if exists g04_mostrar10usuariosMasRicos;

drop trigger if exists  tr_g04_deleteBilleterasDeLaVistaBTCyUSDT on g04_mostrarCotizacionBTCyUSDT;
drop trigger if exists tr_g04_deleteBilleterasDeLaVistaUSDT on g04_mostrarCotizacionUSDT;
drop trigger if exists tr_g04_deleteBilleterasDeLaVistaBTC on g04_mostrarCotizacionBTC;
drop function if exists trfn_g04_deleteBilleterasDeLaVista();

drop trigger if exists tr_g04_updateBilleterasDeLaVistaBTCyUSDT on g04_mostrarCotizacionBTCyUSDT;
drop trigger if exists tr_g04_updateBilleterasDeLaVistaUSDT on g04_mostrarCotizacionUSDT;
drop trigger if exists tr_g04_updateBilleterasDeLaVistaBTC on g04_mostrarCotizacionBTC;
drop function if exists trfn_g04_updateBilleterasDeLaVistaBTCyUSDT();
drop function if exists trfn_g04_updateBilleterasDeLaVistaUSDT();
drop function if exists trfn_g04_updateBilleterasDeLaVistaBTC();

drop trigger if exists tr_g04_insertBilleterasDeLaVistaBTCyUSDT on g04_mostrarCotizacionBTCyUSDT;
drop trigger if exists tr_g04_insertBilleterasDeLaVistaUSDT on g04_mostrarCotizacionUSDT;
drop trigger if exists tr_g04_insertBilleterasDeLaVistaBTC on g04_mostrarCotizacionBTC;
drop function if exists trfn_g04_insertBilleterasDeLaVistaBTCyUSDT();
drop function if exists trfn_g04_insertBilleterasDeLaVistaUSDT();
drop function if exists trfn_g04_insertBilleterasDeLaVistaBTC();

drop view if exists g04_mostrarCotizacionBTCyUSDT;
drop view if exists g04_mostrarCotizacionUSDT;
drop view if exists g04_mostrarCotizacionBTC;
drop view if exists g04_mostrarBilleteras;

------------------------------------------------------------------------------------------------------------------------
-- Drop de las resoluciones del ejercicio C
------------------------------------------------------------------------------------------------------------------------

drop function if exists fn_g04_mostrarOrdenesCronologicamente(mercadovar varchar(20), fechadesde timestamp);
drop function if exists trfn_g04_ejecucionOrden();
drop procedure if exists pr_g04_ejecutarOrden(idvar bigint);
drop procedure if exists pr_g04_ejecucionordencompra(ordenaejecutar record);
drop procedure if exists pr_g04_ejecucionordenventa(ordenaejecutar record);
drop function if exists trfn_g04_tieneordenesactivas(idvar bigint, id_usuariovar integer, mercadovar varchar);
drop function if exists trfn_g04_generaDireccion();
drop function if exists fn_g04_calculoSuma(stop numeric(20,10),mercadoVar varchar(20),tipoVar char(10),orden varchar(4));
drop function if exists fn_g04_calculaTotalCrypto(mercadoVar varchar(20), tipoVar char(10));
drop function if exists fn_g04_devuelvePrecioMercado(mercadoConsultado varchar(20));

------------------------------------------------------------------------------------------------------------------------
-- Drop de las resoluciones del ejercicio B
------------------------------------------------------------------------------------------------------------------------

alter table g04_movimiento
drop constraint if exists ck_g04_movimiento_checkeoNulidad;
drop trigger if exists tr_g04_compruebaOrdenesRetiro on g04_movimiento;
drop function if exists trfn_g04_compruebaOrdenesRetiro();
drop trigger if exists tr_g04_controlarSaldoOrdenCompra on g04_orden;
drop trigger if exists tr_g04_controlarSaldoOrdenVenta on g04_orden;
drop function if exists trfn_g04_controlarSaldoOrdenVenta();
drop function if exists trfn_g04_controlarSaldoOrdenCompra();
drop function if exists trfn_g04_getSaldo(idUsuarioVar integer, monedaVar varchar(20));
drop trigger if exists tr_g04_controlbloque on g04_movimiento;
drop function if exists trfn_g04_controlBloque();
drop function if exists trfn_g04_isMaxFecha(fechaVar timestamp, monedaVar varchar(10));
drop function if exists trfn_g04_getMaxBloque(monedaVar varchar(10));
drop procedure if exists pr_g04_insertaOrdenesMasivas(cantVar integer);
drop procedure if exists pr_g04_insertOrdenes(mercadoVar varchar(20),moneda_oVar varchar(10) ,moneda_dVar varchar(10),cantOrdenes integer);
drop function if exists fn_g04_getTimestamp();
drop function if exists fn_g04_getSigID();
drop trigger if exists tr_g04_calcularPrecioMercado on g04_orden;
drop function if exists trfn_g04_calcularPrecioMercado();
drop view if exists g04_precioSobreMercado;
drop trigger if exists tr_g04_insertUsuarios on g04_usuario;
drop trigger if exists tr_g04_insertBilleteraNueva on g04_moneda;
drop function if exists trfn_g04_insertUsuarios();
drop function if exists trfn_g04_insertBilleteraNueva();
drop procedure if exists pr_g04_insertUsuarios(cantUsuariosVar integer);
drop function if exists fn_g04_fechasRandom(desde timestamp, hasta timestamp);


------------------------------------------------------------------------------------------------------------------------
-- Drop de las resoluciones del ejercicio A
------------------------------------------------------------------------------------------------------------------------

alter table G04_ComposicionOrden
    drop constraint if exists FK_G04_CompOp_Op_o;
alter table G04_ComposicionOrden
    drop constraint if exists FK_G04_CompOp_Op_d;
alter table G04_Movimiento
    drop constraint if exists FK_G04_Movimiento_Billetera;
alter table G04_Billetera
    drop constraint if exists FK_G04_Billetera_Usuario;
alter table G04_Billetera
    drop constraint if exists FK_G04_Billetera_Moneda;
alter table G04_Orden
    drop constraint if exists FK_G04_Operacion_Usuario;
alter table G04_Orden
    drop constraint if exists FK_G04_Operacion_Mercado;
alter table G04_Usuario
    drop constraint if exists FK_G04_Usuario_Pais;
alter table G04_RelMoneda
    drop constraint if exists FK_G04_RelMoneda_Moneda;
alter table G04_RelMoneda
    drop constraint if exists  FK_G04_RelMoneda_Moneda;
alter table G04_Mercado
    drop constraint if exists FK_G04_mercado_moneda_o;
alter table G04_Mercado
    drop constraint if exists FK_G04_mercado_moneda_d;

alter table G04_ComposicionOrden drop constraint if exists PK_G04_ComposicionOrden cascade;
alter table G04_Movimiento drop constraint if exists PK_G04_Movimiento cascade;
alter table G04_Billetera drop constraint if exists PK_G04_Billetera cascade;
alter table G04_Orden drop constraint if exists PK_G04_Orden cascade;
alter table G04_Usuario drop constraint if exists PK_G04_Usuario cascade;
alter table G04_Pais drop constraint if exists PK_G04_Pais cascade;
alter table G04_RelMoneda drop constraint if exists PK_G04_RelMoneda cascade;
alter table G04_Mercado drop constraint if exists PK_G04_Mercado cascade;
alter table G04_Moneda drop constraint if exists PK_G04_Moneda cascade;

drop table if exists G04_ComposicionOrden;
drop table if exists G04_Movimiento;
drop table if exists G04_Billetera;
drop table if exists G04_Orden;
drop table if exists G04_Usuario;
drop table if exists G04_Pais;
drop table if exists G04_RelMoneda;
drop table if exists G04_Mercado;
drop table if exists G04_Moneda;

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------