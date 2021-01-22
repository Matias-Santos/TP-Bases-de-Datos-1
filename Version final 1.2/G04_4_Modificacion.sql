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
                update g04_billetera set saldo = (saldo + (tupla.valor * tupla.cantidad * 0.95))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,ordenAEjecutar.id,tupla.cantidad);

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,tupla.cantidad,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());

            -- Esto cortaria solo para algunos casos especificos en los que la orden de venta es muy grande y hay que dividirla
            else
                update g04_orden set fecha_ejec = current_timestamp , estado = 'finalizado' where id = tupla.id;
                -- Actualizo las billeteras del vendedor
                -- Update del saldo en la moneda que va a recibir por la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_o);

                update g04_billetera set saldo = (saldo + (tupla.valor * (tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)) * 0.95))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_d);

                insert into g04_orden values
                (fn_g04_getSigID(), tupla.mercado, tupla.id_usuario, tupla.tipo, current_timestamp, null, tupla.valor, tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum), 'activo');

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,ordenAEjecutar.id,(tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)));

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * (tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,(tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                cantAcum := ordenAEjecutar.cantidad;
                saldoGastado := saldoGastado + (tupla.valor * (tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)));
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            update g04_billetera set saldo = saldo + (ordenAEjecutar.cantidad * ordenAEjecutar.valor - saldoGastado) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_d);
            update g04_billetera set saldo = (saldo + (cantAcum * 0.95)) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_o);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=ordenAEjecutar.id;
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,saldoGastado,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
            if (cantAcum < ordenAEjecutar.cantidad) then
                insert into g04_orden values (fn_g04_getsigid(),ordenAEjecutar.mercado,ordenAEjecutar.id_usuario,ordenAEjecutar.tipo,current_timestamp,null,ordenAEjecutar.valor,ordenAEjecutar.cantidad-cantAcum,'activo');
            end if;
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
        saldoAux numeric(20,10):=0;
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
                -- Update del saldo en la moneda con la que se va a pagar la transaccion
                update g04_billetera set saldo = (saldo + (tupla.cantidad * tupla.valor) - (ordenAEjecutar.valor * tupla.cantidad))
                    where (id_usuario= tupla.id_usuario) and (moneda = monedas.moneda_d);

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,ordenAEjecutar.id,tupla.cantidad);

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

                update g04_billetera set saldo = (saldo + (tupla.cantidad * tupla.valor) - (ordenAEjecutar.valor * (ordenAEjecutar.cantidad - cantAcum)))
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_d);

                update g04_billetera set saldo = (saldo + (ordenAEjecutar.cantidad - cantAcum) * 0.95)
                    where (id_usuario = tupla.id_usuario) and (moneda = monedas.moneda_o);
                select saldo into saldoAux
                    from g04_billetera where id_usuario = tupla.id_usuario and moneda like monedas.moneda_d;
                raise warning 'ordenAEjecutar.valor: % , ordenAEjecutar.cantidad: % ,  cantAcum: % ' , ordenAEjecutar.valor, ordenAEjecutar.cantidad, cantAcum;
                raise warning 'saldo de la billetera: %' , saldoAux;
                raise warning 'tupla.cantidad: % , tupla.valor: % ', tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum), tupla.valor;
                /*
                [2020-11-10 16:40:14] [01000] saldo de la billetera: 0.0000000000
                [2020-11-10 16:40:14] [01000] ordenAEjecutar.valor: 2.8354838444 , ordenAEjecutar.cantidad: 55.7650043605 ,  cantAcum: 53.4283004538
                [2020-11-10 16:40:14] [01000] saldo de la billetera: 437.0134722071
                [2020-11-10 16:40:14] [01000] tupla.cantidad: 79.1945164937 , tupla.valor: 8.1142934086
                */
                insert into g04_orden values
                (fn_g04_getSigID(), tupla.mercado, tupla.id_usuario, tupla.tipo, current_timestamp, null, tupla.valor, tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum), 'activo');

                -- Inserto composicion orden
                insert into g04_composicionorden values (tupla.id,ordenAEjecutar.id,(tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)));

                -- Insertar movimientos vendedor
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,tupla.valor * (tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
                insert into g04_movimiento values (tupla.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,(tupla.cantidad - (ordenAEjecutar.cantidad - cantAcum)),trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
                saldoObtenido := saldoObtenido + (ordenAEjecutar.valor * (ordenAEjecutar.cantidad - cantAcum));
                cantAcum := ordenAEjecutar.cantidad;
                exit;
            end if;
        end loop;

        -- Actualizo la orden y billeteras en caso de que se haya completado entera o al menos una parte
        if (cantAcum > 0) then
            update g04_billetera set saldo = (saldo + ordenAEjecutar.cantidad - cantAcum) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_o);
            update g04_billetera set saldo = (saldo + (saldoObtenido * 0.95)) where (id_usuario = ordenAEjecutar.id_usuario and moneda = monedas.moneda_d);
            update g04_orden set fecha_ejec = current_timestamp, estado= 'finalizado' where id=ordenAEjecutar.id;
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_o,fn_g04_getTimestamp(),'t',0.05,cantAcum,trfn_g04_getMaxBloque(monedas.moneda_o) + 1,trfn_g04_generaDireccion());
            insert into g04_movimiento values (ordenAEjecutar.id_usuario,monedas.moneda_d,fn_g04_getTimestamp(),'t',0.05,saldoObtenido,trfn_g04_getMaxBloque(monedas.moneda_d) + 1,trfn_g04_generaDireccion());
            if (cantAcum < ordenAEjecutar.cantidad) then
                insert into g04_orden values (fn_g04_getsigid(),ordenAEjecutar.mercado,ordenAEjecutar.id_usuario,ordenAEjecutar.tipo,current_timestamp,null,ordenAEjecutar.valor,ordenAEjecutar.cantidad-cantAcum,'activo');
            end if;
        else
            update g04_orden set estado= 'activo' where id=ordenAEjecutar.id;
        end if;

    end $$ language 'plpgsql';