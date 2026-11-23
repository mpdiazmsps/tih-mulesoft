# sapi-price-providers

System API de los tres proveedores de precios (tarea 12). Contrato en Exchange: `sapi-price-providers` 1.0.1
(`specs/sapi-price-providers/sapi-price-providers.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1, Web Service Consumer 2.1.2,
APIkit 1.11.16 y `poc-resilience` 1.0.0.

| Proveedor | Código | Simulador local (WireMock, `poc-wiremock`, puerto 8089) |
|---|---|---|
| A (REST) | `FAK` | `GET /proveedor-a/products/{id}` → `{id, title, price, currency}`; id desconocido: 200 sin cuerpo |
| B (REST) | `ESC` | `GET /proveedor-b/api/v1/products/{id}` → `{id, title, price, currency, category}`; id desconocido: 400 |
| C (SOAP 1.1) | `BOR` | `POST /proveedor-c/OrderService`, operación `GetArticleById`; id desconocido: sin `GetArticleByIdResult` |

La moneda siempre sale de la respuesta del proveedor (en C, el elemento opcional `Currency` que se agregó al WSDL).

## Recursos

Base local: `http://localhost:8093/api/v1/price-providers`

| Método | Recurso | Respuestas |
|---|---|---|
| GET | `/providers/{providerAbv}/products/{externalId}/price` | 200 `Quote`, 400, 404 `PRODUCT_NOT_FOUND`, 502 `PROVIDER_ERROR`, 503 `SERVICE_UNAVAILABLE` + `Retry-After` |
| POST | `/quotes` (lista de 1 a 10 `{abv, externalId}`) | Siempre 200 `{quotes, noResponse}` dentro del tiempo límite; 400 si la lista no cumple el contrato |

En `noResponse` cada proveedor lleva su motivo: `TIMEOUT`, `CIRCUIT_OPEN`, `NOT_FOUND` o `ERROR`.

## Resiliencia

Cada llamada a un proveedor pasa por `resilience-call` de `poc-resilience`, con la fuente `provider-fak`, `provider-esc`
o `provider-bor`:

- Tiempo límite de 2 s por proveedor (`rs.provider-<abv>.timeoutMillis`). Como `/quotes` llama a los proveedores en
  paralelo (`parallel-foreach`), la respuesta completa tarda menos de 3 s aunque C tarde 5 s.
- Un solo reintento y solo ante falla de conexión. Un tiempo agotado no se reintenta (D9).
- Un interruptor por proveedor: se abre tras 3 fallas seguidas y queda abierto 30 s.
- Que el proveedor no conozca el producto no es una falla: no abre el interruptor.

## Ejecución local

- Requiere `poc-wiremock` corriendo (`infra/scripts/start-infra`). No hay credenciales.
- En Studio: VM args `-M-Denv=local`. Hace falta porque la variable de entorno `env` de Windows tiene prioridad
  sobre el valor por defecto de la app.
- Para la demostración, `demo/control slow-c` pone a C en 5 s y `demo/control normal-c` lo regresa.
- Pruebas: `mvn -B clean package` (15 MUnit: 10 de flujos y 5 HTTP; la suite HTTP necesita libre el puerto 8093).
