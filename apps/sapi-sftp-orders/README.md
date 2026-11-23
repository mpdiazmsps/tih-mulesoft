# sapi-sftp-orders

System API hacia logística por SFTP (tarea 13). Contrato en Exchange: `sapi-sftp-orders` 1.0.1
(`specs/sapi-sftp-orders/sapi-sftp-orders.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1, SFTP 2.7.1, APIkit 1.11.16 y
`poc-resilience` 1.0.0.

## Cómo funciona

- El estado de una remisión es la carpeta donde está: `/despachos/pendientes` (PENDING), `/despachos/firmadas` (SIGNED)
  y `/despachos/rechazadas` (REJECTED).
- Cada remisión es `remision_<orderId>_<n>.csv`. Reemitir crea el siguiente `n` (el mayor en las tres carpetas, más 1);
  nunca sobrescribe.
- Se escribe primero `<archivo>.tmp` y luego se renombra, para que logística nunca lea un archivo a medias
  (`poc-logistics-sim` ignora los `.tmp`).
- El acuse `<archivo>.acuse.json` lo deja logística junto al CSV: `recibio` y `fecha` si se firmó, `motivo` y `fecha`
  si se rechazó.

## Recursos

Base local: `http://localhost:8092/api/v1/sftp/orders`

| Método | Recurso | Respuestas |
|---|---|---|
| POST | `/dispatch-notes` | 201 `DispatchNote` (PENDING), 400, 503 |
| GET | `/dispatch-notes?status=PENDING\|SIGNED\|REJECTED` | 200 (puede venir vacía), 400, 503 |
| GET | `/dispatch-notes/{orderId}` | 200 con la remisión de mayor `n`, 404 `DISPATCH_NOTE_NOT_FOUND` (papi-orders lo lee como `ON_HOLD`), 503 |

## Resiliencia

Las tres operaciones pasan por `resilience-call` de `poc-resilience` con la fuente `sftp`. La conexión tiene un tiempo
límite de 3 s, hay un solo reintento y solo ante falla de conexión, y el interruptor se abre tras 3 fallas seguidas
por 30 s. Con el interruptor abierto se responde 503 `SERVICE_UNAVAILABLE` con `Retry-After`, sin tocar el SFTP.

## Ejecución local

- Requiere `poc-sftp` y `poc-logistics-sim` corriendo (`infra/scripts/start-infra`).
- Autenticación solo con llave (D21): usuario `pocsftp`, llave privada `infra/sftp/keys/poc_sftp_rsa`, que genera
  `start-infra` y que no se versiona. La llave no tiene frase de paso, así que la app no usa propiedades seguras.
- En Studio, VM args:
  `-M-Denv=local -M-Dsftp.identityFile=<ruta del repo>/infra/sftp/keys/poc_sftp_rsa`
- Demostración: `demo/control sftp-down` detiene `poc-sftp` y `demo/control sftp-up` lo vuelve a levantar.
- Pruebas: `mvn -B clean package` (14 MUnit: 9 de flujos y 5 HTTP, con el SFTP simulado; la suite HTTP necesita
  libre el puerto 8092).
