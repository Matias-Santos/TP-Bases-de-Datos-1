select * from g04_orden where mercado like 'BNB/DAI' and tipo = 'venta'  order by valor asc;

--usuarios de prueba
insert into g04_Usuario values (999,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',999,1);
insert into g04_Usuario values (998,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',999,1);
insert into g04_Usuario values (997,'apetest1','nomtest1',current_date,'activo','emtest1@gmail.com','passtest1',999,1);

--billeteras inciales de prueba
update g04_billetera set saldo = 1000 where id_usuario = 998 and moneda like 'ADA';
update g04_billetera set saldo = 640 where id_usuario = 999 and moneda like 'XML';
update g04_billetera set saldo = 1600 where id_usuario = 998 and moneda like 'BNB';
update g04_billetera set saldo = 0 where id_usuario = 997 and moneda like 'BNB';
update g04_billetera set saldo = 1250 where id_usuario = 997 and moneda like 'DAI';

--ordenes de venta
insert into g04_orden values (8697,'BNB/DAI',997,'compra',current_date,null,2,54,'activo');

--ordenes de compra

select * from g04_billetera where saldo > 0;
delete from g04_composicionorden;
delete from g04_movimiento;
select * from g04_composicionorden where id_d=8697;
select * from g04_movimiento where (moneda like 'BNB' or moneda like 'DAI') order by fecha desc;
select * from g04_billetera where (id_usuario= 39 or id_usuario= 71 or id_usuario= 997)  and
                                  (moneda like 'BNB' or moneda like 'DAI');


