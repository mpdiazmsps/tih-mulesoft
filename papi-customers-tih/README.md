# papi-customers-tih

Process API de clientes (puerto local 8082, ruta base `/api/v1/customers-management`). Contrato: `specs/papi-customers-tih/papi-customers-tih.raml`.
Solo habla con `sapi-oracle-core-tih` (puerto 8091, que debe estar arriba para ejecutarla de verdad).

## Operaciones

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/customers` | Valida **email o teléfono**, busca duplicados (`GET /customers?email&phone` en la SAPI), genera `id` (UUID) y `creationDate`, registra con `POST /customers`. Responde 201 `{customerId, creationDate}` |
| GET | `/customers/{customerId}` | Consulta el cliente. Lo usan papi-orders-tih y papi-notifications-tih |

## Errores

| Situación | HTTP | code |
|---|---|---|
| Sin email ni teléfono / cuerpo fuera del contrato / id no UUID | 400 | `VALIDATION_ERROR` |
| Ya existe cliente con ese email o teléfono (búsqueda previa o 409 de la SAPI por carrera) | 409 | `CUSTOMER_ALREADY_EXISTS` |
| Cliente inexistente | 404 | `CUSTOMER_NOT_FOUND` |
| Oracle o la SAPI no disponibles | 503 + `Retry-After` | `SERVICE_UNAVAILABLE` |

Nota técnica: el conector HTTP de Mule no tiene tipo de error para 409, por eso los flujos aceptan 404/409 en el `response-validator` y deciden con `attributes.statusCode`.

## Ejecución y pruebas

- Propiedades: `src/main/resources/properties/dev-application-config.yaml` (`client_id/client_secret` son placeholders: la política Client ID Enforcement solo existe en API Manager).
- `mvn -o -B clean package`: 15 MUnit, cobertura 100 %. La SAPI se simula; la suite HTTP necesita el puerto 8082 libre.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
