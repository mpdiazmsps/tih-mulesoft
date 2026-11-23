# sapi-crm

System API de Salesforce (tarea 14): los clientes son Contacts. Contrato en Exchange: `sapi-crm` 1.0.1
(`specs/sapi-crm/sapi-crm.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1, Salesforce 12.1.1 (JWT), APIkit 1.11.16,
Secure Properties 1.3.2 y `poc-resilience` 1.0.0.

## Recursos

Base local: `http://localhost:8094/api/v1/crm`

| Método | Recurso | Qué hace | Respuestas |
|---|---|---|---|
| GET | `/contacts?ids=` | Hasta 50 contactos en **una sola** consulta SOQL con `IN` | 200, 400, 502, 503 |
| GET | `/contacts?email=&phone=` | Búsqueda (parámetros SOQL escapados por el conector) | 200 (puede venir vacía) |
| GET | `/contacts?page=&size=` | Listado por nombre | 200 |
| GET | `/contacts/{id}` | Un contacto por Id de 18 caracteres | 200, 404 `CONTACT_NOT_FOUND` |
| POST | `/contacts` | Crea el Contact; sin `segment` queda `REGULAR` | 201, 409 `CONTACT_ALREADY_EXISTS`, 502, 503 |

Combinar `ids` con `email`/`phone` responde 400.

Traducción del Contact: `Segmento__c` `Estratégico` → `STRATEGIC` y `Regular` → `REGULAR`; la dirección sale de
`MailingStreet`, `MailingCity`, `MailingState` y `MailingPostalCode` (solo si hay ciudad). Al crear, el nombre completo
va a `LastName`.

Correo duplicado (D22): un correo que ya existe lo bloquea la regla `POC_Bloquear_Correo_Duplicado`
(`DUPLICATES_DETECTED`); dos altas simultáneas con el mismo correo las bloquea el campo único `Email_Key__c`, que la
app llena con el correo en minúsculas (`DUPLICATE_VALUE`). En ambos casos la API responde 409 y no reintenta.

La org tiene listas de estados y países: cuando hay dirección se manda `MailingCountry = Mexico` (un estado sin país
lo rechaza Salesforce).

## Resiliencia

Todas las llamadas pasan por `resilience-call` de `poc-resilience` con la fuente `crm`: 3 s de lectura por operación
(`rs.crm.timeoutMillis`), un solo reintento y solo ante falla de conexión, e interruptor tras 3 fallas seguidas por
30 s. Salesforce no disponible, sin cuota o con el interruptor abierto → 503 con `Retry-After`; otro error de
Salesforce → 502.

Limitación conocida: el conector clasifica `SALESFORCE:UNAVAILABLE` (Salesforce respondiendo "servicio no disponible",
por ejemplo en mantenimiento) como hijo de `MULE:CRITICAL`, y Mule 4 no deja manejar esos errores ni con un manejador
explícito: en ese caso la API responde 500 en lugar de 503. Salesforce inalcanzable por red llega como `CONNECTIVITY`
o `TIMEOUT` y sí responde 503.

## Credenciales

- `src/main/resources/properties/local-secure-application-config.yaml`, ignorado por Git: Consumer Key de la app
  `POC sapi-crm`, usuario de Salesforce y contraseña del keystore, cifrados con `POC_ENC_KEY` (AES/CBC). La plantilla
  es el `.example` de la misma carpeta.
- El keystore `infra/salesforce/certs/poc-sf.p12` (alias `poc-sf`) no se versiona y su ruta se pasa al arrancar. Tiene que ser PKCS12: el conector no lee JKS ("Tag number over 30 is not supported"). Se saca de `poc-sf.jks` con `keytool -importkeystore ... -deststoretype PKCS12` (misma contraseña).

## Ejecución local

- En Studio, VM args:
  `-M-Denv=local -M-Dencryption.key=<POC_ENC_KEY> -M-Dsalesforce.keyStore=<ruta del repo>/infra/salesforce/certs/poc-sf.p12`
- Pruebas: `mvn -B clean package "-Dencryption.key=$POC_ENC_KEY"` (18 MUnit: 13 de flujos y 5 HTTP, con Salesforce
  simulado; la suite HTTP necesita libre el puerto 8094).
