# papi-notifications-tih

PAPI de notificaciones. Contrato: `specs/papi-notifications-tih/papi-notifications-tih.raml`.

`POST /api/v1/notifications/orders-registered` (puerto local 8084) procesa un evento `order.registered`:
1. `GET` papi-customers `/customers/{customerId}` (404 → `CUSTOMER_NOT_FOUND`).
2. Sin email → 200 `SKIPPED_NO_EMAIL` (no se llama a MagicBell).
3. Con email → `POST https://api.magicbell.com/broadcasts` (token Bearer de Project Auth) → 200 `SENT`. MagicBell ya no tiene SAPI propia: se llama directo desde esta PAPI.

Errores: 400 (APIkit), 404 `CUSTOMER_NOT_FOUND`, 502 `PROVIDER_ERROR`/`PROVIDER_REJECTED`, 503 + `Retry-After`.

## Disparador AMQP
Listener sobre la cola `orders.registered.q` (RabbitMQ, ACK manual) en `consume-order-registered.xml`; usa el AMQP Connector 1.9.4.
- Éxito o cliente sin email → ACK.
- Error permanente (cliente inexistente, MagicBell rechaza: 400/401/403/404/422) → reject sin requeue → DLQ `orders.registered.dlq`, sin reintentos.
- Error transitorio (503, 5xx, timeout) → hasta 2 reintentos (2 s) y luego reject a la DLQ.
- Mensaje que no es JSON → reject a la DLQ.
Conexión: `rabbitmq.*` en `dev-application-config.yaml`; usuario y clave en `dev-secure-application-config.yaml`.
Probado solo con ack/reject simulados: falta una prueba contra el RabbitMQ real.

## Pruebas (resumen anterior)
`mvn -o -B clean package` (8 MUnit, cobertura 100 %). Las APIs consumidas se simulan; la suite HTTP necesita el puerto 8084 libre.

## Credencial de MagicBell
Token de **Project Auth** en `src/main/resources/properties/dev-secure-application-config.yaml` (`magicbell.token`), fuera de control de versiones. Origen: `infra/magicbell/credentials.local`.
Errores de MagicBell: 401/403/400/404/422 → 502 `PROVIDER_REJECTED` (no reintentable); 5xx → 502 `PROVIDER_ERROR`; caído/timeout/429 → 503 + `Retry-After`.
Pruebas: 14 MUnit (cobertura 92 %; el listener en sí no se cubre porque necesita broker). Pendiente: prueba de envío real y canal de email habilitado en el dashboard.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
