create or replace function trfn_g04_calcularPrecioMercado() returns trigger as $$
    declare
        filaActual int;
        maxFilasVentas int;
        maxFilasCompras int;
        cantActual numeric(20,10);
        cantAux numeric(20,10);
        valorAux numeric(20,10);
        cantVentas numeric(20,10);
        cantCompras numeric(20,10);
        precioMercado numeric(20,10);
        valorVentas numeric(20,10);
        valorCompras numeric(20,10);
    begin
        cantActual:=0;
        filaActual:=0;
        cantAux:=0;
        valorVentas:=0;
        valorAux:=0;
        select sum(o.cantidad), count(o.id) into cantVentas, maxFilasVentas
            from g04_orden o
            where (o.tipo = 'venta') and (o.mercado like new.mercado);
        raise warning 'cantVentas antes de multiplicar: %',cantVentas;
        if (cantVentas is null) then
            cantVentas :=0;
        end if;
        cantVentas:= cantVentas * 0.2;
        raise warning 'cantVentas: %',cantVentas;
        loop
            exit when cantActual >= cantVentas;
            if(filaActual < maxFilasVentas) then
                select o.valor , o.cantidad into valorAux, cantAux
                    from g04_orden o
                    where (o.tipo = 'venta') and (o.mercado like new.mercado)
                    order by o.valor / o.cantidad asc
                    offset filaActual
                    limit 1;
                valorVentas:= valorVentas + valorAux/cantAux;
                cantActual:= cantActual + cantAux;
                filaActual:= filaActual + 1;
            else
                cantActual:= cantVentas;
            end if;
        end loop;
        raise warning 'valorVentas antes de multiplicar: %',valorVentas;
        valorVentas:= valorVentas * cantVentas;
        cantActual:=0;
        filaActual:=0;
        cantAux:=0;
        valorCompras:=0;
        valorAux:=0;
        select sum(o.cantidad), count(o.id) into cantCompras, maxFilasCompras
            from g04_orden o
            where (o.tipo = 'compra') and (o.mercado like new.mercado);
        raise warning 'cantCompras antes de multiplicar: %',cantCompras;
        if (cantCompras is null) then
            cantCompras :=0;
        end if;
        cantCompras:= cantCompras * 0.2;
        raise warning 'cantCompras: %',cantCompras;
        loop
            exit when cantActual >= cantCompras;
            if(filaActual < maxFilasCompras) then
                select o.valor, o.cantidad into valorAux, cantAux
                    from g04_orden o
                    where (o.tipo = 'compra') and (o.mercado like new.mercado)
                    order by o.valor / o.cantidad desc
                    offset filaActual
                    limit 1;
                valorCompras:= valorCompras + valorAux/cantAux;
                cantActual:= cantActual + cantAux;
                filaActual:= filaActual + 1;
            else
                cantActual:= cantCompras;
            end if;
        end loop;
        raise warning 'valorCompras antes de multiplicar: %',valorCompras;
        valorCompras:= valorCompras * cantCompras;
        raise warning 'valorCompras: %  valorVentas: %',valorCompras, valorVentas;
        precioMercado:= (valorVentas + valorCompras)/2;
        update g04_mercado set precio_mercado = precioMercado where (nombre = new.mercado);
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_calcularPrecioMercado on g04_orden;
create trigger tr_g04_calcularPrecioMercado
    after insert on g04_orden
    for each row
        execute function trfn_g04_calcularPrecioMercado();

delete from g04_orden where id >= 0;

-- Ventas
insert into g04_orden values (002,'BTC/USDT',1,'venta',current_date,NULL, 1, 0.2, 'activo');
insert into g04_orden values (001,'BTC/USDT',1,'venta',current_date,NULL, 1, 0.8, 'activo');
insert into g04_orden values (003,'BTC/USDT',1,'venta',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (004,'BTC/USDT',1,'venta',current_date,NULL, 1, 1, 'activo');
-- 1

--(1, 1 ) * 0.6 --> 1
-- Compras 14.5/2 = 7.25 <-- precio que deberia dar, precio que me da a mi --> 3.5700000000
--(1, 0.1) * 0.1 --> 10
--(1, 0.4) * 0.4 --> 2.5
--(1, 1) * 0.6 --> 1


-- 8.73
insert into g04_orden values (010,'BTC/USDT',1,'compra',current_date,NULL, 1, 0.1, 'activo');
insert into g04_orden values (011,'BTC/USDT',1,'compra',current_date,NULL, 1, 0.4, 'activo');
insert into g04_orden values (005,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (006,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (007,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (008,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (009,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');

select *
    from g04_mercado where nombre like 'BTC/USDT';