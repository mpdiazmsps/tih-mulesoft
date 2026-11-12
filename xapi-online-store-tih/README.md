# xapi-online-store-tih

Experience API de la tienda en línea (puerto local 8080, ruta base `/api/v1/online-store`). Contrato: `specs/xapi-online-store-tih/xapi-online-store-tih.raml`. Es el único punto de entrada para el consumidor externo y no tiene lógica de negocio.

| Método | Ruta | Delega en |
|---|---|---|
| POST | `/customers` | `papi-customers-tih` `POST /customers` (8082) |
| POST | `/orders` | `papi-orders-tih` `POST /orders` (8083) |

## Cómo responde

- Valida el contrato con APIkit (400 `VALIDATION_ERROR` sin llamar a la PAPI).
- Reenvía la respuesta de la PAPI **tal cual**: estado, cuerpo y `Retry-After`. Las PAPI ya devuelven el `ErrorResponse` del contrato (409 `CUSTOMER_ALREADY_EXISTS`, 404 `CUSTOMER_NOT_FOUND`, 503 `SERVICE_UNAVAILABLE`…), así que el consumidor ve el `retryable` que indica si puede reintentar.
- Si la PAPI no responde (conectividad o timeout), contesta su propio 503 `SERVICE_UNAVAILABLE` con `Retry-After: 30`.

## Ejecución y pruebas

- Propiedades: `src/main/resources/properties/dev-application-config.yaml` (`client_id/client_secret` son placeholders; Client ID Enforcement solo existe en API Manager).
- Para usarla de verdad deben estar arriba papi-customers (8082), papi-orders (8083) y, detrás, las SAPIs, Oracle y el SFTP.
- `mvn -o -B clean package`: 9 MUnit, cobertura 100 %. Las PAPIs se simulan; la suite necesita el puerto 8080 libre.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
