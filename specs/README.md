# Especificaciones RAML 1.0 (Fase 1)

Contratos de las 8 APIs del proyecto TIH, más 2 fragments compartidos. Están escritos y validados localmente; **todavía no se publican** en Design Center ni en Exchange.

```
specs/
  fragments/
    tih-common-types.raml      # tipos compartidos (Customer, OrderRequest, Price, ErrorResponse...)
    tih-common-traits.raml     # traits: secured, validated, not-found, conflict, retryable...
  xapi-online-store-tih/xapi-online-store-tih.raml
  papi-customers-tih/papi-customers-tih.raml
  papi-orders-tih/papi-orders-tih.raml
  papi-notifications-tih/papi-notifications-tih.raml
  sapi-oracle-core-tih/sapi-oracle-core-tih.raml
  sapi-sftp-orders-tih/sapi-sftp-orders-tih.raml
  sapi-price-providers-tih/sapi-price-providers-tih.raml
  tools/                       # validador (webapi-parser)
```

El nombre de cada archivo RAML y su `title` coinciden con el nombre de la aplicación, como pide el estándar (§12.3).

## APIs y recursos

| API | Base URI (local) | Recursos |
|---|---|---|
| xapi-online-store-tih | `http://localhost:8080/api/v1/online-store` | `POST /customers`, `POST /orders` |
| papi-customers-tih | `http://localhost:8082/api/v1/customers-management` | `POST /customers`, `GET /customers/{customerId}` |
| papi-orders-tih | `http://localhost:8083/api/v1/orders-management` | `POST /orders`, `POST /orders/process` |
| papi-notifications-tih | `http://localhost:8084/api/v1/notifications` | `POST /orders-registered` (más el listener AMQP, que no es HTTP) |
| sapi-oracle-core-tih | `http://localhost:8091/api/v1/core/store` | `POST/GET /customers`, `GET /customers/{customerId}`, `GET /inventory/items?ids=`, `POST /orders`, `GET /orders/{orderId}` |
| sapi-sftp-orders-tih | `http://localhost:8092/api/v1/sftp/orders` | `GET /files`, `PUT/GET /files/{fileName}`, `POST /files/{fileName}/move` |
| sapi-price-providers-tih | `http://localhost:8093/api/v1/price-providers` | `GET /providers/{providerAbv}/products/{externalId}/price` |

## Convenciones del contrato

- **Seguridad:** todos los métodos usan el trait `secured`: headers `client_id` y `client_secret` (los que espera la política Client ID Enforcement) y `x-correlation-id` opcional. El `401` lo devuelve la política.
- **Errores:** un único modelo `ErrorResponse` con `code`, `message`, `correlationId`, `timestamp` y `retryable`. Los `503` incluyen el header `Retry-After`.
- **JSON en camelCase.** Las columnas de Oracle (snake_case) se traducen en `sapi-oracle-core-tih`.
- **Regla "email o teléfono":** RAML no la puede expresar, la valida `papi-customers-tih`.
- **Rutas con `/process` y `/move`** en lugar de `:process` y `:move`: un sufijo con dos puntos pegado a un parámetro (`{fileName}:move`) puede confundir al router de APIkit.
- **Borland (`BOR`)** está en el enum `ProviderAbv` para poder responder `501 PROVIDER_NOT_SUPPORTED`.

### Códigos de error

| Código | HTTP | Uso |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Datos inválidos o faltantes |
| `UNAUTHORIZED` | 401 | Credenciales ausentes o inválidas (política) |
| `CUSTOMER_NOT_FOUND`, `ORDER_NOT_FOUND`, `FILE_NOT_FOUND`, `PRODUCT_NOT_FOUND` | 404 | Recurso inexistente |
| `CUSTOMER_ALREADY_EXISTS`, `FILE_ALREADY_EXISTS`, `PROCESS_ALREADY_RUNNING` | 409 | Conflicto con el estado actual |
| `PROVIDER_NOT_SUPPORTED` | 501 | Proveedor fuera de alcance (BOR) |
| `PROVIDER_ERROR` | 502 | Un sistema externo respondió con error |
| `SERVICE_UNAVAILABLE` | 503 | Oracle, SFTP o RabbitMQ no disponibles. `retryable: true` |
| `INTERNAL_ERROR` | 500 | Error inesperado |

## Validar los RAML

Requiere Node.js. Desde `specs/tools`:

```
npm install
npm run validate
```

El validador usa el parser AMF de MuleSoft: comprueba la sintaxis, las referencias a tipos y traits, y que los ejemplos cumplan sus tipos (así el mocking service de Design Center no devuelve datos inválidos).

## Publicar en Design Center y Exchange (cuando lo decidamos)

1. En Design Center crear dos proyectos *API Specification Fragment*: `tih-common-types` (Library) y `tih-common-traits` (Library, depende de la anterior) y publicarlos en Exchange.
2. Crear un proyecto *API Specification* por cada API, con el mismo nombre que la aplicación (RAML 1.0), y pegar el contenido del `.raml`.
3. Agregar los fragments como dependencias del proyecto y cambiar las rutas del bloque `uses` a las de Exchange, por ejemplo:
   `types: exchange_modules/<groupId>/tih-common-types/1.0.0/tih-common-types.raml`.
4. Publicar cada API en Exchange con versión `1.0.0`.
5. En Studio, importar la especificación desde Exchange y generar el scaffolding (APIkit) en `interface.xml`.
