------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------Apartado B-------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.1

create or replace function trfn_g04_controlBloque() returns trigger as $$
--Funcion que se encarga de controlar que el bloque y la fecha a insertar sean mayor a su max actual
    begin
        if (new.bloque > (select max(bloque) from g04_movimiento where moneda = new.moneda)) then
            if (new.fecha > (select max(fecha) from g04_movimiento where moneda = new.moneda)) then
                return new;
            else
                raise exception 'error de inserccion en movimiento por fecha menor a la max';
            end if;
        else
            raise exception 'error de inserccion en movimiento por numero de bloque';
        end if;
    end $$ language 'plpgsql';

create trigger tr_g04_controlBloque
    before insert
    on g04_movimiento
    for each row
        execute function trfn_g04_controlBloque();

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.2

create or replace function trfn_g04_existeBilletera(idUsuarioVar integer,monedaVar varchar(20)) returns boolean as $$
    begin
        if (not exists (select 1 from g04_billetera b
                            where (idUsuarioVar = b.id_usuario) and (monedaVar like b.moneda))) then
            return false;
        else
            return true;
        end if;
    end $$ language 'plpgsql';

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
        monedaVar varchar(20);
        saldoVar decimal(20,10);
    begin
        select moneda_d into monedaVar
            from g04_mercado
            where nombre like new.mercado;
        if (trfn_g04_existeBilletera(new.id_usuario,monedaVar)) then
            saldoVar:= trfn_g04_getSaldo(new.id_usuario,monedaVar);
            if(saldoVar < (new.valor * new.cantidad)) then
                raise exception 'El usuario % no tiene saldo suficiente para comprar % monedas de %' , new.id_usuario, new.cantidad, monedaVar;
            end if;
        else
            raise exception 'El usuario no tiene una billetera de %' , monedaVar;
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
        if (trfn_g04_existeBilletera(new.id_usuario,monedaVar)) then
            saldoVar:= trfn_g04_getSaldo(new.id_usuario,monedaVar);
            if(saldoVar < new.cantidad) then
                raise exception 'El usuario % no tiene % de para vender%' , new.id_usuario, new.cantidad, monedaVar;
            end if;
        else
            raise exception 'El usuario no tiene una billetera de %' , monedaVar;
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
-- insert into g04_orden values (342123, 'ETC/PAX', 1, 'compra', current_date, null, 24532, 43, 'activo');
-- insert into g04_orden values (342124, 'BTC/PAX', 1, 'compra', current_date, null, 24532, 43, 'activo');
-- insert into g04_orden values (342125, 'ETC/PAX', 1, 'venta', current_date, null, 24532, 43, 'activo');
-- insert into g04_orden values (342126, 'BTC/PAX', 1, 'venta', current_date, null, 24532, 43, 'activo');

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.3

create or replace function trfn_g04_compruebaOrdenesRetiro() returns trigger as $$
    begin
        if exists(select 1 from g04_orden o
            where (o.estado = 'activo') and (o.id_usuario = new.id_usuario) and
                  (o.mercado in (select m.nombre from g04_mercado m where m.moneda_o = new.moneda))) then
            raise exception 'El usuario % Tiene ordenes activas de la moneda %, por lo tanto no puede retirar', new.id_usuario, new.moneda;
        end if;
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_compruebaOrdenesRetiro on g04_movimiento;
create trigger tr_g04_compruebaOrdenesRetiro
    before insert
    on g04_movimiento
    for each row when (new.tipo = 'S')
        execute function trfn_g04_compruebaOrdenesRetiro();

-- Checkeo de funcionamiento correcto del trigger del ejercicio B.3
-- insert into g04_movimiento values (1, 'ETC', current_date, 'S', 0.5, 12344, null, null);

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.4
ALTER TABLE g04_movimiento
ADD CONSTRAINT ck_g04_movimiento_checkeoNulidad CHECK ((direccion is null and bloque is null) or
                                                       (direccion is not null and bloque is not null));
-- Checkeo de funcionamiento correcto del constraint del ejercicio B.4
-- insert into g04_movimiento values(21,'ETC', current_date, 'R', 4321, 32431, 2134365, null);
-- insert into g04_movimiento values(21,'ETC', current_date, 'R', 4321, 32431, null, 'direccion 1');

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

select fn_g04_devuelvePrecioMercado('BTC/USDT');

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicico C.1.b

create or replace function trfn_g04_ejecucionOrden() returns trigger as $$
    declare
        cantAcum numeric(20,10);
        saldoGastado numeric(20,10);
        monedas record;
        tupla record;
    begin
        --Inicializo variables
        cantAcum:=0;
        saldoGastado:=0;

        --Obtengo las monedas sobre las que van a suceder operaciones
        select moneda_o , moneda_d into monedas
        from g04_mercado
        where (nombre like new.mercado);

        -- chequeo que el usuario tenga billetera de la moneda a comprar en caso de no tener una , la creo.
        if (not trfn_g04_existeBilletera(new.id_usuario, monedas.moneda_o)) then
            insert into g04_billetera values (new.id_usuario,monedas.moneda_o,0);
        end if;

        --Recorro la tabla de orden para ver si se puede ejecutar alguna orden de venta
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'venta') and (o.estado = 'activo') and (o.mercado like new.mercado) and (valor <= new.valor)
                            order by valor,fecha_creacion loop

            --Chequeo que la cantidad no supere a la cantidad maxima a comprar
            if (cantAcum + tupla.cantidad <= new.cantidad) then

                --Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoGastado := saldoGastado + (tupla.valor * tupla.cantidad);

                --Modifico la orden de venta a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_date , estado = 'finalizado' where id = tupla.id;

                --Actualizo billeteras del vendedor en caso de no existir la creo
                if (trfn_g04_existeBilletera(new.id_usuario, monedas.moneda_d)) then
                    update g04_billetera saldo
                else
                    insert into g04_billetera values (new.id_usuario,monedas.moneda_o,0);
                end if;
                --Inserto composicion orden
                --Insertar movimientos
            end if;






--falta quitarles el saldo de las billeteras cuando se inserte una orden

            if () then
                exit;
            end if;
        end loop;

    end $$ language 'plpgsql';

drop trigger if exists tr_g04_ejecucionOrden on g04_orden;
create trigger tr_g04_ejecucionOrden
    before insert
    on g04_orden
    for each row when (new.tipo = 'compra')
    execute function trfn_g04_ejecucionOrden();

-- Resolucion del ejercicico C.1.C

prepare pr_g04_mostrarOrdenesCronologicamente ( varchar(20), timestamp) as
    select o.id, o.fecha_creacion, o.tipo,o.estado
        from g04_orden o
        where (o.mercado like $1) and ( o.fecha_creacion between $2 and current_date)
        order by o.fecha_creacion,o.id asc;

execute pr_g04_mostrarOrdenesCronologicamente('BTC/USDT', '2020-10-30');



