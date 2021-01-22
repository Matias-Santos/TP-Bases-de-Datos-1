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

-- Checkeo de funcionamiento correcto de los triggers del ejercicio B.2

/*
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

-- Checkeo de funcionamiento correcto del trigger del ejercicio B.3

/*
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

-- Funcionalidad relacionada al calculo del precio mercado

-- Vista que tiene una columna que ya posee precio/cantidad calculado para facilitarnos las funciones
drop view if exists g04_precioSobreMercado;
create view g04_precioSobreMercado as
    select o.mercado, o.valor*o.cantidad as "valor",o.cantidad, o.tipo
        from g04_orden o
        where (o.estado = 'activo');

-- Funcion que se encarga de calcular el total de crypto segun el tipo que reciba
create or replace function fn_g04_calculaTotalCrypto(mercadoVar varchar(20),tipoVar char(10)) returns numeric(20,10) as $$
    declare
        total numeric(20,10);
    begin
        total:=0;
        select sum(p.cantidad) into total
            from g04_precioSobreMercado p
            where (p.tipo = tipoVar) and (p.mercado like mercadoVar);
        if (total is null) then
            return 0;
        else
            return total;
        end if;
    end $$ language 'plpgsql';

-- Funcion que realiza la sumatoria de precio/cantidad
create or replace function fn_g04_calculoSuma(stop numeric(20,10),mercadoVar varchar(20),tipoVar char(10),orden varchar(4)) returns numeric(20,10) as $$
    declare
        totalSuma numeric(20,10):=0;
        cantAux numeric(20,10):=0;
        tupla record;
    begin
        raise warning 'entra con cantAux: % , stop: % ', cantAux, stop;
        raise warning 'entra con tupla: %' ,tupla;
        for tupla in
                --select p.valor, p.cantidad
                select *
                from g04_precioSobreMercado p
                where (p.mercado like mercadoVar) and (p.tipo = tipoVar)
                order by
                    case when orden like 'asc' then
                        (p.valor, p.cantidad) end,
                    case when orden like 'desc' then
                        (p.valor, p.cantidad) end desc
            loop
                raise warning 'cantAux: % , stop: % ', cantAux, stop;
                raise warning 'tupla: %' ,tupla;
                if (cantAux + tupla.cantidad <= stop) then
                    totalSuma := totalSuma + tupla.valor;
                    cantAux := cantAux + tupla.cantidad;
                else
                    exit;
                end if;
            end loop;
        return totalSuma;
    end $$ language 'plpgsql';

-- Funcion que se encarga de llamar a las otras funciones que nos sirven para calcular el precio mercado, la misma
-- a partir de los datos,calcula y modifica el precio_mercado en g04_mercado segun el mercado de la orden que se inserta
create or replace function fn_g04_devuelvePrecioMercado(mercadoVar varchar(20)) returns numeric(20,10) as $$
    declare
        totalCryptoV numeric(20,10):=0;
        totalCryptoC numeric(20,10):=0;
        totalValorC numeric(20,10):=0;
        totalValorV numeric(20,10):=0;
        precioMercadoActual numeric(20,10):=0;
    begin
        --Calculo la cantidad total de crypto en compra y en venta
        totalCryptoC:= fn_g04_calculaTotalCrypto(mercadoVar,'compra') * 0.2;
        totalCryptoV:= fn_g04_calculaTotalCrypto(mercadoVar,'venta') * 0.2;

        --Sumo hasta el indice calculado y almaceno el valor en sus variables
        totalValorC:= fn_g04_calculoSuma(totalCryptoC ,mercadoVar ,'compra' ,'desc');
        totalValorV:= fn_g04_calculoSuma(totalCryptoV ,mercadoVar ,'venta','asc');

        --Calculo el promedio entre estos dos valores y lo asigno
        precioMercadoActual:= (coalesce(totalValorC,0) + coalesce(totalValorV,0))/2;
        return precioMercadoActual;
    end $$ language 'plpgsql';

--Creacion del trigger que se va a activar cuando se inserte una orden nueva
create or replace function trfn_g04_calcularPrecioMercado() returns trigger as $$
    begin
        update g04_mercado set precio_mercado = fn_g04_devuelvePrecioMercado(new.mercado) where nombre = new.mercado;
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_calcularPrecioMercado on g04_orden;
create trigger tr_g04_calcularPrecioMercado
    after insert or update of estado,fecha_ejec
    on g04_orden
    for each row
        execute function trfn_g04_calcularPrecioMercado();

-- Actualizo la tabla G04_Mercado con los precios de las monedas de cada mercado utilizando la funcion
update g04_mercado set precio_mercado = fn_g04_devuelvepreciomercado(nombre);

-- Checkeo del funcionamiento de la funcion
/*
select * from fn_g04_devuelvePrecioMercado('BTC/USDT');
*/
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

create or replace procedure pr_g04_ejecucionOrdenCompra(ordenAEjecutar record) as $$
    declare
        cantAcum numeric(20,10):=0;
        saldoGastado numeric(20,10):=0;
        monedas record;
        tupla record;
    begin
        -- Obtengo las monedas sobre las que van a suceder operaciones
        select moneda_o , moneda_d into monedas
        from g04_mercado
        where (nombre like ordenAEjecutar.mercado);

        -- Pregunto si el usuario que quiere insertar la orden tiene alguna orden activa para ese mercado
        if (trfn_g04_tieneOrdenesActivas(ordenAEjecutar.id,ordenAEjecutar.id_usuario, ordenAEjecutar.mercado)) then
            raise exception 'El usuario % ya tiene una orden activa para el mercado % ',  ordenAEjecutar.id_usuario, ordenAEjecutar.mercado;
        end if;

        update g04_billetera set saldo = (saldo - ordenAEjecutar.valor * ordenAEjecutar.cantidad)  where id_usuario = ordenAEjecutar.id_usuario and moneda like monedas.moneda_d;
        update g04_orden set estado= 'pendiente' where id=ordenAEjecutar.id;

        -- Recorro la tabla de orden para ver si se puede ejecutar alguna orden de venta
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'venta') and (o.estado = 'activo') and (o.mercado like ordenAEjecutar.mercado) and (valor <= ordenAEjecutar.valor)
                            order by valor loop

            -- Chequeo que la cantidad no supere a la cantidad maxima a comprar
            if (cantAcum + tupla.cantidad <= ordenAEjecutar.cantidad) then

                -- Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoGastado := saldoGastado + (tupla.valor * tupla.cantidad);

                -- Modifico la orden de venta a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;

                -- Actualizo las billeteras del vendedor
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo= (saldo + (tupla.valor * tupla.cantidad * 0.95))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,ordenAEjecutar.id,tupla.cantidad);

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());

            -- Esto cortaria solo para algunos casos especificos en el que ya completamos la orden y sigue habiendo ordenes que se pueden cumplir
            else
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            if (cantAcum < ordenAEjecutar.cantidad) then
                update g04_billetera set saldo = saldo + (ordenAEjecutar.cantidad * ordenAEjecutar.valor - saldoGastado) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_d);
            end if;
            update g04_billetera set saldo = (saldo + (cantAcum * 0.95)) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_o);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=ordenAEjecutar.id;
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,saldoGastado,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
        else
            update g04_orden set estado= 'activo' where id=ordenAEjecutar.id;
        end if;

    end $$ language 'plpgsql';

create or replace procedure pr_g04_ejecucionOrdenVenta(ordenAEjecutar record) as $$
    declare
        cantAcum numeric(20,10):=0;
        saldoObtenido numeric(20,10):=0;
        monedas record;
        tupla record;
    begin
        -- Obtengo las monedas sobre las que van a suceder operaciones
        select moneda_o , moneda_d into monedas
        from g04_mercado
        where (nombre like ordenAEjecutar.mercado);

        -- Pregunto si el usuario que quiere insertar la orden tiene alguna orden activa para ese mercado
        if (trfn_g04_tieneOrdenesActivas(ordenAEjecutar.id,ordenAEjecutar.id_usuario, ordenAEjecutar.mercado)) then
            raise exception 'El usuario % ya tiene una orden activa para el mercado % ',  ordenAEjecutar.id_usuario, ordenAEjecutar.mercado;
        end if;

        update g04_billetera set saldo = (saldo - ordenAEjecutar.cantidad)  where id_usuario = ordenAEjecutar.id_usuario and moneda like monedas.moneda_o;
        update g04_orden set estado = 'pendiente' where id = ordenAEjecutar.id;

        -- Recorro la tabla de orden para ver si se puede ejecutar alguna orden de compra
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'compra') and (o.estado = 'activo') and (o.mercado like ordenAEjecutar.mercado) and (o.valor >= ordenAEjecutar.valor)
                            order by valor desc loop

            -- Chequeo que la cantidad no supere a la cantidad maxima a comprar
           if (cantAcum + tupla.cantidad <= ordenAEjecutar.cantidad) then

                -- Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoObtenido := saldoObtenido + (ordenAEjecutar.valor * tupla.cantidad);

                -- Modifico la orden de compra a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;

                --Actualizo las billeteras del comprador
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad * 0.95))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_o);
                -- Update del saldo en la moneda que se va a vender en la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad * tupla.valor) - (ordenAEjecutar.valor * tupla.cantidad))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,ordenAEjecutar.id,tupla.cantidad);

                -- Insertar movimientos comprador
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());

            -- Esto cortaria solo para algunos casos especificos en el que ya completamos la orden y sigue habiendo ordenes que se pueden cumplir
            else
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            if (cantAcum < ordenAEjecutar.cantidad) then
                update g04_billetera set saldo = (saldo + ordenAEjecutar.cantidad - cantAcum) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_o);
            end if;
            update g04_billetera set saldo = (saldo + (saldoObtenido * 0.95)) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_d);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=ordenAEjecutar.id;
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,saldoObtenido,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
        else
            update g04_orden set estado= 'activo' where id=ordenAEjecutar.id;
        end if;

    end $$ language 'plpgsql';

create or replace procedure pr_g04_ejecutarOrden(idVar bigint) as $$
    declare
        tupla record;
    begin
        select * into tupla
            from g04_orden where id = idVar;
        raise warning 'idVar: %, tupla: % ', idVar, tupla;
        if (tupla.fecha_ejec is null) then
            if (tupla.tipo = 'venta')then
                call pr_g04_ejecucionOrdenVenta(tupla);
            else
                if (tupla.tipo = 'compra') then
                    call pr_g04_ejecucionOrdenCompra(tupla);
                else
                    raise exception 'El tipo de la orden no es correcto';
                end if;
            end if;
        else
            raise exception 'La orden que se quiere ejecutar ya se ha ejecutado anteriormente';
        end if;

    end $$ language 'plpgsql';

create or replace function trfn_g04_ejecucionOrden() returns trigger as $$
    begin
        call pr_g04_ejecutarOrden(new.id);
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_ejecucionOrdenCompra on g04_orden;
create trigger tr_g04_ejecucionOrdenCompra
    after insert
    on g04_orden
    for each row when (new.tipo = 'compra')
    execute function trfn_g04_ejecucionOrden();

drop trigger if exists tr_g04_ejecucionOrdenVenta on g04_orden;
create trigger tr_g04_ejecucionOrdenVenta
    after insert
    on g04_orden
    for each row when (new.tipo = 'venta')
    execute function trfn_g04_ejecucionOrden();

-- Resolucion del ejercicico C.1.c

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

-- Definicion de los trigger para que la vista sea actualizable

-- Definicion para los insert
create or replace function trfn_g04_insertBilleterasDeLaVistaUSDT() returns trigger as $$
    declare
        precio_cotizacion numeric(20,10);
    begin
        select precio_mercado into precio_cotizacion
        from g04_mercado
        where moneda_o like new.moneda and moneda_d like 'USDT';
        if(not exists(select 1 from g04_billetera where id_usuario= new.id_usuario and moneda like new.moneda)) then
            insert into g04_billetera values(new.id_usuario,new.moneda,new.precio_cotizacion_usdt/precio_cotizacion);
        else
            update g04_billetera set saldo = new.precio_cotizacion_usdt/precio_cotizacion where id_usuario=new.id_usuario and moneda like new.moneda;
        end if;
        insert into g04_movimiento values (new.id_usuario,new.moneda,current_timestamp,'e',0.05,new.precio_cotizacion_usdt/precio_cotizacion,trfn_g04_getMaxBloque(new.moneda) + 1,trfn_g04_generaDireccion());
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_insertBilleterasDeLaVistaBTC() returns trigger as $$
    declare
        precio_cotizacion numeric(20,10);
    begin
        select precio_mercado into precio_cotizacion
        from g04_mercado
        where moneda_o like new.moneda and moneda_d like 'BTC';
        if(not exists(select 1 from g04_billetera where id_usuario= new.id_usuario and moneda like new.moneda)) then
            insert into g04_billetera values(new.id_usuario,new.moneda,new.precio_cotizacion_btc/precio_cotizacion);
        else
            update g04_billetera set saldo = new.precio_cotizacion_btc/precio_cotizacion where id_usuario=new.id_usuario and moneda like new.moneda;
        end if;
        insert into g04_movimiento values (new.id_usuario,new.moneda,current_timestamp,'e',0.05,new.precio_cotizacion_btc/precio_cotizacion,trfn_g04_getMaxBloque(new.moneda) + 1,trfn_g04_generaDireccion());
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_insertBilleterasDeLaVistaBTCyUSDT() returns trigger as $$
    begin
        if(not exists(select 1 from g04_billetera where id_usuario= new.id_usuario and moneda like new.moneda)) then
            insert into g04_billetera values(new.id_usuario,new.moneda,new.saldo);
        else
            update g04_billetera set saldo = new.saldo where id_usuario=new.id_usuario and moneda like new.moneda;
        end if;
        insert into g04_movimiento values (new.id_usuario,new.moneda,current_timestamp,'e',0.05,new.saldo,trfn_g04_getMaxBloque(new.moneda) + 1,trfn_g04_generaDireccion());
        return new;
    end $$ language 'plpgsql';

--Trigger instead of para los insert

create trigger tr_g04_insertBilleterasDeLaVistaBTC
    instead of insert
    on g04_mostrarCotizacionBTC
    for each row
        execute function trfn_g04_insertBilleterasDeLaVistaBTC();

create trigger tr_g04_insertBilleterasDeLaVistaUSDT
    instead of insert
    on g04_mostrarCotizacionUSDT
    for each row
        execute function trfn_g04_insertBilleterasDeLaVistaUSDT();

create trigger tr_g04_insertBilleterasDeLaVistaBTCyUSDT
    instead of insert
    on g04_mostrarCotizacionBTCyUSDT
    for each row
        execute function trfn_g04_insertBilleterasDeLaVistaBTCyUSDT();

-- Sentencia de activacion

/*
insert into g04_mostrarCotizacionBTC values(1,'BTC',5156);
insert into g04_mostrarCotizacionUSDT values(1,'BTC',51.25);
insert into g04_mostrarCotizacionBTCyUSDT  values(1,'BTC',5446,0,0);
*/

-- Definicion para los update

create or replace function trfn_g04_updateBilleterasDeLaVistaUSDT() returns trigger as $$
    declare
        precio_cotizacion numeric(20,10);
    begin
        select precio_mercado into precio_cotizacion
        from g04_mercado
        where moneda_o like new.moneda and moneda_d like 'USDT';
        update g04_billetera set saldo = new.precio_cotizacion_usdt/precio_cotizacion where id_usuario=new.id_usuario and moneda like new.moneda;
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_updateBilleterasDeLaVistaBTC() returns trigger as $$
    declare
        precio_cotizacion numeric(20,10);
    begin
        select precio_mercado into precio_cotizacion
        from g04_mercado
        where moneda_o like new.moneda and moneda_d like 'BTC';
        update g04_billetera set saldo = new.precio_cotizacion_btc/precio_cotizacion where id_usuario=new.id_usuario and moneda like new.moneda;
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_updateBilleterasDeLaVistaBTCyUSDT() returns trigger as $$
    begin
        update g04_billetera set saldo = new.saldo where id_usuario=new.id_usuario and moneda like new.moneda;
        return new;
    end $$ language 'plpgsql';

-- Trigger instead of para los update
create trigger tr_g04_updateBilleterasDeLaVistaBTC
    instead of update
    on g04_mostrarCotizacionBTC
    for each row
        execute function trfn_g04_updateBilleterasDeLaVistaBTC();

create trigger tr_g04_updateBilleterasDeLaVistaUSDT
    instead of update
    on g04_mostrarCotizacionUSDT
    for each row
        execute function trfn_g04_updateBilleterasDeLaVistaUSDT();

create trigger tr_g04_updateBilleterasDeLaVistaBTCyUSDT
    instead of update
    on g04_mostrarCotizacionBTCyUSDT
    for each row
        execute function trfn_g04_updateBilleterasDeLaVistaBTCyUSDT();

-- Definicion para los delete
create or replace function trfn_g04_deleteBilleterasDeLaVista() returns trigger as $$
    begin
        delete from g04_billetera where id_usuario = old.id_usuario and moneda like old.moneda;
        return old;
    end $$ language 'plpgsql';


-- Trigger instead of para los delete
create trigger tr_g04_deleteBilleterasDeLaVistaBTC
    instead of delete
    on g04_mostrarCotizacionBTC
    for each row
        execute function trfn_g04_deleteBilleterasDeLaVista();

create trigger tr_g04_deleteBilleterasDeLaVistaUSDT
    instead of delete
    on g04_mostrarCotizacionUSDT
    for each row
        execute function trfn_g04_deleteBilleterasDeLaVista();

create trigger tr_g04_deleteBilleterasDeLaVistaBTCyUSDT
    instead of delete
    on g04_mostrarCotizacionBTCyUSDT
    for each row
        execute function trfn_g04_deleteBilleterasDeLaVista();

-- Resolucion del ejercicico D.3

create or replace view g04_mostrar10usuariosMasRicos as
    select a.id_usuario, sum(a.precio_cotizacion_btc) as "total billeteras"
    from g04_mostrarCotizacionBTCyUSDT a
    group by a.id_usuario
    order by "total billeteras" desc
    limit 10;

--Definicion de los trigger y funciones para que la vista sea actualizable

create or replace function trfn_g04_insertVista10usuariosMasRicos() returns trigger as $$
    begin
        if(exists(select 1 from g04_usuario where id_usuario=new.id_usuario)) then
            update g04_billetera set saldo = new."total billeteras" where id_usuario= new.id_usuario and moneda like 'BTC';
        else
            raise exception 'El usuario % no existe ',new.id_usuario;
        end if;
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_updateVista10usuariosMasRicos() returns trigger as $$
    begin
        update g04_billetera set saldo = 0 where id_usuario = new.id_usuario;
        update g04_billetera set saldo = new."total billeteras" where id_usuario= new.id_usuario and moneda like 'BTC';
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_deleteVista10usuariosMasRicos() returns trigger as $$
    begin
        update g04_usuario set estado= 'inactivo' where id_usuario=old.id_usuario;
        return old;
    end $$ language 'plpgsql';

create trigger tr_g04_insertVista10usuariosMasRicos
    instead of insert
    on g04_mostrar10usuariosMasRicos
    for each row
        execute function trfn_g04_insertVista10usuariosMasRicos();

create trigger tr_g04_updateVista10usuariosMasRicos
    instead of update
    on g04_mostrar10usuariosMasRicos
    for each row
        execute function trfn_g04_updateVista10usuariosMasRicos();

create trigger tr_g04_deleteVista10usuariosMasRicos
    instead of delete
    on g04_mostrar10usuariosMasRicos
    for each row
        execute function trfn_g04_deleteVista10usuariosMasRicos();