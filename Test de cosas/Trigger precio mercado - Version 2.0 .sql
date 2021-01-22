select * from g04_mercado where nombre like 'BTC/USDT';
select * from g04_orden;
delete from g04_orden where id >= 000;

insert into g04_orden values (000,'BTC/USDT',1,'venta',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (001,'BTC/USDT',1,'venta',current_date,NULL, 1, 0.8, 'activo');
insert into g04_orden values (002,'BTC/USDT',1,'venta',current_date,NULL, 1, 0.2, 'activo');
insert into g04_orden values (003,'BTC/USDT',1,'venta',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (004,'BTC/USDT',1,'venta',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (005,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (006,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (007,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (008,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (009,'BTC/USDT',1,'compra',current_date,NULL, 1, 1, 'activo');
insert into g04_orden values (010,'BTC/USDT',1,'compra',current_date,NULL, 1, 0.1, 'activo');
insert into g04_orden values (011,'BTC/USDT',1,'compra',current_date,NULL, 1, 0.4, 'activo');


-- vista que tiene una columna que ya posee precio/cantidad calculado
create view precioSobreMercado as
    select  o.mercado,o.valor/o.cantidad as "valor",o.cantidad, o.tipo
    from g04_orden o
    where (o.estado = 'activo');

create or replace function calculaTotalCrypto(mercadoVar varchar(20),tipoVar char(10)) returns numeric(20,10) as $$
    --funcion que se encarga de calcular el total de crypto segun el tipo que reciba
    declare
        total numeric(20,10);
    begin
        total:=0;
        select sum(p.cantidad) into total
        from precioSobreMercado p
        where (p.tipo = tipoVar) and (p.mercado like mercadoVar);
        if (total is null) then
            return 0;
        else
            return total;
        end if;
    end $$ language 'plpgsql';

create or replace function calculaHastaDondeSumar(cantASuperar numeric(20,10),mercadoVar varchar(20),tipoVar char(10), orden varchar(4)) returns integer as $$
    declare
        filaActual integer;
        cantControl numeric(20,10);
        cantAux numeric(20,10);
    begin
        filaActual:=0;
        cantAux:=0;
        cantControl:=0;
        loop
            exit when cantControl >= cantASuperar;
            select p.cantidad into cantAux
                from precioSobreMercado p
                where (p.tipo = tipoVar) and (p.mercado like mercadoVar)
                order by
                    case when orden like 'asc' then
                        p.valor end,
                    case when orden like 'desc' then
                        p.valor end desc
                offset filaActual
                limit 1;
                cantControl:= cantControl + cantAux;
                filaActual:= filaActual + 1;
        end loop;
        return filaActual;
    end $$ language 'plpgsql';

create or replace function calculoSuma(indice integer,mercadoVar varchar(20),tipoVar char(10),orden varchar(4)) returns numeric(20,10) as $$
    declare
        auxSuma numeric(20,10);
        totalSuma numeric(20,10);
        auxInd integer;
    begin
        auxInd:= 0;
        totalSuma:=0;
        loop
            exit when auxInd >= indice;
                select p.valor into auxSuma
                from precioSobreMercado p
                where (p.mercado like mercadoVar) and (p.tipo = tipoVar)
                order by
                    case when orden like 'asc' then
                        p.valor end,
                    case when orden like 'desc' then
                        p.valor end desc
                    offset auxInd
                    limit 1;
                auxInd:= auxInd + 1;
                totalSuma:= totalSuma + auxSuma;
        end loop;
        return totalSuma;
    end $$ language 'plpgsql';

create or replace function trfn_g04_calcularPrecioMercado() returns trigger as $$
    declare
        totalCryptoV numeric(20,10);
        totalCryptoC numeric(20,10);
        indiceSumadorC integer;
        indiceSumadorV integer;
        totalValorC numeric(20,10);
        totalValorV numeric(20,10);
        precioMercadoActual numeric(20,10);

    begin
        --Calculo la cantidad total de crypto en compra y en venta
        totalCryptoV:= calculaTotalCrypto(new.mercado,'venta') * 0.2;
        totalCryptoC:= calculaTotalCrypto(new.mercado,'compra') * 0.2;
        raise warning 'totalCryptoC: %  totalCryptoV: %',totalCryptoC, totalCryptoV;
        --Calculo hasta donde debo sumar en precioSobreCantidad comprobando que la cantidad de la orden supere mi total calculado
        indiceSumadorC:= calculaHastaDondeSumar(totalCryptoC,new.mercado ,'compra','desc' );
        indiceSumadorV:= calculaHastaDondeSumar(totalCryptoV, new.mercado , 'venta','asc' );
        raise warning 'indiceSumadorC: %  indiceSumadorV: %',indiceSumadorC, indiceSumadorV;
        --Sumo hasta el indice calculado y almaceno el valor en sus variables
        totalValorC:= calculoSuma(indiceSumadorC ,new.mercado ,'compra' ,'desc');
        totalValorV:= calculoSuma(indiceSumadorV ,new.mercado ,'venta','asc');

        --Calculo el promedio entre estos dos valores y lo asigno
        raise warning 'totalValorC: %  totalValorV: %',totalValorC, totalValorV;
        precioMercadoActual:= (coalesce(totalValorC,0) + coalesce(totalValorV,0))/2;
        update g04_mercado set precio_mercado = precioMercadoActual where nombre = new.mercado;

        return new;

    end $$ language 'plpgsql';

drop trigger if exists tr_g04_calcularPrecioMercado on g04_orden;
create trigger tr_g04_calcularPrecioMercado
    after insert on g04_orden
    for each row
        execute function trfn_g04_calcularPrecioMercado();