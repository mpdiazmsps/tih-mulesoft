# xapi-online-store

Experience API de la tienda (tarea 23): la única puerta REST para la tienda y el aprobador. Solo llama a la capa de
proceso y oculta qué sistema responde cada cosa. Contrato en Exchange: `xapi-online-store` 1.0.0
(`specs/xapi-online-store/xapi-online-store.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1 y APIkit 1.11.16.

Base local: `http://localhost:8080/api/v1/online-store`

| Operación | Process API |
|---|---|
| `GET /products` | papi-orders `GET /products` |
| `GET /customers`, `POST /customers`, `GET /customers/{customerId}` | papi-customers, mismas rutas |
| `GET /orders?status=&from=`, `POST /orders` (Id de Salesforce, sin `fileName`) | papi-orders, mismas rutas |
| `GET /orders/exceptions`, `GET /orders/{orderId}`, `GET /orders/{orderId}/alternatives` | papi-orders, mismas rutas |
| `POST /order-requests` (`Idempotency-Key`), `GET /order-requests?status=`, `GET /order-requests/{requestId}` | papi-order-requests, mismas rutas |
| `POST /order-requests/{requestId}/approve`, `POST /order-requests/{requestId}/reject` | papi-order-requests, mismas rutas |

## Cómo responde

- APIkit valida el contrato: 400 `VALIDATION_ERROR` sin llamar a la capa de proceso.
- Reenvía la respuesta de la Process API tal cual: estado, cuerpo (el tipo del contrato o el `ErrorResponse` común) y
  `Retry-After`. La `Location` de una solicitud nueva apunta a esta API (`/api/v1/online-store/order-requests/{id}`).
- Si la Process API no responde, contesta su propio 503 `SERVICE_UNAVAILABLE` con `Retry-After: 30`.
- **Quién llama (D10):** el `client_id` de quien llama viaja a la capa de proceso como `x-client-app`. Solo la aplicación
  del aprobador puede aprobar o rechazar; papi-order-requests responde 403 a cualquier otra, y la xapi lo reenvía.
  En local el `client_id` es libre: la tienda usa, por ejemplo, `tienda-web` y el aprobador `aprobador-tienda`.
- Propaga `x-correlation-id` y `Idempotency-Key`.

## Autodiscovery y Client ID Enforcement

`global.xml` tiene `api-gateway:autodiscovery` con `api.autodiscovery.id`:
- `cloud-application-config.yaml`: el id de la instancia de API Manager (se llena al crearla, tarea 26-27), donde se
  aplica Client ID Enforcement para la tienda, el aprobador y el generador de tráfico. Sin `client_id` la política
  responde 401.
- `local-application-config.yaml`: `"0"`. En Studio se arranca con `-M-Danypoint.platform.gatekeeper=disabled` en los
  VM args: el gateway queda en modo STANDALONE con el GateKeeper desactivado y la API responde sin políticas.

## Ejecución local

- Requiere papi-customers (8082), papi-orders (8083) y papi-order-requests (8085).
- En Studio, VM args: `-M-Denv=local -M-Danypoint.platform.gatekeeper=disabled`. No tiene propiedades seguras.
- La primera llamada al Pedido 360 tras arrancar tarda unos 5 s (conexiones en frío); antes de la demo conviene una
  llamada de calentamiento.
- Pruebas: `mvn -B clean package`: 25 MUnit (7 de flujos y 18 HTTP: una prueba de enrutamiento por operación, que
  revisa con un spy el método, la ruta y los encabezados de la llamada a la Process API, más las del contrato), cobertura
  100%. Las Process APIs se simulan; la suite HTTP necesita libre el puerto 8080.
