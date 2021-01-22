-- Resolucion del ejercicio B.1

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicio B.2

create or replace function trfn_g04_controlarSaldoOrdenCompra() returns trigger as $$
    declare
        monedaVar varchar(20);
        saldoVar decimal(20,10);
    begin
        saldoVar := 0;
        select moneda_d into monedaVar
            from g04_mercado
            where nombre like new.mercado;
        if (not exists (select 1
                            from g04_billetera b
                            where (new.id_usuario = b.id_usuario) and (monedaVar like b.moneda))) then
            raise exception 'El usuario no tiene una billetera de %' , monedaVar;
        end if;
        select saldo into saldoVar
            from g04_billetera
            where (id_usuario = new.id_usuario) and (moneda like monedaVar);

        if(saldoVar < (new.valor * new.cantidad)) then
            raise exception 'El usuario % no tiene saldo suficiente para comprar % de %' , new.id_usuario, new.cantidad, monedaVar;
        end if;
        return new;
    end $$ language 'plpgsql';

create or replace function trfn_g04_controlarSaldoOrdenVenta() returns trigger as $$
    declare
        monedaVar varchar(20);
        saldoVar decimal(20,10);
    begin
        saldoVar := 0;
        select moneda_o into monedaVar
            from g04_mercado
            where nombre like new.mercado;
        if (not exists (select 1
                            from g04_billetera b
                            where (new.id_usuario = b.id_usuario) and (monedaVar like b.moneda))) then
            raise exception 'El usuario no tiene una billetera de %' , monedaVar;
        end if;
        select saldo into saldoVar
            from g04_billetera
            where (id_usuario = new.id_usuario) and (moneda like monedaVar);
        if(saldoVar < new.cantidad) then
            raise exception 'El usuario % no tiene % de %' , new.id_usuario, new.cantidad, monedaVar;
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
        if (exists(select 1
            from g04_orden o
            where (o.estado = 'activo') and (o.id_usuario = new.id_usuario) and (o.mercado in (select m.nombre
                                                                from g04_mercado m
                                                                where m.moneda_o = new.moneda))
        )) then
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

-- Resolucion del ejercicico C.1.a
create or replace function fn_g04_devuelvePrecioMercado(mercadoConsultado varchar(20)) returns numeric(20,10) as $$
    declare
        valorMer numeric(20,10);
    begin
        select precio_mercado into valorMer
        from g04_mercado
        where (nombre like mercadoConsultado);
        return valorMer;
    end $$ language 'plpgsql';

select fn_g04_devuelvePrecioMercado('BTC/USDT');

------------------------------------------------------------------------------------------------------------------------

-- Resolucion del ejercicico C.1.b
create or replace function trfn_g04_checkeaSaldo(monedaVar varchar(20), idVar integer) returns numeric(20,10) as $$
    declare
        saldoVar numeric(20,10);
    begin
        if (not exists(select 1
                            from g04_billetera b
                            where (b.id_usuario = idVar) and (moneda like monedaVar))) then
            insert into g04_billetera values (idVar, monedaVar, 0);
            return 0;
        else
            select b.saldo into saldoVar
                from g04_billetera b
                where (b.id_usuario = idVar) and (moneda like monedaVar);
            return saldoVar;
        end if;
    end $$ language 'plpgsql';

create or replace procedure trpr_g04_devuelveSaldo(monedaVar varchar(20), idVar integer,saldoVar numeric (20,10)) as $$
    begin
        if (not exists(select 1
                            from g04_billetera b
                            where (b.id_usuario = idVar) and (moneda like monedaVar))) then
            insert into g04_billetera values (idVar, monedaVar, saldoVar);
        else
            update g04_billetera set saldo = saldoVar where ((id_usuario = idVar) and (moneda = monedaVar));
        end if;
    end $$ language 'plpgsql';

create or replace function trfn_g04_ejecucionOrden() returns trigger as $$
    declare
        cantOrdenes integer;
        monedaOfertaVar varchar(20);
        monedaDemandaVar varchar(20);
        cantMonedaDestComprador varchar(20);
        idUsuarioAux integer;
        idAux integer;
        valorAux numeric(20,10);
        cantidadAux numeric(20,10);
        saldoAux numeric(20,10);
        cantidadActual numeric(20,10);
        superaCant boolean;
        saldoGastado numeric(20,10);
    begin
        --Extraigo los tipos de moneda del mercado
        select m.moneda_o, m.moneda_d into monedaOfertaVar, monedaDemandaVar
            from g04_mercado m
            where (m.nombre like new.mercado);
        cantMonedaDestComprador:= trfn_g04_checkeaSaldo(monedaOfertaVar, new.id_usuario);

        cantidadActual:=0;
        saldoGastado:=0;
        superaCant:= false;
        select count(*) into cantOrdenes
            from g04_orden o
            where (o.tipo = 'venta') and (o.mercado like new.mercado) and (o.estado = 'activo');
        if (cantOrdenes is null) then
            cantOrdenes:= 0;
        end if;
        loop
            exit when ((cantOrdenes = 0) or (superaCant));
                --Extraigo la cantidad de ordenes de venta de ese tipo de mercado, que esten activas
                select o.id_usuario, o.id, o.valor, o.cantidad into idUsuarioAux, idAux, valorAux, cantidadAux
                    from g04_orden o
                    where (o.tipo = 'venta') and (o.mercado like new.mercado) and (o.estado = 'activo')
                    order by o.valor, o.cantidad
                    limit 1;
                if ((cantidadAux+cantidadActual <= new.cantidad) and (new.valor >= valorAux)) then
                    cantidadActual:= cantidadActual + cantidadAux;
                    saldoGastado:= saldoGastado + (valorAux * cantidadAux);
                    saldoAux:= trfn_g04_checkeaSaldo(monedaDemandaVar,idUsuarioAux);
                    update g04_orden set estado = 'finalizado', fecha_ejec = current_date
                        where (id = idAux);
                    update g04_billetera set saldo = (saldoAux + (valorAux*cantidadAux))
                        where (id_usuario = idUsuarioAux) and (moneda like monedaDemandaVar);
                    saldoAux:= trfn_g04_checkeaSaldo(monedaOfertaVar,idUsuarioAux);
                    update g04_billetera set saldo = (saldoAux - cantidadAux)
                        where (id_usuario = idUsuarioAux) and (moneda like monedaOfertaVar);
                else
                    superaCant:=true;
                end if;
                cantOrdenes:= cantOrdenes - 1;
            end loop;
        saldoAux:= trfn_g04_checkeaSaldo(monedaOfertaVar,new.id_usuario);
        update g04_billetera set saldo = (cantidadActual)
            where (id_usuario = new.id_usuario) and (moneda like monedaOfertaVar);
        saldoAux:= trfn_g04_checkeaSaldo(monedaDemandaVar,new.id_usuario);
        update g04_billetera set saldo = (saldoAux - saldoGastado)
            where (id_usuario = new.id_usuario) and (moneda like monedaDemandaVar);
        new.estado = 'finalizado';
        new.fecha_ejec = current_date;
        return new;
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

select *
from g04_orden;
select *
from g04_billetera;
select *
from g04_usuario;
select *
from g04_mercado;
select *
from g04_orden
order by valor/cantidad;
insert into g04_orden values (012,'BTC/USDT',1,'compra',current_date,NULL, 2, 3, 'activo');

delete from g04_orden ;
delete from g04_mercado ;
delete from g04_billetera;
delete from g04_usuario;
delete from g04_pais;
delete from g04_moneda;