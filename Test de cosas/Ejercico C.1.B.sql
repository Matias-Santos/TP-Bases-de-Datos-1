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
                    --Me quede manija y me puse a arreglar esto a las 2:40 de la madrugada jeje, ahora anda joya
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