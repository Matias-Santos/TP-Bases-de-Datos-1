-- Delete de todas las tablas en el orden correcto, para inicializarlas todas vacias
delete from g04_composicionorden where cantidad >=0;
delete from g04_movimiento where bloque >=0;
delete from g04_billetera where id_usuario >=0;
delete from g04_orden where id>=0;
delete from g04_usuario where id_usuario >=0;
delete from g04_pais where id_pais>=0;
delete from g04_mercado where precio_mercado >=0;
delete from g04_moneda where estado = 'A';

------------------------------------------------------------------------------------------------------------------------
-- Funcion que retorna una fecha desde dos limites dados, la usamos para hacer los insert
create or replace function fn_g04_fechasRandom(desde timestamp, hasta timestamp) returns timestamp as $$
    begin
        return desde + random() * (hasta - desde);
    end; $$ language 'plpgsql';


------------------------------------------------------------------------------------------------------------------------

--Procedimiento que se encarga de insertar 100 usuarios
create or replace procedure pr_g04_insertUsuarios(cantUsuariosVar integer) as $$
    declare
        i integer;
        maxAux integer;
    begin
        select max(g.id_usuario) into maxAux
        from g04_usuario g;
        if(maxAux is null) then
            maxAux:= 0;
        end if;
        i:= maxAux+1;
        loop
            exit when (i >= (cantUsuariosVar+maxAux+1));
                insert into g04_usuario(id_usuario, apellido, nombre, fecha_alta, estado, email, password, telefono, id_pais)
                    values (i,
                            'apellido'|| i,
                            'nombre' || i,
                            fn_g04_fechasRandom(timestamp '1994-03-01 00:00:00', timestamp '2020-10-22 00:00:00'),
                            'activo',
                            'email'|| i || '@gmail.com',
                            'contraseña' || i,
                            2494000000+i,
                            1);
                i:=i+1;
        end loop;
    end $$ language 'plpgsql';

-- Trigger que inserta una billetera con saldo 0 de la moneda nueva que se insertó, a cada usuario

create or replace function trfn_g04_insertBilleteraNueva() returns trigger as $$
    declare
        tupla record;
    begin
        for tupla in select id_usuario
                        from g04_usuario loop
            insert into g04_billetera values (tupla.id_usuario, new.moneda, 0);
        end loop;
        return new;
    end $$ language 'plpgsql';

-- Trigger que inserta todas las billeteras disponibles de la tabla moneda, por cada usuario nuevo

create or replace function trfn_g04_insertUsuarios() returns trigger as $$
    declare
        tupla record;
    begin
        for tupla in select moneda from g04_moneda loop
            insert into g04_billetera(id_usuario, moneda, saldo) values (new.id_usuario, tupla.moneda, 0);
        end loop;
        return new;
    end $$ language 'plpgsql';

drop trigger if exists tr_g04_insertBilleteraNueva on g04_moneda;
create trigger tr_g04_insertBilleteraNueva
    after insert
    on g04_moneda
    for each row
        execute function trfn_g04_insertBilleteraNueva();

drop trigger if exists tr_g04_insertUsuarios on g04_usuario;
create trigger tr_g04_insertUsuarios
    after insert
    on g04_usuario
    for each row
        execute function trfn_g04_insertUsuarios();


------------------------------------------------------------------------------------------------------------------------

-- Funcionalidad relacionada al calculo del precio mercado

-- Funcion que se encarga de calcular el total de crypto segun el tipo que reciba
create or replace function trfn_g04_calculaTotalCrypto(mercadoVar varchar(20),tipoVar char(10)) returns numeric(20,10) as $$
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

-- Funcion que se encarga de retornar el limites de filas a sumar
create or replace function trfn_g04_calculaHastaDondeSumar(cantASuperar numeric(20,10),mercadoVar varchar(20),tipoVar char(10), orden varchar(4)) returns integer as $$
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
                from g04_precioSobreMercado p
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

-- Funcion que realiza la sumatoria de precio/cantidad
create or replace function trfn_g04_calculoSuma(indice integer,mercadoVar varchar(20),tipoVar char(10),orden varchar(4)) returns numeric(20,10) as $$
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
                from g04_precioSobreMercado p
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

-- Vista que tiene una columna que ya posee precio/cantidad calculado para facilitarnos las funciones
drop view if exists g04_precioSobreMercado;
create view g04_precioSobreMercado as
    select  o.mercado, o.valor/o.cantidad as "valor",o.cantidad, o.tipo
    from g04_orden o
    where (o.estado = 'activo');

-- Funcion que se encarga de llamar a las otras funciones que nos sirven para calcular el precio mercado, la misma
-- a partir de los datos,calcula y modifica el precio_mercado en g04_mercado segun el mercado de la orden que se inserta
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
        totalCryptoV:= trfn_g04_calculaTotalCrypto(new.mercado,'venta') * 0.2;
        totalCryptoC:= trfn_g04_calculaTotalCrypto(new.mercado,'compra') * 0.2;

        --Calculo hasta donde debo sumar en precioSobreCantidad comprobando que la cantidad de la orden supere mi total calculado
        indiceSumadorC:= trfn_g04_calculaHastaDondeSumar(totalCryptoC,new.mercado ,'compra','desc' );
        indiceSumadorV:= trfn_g04_calculaHastaDondeSumar(totalCryptoV, new.mercado , 'venta','asc' );

        --Sumo hasta el indice calculado y almaceno el valor en sus variables
        totalValorC:= trfn_g04_calculoSuma(indiceSumadorC ,new.mercado ,'compra' ,'desc');
        totalValorV:= trfn_g04_calculoSuma(indiceSumadorV ,new.mercado ,'venta','asc');

        --Calculo el promedio entre estos dos valores y lo asigno
        precioMercadoActual:= (coalesce(totalValorC,0) + coalesce(totalValorV,0))/2;
        update g04_mercado set precio_mercado = precioMercadoActual where nombre = new.mercado;
        return new;
    end $$ language 'plpgsql';

--Creacion del trigger que se va a activar cuando se inserte una orden nueva
drop trigger if exists tr_g04_calcularPrecioMercado on g04_orden;
create trigger tr_g04_calcularPrecioMercado
    after insert or update of estado,fecha_ejec
    on g04_orden
    for each row
        execute function trfn_g04_calcularPrecioMercado();

create or replace function fn_g04_getSigID() returns integer as $$
    declare
        idAux integer:=0;
    begin
        select max(id) into idAux
        from g04_orden;
        if (idAux is null) then
            return 0;
        end if;
        return idAux + 1;
    end $$ language 'plpgsql';

create or replace function fn_g04_getTimestamp() returns timestamp as $$
    declare
        time timestamp:=now();
    begin
        select max(fecha) into time
            from g04_movimiento;
        if (time is null) then
            return current_timestamp;
        end if;
        return time + '1 second';
    end $$ language 'plpgsql';

------------------------------------------------------------------------------------------------------------------------

-- Insert en g04_ordenes

-- Procedimiento que inserta 100 ordenes segun un mercado
create or replace procedure pr_g04_insertOrdenes(mercadoVar varchar(20),moneda_oVar varchar(10) ,moneda_dVar varchar(10),idVar bigint,cantOrdenes integer) as $$
    declare
        i integer:= 1;
        randomVar decimal(20,10);
    begin
        loop
            exit when i > cantOrdenes;
                randomVar:= random() * 100;
                if (i%2 = 0) then
                    update g04_billetera set saldo = (randomVar * 10) where id_usuario = i and moneda like moneda_dVar;
                    insert into g04_orden values (fn_g04_getsigid(), mercadoVar, i ,'compra', current_date, NULL, random() * 10, random() * randomVar, 'activo');
                else
                    update g04_billetera set saldo = (randomVar * 10) where id_usuario = i and moneda like moneda_oVar;
                    insert into g04_orden values (fn_g04_getsigid(), mercadoVar, i ,'venta', current_date, NULL, random() * 10, random() * randomVar, 'activo');
                end if;
                i:= i + 1;
        end loop;
    end $$ language 'plpgsql';


create or replace procedure pr_g04_insertaOrdenesMasivas(cantVar integer) as $$

    declare
        tupla record;
        idOrden bigint;
    begin
        select max(o.id) into idOrden
            from g04_orden o;
        if (idOrden is null) then
            idOrden:= 0;
        end if;
        for tupla in (select m.nombre,m.moneda_d,m.moneda_o from g04_mercado m order by m.nombre) loop
            call pr_g04_insertOrdenes(tupla.nombre,tupla.moneda_o,tupla.moneda_d,idOrden,cantVar);
            idOrden:= idOrden + cantVar;
        end loop;
    end $$ language 'plpgsql';


------------------------------------------------------------------------------------------------------------------------

-- 20 Inserts en la tabla G04_Monedas 12 Crypto, 5 Crypto estables y 3 Fiat
-- 3 Fiat (Estado: A = Estado activa) (Fiat: A = Fiat Activo)
insert into g04_moneda values('USD','Dolar Americano','Moneda de EE.UU','1971-01-01','A','A');
insert into g04_moneda values('EUR','Euro','Moneda de Europa','2002-01-01','A','A');
insert into g04_moneda values('YEN','Yenes','Moneda de Japon','1871-05-10','A','A');

-- 5 Crypto Estables
insert into g04_moneda values('USDT','Tether','Moneda respaldada por el dolar americano','2014-10-06','A','D');
insert into g04_moneda values('DAI','DAI','Moneda lanzada por sus usuarios atravez de depositos de garantia','2017-01-01','A','D');
insert into g04_moneda values('USDC','USD Coin','Moneda respaldada por dolares americanos','2018-09-02','A','D');
insert into g04_moneda values('PAX','Paxos Standard','Moneda respaldada por el valor del oro','2018-09-10','A','D');
insert into g04_moneda values('BUSD','Binance USD','Moneda respaldada por el dolar americano','2017-09-01','A','D');

-- 12 Crypto monedas

insert into g04_moneda values('BTC','Bitcoin','Moneda que no cuenta con respaldo, su primer trade fue por dos pizzas','2008-08-18','A','D');
insert into g04_moneda values('XML','Stellar','Esta desarollada en C++, Go, Java, JavaScript, Python, Ruby','2014-07-31','A','D');
insert into g04_moneda values('BCH','BitCoin Cash','Se caracteriza por haber elevado el parametro de tamaño maximo de los bloques','2017-08-01','A','D');
insert into g04_moneda values('LINK','ChainLink Standard','La precompra de este moneda incluida un 20% extra','2017-09-01','A','D');
insert into g04_moneda values('BNB','BNB','Cuando esta moneda fue lanzada se ofrecia a este precio 1 ETH por 2,700 BNB o 1 BTC por 20,000 BNB','2017-06-12','A','D');
insert into g04_moneda values('ADA','Cardano','Es una moneda contreversial que fue censurada de wikipedia','2015-06-06','A','D');
insert into g04_moneda values('EOS','EOS','El objetivo es eliminar los costos de transacciones','2018-01-31','A','D');
insert into g04_moneda values('THETA','THETA Network','El precio de salida fue de $0.067 (USD)','2019-03-03','A','D');
insert into g04_moneda values('KSM','Kusama','Este es su telegram t.me/kusamanetworkofficial','2020-07-31','A','D');
insert into g04_moneda values('ALGO','Algorand','Desarollada por gente que resolvio el trilema de blockchain','2019-06-19','A','D');
insert into g04_moneda values('ETC','Ethereum Classic','Ether es la moneda principal para las operaciones realizadas por ETC','2015-06-30','A','D');
insert into g04_moneda values('ZEC','ZCash','Es una criptomoneda destinada a utilizar la criptografía para proporcionar un método más avanzado de privacidad a sus usuarios','2016-10-19','A','D');

------------------------------------------------------------------------------------------------------------------------

-- Inserts en G04_Mercado

-- Estables vs Crypto 60 filas = 5 (monedas estables) * 12 (monedas crypto no estables)

insert into g04_mercado values ('BTC/USDT','BTC','USDT',0);
insert into g04_mercado values ('BTC/DAI','BTC','DAI',0);
insert into g04_mercado values ('BTC/USDC','BTC','USDC',0);
insert into g04_mercado values ('BTC/PAX','BTC','PAX',0);
insert into g04_mercado values ('BTC/BUSD','BTC','BUSD',0);

insert into g04_mercado values ('XML/USDT','XML','USDT',0);
insert into g04_mercado values ('XML/DAI','XML','DAI',0);
insert into g04_mercado values ('XML/USDC','XML','USDC',0);
insert into g04_mercado values ('XML/PAX','XML','PAX',0);
insert into g04_mercado values ('XML/BUSD','XML','BUSD',0);

insert into g04_mercado values ('BCH/USDT','BCH','USDT',0);
insert into g04_mercado values ('BCH/DAI','BCH','DAI',0);
insert into g04_mercado values ('BCH/USDC','BCH','USDC',0);
insert into g04_mercado values ('BCH/PAX','BCH','PAX',0);
insert into g04_mercado values ('BCH/BUSD','BCH','BUSD',0);

insert into g04_mercado values ('LINK/USDT','LINK','USDT',0);
insert into g04_mercado values ('LINK/DAI','LINK','DAI',0);
insert into g04_mercado values ('LINK/USDC','LINK','USDC',0);
insert into g04_mercado values ('LINK/PAX','LINK','PAX',0);
insert into g04_mercado values ('LINK/BUSD','LINK','BUSD',0);

insert into g04_mercado values ('BNB/USDT','BNB','USDT',0);
insert into g04_mercado values ('BNB/DAI','BNB','DAI',0);
insert into g04_mercado values ('BNB/USDC','BNB','USDC',0);
insert into g04_mercado values ('BNB/PAX','BNB','PAX',0);
insert into g04_mercado values ('BNB/BUSD','BNB','BUSD',0);

insert into g04_mercado values ('ADA/USDT','ADA','USDT',0);
insert into g04_mercado values ('ADA/DAI','ADA','DAI',0);
insert into g04_mercado values ('ADA/USDC','ADA','USDC',0);
insert into g04_mercado values ('ADA/PAX','ADA','PAX',0);
insert into g04_mercado values ('ADA/BUSD','ADA','BUSD',0);

insert into g04_mercado values ('EOS/USDT','EOS','USDT',0);
insert into g04_mercado values ('EOS/DAI','EOS','DAI',0);
insert into g04_mercado values ('EOS/USDC','EOS','USDC',0);
insert into g04_mercado values ('EOS/PAX','EOS','PAX',0);
insert into g04_mercado values ('EOS/BUSD','EOS','BUSD',0);

insert into g04_mercado values ('THETA/USDT','THETA','USDT',0);
insert into g04_mercado values ('THETA/DAI','THETA','DAI',0);
insert into g04_mercado values ('THETA/USDC','THETA','USDC',0);
insert into g04_mercado values ('THETA/PAX','THETA','PAX',0);
insert into g04_mercado values ('THETA/BUSD','THETA','BUSD',0);

insert into g04_mercado values ('KSM/USDT','KSM','USDT',0);
insert into g04_mercado values ('KSM/DAI','KSM','DAI',0);
insert into g04_mercado values ('KSM/USDC','KSM','USDC',0);
insert into g04_mercado values ('KSM/PAX','KSM','PAX',0);
insert into g04_mercado values ('KSM/BUSD','KSM','BUSD',0);

insert into g04_mercado values ('ALGO/USDT','ALGO','USDT',0);
insert into g04_mercado values ('ALGO/DAI','ALGO','DAI',0);
insert into g04_mercado values ('ALGO/USDC','ALGO','USDC',0);
insert into g04_mercado values ('ALGO/PAX','ALGO','PAX',0);
insert into g04_mercado values ('ALGO/BUSD','ALGO','BUSD',0);

insert into g04_mercado values ('ETC/USDT','ETC','USDT',0);
insert into g04_mercado values ('ETC/DAI','ETC','DAI',0);
insert into g04_mercado values ('ETC/USDC','ETC','USDC',0);
insert into g04_mercado values ('ETC/PAX','ETC','PAX',0);
insert into g04_mercado values ('ETC/BUSD','ETC','BUSD',0);

insert into g04_mercado values ('ZEC/USDT','ZEC','USDT',0);
insert into g04_mercado values ('ZEC/DAI','ZEC','DAI',0);
insert into g04_mercado values ('ZEC/USDC','ZEC','USDC',0);
insert into g04_mercado values ('ZEC/PAX','ZEC','PAX',0);
insert into g04_mercado values ('ZEC/BUSD','ZEC','BUSD',0);

-- Estables vs Fiat 15 filas = 5 * 3

insert into g04_mercado values ('USD/USDT','USD','USDT',0);
insert into g04_mercado values ('USD/DAI','USD','DAI',0);
insert into g04_mercado values ('USD/USDC','USD','USDC',0);
insert into g04_mercado values ('USD/PAX','USD','PAX',0);
insert into g04_mercado values ('USD/BUSD','USD','BUSD',0);

insert into g04_mercado values ('EUR/USDT','EUR','USDT',0);
insert into g04_mercado values ('EUR/DAI','EUR','DAI',0);
insert into g04_mercado values ('EUR/USDC','EUR','USDC',0);
insert into g04_mercado values ('EUR/PAX','EUR','PAX',0);
insert into g04_mercado values ('EUR/BUSD','EUR','BUSD',0);

insert into g04_mercado values ('YEN/USDT','YEN','USDT',0);
insert into g04_mercado values ('YEN/DAI','YEN','DAI',0);
insert into g04_mercado values ('YEN/USDC','YEN','USDC',0);
insert into g04_mercado values ('YEN/PAX','YEN','PAX',0);
insert into g04_mercado values ('YEN/BUSD','YEN','BUSD',0);

-- BitCoin vs Cryptos 11 filas

insert into g04_mercado values ('XML/BTC','XML','BTC',0);
insert into g04_mercado values ('BCH/BTC','BCH','BTC',0);
insert into g04_mercado values ('LINK/BTC','LINK','BTC',0);
insert into g04_mercado values ('BNB/BTC','BNB','BTC',0);
insert into g04_mercado values ('ADA/BTC','ADA','BTC',0);
insert into g04_mercado values ('EOS/BTC','EOS','BTC',0);
insert into g04_mercado values ('THETA/BTC','THETA','BTC',0);
insert into g04_mercado values ('KSM/BTC','KSM','BTC',0);
insert into g04_mercado values ('ALGO/BTC','ALGO','BTC',0);
insert into g04_mercado values ('ETC/BTC','ETC','BTC',0);
insert into g04_mercado values ('ZEC/BTC','ZEC','BTC',0);

------------------------------------------------------------------------------------------------------------------------

-- 1 insert en la tabla G04_Pais para completar la tabla usuarios
insert into g04_pais values (1,'Argentina',549);

-- Inserts en la tabla G04_Usuarios
call pr_g04_insertUsuarios(1);

-- Inserts en la tabla G04_Ordenes
call pr_g04_insertaOrdenesMasivas(1);