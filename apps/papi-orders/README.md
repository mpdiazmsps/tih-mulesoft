# papi-orders

Process API de pedidos, el corazón de la PoC. Contrato en Exchange: `papi-orders` 1.0.0
(`specs/papi-orders/papi-orders.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1, AMQP 1.9.6 (`com.mulesoft.connectors`),
Object Store 1.3.4, APIkit 1.11.16, Secure Properties 1.3.2 y `poc-resilience` 1.0.0.

Parte A (tarea 17): catálogo, registro, listado y ciclo de confirmación. Parte B (tarea 18): Pedido 360, excepciones y
alternativas. Parte C (tarea 19): correcciones aprobadas.

## Recursos (parte A)

Base local: `http://localhost:8083/api/v1/orders-management`

| Método | Recurso | Qué hace |
|---|---|---|
| GET | `/products?page=&size=` | Catálogo: precio local o último precio del proveedor preferente. Nunca cotiza en vivo |
| GET | `/orders?status=&from=` | Delega la consulta a sapi-oracle-core |
| POST | `/orders` | Valida al cliente con papi-customers y registra el pedido `RECEIVED` en menos de 1 s (201) |
| POST | `/orders/process` | Dispara el ciclo de confirmación en segundo plano (202); 409 si ya hay uno corriendo |

## Ciclo de confirmación (P13)

Corre cada 60 s (scheduler) y con `POST /orders/process`. Un solo ciclo a la vez, con un candado en memoria en el
Object Store (1 réplica, D16); el candado se libera aunque el ciclo falle y vence a los 5 min. Para cada pedido
`RECEIVED`:

1. **Precio por línea:** `localPrice` si es mayor que 0 (`LOCAL`); si no, el `lastPrice` del proveedor preferente
   (`LAST_PRICE`); si no, cotiza en vivo con el preferente (`QUOTE`). Si el proveedor no responde, el pedido sigue
   `RECEIVED` y se reintenta en el siguiente ciclo.
2. **Confirmación:** `PATCH` a `CONFIRMED` con los precios (el ERP guarda el último precio del proveedor).
3. **Con stock completo:** una salida por línea con referencia `<orderId>-out-<itemId>` (se registra una sola vez,
   D7), la remisión a logística y el evento `order.registered` al exchange `orders.events` (D8).
4. **Con faltante:** el pedido queda `CONFIRMED` y la remisión espera; aparece en la bandeja de excepciones.

Un pedido que falla se registra en el log y el ciclo sigue con el siguiente. Si una cotización en vivo falla, ese
producto no se vuelve a cotizar con ese proveedor durante 10 minutos (`cycle.quoteBackoffSeconds`): así un producto
cuyo proveedor siempre falla (SKU-300 con C) no abre el interruptor de C para los demás productos.

## Pedido 360, alternativas y excepciones (parte B)

| Método | Recurso | Qué hace |
|---|---|---|
| GET | `/orders/{orderId}` | Pedido 360: ERP (pedido e inventario por lote) y, en paralelo, CRM, logística y, con faltante, proveedores (`POST /quotes`) |
| GET | `/orders/{orderId}/alternatives` | `RESTOCK` con las cotizaciones de los tres proveedores y la más barata, o `REISSUE` si la remisión fue rechazada; 409 si no hay nada que resolver |
| GET | `/orders/exceptions?limit=` | Pedidos en riesgo con una llamada por lote a cada fuente; primero los `STRATEGIC`, después por antigüedad |

- Cada rama pasa por `resilience-call` (fuentes `crm`, `logistics` y `providers`) con un tiempo límite menor a 3 s.
  Si una fuente no responde la respuesta llega igual y lo marca en `sources`: sin `customer` (CRM), remisión `UNKNOWN`
  (logística) o `providers: "2 of 3"`.
- Excepciones: `UNCONFIRMED` (sigue `RECEIVED`), `STOCK_SHORTAGE` (`CONFIRMED`, sin remisión y una línea pide más que
  el stock) y `DISPATCH_REJECTED` (la última remisión está `REJECTED`).
- La remisión vale `ON_HOLD` si no hay ninguna y `UNKNOWN` si la logística no respondió.

## Correcciones aprobadas (parte C)

`POST /orders/{orderId}/corrections {type, key, itemId?, provider?, quantity?}`, que llama papi-order-requests con la
llave de la solicitud:

- `RESTOCK`: reposición con `reference = key`, una salida por línea con `reference = key-out-itemId` y la remisión si el
  pedido todavía no tiene una. El ERP registra cada referencia una sola vez (D7): repetir la llave responde 200 con el
  mismo resultado y no mueve nada.
- `REISSUE`: nueva remisión (siguiente `n`) solo mientras la última está `REJECTED`; si ya hay una más nueva responde
  200 con esa.
- Ninguna publica `order.registered` (D18): el aviso al cliente sale de `correction.applied` (papi-order-requests).

## Ejecución local

- Requiere sapi-oracle-core (8091), sapi-sftp-orders (8092), sapi-price-providers (8093), sapi-crm (8094),
  papi-customers (8082) y `poc-rabbitmq` (5673).
- Propiedades seguras: `local-secure-application-config.yaml` (ignorado por Git) con el usuario y la contraseña de
  RabbitMQ cifrados con `POC_ENC_KEY`; plantilla en el `.example`.
- En Studio, VM args: `-M-Denv=local -M-Dencryption.key=<POC_ENC_KEY>`.
- Pruebas: `mvn -B clean package "-Dencryption.key=$POC_ENC_KEY"` (47 MUnit: 38 de flujos y 9 HTTP, con las APIs y
  RabbitMQ simulados; las suites HTTP necesitan libre el puerto 8083).
