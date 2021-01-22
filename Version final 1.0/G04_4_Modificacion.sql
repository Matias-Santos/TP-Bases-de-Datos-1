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

        update g04_billetera set saldo = (saldo - new.valor * new.cantidad)  where id_usuario = new.id_usuario and moneda like monedas.moneda_d;
        update g04_orden set estado= 'pendiente' where id=new.id;

        -- Recorro la tabla de orden para ver si se puede ejecutar alguna orden de venta
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'venta') and (o.estado = 'activo') and (o.mercado like new.mercado) and (valor <= new.valor)
                            order by valor loop

            -- Chequeo que la cantidad no supere a la cantidad maxima a comprar
            if (cantAcum + tupla.cantidad <= new.cantidad) then

                -- Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoGastado := saldoGastado + (tupla.valor * tupla.cantidad);

                -- Modifico la orden de venta a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;

                -- Actualizo las billeteras del vendedor
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo = (saldo + (tupla.valor * tupla.cantidad * 0.95))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,new.id,tupla.cantidad);

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());

            -- Esto cortaria solo para algunos casos especificos en los que la orden de venta es muy grande y hay que dividirla
            else
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;
                -- Actualizo las billeteras del vendedor
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad - (new.cantidad - cantAcum)))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_o);

                update g04_billetera set saldo = (saldo + (tupla.valor * (tupla.cantidad - (new.cantidad - cantAcum)) * 0.95))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_d);

                insert into g04_orden values
                (fn_g04_getSigID(), tupla.mercado, tupla.id_usuario, tupla.tipo, current_timestamp, null, tupla.valor, tupla.cantidad - (new.cantidad - cantAcum), 'activo');

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,new.id,(tupla.cantidad - (new.cantidad - cantAcum)));

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * (tupla.cantidad - (new.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,(tupla.cantidad - (new.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                cantAcum := new.cantidad;
                saldoGastado := saldoGastado + (tupla.valor * (tupla.cantidad - (new.cantidad - cantAcum)));
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            update g04_billetera set saldo = saldo + (new.cantidad * new.valor - saldoGastado) where (id_usuario = new.id_usuario and moneda = monedas.moneda_d);
            update g04_billetera set saldo = (saldo + (cantAcum * 0.95)) where (id_usuario = new.id_usuario and moneda = monedas.moneda_o);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=new.id;
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,saldoGastado,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
            if (cantAcum < new.cantidad) then
                insert into g04_orden values (fn_g04_getsigid(),new.mercado,new.id_usuario,new.tipo,current_timestamp,null,new.valor,new.cantidad-cantAcum,'activo');
            end if;
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
        saldoAux numeric(20,10):=0;
    begin
        -- Obtengo las monedas sobre las que van a suceder operaciones
        select moneda_o , moneda_d into monedas
        from g04_mercado
        where (nombre like new.mercado);

        -- Pregunto si el usuario que quiere insertar la orden tiene alguna orden activa para ese mercado
        if (trfn_g04_tieneOrdenesActivas(new.id,new.id_usuario, new.mercado)) then
            raise exception 'El usuario % ya tiene una orden activa para el mercado % ',  new.id_usuario, new.mercado;
        end if;

        update g04_billetera set saldo = (saldo - new.cantidad)  where id_usuario = new.id_usuario and moneda like monedas.moneda_o;
        update g04_orden set estado = 'pendiente' where id = new.id;

        -- Recorro la tabla de orden para ver si se puede ejecutar alguna orden de compra
        for tupla in select o.* from g04_orden o
                            where (o.tipo = 'compra') and (o.estado = 'activo') and (o.mercado like new.mercado) and (o.valor >= new.valor)
                            order by valor desc loop

            -- Chequeo que la cantidad no supere a la cantidad maxima a comprar
           if (cantAcum + tupla.cantidad <= new.cantidad) then

                -- Actualizo el cantAcumulado y saldoGastado hasta el momento
                cantAcum:= cantAcum + tupla.cantidad;
                saldoObtenido := saldoObtenido + (new.valor * tupla.cantidad);

                -- Modifico la orden de compra a estado finalizada y la fecha ejec
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;

                --Actualizo las billeteras del comprador
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad * 0.95))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_o);
                -- Update del saldo en la moneda con la que se va a pagar la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad * tupla.valor) - (new.valor * tupla.cantidad))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,new.id,tupla.cantidad);

                -- Insertar movimientos comprador
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());

            -- Esto cortaria solo para algunos casos especificos en los que la orden de compra es muy grande y hay que dividirla
            else
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;
                -- Actualizo las billeteras del vendedor
                -- Update del saldo en la moneda que va a recibir por la transaccion

                select saldo into saldoAux
                    from g04_billetera where id_usuario = tupla.id_usuario and moneda like monedas.moneda_d;
                raise warning 'saldo de la billetera: %' , saldoAux;

                update g04_billetera set saldo = (saldo + (tupla.cantidad * tupla.valor) - (new.valor * (new.cantidad - cantAcum)))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_d);

                update g04_billetera set saldo = (saldo + (new.cantidad - cantAcum) * 0.95)
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_o);
                select saldo into saldoAux
                    from g04_billetera where id_usuario = tupla.id_usuario and moneda like monedas.moneda_d;
                raise warning 'new.valor: % , new.cantidad: % ,  cantAcum: % ' , new.valor, new.cantidad, cantAcum;
                raise warning 'saldo de la billetera: %' , saldoAux;
                raise warning 'tupla.cantidad: % , tupla.valor: % ', tupla.cantidad - (new.cantidad - cantAcum), tupla.valor;
                /*
                [2020-11-10 16:40:14] [01000] saldo de la billetera: 0.0000000000
                [2020-11-10 16:40:14] [01000] new.valor: 2.8354838444 , new.cantidad: 55.7650043605 ,  cantAcum: 53.4283004538
                [2020-11-10 16:40:14] [01000] saldo de la billetera: 437.0134722071
                [2020-11-10 16:40:14] [01000] tupla.cantidad: 79.1945164937 , tupla.valor: 8.1142934086
                */
                insert into g04_orden values
                (fn_g04_getSigID(), tupla.mercado, tupla.id_usuario, tupla.tipo, current_timestamp, null, tupla.valor, tupla.cantidad - (new.cantidad - cantAcum), 'activo');

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,new.id,(tupla.cantidad - (new.cantidad - cantAcum)));

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * (tupla.cantidad - (new.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,(tupla.cantidad - (new.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                saldoObtenido := saldoObtenido + (new.valor * (new.cantidad - cantAcum));
                cantAcum := new.cantidad;
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            update g04_billetera set saldo = (saldo + new.cantidad - cantAcum) where (id_usuario = new.id_usuario and moneda = monedas.moneda_o);
            update g04_billetera set saldo = (saldo + (saldoObtenido * 0.95)) where (id_usuario = new.id_usuario and moneda = monedas.moneda_d);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=new.id;
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (new.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,saldoObtenido,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            if (cantAcum < new.cantidad) then
                insert into g04_orden values (fn_g04_getsigid(),new.mercado,new.id_usuario,new.tipo,current_timestamp,null,new.valor,new.cantidad-cantAcum,'activo');
            end if;
        else
            update g04_orden set estado= 'activo' where id=new.id;
        end if;

        return new;

    end $$ language 'plpgsql';

select * from g04_orden;