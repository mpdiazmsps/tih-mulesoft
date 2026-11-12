# papi-orders-tih

Process API de pedidos (puerto local 8083, ruta base `/api/v1/orders-management`). Contrato: `specs/papi-orders-tih/papi-orders-tih.raml`.

Consume: `papi-customers-tih` (8082), `sapi-sftp-orders-tih` (8092), `sapi-oracle-core-tih` (8091) y `sapi-price-providers-tih` (8093). Todas deben estar arriba para ejecutarla de verdad.

## Operaciones

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/orders` | Valida que el cliente exista (papi-customers), rechaza artículos repetidos, genera `orderId` y deposita `<customerId>_<orderId>.csv` (`item,qty`) en `/orders/pending`. Responde 201 `OrderReceived` |
| POST | `/orders/process` | Dispara el mismo ciclo que el scheduler. Responde 202 de inmediato; 409 `PROCESS_ALREADY_RUNNING` si ya hay uno en curso |

## Ciclo de procesamiento (`orders-process-pending-flow`)

Scheduler (propiedades `scheduler.*`; `initialState: stopped` lo apaga) o disparo manual. Un candado en Object Store (en memoria, `os:store failIfPresent`) garantiza un solo ciclo a la vez. Por cada CSV pendiente:

1. Nombre inválido, o el pedido ya está en Oracle (`GET /orders/{id}`) → no se vuelve a registrar; si ya existía, el archivo pasa a `processed`.
2. Lee y valida el CSV (UUID válido, qty 1–1000, sin artículos repetidos).
3. Consulta el inventario en una sola llamada. Artículos inexistentes → archivo a `error`.
4. Precio: `localPrice` si es > 0; si es 0 se cotiza con el proveedor (`providerAbv` + `externalId`) vía sapi-price-providers.
5. `POST /orders` en Oracle (una transacción). Un 409 se trata como ya registrado.
6. Arma el evento `order.registered` (**la publicación en RabbitMQ está pendiente del conector AMQP**, ver abajo).
7. Mueve el CSV a `processed`.

| Resultado | Qué pasa con el archivo |
|---|---|
| Registrado / ya estaba registrado | `processed` |
| Error de datos: CSV inválido, artículo inexistente, proveedor no conoce el artículo, BOR (501), 400 de un backend | `error` |
| Falla técnica: backend caído, timeout | se queda en `pending` y se reintenta en el siguiente ciclo |

Cada archivo tiene su propio manejo de errores: uno malo no detiene a los demás.

## Pendientes conocidos

- **Publicar en RabbitMQ**: `orders-publish-order-registered-subflow` arma el evento y lo deja en `vars.orderEvent`, pero falta el conector AMQP (no está en la caché local de Maven). Cuando esté, se agrega ahí el `amqp:publish` (exchange `orders.events`, routing key `order.registered`, header con el correlationId). Con el diseño actual, si publicar fallara después de registrar, el reintento vería el pedido ya registrado y no republicaría; al agregar AMQP conviene decidir entre fallar el ciclo antes de mover el archivo o un patrón outbox.
- Un cliente inexistente en un CSV colocado a mano (no por la API) depende de cómo responda Oracle al violar la FK; si responde 5xx el archivo se reintentaría cada ciclo.

## Pruebas

`mvn -o -B clean package`: 34 MUnit, cobertura 100 %. Las APIs consumidas se simulan por `doc:name`; la suite HTTP necesita el puerto 8083 libre.

## Evento order.registered (RabbitMQ)
Tras registrar el pedido en Oracle, `orders-publish-order-registered-subflow` publica el `OrderRegisteredEvent` en el exchange `orders.events` con routing key `order.registered` (AMQP Connector 1.9.4, header `x-correlation-id`).
Si RabbitMQ falla, el pedido NO se deshace ni se reprocesa: se registra un ERROR con el `orderId` y la notificación se reenvía a mano con `POST /orders-registered` de papi-notifications.
Conexión: `rabbitmq.*` en `dev-application-config.yaml`; usuario y clave en `dev-secure-application-config.yaml` (fuera de control de versiones).
Pruebas: 36 MUnit (cobertura 100 %) con `amqp:publish` simulado; falta una prueba contra el RabbitMQ real.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
