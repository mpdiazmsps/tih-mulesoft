# sapi-oracle-core

System API del ERP (tarea 11): Oracle Free, servicio `FREEPDB1`, esquema `STORE_APP`. Contrato en Exchange:
`sapi-oracle-core` 1.0.1 (`specs/sapi-oracle-core/sapi-oracle-core.raml`). Mule 4.11.4, Java 17, HTTP 1.12.1,
APIkit 1.11.16, Database 1.15.1 y driver `ojdbc11`.

Los clientes ya no viven aquí: están en Salesforce (sapi-crm). `/customers` responde 404.

## Recursos

Base local: `http://localhost:8091/api/v1/core/store`

| Método | Recurso | Qué hace | Respuestas |
|---|---|---|---|
| GET | `/orders?status=&from=&page=&size=` | Pedidos con sus líneas, del más antiguo al más reciente | 200, 400, 503 |
| POST | `/orders` | Registra encabezado y líneas en una transacción; nace `RECEIVED` | 201, 400, 409 `ORDER_ALREADY_EXISTS`, 503 |
| GET | `/orders/{orderId}` | Pedido con sus líneas y SKU | 200, 404 `ORDER_NOT_FOUND`, 503 |
| PATCH | `/orders/{orderId}` | Confirma o rechaza un pedido `RECEIVED`; al confirmar guarda precios, último precio del proveedor y total | 200, 400, 404, 409 `INVALID_TRANSITION`, 503 |
| GET | `/inventory/items?ids=` o `?page=&size=` | Por lote (hasta 100, con proveedores y preferente) o por página | 200, 400, 503 |
| POST | `/inventory/movements` | Salida o reposición, una sola vez por `reference` (D7) | 201, 200 (ya registrado), 404 `ITEM_NOT_FOUND`, 409 `INSUFFICIENT_STOCK`, 503 |

Cualquier error responde con el `ErrorResponse` del contrato. Si Oracle no está disponible: 503 con `retryable: true`
y `Retry-After` (30 s, `error.retryAfterSeconds`).

## Credenciales de Oracle

Copia `src/main/resources/properties/local-secure-application-config.yaml.example` como
`local-secure-application-config.yaml` (ignorado por Git). Usa los mismos valores que `APP_USER` y
`APP_USER_PASSWORD` de `infra/oracle/credentials.local`, cifrados con la clave `POC_ENC_KEY`.

## Ejecutar en Studio

1. Importa la carpeta `apps/sapi-oracle-core` **sin** marcar "Copy project into workspace".
2. VM args: `-M-Denv=local -M-Dencryption.key=<POC_ENC_KEY> -M-Ddb.port=<puerto de poc-oracle>`.
   `-M-Denv=local` hace falta porque la variable de entorno `env` de Windows tiene prioridad sobre el valor por defecto.
3. Verificación en vivo: `infra/scripts/reset-data` y luego la carpeta `sapi-oracle-core` de
   `tests/postman/poc-apps.postman_collection.json` (11 peticiones). Al terminar, vuelve a correr `reset-data`, porque
   la colección mueve el stock.

## Compilar y probar

```
mvn -B -f apps/sapi-oracle-core/pom.xml clean package "-Dencryption.key=$POC_ENC_KEY"
```

27 pruebas MUnit (20 de flujos y 7 HTTP), con Oracle simulado. La suite HTTP necesita libre el puerto 8091. El SQL nuevo
se prueba además contra `poc-oracle` dentro de una transacción con ROLLBACK, porque MUnit lo simula.

## Notas de diseño

- Las fechas se leen como `TO_CHAR(SYS_EXTRACT_UTC(x),'YYYYMMDDHH24MISS')` y se publican en UTC (`...Z`).
- Los errores de Oracle se traducen a errores de negocio: ORA-00001 → ya existe, ORA-02291 → referencia inexistente,
  ORA-02290 (`CHK_INV_STOCK`) → stock insuficiente.
- El cambio de estado usa `UPDATE ... WHERE STATUS = 'RECEIVED'` para evitar carreras.
- Dos movimientos con la misma referencia al mismo tiempo: gana uno, el otro se deshace y devuelve el original.
