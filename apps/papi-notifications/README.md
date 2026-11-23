# papi-notifications

Process API de avisos por correo (tarea 21). Escucha tres eventos de RabbitMQ (exchange `orders.events`), completa el
contacto con papi-customers y envía con MagicBell (`POST /broadcasts`). Contrato en Exchange: `papi-notifications`
1.0.0 (`specs/papi-notifications/papi-notifications.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1, AMQP 1.9.6,
APIkit 1.11.16 y Secure Properties 1.3.2.

## Eventos

| Cola | Evento | Destinatario | Correo |
|---|---|---|---|
| `orders.registered.q` | `order.registered` (solo el ciclo normal, D8) | Cliente | "Tu pedido PED-1003 está confirmado", con el total |
| `approval.requested.q` | `approval.requested` | Aprobador (`notifications.approverEmail`) | "Solicitud por aprobar: RESTOCK del pedido PED-1002", con quién la pide, el monto, la solicitud y el vencimiento |
| `correction.applied.q` | `correction.applied` | Cliente | "Corregimos tu pedido PED-1002": "Hola Constructora Cumbres, … repusimos 3 piezas con el proveedor BOR y enviamos la remisión …". Es el único correo al cliente por una corrección (D18) |

- **Destino (D11):** todos los correos van a `notifications.redirectTo`, porque los contactos del guion tienen correos
  ficticios. Si se deja vacío, cada correo va a su destinatario real.
- **Referencia del pedido:** los pedidos de la demo terminan en su número (`…-000000001002` → `PED-1002`).
- **Cliente sin correo:** el resultado es `SKIPPED` y no se llama a MagicBell.
- El texto de los correos está en español (es contenido de la demo); flujos, logs y errores están en inglés (D5b).

## Reintentos y DLQ

Cada listener usa ACK manual:

- Correo enviado u omitido → ACK.
- Error transitorio (MagicBell o papi-customers caídos, 5xx, timeout) → hasta 3 intentos (`rabbitmq.retryMax` 2, cada
  2 s); al tercer fallo, reject sin requeue → la cola `*.dlq` de su evento.
- Error permanente (cliente inexistente; MagicBell responde 400, 401, 403, 404 o 422) → reject inmediato a la DLQ.
- Mensaje que no es JSON → reject a la DLQ.
- Para `approval.requested`, si el cliente no existe el aviso al aprobador sale igual, con el id del cliente en lugar del
  nombre.

## Recurso HTTP

Base local `http://localhost:8084/api/v1/notifications`. `POST /orders-registered` reenvía a mano la confirmación de
un pedido (pruebas y soporte): 200 `{status, recipient, broadcastId}`; 400; 404 `CUSTOMER_NOT_FOUND`; 502
`PROVIDER_REJECTED` (no reintentable) o `PROVIDER_ERROR`; 503 con `Retry-After`.

## Ejecución local

- Requiere `poc-rabbitmq` (5673) y papi-customers (8082), con sapi-crm detrás.
- Propiedades seguras: `local-secure-application-config.yaml` (ignorado por Git) con el token de MagicBell
  (`ACCESS_TOKEN` de `infra/magicbell/credentials.local`; cuenta personal de Maite en la v1, D23) y el usuario `poc-app`
  de RabbitMQ, cifrados con `POC_ENC_KEY`. Plantilla en el `.example`.
- En Studio, VM args: `-M-Denv=local -M-Dencryption.key=<POC_ENC_KEY>`.
- Pruebas: `mvn -B clean package "-Dencryption.key=$POC_ENC_KEY"`: 23 MUnit (18 de flujos y 5 HTTP), cobertura 100%,
  con papi-customers, MagicBell y el ACK/reject simulados. La suite HTTP necesita libre el puerto 8084. La corrida de
  MUnit usa destinatarios propios (`demo@ejemplo.mx`, `aprobador@ejemplo.mx`) y reintentos de 10 ms (pom).
