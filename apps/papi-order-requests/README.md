# papi-order-requests

Process API de solicitudes de corrección (tarea 20): las guarda con su llave única, controla su estado y espera la
decisión de una persona. Contrato en Exchange: `papi-order-requests` 1.0.0
(`specs/papi-order-requests/papi-order-requests.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1, Database 1.15.1 con
`ojdbc11`, AMQP 1.9.6, APIkit 1.11.16 y Secure Properties 1.3.2.

Almacén: esquema `INTEGRATION_APP` de `poc-oracle` (tablas `ORDER_REQUESTS` y `ORDER_REQUEST_EVENTS`); nunca
`STORE_APP`.

## Recursos

Base local: `http://localhost:8085/api/v1`

| Método | Recurso | Qué hace | Respuestas |
|---|---|---|---|
| POST | `/order-requests` (cabecera `Idempotency-Key` obligatoria) | Guarda la solicitud `PENDING`, publica `approval.requested` y responde de inmediato. Repetir la llave devuelve la misma solicitud | 202 + `Location`, 400 |
| GET | `/order-requests?status=` | Solicitudes de un estado, la más reciente primero, con su historia | 200 |
| GET | `/order-requests/{requestId}` | Estado e historia de cada paso | 200, 404 |
| POST | `/order-requests/{requestId}/approve` | Aprueba y aplica con papi-orders | 200 (`COMPLETED` o `FAILED`), 403, 404, 409 |
| POST | `/order-requests/{requestId}/reject` `{reason}` | Rechaza; no aplica ni publica nada | 200, 403, 404, 409 |
| POST | `/order-requests/{requestId}/retry` | Reaplica una `FAILED` con la misma llave | 200, 403, 404, 409 |

## Estados (P08)

`PENDING` → `APPROVED` → `APPLYING` → `COMPLETED` o `FAILED`; desde `PENDING` también `REJECTED` o `EXPIRED`.
Cada transición es un `UPDATE ... WHERE STATUS = <origen>` más un paso en la historia (`ORDER_REQUEST_EVENTS`) con quién
y cuándo, en una transacción: una solicitud cambia una sola vez aunque lleguen dos decisiones a la vez (la segunda
recibe 409).

- **Quién decide (D10):** solo los `client_id` de `approval.approverClientIds` (cabecera `x-client-app`, que pasa la
  xapi). En local, `aprobador-tienda`; el agente (`agente-mcp`) recibe 403.
- **Al aprobar:** `APPLYING`, `POST papi-orders /orders/{id}/corrections` con la misma llave (papi-orders no mueve nada
  dos veces, D7) y `COMPLETED`, que publica `correction.applied` una sola vez (el único correo al cliente de una
  corrección, D18). Si papi-orders falla queda `FAILED` y no se publica nada; `/retry` la reaplica.
- **Al crear:** `approval.requested` con `amount = quantity × price` (3 × 175.00 = 525.00).
- **Vencimiento:** un scheduler cada 5 minutos pasa a `EXPIRED` lo `PENDING` con más de 24 h
  (`requests.expiryHours`). Aprobar una vencida también la marca `EXPIRED` y responde 409.
- **Cliente del pedido:** se toma del Pedido 360 de papi-orders al crear y se guarda en `CUSTOMER_ID` para los eventos.

## Ejecución local

- Requiere `poc-oracle` (esquema `INTEGRATION_APP`), `poc-rabbitmq` y papi-orders (8083).
- Propiedades seguras: `local-secure-application-config.yaml` (ignorado por Git) con los usuarios de `INTEGRATION_APP`
  y de RabbitMQ cifrados con `POC_ENC_KEY`; plantilla en el `.example`.
- En Studio, VM args: `-M-Denv=local -M-Dencryption.key=<POC_ENC_KEY> -M-Ddb.port=<puerto de poc-oracle>`.
- Pruebas: `mvn -B clean package "-Dencryption.key=$POC_ENC_KEY"` (23 MUnit: 18 de flujos y 5 HTTP, con el almacén,
  papi-orders y RabbitMQ simulados; la suite HTTP necesita libre el puerto 8085). El SQL se probó además contra
  `poc-oracle` con ROLLBACK.
