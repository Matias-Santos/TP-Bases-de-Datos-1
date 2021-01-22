------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------Apartado B-------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.1

/*
alter table g04_movimiento
add constraint  ck_g04_control_bloque check (bloque > (select max(m.bloque)
                                                              from g04_movimiento m
                                                              where (m.moneda = moneda) and (fecha > m.fecha)));
*/

create or replace function trfn_g04_getMaxBloque(monedaVar varchar(10)) returns integer as $$
    declare
        maxBloque integer;
    begin
        select max(bloque) into maxBloque
        from g04_movimiento
        where moneda = monedaVar;
        if (maxBloque is null) then
            return -1;
        else
            return maxBloque;
        end if;
    end $$ language 'plpgsql';

create or replace function trfn_g04_isMaxFecha(fechaVar timestamp, monedaVar varchar(10)) returns boolean as $$
    declare
        maxFecha timestamp;
    begin
        select max(m.fecha) into maxFecha
            from g04_movimiento m
            where m.moneda = monedaVar;
        if (maxFecha is null) or (maxFecha <= fechaVar) then
            raise warning 'entro true';
            return true;
        else
            return false;
        end if;
    end $$ language 'plpgsql';

create or replace function trfn_g04_controlBloque() returns trigger as $$
--Funcion que se encarga de controlar que el bloque y la fecha a insertar sean mayor a su max actual
    begin
        if (new.bloque > trfn_g04_getMaxBloque(new.moneda)) then
            if (trfn_g04_isMaxFecha(new.fecha, new.moneda)) then
                raise warning 'entro a';
                return new;
            else
                raise exception 'Error de inserccion en movimiento por fecha menor a la max';
            end if;
        else
            raise exception 'Error de inserccion en movimiento por numero de bloque';
        end if;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_controlbloque on g04_movimiento;
create trigger tr_g04_controlBloque
    before insert
    on g04_movimiento
    for each row
        execute function trfn_g04_controlBloque();

/*
-- Insert que usaremos de prueba para probar el funcionamiento correcto del trigger
insert into g04_movimiento values (1, 'ADA', current_date, 'e', 0.5, 12344, 5, null);

-- Checkeo que no se permita el insert de abajo, por restriccion de fecha
insert into g04_movimiento values (1, 'ADA', timestamp '1997-06-12 00:00:00', 'e', 0.5, 12344, 6, null);

-- Checkeo que no se permita el insert de abajo, por restriccion de bloque
insert into g04_movimiento values (1, 'ADA', current_date, 'e', 0.5, 12344, 4, null);

-- Checkeo que no se permita el insert de abajo, por restriccion de bloque y fecha
insert into g04_movimiento values (1, 'ADA', current_date, 'e', 0.5, 12344, 4, null);
*/
------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.2

/*
create assertion as_g04_control_bloque check ( not exists (select 1 from g04_orden o
                                                    where (o.tipo = 'venta') and o.cantidad <= (select b.saldo
                                                                                                    from g04_billetera b
                                                                                                    where (b.id_usuario = o.id_usuario) and billetera in (select m.moneda_o
                                                                                                                                                                from mercado m
                                                                                                                                                                where (m.nombre like o.mercado)
                                                                                                                            ))) and
                                                not exists (select 1 from g04_orden o
                                                    where (o.tipo = 'compra') and (o.cantidad * o.valor) <= (select b.saldo
                                                                                                    from g04_billetera b
                                                                                                    where (b.id_usuario = o.id_usuario) and billetera in (select m.moneda_d
                                                                                                                                                                from mercado m
                                                                                                                                                                where (m.nombre like o.mercado)
                                                                                                                            ))));
*/

create or replace function trfn_g04_getSaldo(idUsuarioVar integer,monedaVar varchar(20)) returns decimal(20,10) as $$
    declare
        saldoVar decimal(20,10);
    begin
        select saldo into saldoVar
        from g04_billetera
                where (id_usuario = idUsuarioVar) and (moneda like monedaVar);
        if(saldoVar is null) then
            return 0;
        end if;
        return saldoVar;
    end $$ language 'plpgsql';

create or replace function trfn_g04_controlarSaldoOrdenCompra() returns trigger as $$
    declare
        monedaoVar varchar(20);
        monedadVar varchar(20);
        saldoVar decimal(20,10);
    begin
        select moneda_o, moneda_d into monedaoVar,monedadVar
            from g04_mercado
            where nombre like new.mercado;
            saldoVar:= trfn_g04_getSaldo(new.id_usuario,monedadVar);
        if(saldoVar < (new.valor * new.cantidad)) then
            raise exception 'El usuario % no tiene saldo suficiente para comprar % monedas de % al precio que quiere' , new.id_usuario, new.cantidad, monedaoVar;
        end if;
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_controlarSaldoOrdenVenta() returns trigger as $$
    declare
        monedaVar varchar(20);
        saldoVar decimal(20,10);
    begin
        select moneda_o into monedaVar
            from g04_mercado
            where nombre like new.mercado;
            saldoVar:= trfn_g04_getSaldo(new.id_usuario,monedaVar);
        if(saldoVar < new.cantidad) then
            raise exception 'El usuario % no tiene % de % para vender' , new.id_usuario, new.cantidad, monedaVar;
        end if;
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_controlarSaldoOrdenVenta on g04_orden;
create trigger tr_g04_controlarSaldoOrdenVenta
    before insert or update of valor,cantidad
    on g04_orden
    for each row when (new.tipo = 'venta')
    execute function trfn_g04_controlarSaldoOrdenVenta();

drop trigger if exists tr_g04_controlarSaldoOrdenCompra on g04_orden;
create trigger tr_g04_controlarSaldoOrdenCompra
    before insert or update of valor,cantidad
    on g04_orden
    for each row when (new.tipo = 'compra')
    execute function trfn_g04_controlarSaldoOrdenCompra();

/*
-- Checkeo de funcionamiento correcto de los triggers del ejercicio B.2

delete from g04_orden where (id_usuario = 1) and (mercado like 'ETC/PAX');
delete from g04_billetera where (id_usuario = 1) and (moneda like 'PAX');
-- Este insert no deberia ejecutarse, ya que el usuario no tiene una billetera de PAX
insert into g04_orden values (20000, 'ETC/PAX', 1, 'compra', current_date, null, 10, 43, 'activo');

insert into g04_billetera values (1,'PAX', 100);
-- Este insert no deberia ejecutarse, ya que el usuario no tiene saldo suficiente de PAX para comprar la cantidad de
-- monedas que quiere comprar de ETC, al precio que pide
insert into g04_orden values (20001, 'ETC/PAX', 1, 'compra', current_date, null, 10, 100, 'activo');


delete from g04_billetera where (id_usuario = 1) and (moneda like 'ETC');
-- Este insert no deberia ejecutarse, ya que el usuario no tiene una billetera de ETC
insert into g04_orden values (20002, 'ETC/PAX', 1, 'venta', current_date, null, 10,10, 'activo');

insert into g04_billetera values (1,'ETC', 5);
-- Este insert no deberia ejecutarse, ya que el usuario no tiene suficientes ETC para vender
insert into g04_orden values (20003, 'ETC/PAX', 1, 'venta', current_date, null, 10, 10, 'activo');
*/

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.3

/*
create assertion as_g04_compruebaOrdenesRetiro check(not exists(select 1 from g04_movimiento mov
                                                    where exists(select 1 from g04_orden o join g04_mercado m on o.mercado=m.nombre
                                                                    where (o.estado ='activo') and (o.id_usuario = mov.id_usuario)
                                                                      and ((mov.moneda = m.moneda_d) or (mov.moneda = m.moneda_o)))));
*/

create or replace function trfn_g04_compruebaOrdenesRetiro() returns trigger as $$
    begin
        if exists(select 1 from g04_orden o
                    where (o.estado = 'activo') and (o.id_usuario = new.id_usuario) and
                          (o.mercado in (select m.nombre from g04_mercado m where (m.moneda_o = new.moneda) or (m.moneda_d = new.moneda)))) then
            raise exception 'El usuario % tiene ordenes activas de la moneda %, por lo tanto no puede retirar', new.id_usuario, new.moneda;
        end if;
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_compruebaOrdenesRetiro on g04_movimiento;
create trigger tr_g04_compruebaOrdenesRetiro
    after insert
    on g04_movimiento
    for each row when (new.tipo = 's')
        execute function trfn_g04_compruebaOrdenesRetiro();


/*
-- Checkeo de funcionamiento correcto del trigger del ejercicio B.3

delete from g04_orden where (id_usuario = 1) and (mercado like 'ETC/PAX');
insert into g04_orden values (20004, 'ETC/PAX', 1, 'venta', current_date, null, 10, 1, 'activo');
insert into g04_movimiento values (1, 'ETC', current_date, 's', 0.05, 12344, null, null);
*/
------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.4
ALTER TABLE g04_movimiento
drop constraint if exists ck_g04_movimiento_checkeoNulidad;
ALTER TABLE g04_movimiento
ADD CONSTRAINT ck_g04_movimiento_checkeoNulidad CHECK ((direccion is null and bloque is null) or
                                                       (direccion is not null and bloque is not null));

/*
-- Checkeo de funcionamiento correcto del constraint del ejercicio B.4

insert into g04_movimiento values(1,'ETC', current_date, 's', 0.05, 100, 2134365, null);
insert into g04_movimiento values(1,'ETC', current_date, 's', 0.05, 100, null, 'direccion 1');
*/

------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------Apartado C-------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicico C.1.a

create or replace function fn_g04_devuelvePrecioMercado(mercadoConsultado varchar(20)) returns numeric(20,10) as $$
    declare
        cotizacionMer numeric(20,10);
    begin
        select precio_mercado into cotizacionMer
        from g04_mercado
        where (nombre like mercadoConsultado);
        return cotizacionMer;
    end $$ language 'plpgsql';

-- Checkeo del funcionamiento de la funcion
--select * from fn_g04_devuelvePrecioMercado('BTC/USDT');

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicico C.1.b

create or replace function trfn_g04_generaDireccion() returns varchar(100) as $$
    --Funcion que se encarga de generar de forma random una direccion.
    declare
        i integer:= 1;
        auxDir varchar(100):='';
        chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
    begin
        loop
            exit when i > 100;
                auxDir:= auxDir || chars[1+random()*(array_length(chars, 1)-1)];
                i:= i + 1;
        end loop;
        return auxDir;
    end $$ language 'plpgsql';

create or replace function trfn_g04_tieneOrdenesActivas(idVar bigint,id_usuarioVar integer, mercadoVar varchar(20)) returns boolean as $$
    --Funcion que se engarga de comprobar si tiene ordenes activas ya en ese mercado
    begin
        if (exists(select 1
                from g04_orden o
                where (o.id_usuario = id_usuarioVar) and (o.mercado like mercadoVar) and (o.estado = 'activo') and (o.id <> idVar ) ) ) then
            return true;
        else
            return false;
        end if;
    end $$ language 'plpgsql';

create or replace function trfn_g04_ejecucionOrdenCompra() returns trigger as $$
    declare
        cantAcum numeric(20,10):=0;
        saldoGastado numeric(20,10):=0;
        monedas record;
        tupla record;
    begin
        -- Obtengo las monedas sobre las que van a suceder operaciones
        select moneda_o , moneda_d into monedas
        from g04_mercado
        where (nombre like new.mercado);

        -- Pregunto si el usuario que quiere insertar la orden tiene alguna orden activa para ese mercado
        if (trfn_g04_tieneOrdenesActivas(new.id,new.id_usuario, new.mercado)) then
            raise exception 'El usuario % ya tiene una orden activa para el mercado % ',  new.id_usuario, new.mercado;
        end if;

        update g04_orden set estado= 'pendiente' where id=new.id;

        -- Recorro la tabla de orden para ver si se puede ejecutar alguna orden de venta
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'venta') and (o.estado = 'activo') and (o.mercado like new.mercado) and (valor <= new.valor)
                            order by valor,fecha_creacion loop

            -- Chequeo que la cantidad no supere a la cantidad maxima a comprar
            if (cantAcum + tupla.cantidad <= new.cantidad) then

                -- Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoGastado := saldoGastado + (tupla.valor * tupla.cantidad);

                -- Modifico la orden de venta a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_date , estado = 'finalizado' where id = tupla.id;

                -- Actualizo las billeteras del vendedor
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo= (saldo + (tupla.valor * tupla.cantidad * 0.95))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Update del saldo en la moneda que se va a vender en la transaccion
                update g04_billetera set saldo= (saldo - tupla.cantidad)
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_o);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,new.id,tupla.cantidad);

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,current_timestamp,'e',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,current_timestamp,'s',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());

            end if;

            -- Esto cortaria solo para algunos casos especificos en el que ya completamos la orden y sigue habiendo ordenes que se pueden cumplir
            if (cantAcum = new.cantidad) then
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            update g04_billetera set saldo =  (saldo - saldoGastado) where (id_usuario = new.id_usuario and moneda = monedas.moneda_d);
            update g04_billetera set saldo = (saldo + (cantAcum * 0.95)) where (id_usuario = new.id_usuario and moneda = monedas.moneda_o);
            update g04_orden set fecha_ejec = current_date, estado= 'finalizado' where id=new.id;
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_d,current_timestamp,'s',0.05,saldoGastado,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_o,current_timestamp,'e',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
        else
            update g04_orden set estado= 'activo' where id=new.id;
        end if;

        return new;

    end $$ language 'plpgsql';

create or replace function trfn_g04_ejecucionOrdenVenta() returns trigger as $$
    declare
        cantAcum numeric(20,10):=0;
        saldoObtenido numeric(20,10):=0;
        monedas record;
        tupla record;
    begin
        -- Obtengo las monedas sobre las que van a suceder operaciones
        select moneda_o , moneda_d into monedas
        from g04_mercado
        where (nombre like new.mercado);

        -- Pregunto si el usuario que quiere insertar la orden tiene alguna orden activa para ese mercado
        if (trfn_g04_tieneOrdenesActivas(new.id,new.id_usuario, new.mercado)) then
            raise exception 'El usuario % ya tiene una orden activa para el mercado % ',  new.id_usuario, new.mercado;
        end if;

        update g04_orden set estado = 'pendiente' where id = new.id;

        -- Recorro la tabla de orden para ver si se puede ejecutar alguna orden de compra
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'compra') and (o.estado = 'activo') and (o.mercado like new.mercado) and (o.valor >= new.valor)
                            order by valor,fecha_creacion desc loop

            -- Chequeo que la cantidad no supere a la cantidad maxima a comprar
           if (cantAcum + tupla.cantidad <= new.cantidad) then

                -- Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoObtenido := saldoObtenido + (new.valor * tupla.cantidad);

                -- Modifico la orden de compra a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_date , estado = 'finalizado' where id = tupla.id;

                --Actualizo las billeteras del comprador
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad * 0.95))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_o);
                -- Update del saldo en la moneda que se va a vender en la transaccion
                update g04_billetera set saldo = (saldo - (new.valor * tupla.cantidad))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,new.id,tupla.cantidad);

                -- Insertar movimientos comprador
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,current_timestamp,'e',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,current_timestamp,'s',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            end if;

            -- Esto cortaria solo para algunos casos especificos en el que ya completamos la orden y sigue habiendo ordenes que se pueden cumplir
            if (cantAcum = new.cantidad) then
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            update g04_billetera set saldo = (saldo - cantAcum) where (id_usuario = new.id_usuario and moneda = monedas.moneda_o);
            update g04_billetera set saldo = (saldo + (saldoObtenido * 0.95)) where (id_usuario = new.id_usuario and moneda = monedas.moneda_d);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=new.id;
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_d,current_timestamp,'s',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_o,current_timestamp,'e',0.05,saldoObtenido,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
        else
            update g04_orden set estado= 'activo' where id=new.id;
        end if;

        return new;

    end $$ language 'plpgsql';


drop trigger if exists tr_g04_ejecucionOrdenCompra on g04_orden;
create trigger tr_g04_ejecucionOrdenCompra
    after insert
    on g04_orden
    for each row when (new.tipo = 'compra')
    execute function trfn_g04_ejecucionOrdenCompra();

drop trigger if exists tr_g04_ejecucionOrdenVenta on g04_orden;
create trigger tr_g04_ejecucionOrdenVenta
    after insert
    on g04_orden
    for each row when (new.tipo = 'venta')
    execute function trfn_g04_ejecucionOrdenVenta();

-- Resolucion del ejercicico C.1.C

create or replace function fn_g04_mostrarOrdenesCronologicamente(mercadoVar varchar(20), fechaDesde timestamp)
    returns table (id bigint, fecha_creacion timestamp, tipo char(10), estado char(10)) as $$
    declare
        tupla record;
    begin
        for tupla in select o.id, o.fecha_creacion, o.tipo,o.estado
                        from g04_orden o
                        where (o.mercado like mercadoVar) and ( o.fecha_creacion between fechaDesde and current_date)
                        order by o.fecha_creacion,o.id loop
            id:=tupla.id;
            fecha_creacion:= tupla.fecha_creacion;
            tipo:= tupla.tipo;
            estado:= tupla.estado;
            return next;
            end loop;

    end $$ language 'plpgsql';

-- Checkeo del funcionamiento de la funcion
/*
select * from fn_g04_mostrarOrdenesCronologicamente('BTC/USDT',timestamp '1997-06-12 00:00:00');
*/

------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------Apartado D-------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicico D.1

create or replace view g04_mostrarBilleteras as
    select *
    from g04_billetera;

select * from g04_mostrarBilleteras where moneda like 'BTC' order by id_usuario ;

-- Resolucion del ejercicico D.2

create or replace view g04_mostrarCotizacionUSDT as
    select b.id_usuario,b.moneda, (m.precio_mercado * b.saldo) as precio_cotizacion_usdt
    from g04_billetera b left join g04_mercado m on b.moneda = m.moneda_o
        where (m.moneda_d like 'USDT');

create or replace view g04_mostrarCotizacionBTC as
    select b.id_usuario,b.moneda,(m.precio_mercado * b.saldo) as precio_cotizacion_btc
    from g04_billetera b  left join g04_mercado m on b.moneda = m.moneda_o
        where (m.moneda_d like 'BTC');

create or replace view g04_mostrarCotizacionBTCyUSDT as
    select b.*,mcb.precio_cotizacion_btc, mcu.precio_cotizacion_usdt
    from g04_billetera b
        join g04_mostrarCotizacionBTC mcb on mcb.moneda = b.moneda
        join g04_mostrarCotizacionUSDT mcu on mcu.moneda = b.moneda
        where (b.id_usuario = mcb.id_usuario) and (b.id_usuario = mcu.id_usuario);

select *
from g04_mostrarCotizacionBTCyUSDT
order by id_usuario;

-- Resolucion del ejercicico D.3

create or replace view g04_mostrar10usuariosMasRicos as
    select a.id_usuario, sum(a.precio_cotizacion_btc) as "total billeteras"
    from g04_mostrarCotizacionBTCyUSDT a
    group by a.id_usuario
    order by "total billeteras" desc
    limit 10;

select * from g04_mostrar10usuariosMasRicos;