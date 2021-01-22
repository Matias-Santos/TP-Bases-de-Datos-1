-- Delete de todas las tablas en el orden correcto, para inicializarlas todas vacias
delete from g04_billetera where id_usuario >=0;
delete from g04_orden where id>=0;
delete from g04_usuario where id_usuario >=0;
delete from g04_pais where id_pais>=0;
delete from g04_mercado where precio_mercado >=0;
delete from g04_moneda where estado = 'A';
select * from g04_moneda;
--pais de prueba
insert into g04_Pais values (1,'pais1',1111);

--usuarios de prueba
insert into g04_Usuario values (999,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',999,1);
insert into g04_Usuario values (998,'apetest2','nomtest2',current_date,'activo','emtest2@gmail.com','passtest2',998,1);
insert into g04_Usuario values (997,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',997,1);
insert into g04_Usuario values (996,'apetest2','nomtest2',current_date,'activo','emtest2@gmail.com','passtest2',996,1);
insert into g04_Usuario values (995,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',995,1);
insert into g04_Usuario values (994,'apetest2','nomtest2',current_date,'activo','emtest2@gmail.com','passtest2',994,1);
insert into g04_Usuario values (993,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',993,1);
insert into g04_Usuario values (992,'apetest2','nomtest2',current_date,'activo','emtest2@gmail.com','passtest2',992,1);

--monedas de prueba
insert into g04_moneda values ('BTC','bitcoin','moneda para testeo',current_date,'A','D');
insert into g04_moneda values ('USDT','usdt','moneda para testeo',current_date,'A','D');

--mercados de prueba
insert into g04_Mercado values ('BTC/USDT','BTC','USDT',0);

delete from g04_billetera where id_usuario >=0;
delete from g04_orden where id>=0;
--billeteras inciales de prueba
insert into g04_billetera values (999,'BTC',100);
insert into g04_billetera values (998,'BTC',100);
insert into g04_billetera values (997,'BTC',100);
insert into g04_billetera values (996,'BTC',100);
insert into g04_billetera values (995,'BTC',100);
insert into g04_billetera values (994,'USDT',4000);

--ordenes de venta
insert into g04_Orden values (0002,'BTC/USDT',998,'venta',current_date,null,3,0.3,'activo');
insert into g04_Orden values (0003,'BTC/USDT',997,'venta',current_date,null,4,0.4,'activo');
insert into g04_Orden values (0005,'BTC/USDT',995,'venta',current_date,null,2,1,'activo');
insert into g04_Orden values (0001,'BTC/USDT',999,'venta',current_date,null,2,0.2,'activo');
insert into g04_Orden values (0004,'BTC/USDT',996,'venta',current_date,null,5,0.5,'activo');
-- BTC totales = 2.4

--ordenes de compra

-- prueba el usuario quiere comprar 1 monedaTest1 a un valor de 7 monedatest2
insert into  g04_Orden values (0006,'BTC/USDT',994,'compra',current_date,null,3,50,'activo');

select *
from g04_orden;
select *
    from g04_billetera
    order by id_usuario;
--resultado esperado:
	--Se Finaliza la orden de venta 0005 sola
	--Se Finaliza la orden de compra 0006                                           (NO SE MARCO COMO FINALIZADA)
	--Se crea la billetera faltantes en ambos usuarios
	--La billetera monedatest1 del usuario 998 queda con 1
	--La billetera monedaTest2 del usuario 998 queda con 199
	--La billetera monedaTest1 del usuario 999 queda con 99
	--La billetera monedaTest2 del usuario 999 queda con 1

-- prueba el usuario quiere comprar 3 monedaTest1 a un valor de 100 monedatest2
insert into g04_Orden values (0006,'monTest1/monTest2',998,'compra',current_date,null,100,1,'activo');

--resultado esperado:
	--Se crea la billetera faltantes en ambos usuarios
	--Se Finalizan todas las ordenes
	--La billetera monedatest1 del usuario 998 queda con 2.4
	--La billetera monedaTest2 del usuario 998 queda con 176.6
	--La billetera monedaTest1 del usuario 999 queda con 76
	--La billetera monedaTest2 del usuario 999 queda con 24

-- prueba el usuario quiere comprar 3 monedaTest1 a un valor de 100 monedatest2
insert into  g04_Orden values (0006,'monTest1/monTest2',998,'compra',current_date,null,0.1,0.1,'activo');

--resultado esperado:
	--No pasa nada