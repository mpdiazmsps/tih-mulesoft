# papi-customers

Process API de clientes (tarea 16): gestiona a los clientes de la tienda sobre Salesforce, a través de `sapi-crm`.
Contrato en Exchange: `papi-customers` 1.0.0 (`specs/papi-customers/papi-customers.raml`). Mule 4.11.4, Java 17,
HTTP 1.12.1 y APIkit 1.11.16.

## Recursos

Base local: `http://localhost:8082/api/v1/customers-management`

| Método | Recurso | Qué hace | Respuestas |
|---|---|---|---|
| GET | `/customers?ids=` | Hasta 50 clientes en una sola llamada a sapi-crm (una sola consulta SOQL) | 200, 400, 502, 503 |
| GET | `/customers?email=&phone=` | Búsqueda | 200 (puede venir vacía) |
| GET | `/customers?page=&size=` | Listado paginado para elegir quién compra | 200 |
| GET | `/customers/{customerId}` | Un cliente por Id de Salesforce | 200, 404 `CUSTOMER_NOT_FOUND` |
| POST | `/customers` | Registra el cliente en Salesforce | 201, 400, 409 `CUSTOMER_ALREADY_EXISTS`, 502, 503 |

Reglas de negocio:
- Un cliente necesita correo o teléfono (400 si no trae ninguno).
- Correo repetido → 409 `CUSTOMER_ALREADY_EXISTS`, en dos capas: primero se busca el correo en sapi-crm; si dos altas
  llegan a la vez, la regla de duplicados de Salesforce bloquea la segunda y sapi-crm responde 409
  `CONTACT_ALREADY_EXISTS`, que aquí se traduce igual (D22).
- El Id del cliente es el de Salesforce (18 caracteres); ya no se genera un UUID.

Errores de sapi-crm: no disponible, sin conexión o tiempo agotado → 503 con `Retry-After`; error del CRM → 502.

## Ejecución local

- Requiere `sapi-crm` corriendo en el puerto 8094.
- En Studio: VM arg `-M-Denv=local`. No usa propiedades seguras: localmente cualquier `client_id`/`client_secret`
  sirve para llamar a sapi-crm; en CloudHub (T26) serán las credenciales de la aplicación cliente.
- Pruebas: `mvn -B clean package` (15 MUnit: 10 de flujos y 5 HTTP, con sapi-crm simulado; la suite HTTP necesita libre
  el puerto 8082).
