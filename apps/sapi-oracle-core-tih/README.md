# sapi-oracle-core-tih

System API sobre la base de datos core de la tienda (Oracle 26ai Free, servicio `FREEPDB1`, esquema `STORE_APP`).
Implementa el contrato `src/main/resources/api/sapi-oracle-core-tih.raml` (copia del RAML de `specs/`).

- Mule Runtime 4.11.4 (EE) y Java 17.
- Conectores: HTTP 1.12.1, APIkit 1.11.16, Database 1.15.1 y driver `ojdbc11` 23.8.0.25.04.
- Sin conexión a Anypoint Platform: no hay Autodiscovery ni política Client ID. **No se modifica el esquema de Oracle.**

## Recursos

Base: `http://localhost:8091/api/v1/core/store`

| Método | Recurso | Respuestas |
|---|---|---|
| POST | `/customers` | 201, 400, 409, 503 |
| GET | `/customers?email=&phone=` (al menos uno) | 200, 400, 503 |
| GET | `/customers/{customerId}` | 200, 404, 503 |
| GET | `/inventory/items?ids=id1,id2` | 200, 400, 503 |
| POST | `/orders` (una transacción local) | 201, 400, 404, 409, 503 |
| GET | `/orders/{orderId}` | 200, 404, 503 |

Todas las peticiones requieren los headers `client_id` y `client_secret` (están en el contrato). Localmente cualquier valor sirve; en un ambiente con API Manager los valida la política.

## Estructura (estándar MADO v1.1)

```
src/main/mule/
  interface.xml                  # listener, APIkit y flujos de interfaz (solo flow-ref)
  common/global.xml              # propiedades por ambiente, manejador global y conexión a Oracle
  handlers/global-error-handlers.xml    # traduce cualquier error al ErrorResponse del contrato
  handlers/db-connection-handlers.xml   # ORA-00001 -> 409, ORA-02291 -> 404/400
  implementations/*.xml          # un archivo por operación
src/main/resources/
  api/                           # RAML y fragments
  dataweave/mapping-*.dwl        # transformaciones
  properties/                    # dev-application-config.yaml y credenciales
src/test/munit/                  # 45 pruebas, cobertura 100 %
```

## Credenciales de Oracle

1. Abre `src/main/resources/properties/dev-secure-application-config.yaml`.
2. Reemplaza `CHANGE_ME` en `db.user` y `db.password` con tu usuario y contraseña.

Ese archivo está en `.gitignore`.
Los valores van cifrados con la skill `secure-mule-app`; la clave se pasa con la VM arg `-M-Dencryption.key`.

La URL (`jdbc:oracle:thin:@//localhost:1521/FREEPDB1`) está en `dev-application-config.yaml`.

## Compilar y probar (sin conexión)

Requiere Java 17 y Maven. Usa solo lo que ya está en tu caché local de Maven (`~/.m2`):

```
cd apps/sapi-oracle-core-tih
mvn -o -B clean package
```

- `-o` evita descargas.
- El `pom.xml` ya trae `<skipAST>true</skipAST>`: el plugin intentaba armar un árbol de la app con el runtime completo, lo que exige artefactos que no están en tu caché (por ejemplo `guava 33.2.1-jre`) y fallaba con `DependencyResolutionException`. No afecta el empaquetado: la app se valida al arrancar y con las pruebas MUnit.
- El `pom.xml` también declara el repositorio `anypoint-exchange-v3` (como los proyectos de Studio) porque los artefactos de `~/.m2` se descargaron con ese identificador. No se consume nada de Exchange.

Resultado esperado: 45 pruebas, 0 fallos, cobertura 100 % y `target/sapi-oracle-core-tih-1.0.0-SNAPSHOT-mule-application.jar`.

Las pruebas simulan Oracle con mocks: no se contacta ninguna base de datos. `sapi-oracle-core-tih-main-test.xml` levanta el listener real y llama a la API por HTTP.

## Ejecutar en Anypoint Studio

1. **File → Import → Anypoint Studio → Packaged mule application (.jar)** (o *Mule Project from File System* sobre esta carpeta).
2. Completa las credenciales (sección anterior).
3. **Run As → Mule Application**. El ambiente por defecto es `dev`.
4. Prueba, por ejemplo:

```
curl -H "client_id: x" -H "client_secret: y" http://localhost:8091/api/v1/core/store/customers/<uuid-de-un-cliente>
curl -H "client_id: x" -H "client_secret: y" "http://localhost:8091/api/v1/core/store/inventory/items?ids=<uuid1>,<uuid2>"
```

Las llamadas GET solo leen datos. Las POST (`/customers`, `/orders`) **insertan filas** en `CUSTOMERS` y `ORDERS`.

## Errores

Cualquier error responde con el `ErrorResponse` del contrato: `code`, `message`, `correlationId`, `timestamp` y `retryable`.
Si Oracle no está disponible: 503 con `retryable: true` y el header `Retry-After` (30 s, configurable en `error.retryAfterSeconds`).

## Notas de diseño

- Los conectores reemplazan los `attributes` del mensaje. Por eso los ids de la URL se guardan en variables antes de consultar Oracle.
- Oracle trata la cadena vacía como NULL: los campos opcionales ausentes se envían como `""` (evita `ORA-17004`).
- Las fechas se guardan en UTC y se leen con `TO_CHAR(...,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"')`.
- La consulta de inventario arma `IN (:id0, :id1, ...)` con parámetros nombrados; nunca concatena valores.
- Los pedidos se registran con `bulk-insert` dentro de una transacción local; no hay restricción de unicidad en `ORDERS`, así que el flujo comprueba antes que el `orderId` no exista.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
