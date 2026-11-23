# PoC «Integración en la era agéntica» v1 · Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:** dejar las cuatro escenas de la PoC corriendo de punta a punta en local y en CloudHub 2.0, con los contratos en Exchange y un repositorio que cualquiera pueda clonar y levantar.

**Arquitectura:** tres capas API-led con 10 apps Mule:
- Canales: xapi y MCP.
- Proceso: 4 Process APIs.
- Sistema: 4 System APIs.

Además hay una biblioteca de resiliencia y un fragmento RAML común.

Las dependencias corren en Docker en local: una Oracle con dos esquemas, RabbitMQ, SFTP con simulador de logística y WireMock. Para CloudHub se exponen con túneles.

Salesforce y MagicBell son servicios en la nube. El orden es "contrato primero", en tres oleadas.

**Tecnologías:**
- Mule 4.11.4 y Java 17, con APIkit, MUnit 3.7.1 y CloudHub 2.0.
- Conectores: Database (Oracle JDBC), SFTP, AMQP, Web Service Consumer, Salesforce y MCP.
- Dependencias locales: Oracle Database Free, RabbitMQ 3.13, atmoz/sftp y WireMock.
- Salesforce CLI (`sf`), ngrok y cloudflared.
- Postman y newman.

**Especificación:**
- `docs/superpowers/specs/2026-11-20-poc-agentica-design.md`: decisiones C1–C6 y D1–D17, desviaciones y preguntas P1–P7.
- `docs/final integracion-en-la-era-agentica-poc.html`: sección "Plan de trabajo"; la sección 4 trae las operaciones, reglas y aceptación de cada pieza y la 6 los datos del guion.

**Quién hace qué:** las tareas marcadas **[Maite]** son acciones que solo tú puedes hacer: crear cuentas, publicar en Exchange y desplegar. El resto lo implementa quien ejecute el plan.

## Restricciones globales

- **Versiones:** Mule `4.11.4`, Java 17, `mule-maven-plugin` 4.9.1 y MUnit 3.7.1. Los conectores de la base se conservan: HTTP 1.12.1, APIkit 1.11.16, AMQP 1.9.4, Secure Properties 1.3.2 y SFTP 2.7.1.
- **Versiones de los conectores nuevos** (Database, Salesforce, MCP): la última compatible con 4.11.4 que haya en Exchange al momento de construir. Anota la versión en el README de la app.
- **Cobertura MUnit:** al menos 80 % por app (`requiredApplicationCoverage` 80, como en la base).
- **Datos:**
  - Contratos completamente en inglés según D5: nombres de campos en camelCase, valores de enums, descripciones y `displayName`. Los datos del guion en los ejemplos (nombres de clientes, ciudades, motivos) se quedan como son.
  - Moneda ISO 4217; en la PoC siempre `MXN`.
  - Fechas ISO 8601 con zona horaria.
- **Identificadores:**
  - Pedidos, artículos y solicitudes usan UUID.
  - El cliente usa el Id de Salesforce de 18 caracteres.
- **Errores:** todas las APIs aceptan y propagan `x-correlation-id`. Responden con `ErrorResponse {code, message, correlationId, timestamp, retryable}`, y los `503` llevan `Retry-After`.
- **Tiempos (sección 4, biblioteca de resiliencia):**
  - Tiempo límite de 2 s por proveedor y de 3 s para el SFTP y Salesforce.
  - Un solo reintento, solo en lecturas y solo ante fallas de conexión (D9).
  - El interruptor abre tras 3 fallas seguidas, espera 30 s y prueba con una llamada.
  - El Pedido 360 responde en menos de 3 s y `POST /orders` en menos de 1 s.
- **Scheduler:** el de confirmación corre cada 60 s y sus ciclos no se traslapan.
- **Solicitudes:** vencen a las 24 h; el plazo se configura en propiedades.
- **Contratos:** ninguna app guarda copia de su contrato. APIkit lo toma de Exchange: `api="resource::<orgId>:<asset>:<ver>:raml:zip:<asset>.raml"`.
- **orgId (D19):** literal `9885f017-0660-4c80-a27f-eb006d124bd8` en el `<groupId>` de cada pom, en la dependencia del contrato y en el `api` de APIkit (`resource::<orgId>:<asset>:<versión>:raml:zip:<asset>.raml`). Sin propiedad ni filtrado.
- **Implementación en inglés (D5b):** `doc:name`, flujos, variables, `doc:description`, comentarios, logs y mensajes de error en inglés; datos del guion en español.
- **`baseUri` de los contratos:** solo HTTPS, como si la API estuviera desplegada en CloudHub 2.0: `https://{host}/api/{version}/<ruta>`, `baseUriParameters.host` con el endpoint público de CloudHub y `protocols: [HTTPS]`. Ningún contrato menciona `localhost` (ajuste de Maite, 20-nov). En local las apps escuchan en HTTP con la misma ruta.
- **Librería común:** `specs/fragments/poc-common/poc-common.raml` es la única librería del fragmento (main en Exchange): declara cada tipo (`types/<sección>/<Tipo>.raml`, fragmentos `DataType`) y cada trait (`traits/<trait>.raml`, fragmentos `Trait`) con `!include`. Las APIs usan `uses: common: …/poc-common.raml` y referencian `common.<Tipo>` y `common.<trait>` (ajuste de Maite, 20-nov).
- **Llamadas HTTP salientes:** toda `http:request-config` toma `protocol`, `host`, `port` y `basePath` de propiedades. En la nube cambian a HTTPS/443 y a los hosts de los túneles o de CloudHub.
- **Ambientes:** `local` (por defecto) y `cloud`. Las propiedades viven en `properties/${env}-application-config.yaml`. Los secretos van en `${env}-secure-application-config.yaml`, cifrados con AES/CBC, y la llave se pasa con `-M-Dencryption.key`.
- **Repositorio sin secretos:** ni `.env`, ni `credentials.local`, ni `*-secure-application-config.yaml`, ni `.jks`, ni IDs de la org.
- **Prohibido tocar** los contenedores `oracle-store` y `ngrok-oracle`.
- **Commits:**
  - Sin `Co-Authored-By` ni mención de Claude.
  - **Ningún commit durante las tareas** (decisión de Maite, 20-nov). Todo se trabaja sin commit en `poc/agentica-v1` hasta validar la implementación en local (tarea 25) y en CloudHub (tarea 28).
  - Al final, **una rama por pieza** (`feat/<pieza>`, sección 3 de la final), que se integra a `main` en orden de dependencias (tarea 30). Maite aprueba antes de crear las ramas y antes de cada integración.
  - Como no hay commits intermedios, al cerrar cada fase se sugiere a Maite un respaldo zip del repositorio fuera del repo (lo hace ella).
  - El push lo hace Maite.
- **Contrato primero:** un cambio de comportamiento empieza en `specs/` y `data/`, y después va el código.
- **Compilar una app:** `mvn -B -f apps/<app>/pom.xml clean test "-Dencryption.key=$env:POC_ENC_KEY"`.
  - La primera vez que una app depende de Exchange, se compila con conexión. Necesita `~/.m2/settings.xml` con el server `anypoint-exchange-v3`, que ya existe y usa `ANYPOINT_CLIENT_ID` y `ANYPOINT_CLIENT_SECRET`.
  - Si Studio tiene ocupado el puerto de la app, la suite `*-main-test.xml` falla: detén primero la app en Studio.

## Focos de revisión

1. **Dos fallas a la vez.** Con el SFTP apagado y el proveedor C lento al mismo tiempo, el Pedido 360 debe llegar en menos de 3 s, con `dispatchNote.status = UNKNOWN` y `sources.providers = "2 of 3"`. La prueba está en la tarea 18.
2. **CRM caído.** Si Salesforce está caído o llegó a su límite diario, `sapi-crm` responde 503 `retryable` en menos de 3 s. El Pedido 360 no falla: devuelve 200 con `sources.crm = UNAVAILABLE`. Las pruebas están en las tareas 14 y 18.
3. **Aprobar dos veces, o aprobar una solicitud vencida o rechazada.** Responde 409 y el stock no se mueve. La prueba está en la tarea 20.
4. **Corrección repetida o simultánea.** El stock se mueve una sola vez, y una salida mayor al stock responde 409 sin cambiar nada. Las pruebas están en las tareas 11 y 19.
5. **Túneles que cambian de dirección.** Con un host viejo, las apps en la nube responden 503 `retryable`, no 500. El script `cloud-endpoints` muestra los valores nuevos. La prueba está en la tarea 26.

---

## Fase 0 · Repositorio

### Tarea 1: Rama, estructura y nombres sin `-tih`

**Archivos:**
- Mover: `apps/<app>-tih/` → `apps/<app>/` para las 7 apps, con `git mv`.
- Modificar en cada app:
  - `pom.xml`: `artifactId`, `name` y `description`.
  - `mule-artifact.json`.
  - `src/main/mule/**/*.xml`: los nombres de configuración que llevan `-tih`.
  - `src/test/munit/*` y `README.md`.
- Crear: `libs/`, `data/`, `demo/`, `tests/` y `tests/postman/`, cada una con un `README.md` de una línea.
- Modificar: `.gitignore` en la raíz.
- Borrar en la rama, porque prueban contratos que se retiran (siguen en `main` y en el respaldo):
  - `postman/tih-all-apis.postman_collection.json`;
  - `apps/*/bat-generated/`;
  - `apps/sapi-price-providers-tih/borland-mock/`, porque la final retira SoapUI.

**Produce:**
- Nombres de app: `xapi-online-store`, `papi-customers`, `papi-orders`, `papi-notifications`, `sapi-oracle-core`, `sapi-sftp-orders` y `sapi-price-providers`.
- `groupId` provisional `com.sps.poc`. En la tarea 4 se cambia al `orgId`.

- [x] **Paso 1:** crear la rama `git switch -c poc/agentica-v1` desde `main` (`6f220ee`). Revisar que `git status` no tenga cambios sin commit. El `.gitignore` modificado se incluye en este commit.
- [x] **Paso 2:** agregar a `.gitignore` estas entradas:
  - `/*-tih/` y `/sapi-stores/` (D3).
  - `**/bat-generated/reports/` y `mvn-last.log`.
  - `/infra/tunnels/*.local.yml`.
  - `/data/*.local.json`.
  - `/infra/salesforce/certs/` y `*.jks`.
  - `/tmp/`.
  - `**/exchange_modules/`.

  Conservar las entradas actuales.
- [x] **Paso 3:** hacer el renombre y los reemplazos de texto `-tih` → sin sufijo en los archivos listados. `grep -r -- "-tih" apps tests` solo debe encontrar historia en los README.
- [x] **Paso 4:** compilar las 7 apps con el comando global. Esperado: `BUILD SUCCESS` en las 7, con la misma cantidad de pruebas MUnit que antes del renombre.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `chore: estructura de la PoC y nombres sin sufijo -tih` se usa en la tarea 30, en `feat/repository`.

---

## Fase 1 · Contratos (oleada 1)

### Tarea 2: Fragmento común y herramientas de contratos

**Archivos:**
- Crear: `specs/fragments/poc-common/types.raml` y `specs/fragments/poc-common/traits.raml`. Parten de `tih-common-*`; las versiones viejas se borran.
  - Ajuste de Maite (20-nov): `types.raml` y `traits.raml` se reemplazaron por una sola librería `poc-common.raml` que declara cada tipo y cada trait con `!include` (ver restricciones globales).
- Modificar: `specs/tools/validate.js` (acepta `exchange_modules` locales) y `specs/tools/package.json`, con los scripts `validate` y `package`.
- Crear: `specs/tools/package-exchange.mjs`.

**Interfaces:**
- Tipos de `types.raml`, sección 4 · Fragmento común:
  - Se conservan: `ErrorResponse` y sus códigos.
  - Cambian: `Customer` (`id` es el Id de Salesforce, con `segment` `STRATEGIC|REGULAR` y `address.city`) y `Order` (`status` `RECEIVED|CONFIRMED|REJECTED`, `currency` y `lines`).
  - Nuevos: `Order360`, `OrderException` (`STOCK_SHORTAGE|UNCONFIRMED|DISPATCH_REJECTED`), `Quote`, `DispatchNote` (`status` `PENDING|SIGNED|REJECTED|ON_HOLD|UNKNOWN`), `OrderRequest` (`type` `RESTOCK|REISSUE` y `status` `PENDING|APPROVED|APPLYING|COMPLETED|FAILED|REJECTED|EXPIRED`), `InventoryItem` y `Sources` (`erp|crm|logistics: OK|UNAVAILABLE` y `providers: "n of m"`).
- `traits.raml` conserva `secured`, `validated` y `retryable`.
- `node package-exchange.mjs --group <orgId> --version 1.0.0 [--only <asset>]` deja, por cada asset, `tmp/exchange/<asset>-<ver>.zip` con:
  - el RAML principal, con `uses` reescrito a `exchange_modules/<orgId>/poc-common/<ver>/…`;
  - un `exchange.json` con `main`, `name`, `groupId`, `assetId`, `version`, `classifier` (`raml` o `raml-fragment`) y `dependencies: [poc-common]`.

- [x] **Paso 1:** escribir los tipos. Cada tipo nuevo lleva un `example` sacado de los datos del guion (PED-1002 con su UUID de `data/`; si `data/` aún no existe, un UUID fijo que la tarea 6 reutiliza).
- [x] **Paso 2:** `npm --prefix specs/tools run validate`. Esperado: `0 errores` en el fragmento.
- [x] **Paso 3:** escribir `package-exchange.mjs` y correrlo con `--group 00000000-0000-0000-0000-000000000000 --only poc-common`. Esperado: el zip contiene `types.raml`, `traits.raml` y un `exchange.json` con `classifier: raml-fragment`.
- [ ] **Paso 4:** sin commit por ahora. El mensaje `feat(specs): fragmento común poc-common y empaquetado para Exchange` se usa en la tarea 30, en `feat/common-fragment`.

### Tarea 3: Contratos de las 4 System APIs

**Archivos:** crear o reescribir:
- `specs/sapi-oracle-core/sapi-oracle-core.raml`
- `specs/sapi-price-providers/sapi-price-providers.raml`
- `specs/sapi-sftp-orders/sapi-sftp-orders.raml`
- `specs/sapi-crm/sapi-crm.raml`

Borrar los `*-tih` correspondientes.

**Interfaces** (operaciones exactas de la sección 4 de la final):

| API | Operaciones |
|---|---|
| sapi-oracle-core | `GET /orders/{orderId}` · `POST /orders` (nace RECEIVED) · `GET /orders?status=&from=` · `PATCH /orders/{orderId}` · `GET /inventory/items?page=&size=` · `GET /inventory/items?ids=` (hasta 100, con `providers`) · `POST /inventory/movements` |
| sapi-price-providers | `GET /providers/{abv}/products/{externalId}/price` · `POST /quotes` → `{quotes[], noResponse[]}` |
| sapi-sftp-orders | `POST /dispatch-notes` · `GET /dispatch-notes/{orderId}` · `GET /dispatch-notes?status=` |
| sapi-crm | `GET /contacts?page=&size=` · `GET /contacts/{id}` · `GET /contacts?ids=` (hasta 50) · `GET /contacts?email=\|phone=` · `POST /contacts` |

Detalles de los contratos:
- `PATCH /orders/{orderId}` recibe `{status, lines[{itemId, unitPrice, priceSource, provider}]}`. Al confirmar, sapi-oracle-core guarda `lastPrice` en el proveedor usado.
- `POST /inventory/movements` recibe `{itemId, type: OUTBOUND|RESTOCK, quantity, reference, orderId}`. Responde 409 si la salida deja el stock en negativo, y 200 con el movimiento existente si la `reference` se repite (D7).

- [x] **Paso 1:** escribir los 4 RAML con sus ejemplos y los traits `secured` y `validated`, y `retryable` en los 503.
- [x] **Paso 2:** `npm --prefix specs/tools run validate`. Esperado: 0 errores.
- [x] **Paso 3:** validar contra el ruleset `infra/governance/tih-raml-conventions.yaml`, con el comando de la memoria del proyecto, en una sola API (tarda unos 4 minutos). Corregir y aplicar las mismas correcciones a las otras tres.
- [ ] **Paso 4:** sin commit por ahora. El mensaje `feat(specs): contratos de las System APIs (oleada 1)` se usa en la tarea 30, en la rama de cada System API (`feat/sapi-oracle-core`, `feat/sapi-crm`, `feat/sapi-sftp-orders` y `feat/sapi-price-providers`): cada contrato va con su pieza.

### Tarea 4: [Maite] Org trial, revisión y publicación de la oleada 1

- [x] **Paso 1 (Maite):** crear la org trial de Anypoint. Anotar el `orgId` (es el `groupId` de Exchange) en `data/org.local.json`, que no se versiona, y en `.mvn/maven.config` (D19; el perfil `poc-org` de `~/.m2/settings.xml` resultó insuficiente para el `mule-maven-plugin`).
- [x] **Paso 2 (Maite):** crear una Connected App con permisos de Exchange Contributor, Runtime Manager y API Manager, y poner sus valores en `ANYPOINT_CLIENT_ID`, `ANYPOINT_CLIENT_SECRET` y `ANYPOINT_ORG`. Esto se hace con `! anypoint-cli-v4 conf ...` y nunca por el chat.
- [x] **Paso 3 (Maite):** en Runtime Manager, revisar cuántos vCores de CloudHub 2.0 trae la org (P6). Se necesita al menos 1 vCore. Resultado (20-nov): 1 vCore de Sandbox, justo lo que piden 10 apps de 0.1.
- [x] **Paso 4 (Maite):** revisar los RAML de las tareas 2 y 3. D5 resuelto por Maite el 20-nov: los contratos van completamente en inglés (P2 cerrada).
- [x] **Paso 5:** cambiar el `groupId` de las 7 apps del provisional `com.sps.poc` al orgId literal `9885f017-0660-4c80-a27f-eb006d124bd8` (D19, ajustado el 21-nov). Esperado: `mvn -B -f apps/<app>/pom.xml help:evaluate -Dexpression=project.groupId -q -DforceStdout` imprime el `orgId` real en las 7, y las 7 siguen compilando (aún no dependen de Exchange).
- [x] **Paso 6:** correr `node specs/tools/package-exchange.mjs --group <orgId> --version 1.0.0`. Ajuste (20-nov): la 1.0.0 ya existía en Exchange. **Versiones publicadas (verificadas en Exchange con la CLI):** `poc-common` **1.0.2** y las 4 System APIs **1.0.1**, cada una con dependencia de `poc-common` 1.0.2 y `uses` a `exchange_modules/<orgId>/poc-common/1.0.2/poc-common.raml`. Para volver a empaquetar: `--version <x.y.z> --common-version 1.0.2`. Las apps de las tareas 11 a 14 toman su contrato en la versión 1.0.1.
- [x] **Paso 7 (Maite):** publicar en Exchange, primero `poc-common` y después las 4 System APIs. Puede ser desde la UI de Exchange (Publish new asset → RAML) o con `anypoint-cli-v4 exchange:asset:upload` (revisar `--help` antes). Verificar en Exchange que cada API muestra `poc-common` como dependencia y que la consola de la API se ve bien.
  - Si Exchange no resuelve la dependencia, hay plan B: `package-exchange.mjs --bundle` mete el fragmento dentro de cada zip y la dependencia se pierde. Anotarlo en el diseño.

---

## Fase 2 · Diagramas

### Tarea 5: Diagramas de secuencia y C4

**Archivos** en `docs/diagrams/` (ajuste de Maite, 20-nov: secuencias en Mermaid con la skill `generador-diagramas-de-flujo`, C4 en HTML con la skill `archify`; sin SVG):
- Secuencia, uno por recorrido de II.2, en Mermaid:
  - `seq-1-vida-del-pedido.mmd`
  - `seq-2-pedido-360.mmd` (escenas 1 y 2)
  - `seq-3-fallas.mmd` (escena 3)
  - `seq-4-correccion.mmd` (escena 4)
  - `secuencias.md`: los cuatro en bloques `mermaid`, cada uno con sus puntos clave (se ve en GitHub y VS Code).
  - `secuencias.html`: la misma página en HTML; Mermaid 11.4.1 desde jsDelivr dibuja los cuatro en el navegador (requiere internet).
- C4 en HTML (archify), con su fuente `*.archify.json`:
  - `c4-1-contexto.html`
  - `c4-2-contenedores.html`
  - `c4-3-componentes-papi-orders.html`

Borrar del repositorio `sequence-tih-completo.*` y `flujo-negocio-*.html`, que quedaron desactualizados.

- [x] **Paso 1:** escribir los `.mmd` de secuencia y `secuencias.md`. Los nombres de participantes, operaciones y eventos son los de los contratos de la tarea 3 y de la sección 4 de la final (las Process APIs, la xapi y el MCP se vuelven a revisar en las tareas 15 y 22).
- [x] **Paso 2:** generar los C4 con `archify finalize architecture`. Resultado: `validate`, `deliver` y `check` estricto pasan en los 3. La revisión en navegador (`browser-check`) no corre en esta máquina: Edge no termina y deja un perfil temporal (se borró); queda sin revisión visual automática.
- [x] **Paso 3:** revisar que cada operación de las System APIs mencionada en los diagramas exista en `specs/`. Resultado: las 13 operaciones existen; eventos y herramientas MCP coinciden con el plan.
- [ ] **Paso 4:** sin commit por ahora. El mensaje `docs: diagramas de secuencia y C4 de la PoC` se usa en la tarea 30, en `feat/diagrams`.

---

## Fase 3 · Datos y dependencias locales

### Tarea 6: Datos del guion y Oracle con dos esquemas

**Archivos:**
- Crear: `data/scenario.json`, la única fuente de los datos del guion.
- Crear: `data/tools/build-seeds.mjs`.
- Crear: `infra/oracle/sql/erp/01-schema.sql` y `infra/oracle/sql/integration/01-schema.sql`.
- Crear: `infra/oracle/init/01-create-users.sh`, que reemplaza a `01-create-app-user.sh`.
- Generar: `infra/oracle/sql/erp/20-seed.generated.sql`.
- Borrar: los SQL viejos.
- Ajustes de ejecución (20-nov): el compose `poc-infra` con solo `poc-oracle` se escribe aquí (la tarea 8 agrega el resto), puerto **1523** (1521 es de `oracle-store` y 1522 de `tih-oracle`); valores de estado en la base en inglés como los contratos; `INVENTORY` agrega `SKU` y `CURRENCY`, `ORDER_ITEMS` agrega `PRICE_PROVIDER` y `ORDERS` agrega `STATUS_REASON` y `UPDATED_AT` (los piden los contratos); la semilla, las remisiones semilla y `data/logistics-rules.json` son generados y no se versionan; `verify-schema` se conecta dentro del contenedor con sus variables, sin leer claves.

**Interfaces:**
- `scenario.json` contiene, con los valores de la sección 6 de la final y D15:
  - **Clientes:** `clientes[{externalId, nombre, segmento, ciudad, correo, telefono}]`. Son 4: Constructora Cumbres (STRATEGIC, Monterrey), Grupo Hotelero Tapatío (STRATEGIC, Guadalajara), Ferretería Angelópolis (REGULAR, Puebla) y Papelería Coyoacán (REGULAR, Ciudad de México).
  - **Productos:** `productos[{clave, id, nombre, stock, precioLocal, proveedores[{abv, externalId, preferente, ultimoPrecio, precio, responde}]}]`.

    | Producto | Stock | Precio | Proveedores |
    |---|---|---|---|
    | SKU-100 | 2 | precioLocal 0; preferente FAK, último precio 189.00 | A 189.00, B 194.00, C 175.00 |
    | SKU-200 | 40 | precioLocal 250.00 | A 231.00, B 228.00, C 236.00 |
    | SKU-300 | 15 | sin precio | preferente BOR, `responde: false` |

  - **Pedidos:** `pedidos[{clave, id, cliente, estado, creado, lineas[{producto, cantidad}], remision?}]`. La fecha `creado` va en orden 1001 < 1002 < 1003 < 1004 < 1005.

    | Pedido | Estado | Cliente | Línea | Remisión |
    |---|---|---|---|---|
    | PED-1001 | RECEIVED | Angelópolis | SKU-300 × 2 | — |
    | PED-1002 | CONFIRMED | Cumbres | SKU-100 × 5 | — |
    | PED-1003 | CONFIRMED | Cumbres | SKU-200 × 3 | n=1, SIGNED |
    | PED-1004 | CONFIRMED | Tapatío | SKU-200 × 1 | n=1, REJECTED, "Dirección incorrecta" |
    | PED-1005 | CONFIRMED | Coyoacán | SKU-100 × 4 | — |

- **Separación de esquemas (confirmada por Maite):**
  - `STORE_APP` (ERP) tiene solo `ORDERS`, `ORDER_ITEMS`, `INVENTORY`, `INVENTORY_PROVIDERS` e `INVENTORY_MOVEMENTS`. No hay `CUSTOMERS` (los clientes viven en Salesforce) ni tablas de remisiones (viven en el SFTP).
  - `INTEGRATION_APP` tiene solo `ORDER_REQUESTS` y `ORDER_REQUEST_EVENTS`.
  - Ningún usuario tiene permisos sobre el esquema del otro. sapi-oracle-core se conecta solo como `STORE_APP` y papi-order-requests solo como `INTEGRATION_APP`.
  - Desviación anotada en el diseño: la PoC pide una instancia Oracle separada para la integración; aquí es otro esquema en la misma instancia.
- **Esquema `STORE_APP`:**
  - `ORDERS`: `ID`, `CUSTOMER_ID VARCHAR2(18)`, `STATUS` con CHECK, `CURRENCY` (default `MXN`), `TOTAL`, `CREATED_AT` y `CONFIRMED_AT`.
  - `ORDER_ITEMS`: `ORDER_ID`, `ITEM_ID`, `QTY > 0`, `UNIT_PRICE` y `PRICE_SOURCE`; PK `(ORDER_ID, ITEM_ID)`.
  - `INVENTORY`: `ID`, `NAME`, `STOCK_QTY >= 0` y `LOCAL_PRICE >= 0`.
  - `INVENTORY_PROVIDERS`: `ITEM_ID`, `PROVIDER_ABV` (`FAK|ESC|BOR`), `EXTERNAL_ID`, `IS_PREFERRED`, `LAST_PRICE` y `LAST_PRICE_AT`; PK `(ITEM_ID, PROVIDER_ABV)`. Un índice único `CASE WHEN IS_PREFERRED=1 THEN ITEM_ID END` asegura un solo preferente por producto.
  - `INVENTORY_MOVEMENTS`: `ID`, `ITEM_ID`, `TYPE`, `QTY`, `REFERENCE UNIQUE`, `ORDER_ID` y `CREATED_AT`.
- **Esquema `INTEGRATION_APP`:**
  - `ORDER_REQUESTS`: `ID`, `IDEMPOTENCY_KEY UNIQUE`, `ORDER_ID`, `TYPE`, `PROVIDER_ABV`, `QTY`, `AMOUNT`, `STATUS`, `REQUESTED_BY`, `DECIDED_BY`, `REASON`, `EXPIRES_AT`, `CREATED_AT` y `UPDATED_AT`.
  - `ORDER_REQUEST_EVENTS`: `ID`, `REQUEST_ID` (FK), `FROM_STATUS`, `TO_STATUS`, `ACTOR`, `AT` y `DETAIL`.
- `node data/tools/build-seeds.mjs` lee `data/scenario.json` y `data/salesforce-ids.local.json` (de la tarea 9). Genera la semilla del ERP, las remisiones iniciales del SFTP en `infra/sftp/seed/` y `data/logistics-rules.json`, con PED-1004 → "Dirección incorrecta". Si todavía no existe el archivo de Ids de Salesforce, usa Ids marcadores `003000000000000AAA`… y lo avisa.

- [x] **Paso 1:** escribir `scenario.json` con UUID fijos.
- [x] **Paso 2:** escribir los dos esquemas y `01-create-users.sh`. El script crea `STORE_APP` e `INTEGRATION_APP` en FREEPDB1 con las claves de `infra/oracle/credentials.local` (`APP_USER_PASSWORD` e `INT_USER_PASSWORD`; agregar este último al `.example`) y es idempotente, como el actual.
- [x] **Paso 3:** escribir `infra/oracle/verify-schema.sql` (reemplaza al actual) con estas consultas:
  - el conteo de filas por tabla;
  - un intento de dejar el stock en negativo (debe fallar con ORA-02290);
  - un segundo preferente para SKU-100 (debe fallar con ORA-00001);
  - una `REFERENCE` repetida (debe fallar con ORA-00001);
  - como `STORE_APP`, leer `INTEGRATION_APP.ORDER_REQUESTS` (debe fallar con ORA-00942), y al revés;
  - la lista de tablas de cada esquema (debe ser exactamente la de arriba).
- [x] **Paso 4:** levantar `poc-oracle` (tarea 8, perfil `erp`), cargar la semilla y correr `verify-schema`. Esperado:
  - Resultado (20-nov): `poc-oracle` healthy en ~120 s, los dos esquemas creados al primer arranque; `verify-schema`: STORE_APP 11 OK y INTEGRATION_APP 3 OK, 0 fallos. Hallazgo: Oracle 23ai rechaza un comentario después de `;` en la misma línea (ORA-03405); `build-seeds.mjs` los pone en su propia línea. En la máquina de Maite el puerto es 1522 (su `infra/.env`).
  - 5 pedidos, 5 líneas, 3 productos y 7 filas de proveedores;
  - las tres violaciones fallan con el código esperado;
  - ningún esquema ve las tablas del otro, y `STORE_APP` no tiene `CUSTOMERS`.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(infra): datos del guion y Oracle con esquemas ERP e integración` se usa en la tarea 30, en `feat/local-infra`.

### Tarea 7: Proveedores simulados con WireMock

**Archivos:**
- Crear: `infra/wiremock/mappings/proveedor-a.json`, `proveedor-b.json` y `proveedor-c.json`, generados por `build-seeds.mjs` desde `scenario.json`.
- Crear: `infra/wiremock/__files/` y `infra/wiremock/README.md`.
- C responde además `<Currency>MXN</Currency>` dentro de `GetArticleByIdResult` (la final pide la moneda en la respuesta del proveedor); la tarea 12 agrega ese elemento opcional al WSDL de sapi-price-providers.

**Produce:** un solo WireMock en `localhost:8089` (`poc-wiremock`):
- **A, estilo Fakestore:** `GET /proveedor-a/products/{id}` → `{id, title, price, currency}`.
- **B, estilo Escuelajs:** `GET /proveedor-b/api/v1/products/{id}` → `{id, title, price, currency, category{}}`. Es un formato distinto al de A.
- **C, SOAP:** `POST /proveedor-c/OrderService` con `GetArticleById` → `GetArticleByIdResponse` con `price` y `currency`. Usa el WSDL que ya está en sapi-price-providers.
- **SKU-300 en C:** el externalId 5 responde con `fault: CONNECTION_RESET_BY_PEER`.

- [x] **Paso 1:** generar los mappings con `build-seeds.mjs`.
- [x] **Paso 2:** probar con `curl` cada proveedor para SKU-100. Esperado: A 189.00, B 194.00 y C 175.00, todos con `MXN`. Para C, externalId 5, se espera que la conexión se corte.
  - Resultado (20-nov): A 189, B 194 y C 175.00, todos en MXN; SKU-200 A 231 y B 228; C con ArticleId 5 corta la conexión (curl exit 52, sin respuesta). Id desconocido: A 200 sin cuerpo, B 400 `EntityNotFound` y C sin `GetArticleByIdResult`, igual que los proveedores reales. Imagen fija `wiremock/wiremock:3.9.1`; los mappings se generan y no se versionan.
- [ ] **Paso 3:** sin commit por ahora. El mensaje `feat(infra): simuladores de proveedores A, B y C en WireMock` se usa en la tarea 30, en `feat/local-infra`.

### Tarea 8: SFTP, logística, RabbitMQ, compose y scripts de operación

**Archivos:**
- Reescribir: `infra/docker-compose.yml`.
  - Proyecto `poc-infra`, con los servicios `poc-oracle`, `poc-rabbitmq`, `poc-sftp`, `poc-logistics-sim` y `poc-wiremock`.
  - Perfiles: `erp` (Oracle), `integracion` (Oracle y RabbitMQ), `logistica` (SFTP y simulador), `proveedores` (WireMock) y `local` (todo).
  - Puertos desde `.env`.
- Crear: `infra/sftp/docker/create-dispatch-dirs.sh` (crea `/despachos/pendientes`, `firmadas` y `rechazadas`) y `infra/sftp/keys/README.md`. La llave se genera al levantar y queda en `.gitignore`.
- Crear: `demo/logistics-sim/sim.sh` (D12).
- Modificar: `infra/rabbitmq/definitions.json`.
  - Se conservan el exchange `orders.events`, el DLX `orders.events.dlx`, `orders.registered.q` y `orders.registered.dlq`.
  - Se agregan `approval.requested.q` y `correction.applied.q`, cada uno con su DLQ.
- Reescribir: `infra/scripts/start-infra.ps1` y `.sh`.
  - Esperan de verdad a RabbitMQ, reintentando `rabbitmqctl list_users` hasta que responda. Así se corrige la carrera del 20 de noviembre.
  - Generan la llave SFTP si falta.
- Crear: `infra/scripts/reset-data.ps1` y `.sh`.
  - Vacían y vuelven a sembrar los dos esquemas.
  - Limpian `/despachos` y copian las remisiones semilla.
  - Quitan los retardos de WireMock y purgan las colas.
- Crear: `demo/control.ps1` y `demo/control.sh` (D13).
- Borrar: `infra/scripts/load-inventory.*` y lo de Rebex.

- Ajustes de ejecución (20-nov):
  - Puertos por defecto que no chocan con la base: RabbitMQ 5673/15673, SFTP 2223 (Oracle 1523 y WireMock 8089 de las tareas 6 y 7).
  - SFTP solo con llave desde esta tarea (D21): RSA 4096 en PEM, generada por `start-infra` con `ssh-keygen` dentro de la imagen `atmoz/sftp`; sin `sftp/credentials.local`.
  - El retardo de C lo cambia `demo/wiremock-delay.mjs` (lo usan `control.ps1` y `control.sh`); `reset-data` lo quita recargando los mappings.
  - Scripts bash con `MSYS_NO_PATHCONV=1` y rutas relativas desde el repo, para que funcionen igual en Git Bash; `.ps1` con BOM y sin comillas dobles en argumentos de `docker` (Windows PowerShell 5.1).
  - Resultado: `start-infra` y `reset-data` probados en `.ps1` y `.sh`; remisión por SFTP con llave firmada o rechazada en ≤ 10 s con su acuse; sin llave se rechaza la conexión; `slow-c` 5.03 s solo en C, `normal-c` 0.05 s, `sftp-down` cierra el 2223 y `sftp-up` lo abre; `verify-schema` 0 fallos tras `reset`.
  - Pendiente opcional: probar en bash la generación de la llave desde cero (en PowerShell ya se generó la llave real).

- [x] **Paso 1:** escribir el compose y los scripts. Los nombres de contenedor llevan el prefijo `poc-`. Las contraseñas salen de `credentials.local`; los `.example` traen valores de ejemplo que solo sirven en local (la tarea 26 los reemplaza para la nube). El script avisa si están corriendo `tih-oracle` o `tih-rabbitmq` y no toca `oracle-store`.
- [x] **Paso 2:** correr `start-infra` y luego `reset-data`. Esperado:
  - los 5 contenedores quedan `healthy` (o `running`, para el simulador);
  - las colas existen;
  - `/despachos/firmadas` tiene `remision_<PED-1003>_1.csv`, y `/despachos/rechazadas` tiene `remision_<PED-1004>_1.csv` con su acuse.
- [x] **Paso 3:** depositar a mano `remision_<uuid>_1.csv` en `pendientes`. Esperado: en 10 s o menos pasa a `firmadas`, con un `*.acuse.json` que trae `{recibio, fecha}`.
- [x] **Paso 4:** probar `demo/control slow-c` (C tarda 5 s en responder), `normal-c`, `sftp-down` (el puerto 2222 rechaza la conexión), `sftp-up` y `reset`. Esperado: cada acción hace lo que su nombre dice, verificado con `curl` o con `Test-NetConnection`.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(infra): compose con perfiles, logística simulada, control de demostración y reinicio de datos` se usa en la tarea 30, en `feat/local-infra`.

### Tarea 9: Salesforce y MagicBell

**Archivos:**
- Crear: `infra/salesforce/sfdx-project.json` y `infra/salesforce/force-app/main/default/`.
  - En Contact: los campos `Segmento__c` (picklist `Estratégico` / `Regular`) y `External_Id__c` (External ID, único).
  - El permission set `POC_Integracion`.
  - La matching rule `Contact.POC_Email_Exacto` (Email, coincidencia exacta, activa) y la duplicate rule `Contact.POC_Bloquear_Correo_Duplicado` (acción **Block** al crear y al editar, para todos los usuarios, incluida la API) (D22).
- Crear: `infra/salesforce/seed-contacts.mjs`. Hace upsert de los 4 clientes de `scenario.json` por `External_Id__c` y escribe `data/salesforce-ids.local.json`.
- Crear: `infra/salesforce/README.md`, con la guía para crear la aplicación conectada con JWT y el certificado.
- Crear: `infra/magicbell/README.md`.
- Crear: `infra/salesforce/destructive/` con `package.xml` vacío y `destructiveChangesPost.xml` (la duplicate rule, la matching rule, los campos `Contact.Segmento__c` y `Contact.External_Id__c`, y el permission set `POC_Integracion`). Antes de borrar la matching rule hay que desactivarla: `teardown` despliega primero `destructive/deactivate/` con la regla en `Inactive`.
- Crear: `infra/scripts/teardown.ps1` y `.sh`: el retiro programático del entorno (la PoC pide "levantamiento y retiro programáticos"). Cada paso se puede saltar con una opción:
  1. Apaga los túneles si están corriendo (`ngrok`, `cloudflared`).
  2. `docker compose -p poc-infra down -v --remove-orphans`: baja los contenedores `poc-*` y borra sus volúmenes. No toca `oracle-store`, `ngrok-oracle` ni los `tih-*`.
  3. Borra lo generado: las llaves SFTP generadas, `infra/oracle/sql/erp/20-seed.generated.sql`, `infra/sftp/seed/`, `data/salesforce-ids.local.json` y `tmp/`.
  4. Salesforce (`-o poc`): borra los contactos cuyo `External_Id__c` empieza con `POC-` y luego `sf project deploy start --manifest destructive/package.xml --post-destructive-changes destructive/destructiveChangesPost.xml`.
  5. Lista lo que no se puede borrar por script: la aplicación conectada de Salesforce, la cuenta de MagicBell y lo publicado en Anypoint.
  - Pide confirmación antes de borrar, salvo con `-Force`.

- Preparado (20-nov), pendiente de probar contra la org: `infra/salesforce/` (sfdx-project con `force-app` y `destructive/deactivate`, los dos campos, `POC_Integracion`, la matching rule y la duplicate rule), `sf-session.mjs` (toma la sesión de `sf` sin imprimir el token), `seed-contacts.mjs` (upsert por REST; sin estado ni país para no chocar con las listas de estados y países), `teardown-salesforce.mjs`, `infra/scripts/teardown.ps1/.sh`, `infra/salesforce/README.md` (guía de la aplicación conectada con JWT y el certificado con `keytool`) e `infra/magicbell/README.md`. Sintaxis revisada (`node --check`, `bash -n`, parser de PowerShell, XML bien formado).

- [x] **Paso 1 (Maite):** crear la org de Salesforce Developer Edition e instalar `sf` (Salesforce CLI). Iniciar sesión con `! sf org login web --alias poc`.
- [x] **Paso 2:** `sf project deploy start --source-dir force-app -o poc`. Esperado: `Status: Succeeded`.
- [x] **Paso 3:** correr `node infra/salesforce/seed-contacts.mjs` dos veces. Esperado: después de la segunda corrida siguen siendo 4 contactos, y el archivo `*.local.json` trae 4 Ids de 18 caracteres.
- [x] **Paso 3b:** probar la regla de duplicados con `sf data create record -s Contact -v "LastName=Prueba Email=compras@cumbres.ejemplo.mx" -o poc`. Esperado: falla con `DUPLICATES_DETECTED` y no se crea nada. Con un correo nuevo se crea; borrarlo al terminar.
- [x] **Paso 4 (Maite):** crear la aplicación conectada con JWT, siguiendo la guía. Generar el `.jks` en `infra/salesforce/certs/`, que no se versiona.
  - Resultado (20-nov): certificado `poc-sf` (`infra/salesforce/certs/poc-sf.jks` y `.crt`, válido hasta 2027-11-20). La org solo ofrece **aplicación de cliente externo**: `POC sapi-crm` (API `POC_sapi_crm`) con OAuth, flujo de portador JWT con `poc-sf.crt`, usuarios aprobados por el administrador y el conjunto `POC_Integracion`. Maite guarda la Consumer Key; se cifra en la tarea 14.
- [x] **Paso 5 (Maite):** crear la cuenta de MagicBell del proyecto, habilitar el canal de correo y guardar el token en `infra/magicbell/credentials.local`.
  - Resultado (20-nov): cuenta personal de Maite (D23) con canal de correo por SMTP de Gmail (contraseña de aplicación). `POST https://api.magicbell.com/broadcasts` con el token de Project Auth → `HTTP 201`, `enqueued`, y **el correo llegó** a la bandeja (la base nunca confirmó la entrega). Token en `infra/magicbell/credentials.local`.
  - Decisión (20-nov, D23): en la v1 se usa la **cuenta personal** de MagicBell de Maite hasta que el equipo tenga su infraestructura. Los pasos para crear el proyecto del equipo y habilitar el correo quedan en `infra/magicbell/README.md`; los de Salesforce, con la interfaz en español y la aplicación de cliente externo, en `infra/salesforce/README.md`.
- [x] **Paso 6:** correr `build-seeds.mjs` y `reset-data` para que el ERP use los Ids reales de Salesforce.
  - Resultado (20-nov): org Developer Edition con alias `poc`. Despliegue OK (la duplicate rule va con `sortOrder` 2 porque la org ya trae `Standard_Contact_Duplicate_Rule` en el 1). `seed-contacts` dos veces: 4 creados y luego los mismos 4 actualizados. Correo repetido → 400 `DUPLICATES_DETECTED` "Ya existe un contacto con este correo."; correo nuevo → 201. La semilla del ERP usa los Ids reales.
  - Hallazgos de la CLI `sf` 2.159: `sf org display` ya no entrega el token de sesión real, así que `sf-session.mjs` llama a la API con `sf api request rest` (autentica por dentro) y borra con `sf data delete record` (`api request` falla en DELETE sin cuerpo). En Windows, `sf` se instala en `C:\Program Files\sfin` y no queda en el PATH; desde bash se llama `"/c/Program Files/sf/bin/sf"`.
- [x] **Paso 7:** probar el retiro y volver a levantar:
  - Resultado (21-nov): `teardown -Force` borró túneles (no había), contenedores y volúmenes `poc-*`, archivos generados, llave del SFTP, los 4 contactos y los metadatos de Salesforce; no tocó `oracle-store`, `ngrok-oracle` ni los `tih-*`. Reconstrucción con `start-infra`, despliegue, `assign permset`, `seed-contacts` y `reset-data`: `verify-schema` 0 fallos, 5 contenedores arriba, 6 colas, remisiones semilla, C cotiza 175.00, el ERP usa los Ids nuevos de Salesforce y el correo duplicado vuelve a dar `DUPLICATES_DETECTED`.
  - Hallazgos corregidos en `teardown-salesforce.mjs`: la matching rule no se puede desactivar mientras la duplicate rule está activa, ni en el mismo despliegue (se desactivan en dos pasos: `destructive/deactivate-1-duplicate` y `-2-matching`); un permission set asignado no se puede borrar (se quitan antes sus `PermissionSetAssignment`).
  - Después de reconstruir: Maite vuelve a agregar `POC Integración` en las *Políticas* de la aplicación `POC sapi-crm` (el permission set se borró y se creó de nuevo).
  1. `teardown -Force`. Esperado: no queda ningún contenedor `poc-*` ni volumen de `poc-infra`, y en Salesforce no hay contactos `POC-*` ni los dos campos.
  2. `start-infra`, `sf project deploy start`, `seed-contacts`, `build-seeds` y `reset-data`. Esperado: el entorno queda igual que antes del retiro.
- [ ] **Paso 8:** sin commit por ahora. El mensaje `feat(infra): metadatos, semilla y retiro de Salesforce y del entorno` se usa en la tarea 30, en `feat/local-infra`.

**Hito 1 (entorno local listo):** con el README se levantan las dependencias con los datos del guion, y las 7 apps compilan.

---

## Fase 4 · Común

### Tarea 10: Biblioteca de resiliencia

**Archivos:**
- Crear: `libs/poc-resilience/`. Es un proyecto Mule con `mule-maven-plugin` y `<classifier>mule-plugin</classifier>` (configuración compartida).
- Crear: `src/main/mule/poc-resilience.xml` y las pruebas en `src/test/munit/`.

**Interfaces** (sub-flows que se llaman con `flow-ref` después de `<import file="poc-resilience.xml"/>`):
- `resilience-call`: entradas `vars.rsSource` (nombre de la fuente) y `vars.rsFlow` (nombre del flujo de lectura a ejecutar).
  - Aplica el interruptor por fuente, con el estado en el Object Store `rs-circuit-store`.
  - Hace un reintento solo si el error es de conectividad (D9).
  - Si el interruptor está abierto o falla, deja `vars.rsResult = {ok: false, fuente, motivo}` y no lanza error.
- `resilience-partial-marker`: a partir de un arreglo de `rsResult`, arma `sources` (`"OK"`, `"UNAVAILABLE"` y `"n of m"`).
- Propiedades por fuente: `rs.<fuente>.failureThreshold` (3), `rs.<fuente>.openMillis` (30000) y `rs.<fuente>.timeoutMillis` (2000 para proveedores, 3000 para sftp y crm).

- Resultado (21-nov): `libs/poc-resilience` creada con la skill `build-mule-integration` (Object Store 1.3.4, buscado en Exchange). Rojo primero (sub-flows inexistentes), después verde: 5 pruebas (las 4 del plan y `partialMarkerWithoutProviders`), cobertura 93.75 %, `mvn install` en `~/.m2` como `<orgId>:poc-resilience:1.0.0:mule-plugin`.
- Decisiones de ejecución:
  - El reintento detecta la conectividad por el identificador del error (`CONNECTIVITY` en cualquier espacio de nombres); las pruebas usan `APP:CONNECTIVITY` y `APP:TIMEOUT` porque `raise-error` no puede lanzar `HTTP:*`.
  - El tiempo límite lo aplica cada app en su conector: la biblioteca no puede cortar un `flow-ref`.
  - Prueba del interruptor abierto: menos de 500 ms (el plan decía 50 ms). Bajo MUnit con cobertura cada procesador cuesta unos 10 ms y `os:retrieve` unos 50 ms (medido); el criterio de la final es "no esperar" el tiempo límite de 2 a 3 s. La prueba del semiabierto usa `openMillis` de 1 s.
  - MUnit inicializa de forma perezosa: los flujos que se pasan a `resilience-call` por `vars.rsFlow` necesitan una referencia estática en la suite (`munit:before-suite` con `choice` en `#[false]`). Las pruebas de las apps (tareas 11 a 18) lo necesitan también; está en el README de la biblioteca.
  - El validador de la skill da un falso positivo con `xmlns:os` (busca `os` en `mule-objectstore-connector`).
  - `mule_version` del validador de la skill sale vacío (la carpeta del runtime de Studio se llama `mule`); `mule-artifact.json` se fijó a mano en 4.11.4 como las demás apps.

- [x] **Paso 1:** escribir pruebas MUnit que fallen:
  - `circuitOpensAfterThreeFailures`: 3 fallas seguidas y una cuarta llamada; se afirma que el flujo destino se ejecutó 3 veces y que la cuarta respondió `ok: false` en menos de 50 ms.
  - `circuitHalfOpenClosesOnSuccess`: con `openMillis` en 100 ms, una llamada exitosa cierra el interruptor.
  - `retryOnlyOnConnectivity`: un `HTTP:CONNECTIVITY` se ejecuta 2 veces; un `HTTP:TIMEOUT` se ejecuta 1 vez.
  - `partialMarkerCountsProviders`: con 2 OK y 1 fallo de proveedores, `sources.providers` es `"2 of 3"`.
- [x] **Paso 2:** `mvn -B -f libs/poc-resilience/pom.xml clean test`. Esperado: FAIL.
- [x] **Paso 3:** implementar los sub-flows.
- [x] **Paso 4:** volver a correr las pruebas. Esperado: PASS y cobertura de al menos 80 %.
- [x] **Paso 5:** `mvn install` para dejarla en `~/.m2`. Publicarla en Exchange es opcional, con `mvn deploy` contra la org (**[Maite]**).
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(libs): biblioteca de resiliencia` se usa en la tarea 30, en `feat/resilience-library`.

---

## Fase 5 · System APIs

> **Para las tareas 11 a 14 y 16 a 24.** El paso "contrato desde Exchange" es igual en todas. En el `pom.xml` se agrega la dependencia `<groupId>{orgId}</groupId><artifactId>{app}</artifactId><version>1.0.0</version><classifier>raml</classifier><type>zip</type>`. Se cambia `apikit:config api="resource::{orgId}:{app}:1.0.0:raml:zip:{app}.raml"`, se borra `src/main/resources/api/` y se regeneran los flujos de APIkit en Studio (Mule → Generate Flows from REST API). Las apps nuevas se crean en Studio desde Exchange, con la ubicación `apps/<app>`. Se puede usar la skill `build-mule-integration`; si falla su validación de prerrequisitos, se sigue el patrón de la app base: `interface.xml`, `implementations/*.xml`, `common/global.xml` y `dataweave/*.dwl`. La "verificación en vivo" de cada tarea agrega su carpeta, con aserciones, a `tests/postman/poc-apps.postman_collection.json` y se corre con `npx --yes newman@6 run tests/postman/poc-apps.postman_collection.json --folder <app> -e tests/postman/local.postman_environment.json`, con la caché de npm en `tmp/`.

### Tarea 11: sapi-oracle-core

**Archivos:** `apps/sapi-oracle-core/`, con los cambios de la sección 4 de la final:
- Se agregan los listados, el cambio de estado, los movimientos y `INVENTORY_PROVIDERS`.
- Se retiran `/customers` y las columnas de proveedor en `INVENTORY`.
- La conexión, el pool y la reconexión salen de propiedades. El usuario es `STORE_APP`, nunca `INTEGRATION_APP`.

**Interfaces:** las operaciones de la tarea 3. Al confirmar, `PATCH` actualiza `LAST_PRICE` del proveedor en la misma transacción. Errores:
- ORA-02290 (stock negativo) → 409 `INSUFFICIENT_STOCK`.
- Transición de estado inválida → 409 `INVALID_TRANSITION`.
- `REFERENCE` repetida → 200 con el movimiento original.

- Resultado (21-nov), con la skill `build-mule-integration` en modo actualización:
  - Contrato `sapi-oracle-core` 1.0.1 desde Exchange con orgId parametrizado: **APIkit acepta `resource::${api.groupId}:…:${api.version}:…`** (D19 verificado). El orgId llega por `.mvn/maven.config`: el `mule-maven-plugin` no ve las propiedades de perfiles de `settings.xml`.
  - Se quitaron `/customers`, la copia del RAML y los ambientes dev/qa/prod (queda `local`; `cloud` en la tarea 26). Conexión a Oracle desde propiedades (host, puerto 1523, servicio, pool y reconexión) con el usuario STORE_APP.
  - Implementación en `implementations/orders.xml` e `implementations/inventory.xml`; traducción de filas en el módulo `modules/erp.dwl`. `PATCH` cambia el estado con `WHERE STATUS = 'RECEIVED'` (sin carreras); los movimientos son idempotentes por `REFERENCE` (consulta previa y, ante ORA-00001 por carrera, rollback y devolución del original).
  - Pruebas: rojo primero; verde con 27 (20 por flujo, incluidas las 5 del plan, y 7 HTTP de punta a punta con el contrato de Exchange); cobertura 98.51 %; `mvn clean package` BUILD SUCCESS.
  - Las consultas se corrieron además contra `poc-oracle` en una transacción con ROLLBACK. **Hallazgo: `:size` no es un nombre de parámetro válido en Oracle (ORA-01745)**; se renombró a `:pageSize`/`:pageOffset`. El resto (lote con proveedores, ORA-02290, reposición, ORA-00001, confirmación) dio lo esperado.
  - Lecciones: `reconnection` va antes de `db:pooling-profile`; en MUnit `munit-tools:error` no admite `typeId` y `cause` juntos; una expresión en línea que mezcla payload JSON y variables Java necesita `output application/java ---`; `type` es palabra reservada en DataWeave; el validador de la skill da falsos positivos con `xmlns:os` y con la URL del XSD de APIkit.
  - Carpeta `sapi-oracle-core` de `tests/postman/poc-apps.postman_collection.json` (11 peticiones) y `tests/postman/local.postman_environment.json` listas para el paso 5.

- [x] **Paso 1:** cambiar el contrato a Exchange con el orgId literal (D19) en pom y `api` de APIkit. Esperado: la app arranca en MUnit y APIkit carga el RAML. Si APIkit no resuelve los placeholders, aplicar la salida de D19 (`set-org.mjs`) y anotarla en el diseño antes de seguir con las otras apps.
- [x] **Paso 2:** escribir pruebas MUnit que fallen, con la base de datos simulada:
  - `postOrder_createsRecibidoWithAllLines`: 2 líneas → 201, `status = RECEIVED`, 2 líneas.
  - `postMovement_salidaOverStock_returns409`: el `db:insert` lanza ORA-02290 → 409 `INSUFFICIENT_STOCK`.
  - `postMovement_repeatedReference_returnsOriginal`: un ORA-00001 sobre `REFERENCE` → 200 con el mismo id.
  - `getItemsByIds_sku100_threeProvidersOnePreferred`.
  - `patchOrder_rechazadoToConfirmado_returns409`.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS, con cobertura de al menos 80 %.
- [x] **Paso 5:** verificación en vivo contra `poc-oracle` con la carpeta `tests/postman` → "sapi-oracle-core". Esperado: *(21-nov: app corriendo en Studio con `-M-Denv=local`; 11 peticiones, 15 aserciones OK contra poc-oracle.)*
  - los 5 pedidos con su estado;
  - SKU-100 con stock 2 y 3 proveedores, con FAK como preferente;
  - una salida de 3 de SKU-100 → 409 y el stock sigue en 2;
  - el mismo `POST /inventory/movements` de reposición dos veces → el stock se mueve una sola vez.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(sapi-oracle-core): pedidos con estado, inventario con proveedores y movimientos` se usa en la tarea 30, en `feat/sapi-oracle-core`.

### Tarea 12: sapi-price-providers

> Nota de la tarea 7: el WSDL `borland-orderservice.wsdl` gana `<s:element minOccurs="0" maxOccurs="1" name="Currency" type="s:string"/>` en `Article`, y la moneda se lee de ahí (D: la moneda viene del proveedor).

**Archivos:** `apps/sapi-price-providers/`.
- Los hosts apuntan a WireMock: `providers.a|b|c.*` en las propiedades.
- La moneda viene en la respuesta del proveedor.
- `POST /quotes` hace un `scatter-gather` por proveedor y cada ruta usa `resilience-call` con la fuente `prov-<abv>`.

- [x] **Paso 1:** cambiar el contrato a Exchange y agregar la dependencia `poc-resilience`.
- [x] **Paso 2:** escribir pruebas MUnit que fallen:
  - `quotes_sku100_threeQuotesMxn`: tres cotizaciones de 189.00, 194.00 y 175.00, con `noResponse = []`.
  - `quotes_providerCTimeout_twoQuotesAndCInNoResponse`: el `wsc:consume` lanza `WSC:TIMEOUT` → 2 cotizaciones y `noResponse = ["BOR"]`.
  - `getPrice_unknownProduct_returns404`.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS.
  - Resultado (21-nov): 15 pruebas MUnit (10 de flujos y 5 HTTP) en verde, cobertura 93.88%.
  - Ajustes: `parallel-foreach` en lugar de `scatter-gather` (la lista de productos es dinámica, hasta 10); las fuentes se llaman `provider-fak|esc|bor` (no `prov-<abv>`) para que `resilience-partial-marker` las cuente como `providers: n of m`; las propiedades van por código, `providers.fak|esc|bor.*` y `rs.provider-<abv>.timeoutMillis` = 2000; el tiempo límite de C se aplica con `wsc:default-http-transport-configuration timeout`. Un producto que el proveedor no conoce no cuenta como falla del interruptor: en `/quotes` sale en `noResponse` con `NOT_FOUND`.
- [x] **Paso 5:** en vivo, con `demo/control slow-c`, medir `POST /quotes` de SKU-100. Esperado: menos de 3 s, 2 cotizaciones y C en `noResponse`. Con `normal-c` vuelven las 3.
  - Resultado (21-nov, app en Studio con `-M-Denv=local`): normal 3 cotizaciones (189, 194 y 175 MXN) en ~0.4 s (la primera llamada tras arrancar tarda ~7 s por la carga inicial de los conectores); con `slow-c` 2.3 s, FAK y ESC, y BOR en `noResponse` con `TIMEOUT`; a la tercera falla se abre el interruptor (0.3 s, `CIRCUIT_OPEN`) y tras 30 s la llamada de prueba lo cierra; SKU-300 en C (conexión cortada) → `ERROR`. Con `normal-c` vuelven las 3.
  - Corrección encontrada en vivo: `poc-resilience` no declaraba `output application/java` en sus expresiones y fallaba con un `rsSource` que venía de JSON; se corrigió y se agregó la prueba `resilienceCallWithJsonSourceName` (6 pruebas). Ojo en la demo: tras `slow-c`, BOR queda en `CIRCUIT_OPEN` 30 s aunque se ponga `normal-c`.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(sapi-price-providers): cotización en paralelo con resiliencia y simuladores` se usa en la tarea 30, en `feat/sapi-price-providers`.

### Tarea 13: sapi-sftp-orders

**Archivos:** `apps/sapi-sftp-orders/`.
- Se retiran `/files` y la carpeta `/orders`.
- Se agregan las remisiones y los acuses.
- La autenticación es con llave: la ruta de la llave va en propiedades y la frase de paso en las propiedades seguras.

**Interfaces:**
- `POST /dispatch-notes {pedidoId, lineas, cliente{nombre, ciudad}}` deposita `remision_<orderId>_<n>.csv`, donde `n` es el último más 1. Escribe primero un `.tmp` y luego lo renombra.
- `GET /dispatch-notes/{orderId}` devuelve la última remisión con `{dispatchNoteId, status, receivedBy?, acknowledgedAt?, reason?}`. Si no hay ninguna responde 404, que papi-orders interpreta como `ON_HOLD`.
- `GET /dispatch-notes?status=` lista por estado.
- Las tres operaciones pasan por `resilience-call` con la fuente `sftp`. Con el interruptor abierto responden 503 `retryable`.

- [x] **Paso 1:** cambiar el contrato a Exchange y agregar la dependencia `poc-resilience`.
- [x] **Paso 2:** escribir pruebas MUnit que fallen:
  - `postDispatch_twiceSameOrder_creates_1_and_2`.
  - `getDispatch_rejected_returnsMotivo`: lee el acuse simulado y responde `REJECTED` con "Dirección incorrecta".
  - `sftpDown_afterThreeFailures_returns503Fast`.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS.
  - Resultado (21-nov): 14 pruebas MUnit (9 de flujos y 5 HTTP) en verde, cobertura 93.22%.
  - Ajustes: la llave no tiene frase (así la genera `start-infra`), por lo que la app no usa propiedades seguras; la ruta de la llave depende de dónde se clone el repo y se pasa con `-M-Dsftp.identityFile=...`. El POST también pasa por `resilience-call` (lee la secuencia y escribe). La fecha de depósito sale del acuse (`depositada`) o, si no la trae, de la fecha del archivo. Pendiente para CloudHub (T26): cómo entregar la llave a la app desplegada.
- [x] **Paso 5:** en vivo:
  - Resultado (21-nov, app en Studio): PED-1004 `REJECTED` "Dirección incorrecta"; PED-1003 `SIGNED` por Jorge Treviño; PED-1001 404; dos `POST` del mismo pedido crean `_1` y `_2` y `poc-logistics-sim` los firma; el CSV sale en UTF-8 con acentos. Con `sftp-down`: llamadas 1 a 3 → 503 en ~2.3 s cada una (Windows tarda ~2 s en rechazar la conexión); la 4.ª → 503 `CIRCUIT_OPEN` en 0.25-0.28 s de punta a punta, sin tocar el SFTP (una llamada normal también tarda ~0.3 s en Studio, así que los 100 ms del plan no se alcanzan medidos con curl). Con `sftp-up`, pasados los 30 s responde otra vez.
  - Corrección en vivo: `sftp:list` de SFTP 2.7.1 devuelve solo la ruta; los acuses se leen con `sftp:read`.
  - Hallazgo: la conexión rechazada llega como error `UNKNOWN`, no `CONNECTIVITY`, así que `poc-resilience` no la reintenta (el interruptor sí funciona). **Resuelto (21-nov):** `poc-resilience` también trata como conectividad un error cuya descripción empieza con "Could not establish" o "Could not obtain": lo reintenta una vez y lo reporta como `CONNECTIVITY` (prueba `refusedConnectionAsUnknown_isRetriedAsConnectivity`, 7 pruebas).
  - PED-1004 → `REJECTED` con su motivo;
  - PED-1003 → `SIGNED` con quién recibió;
  - con `sftp-down`, la cuarta llamada responde 503 en menos de 100 ms;
  - con `sftp-up`, a los 30 s responde otra vez.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(sapi-sftp-orders): remisiones y acuses con logística` se usa en la tarea 30, en `feat/sapi-sftp-orders`.

### Tarea 14: sapi-crm (nueva)

**Archivos:** `apps/sapi-crm/`, creada desde Exchange.
- Usa el conector de Salesforce con autenticación JWT.
- La llave del `.jks`, el usuario y el consumer key van en las propiedades seguras.

**Interfaces:** las operaciones de la tarea 3.
- `segment` se traduce de `Segmento__c`: `Estratégico` → `STRATEGIC` y `Regular` → `REGULAR`.
- `direccion.ciudad` sale de `MailingCity`.
- `?ids=` hace una sola consulta SOQL con `IN` y acepta hasta 50 Ids.
- La fuente de `resilience-call` es `crm`, con 3 s.
- `POST /contacts`: si Salesforce responde `DUPLICATES_DETECTED` (regla de la tarea 9), responde 409 `CONTACT_ALREADY_EXISTS` y no reintenta (D22).

- [x] **Paso 1:** escribir pruebas MUnit que fallen, con el conector simulado:
  - `getContactsByIds_fourIds_singleQuery`: se verifica que `salesforce:query` se llamó 1 vez con los 4 Ids.
  - `mapsSegmentAndCity`.
  - `postContact_returnsSalesforceId`.
  - `postContact_duplicatesDetected_returns409ContactAlreadyExists`: el conector simulado falla con `DUPLICATES_DETECTED`.
  - `salesforceDown_returns503RetryableUnder3s`.
- [x] **Paso 2:** implementar.
- [x] **Paso 3:** compilar. Esperado: PASS.
  - Resultado (21-nov): 17 pruebas MUnit (12 de flujos y 5 HTTP) en verde, cobertura 90.38%. Conector Salesforce 12.1.1 (elegido con la skill de Mule), JWT con `consumerKey`, `principal`, `keyStore`, `storePassword`, `certificateAlias` `poc-sf` y audiencia `login.salesforce.com`.
  - Credenciales cifradas con `POC_ENC_KEY` en `local-secure-application-config.yaml` (no versionado); la ruta del `.jks` se pasa con `-M-Dsalesforce.keyStore=...`.
  - El duplicado se detecta por el `statusCode` del registro (`DUPLICATES_DETECTED`) o por un error `SALESFORCE:*` con ese texto.
  - Revisado (21-nov): el conector declara `SALESFORCE:UNAVAILABLE` como hijo de `MULE:CRITICAL`; Mule 4 no deja manejar esos errores ni con un manejador explícito (probado), así que Salesforce en mantenimiento responde 500. Salesforce inalcanzable por red (`CONNECTIVITY`/`TIMEOUT`) sí responde 503. Documentado como limitación en el README de sapi-crm.
- [x] **Paso 4:** en vivo, contra la org:
  - Resultado (21-nov, app en Studio): `?ids=` con los 4 Ids → 200 con los 4 clientes, su segmento y su ciudad, en una sola consulta; Angelópolis cambiado a Estratégico en Salesforce → la API responde `STRATEGIC` de inmediato, y se devolvió a `Regular` (`REGULAR`); `POST` con el correo de Cumbres → 409 `CONTACT_ALREADY_EXISTS` y sigue habiendo 1 contacto con ese correo y 4 `POC-*`; búsqueda por correo 200; `ids` + `email` → 400.
  - Corrección en vivo: el conector solo lee keystores PKCS12; se generó `infra/salesforce/certs/poc-sf.p12` desde el `.jks` (misma contraseña y alias) y la app usa el `.p12`.
  - los 4 clientes con su segmento y su ciudad;
  - cambiar el segmento de Ferretería Angelópolis en Salesforce y repetir la consulta: el cambio se ve de inmediato. Después devolverlo a REGULAR;
  - `POST /contacts` con el correo de Constructora Cumbres → 409 `CONTACT_ALREADY_EXISTS`, y en Salesforce siguen siendo 4 contactos.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(sapi-crm): clientes desde Salesforce` se usa en la tarea 30, en `feat/sapi-crm`.

**Hito 2 (System APIs listas):** las 4 System APIs y la biblioteca pasan sus criterios contra las dependencias locales. *(21-nov: alcanzado; pendientes menores anotados en las tareas 13 y 14 y las suites HTTP de price-providers y sftp-orders por correr con las apps detenidas.)*

---

## Fase 6 · Process APIs (oleada 2)

### Tarea 15: Contratos de las Process APIs y publicación

**Archivos:** crear `specs/papi-customers/`, `specs/papi-orders/`, `specs/papi-order-requests/` y `specs/papi-notifications/`.

**Interfaces** (sección 4 de la final):

| API | Operaciones |
|---|---|
| papi-customers | `POST /customers` · `GET /customers/{customerId}` · `GET /customers?page=` · `GET /customers?email=\|phone=` · `GET /customers?ids=` |
| papi-orders | `GET /products` · `POST /orders` · `POST /orders/process` · `GET /orders?status=&from=` · `GET /orders/{orderId}` (Pedido 360) · `GET /orders/exceptions` · `GET /orders/{orderId}/alternatives` · `POST /orders/{orderId}/corrections` |
| papi-order-requests | `POST /order-requests` (cabecera `Idempotency-Key` obligatoria; responde 202 con `Location`) · `GET /order-requests/{requestId}` · `GET /order-requests?status=` · `POST …/approve` · `POST …/reject` (con motivo) · `POST …/retry` |
| papi-notifications | `POST /orders-registered`, que se conserva para pruebas. Los eventos AMQP `order.registered`, `approval.requested` y `correction.applied` se documentan en la descripción del RAML. |

- [x] **Paso 1:** escribir los 4 RAML. Los ejemplos son los de la final: `alternatives` de PED-1002 da `faltante 3` y las cotizaciones de A, B y C, con C como `masBarata`; `POST /order-requests` da `RESTOCK`, proveedor C, `202 PENDING`.
- [x] **Paso 2:** validar con el validador y con el ruleset de gobernanza. Esperado: 0 errores.
- [x] **Paso 3:** empaquetar con `package-exchange.mjs`.
  - Resultado (22-nov): los 4 RAML en inglés validan con 0 errores y cumplen el ruleset de gobernanza (en papi-order-requests el trait `approver-only` usa el alias local `ApiError`, porque el parser de gobernanza no resolvía `common.ErrorResponse` dentro de un trait). Zips en `tmp/exchange/<api>-1.0.0.zip`, dependientes de poc-common 1.0.2. Rutas base de la final: papi-customers `/api/v1/customers-management`, papi-orders `/api/v1/orders-management`, papi-order-requests `/api/v1` + `/order-requests`, papi-notifications `/api/v1/notifications`. Los tipos propios de cada API (Product, Alternatives, CorrectionRequest, NewOrderRequest, eventos…) van en su RAML para no republicar poc-common.
- [x] **Paso 4 (Maite):** revisar y publicar las 4 en Exchange.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(specs): contratos de las Process APIs (oleada 2)` se usa en la tarea 30, en la rama de cada Process API (`feat/papi-customers`, `feat/papi-orders`, `feat/papi-order-requests` y `feat/papi-notifications`).

### Tarea 16: papi-customers

**Archivos:** `apps/papi-customers/`.
- Se cambia la fuente de sapi-oracle-core a sapi-crm.
- Se quita la generación del UUID.
- Se agregan la búsqueda, el listado y la consulta por lote.

- [x] **Paso 1:** cambiar el contrato a Exchange.
- [x] **Paso 2:** escribir pruebas MUnit que fallen:
  - `post_withoutEmailAndPhone_returns400`.
  - `post_duplicatedEmail_returns409`: la búsqueda en sapi-crm encuentra un contacto → 409 `CUSTOMER_ALREADY_EXISTS` (código de la final para papi-customers).
  - `post_crmReturns409_mapsToCustomerAlreadyExists`: la búsqueda no encuentra nada (alta simultánea) pero sapi-crm responde 409 `CONTACT_ALREADY_EXISTS` → 409 `CUSTOMER_ALREADY_EXISTS` (D22).
  - `post_returnsSalesforceId`.
  - `getByIds_passesBatchToCrm`.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS.
  - Resultado (22-nov): 15 pruebas MUnit (10 de flujos y 5 HTTP) en verde, cobertura 95.24%. Habla con sapi-crm por HTTP (`client_id`/`client_secret` desde propiedades; en CloudHub pasarán a protegidas). Sin resiliencia propia: sapi-crm ya la aplica; un 503 de sapi-crm se devuelve como 503 con `Retry-After`.
- [x] **Paso 5:** en vivo:
  - Avance (22-nov): los 4 clientes por lote, listado y consulta OK. Hallazgos en vivo: (1) Salesforce rechazaba el alta con estado sin país (la org tiene listas de estados y países) → sapi-crm manda `MailingCountry = Mexico`; (2) dos altas simultáneas crearon dos contactos: la regla de duplicados no ve inserciones a la vez → campo único `Contact.Email_Key__c` desplegado en la org, llenado en los 4 contactos y por sapi-crm (`DUPLICATE_VALUE` → 409). Contactos de prueba borrados. Repetido con sapi-crm reiniciado: alta nueva con dirección → 201 (Guanajuato/Mexico); repetida → 409 `CUSTOMER_ALREADY_EXISTS` (búsqueda previa); dos simultáneas → una 201 y una 409, que pasó la búsqueda y la bloqueó Salesforce por `Email_Key__c` (sapi-crm 409 `CONTACT_ALREADY_EXISTS`); un solo contacto por correo. Contactos de prueba borrados; siguen 4 `POC-*`.
  - los 4 clientes del guion;
  - un alta nueva aparece en Salesforce;
  - repetir esa alta responde 409;
  - dos altas simultáneas con el mismo correo nuevo: una 201 y otra 409, y en Salesforce queda un solo contacto.

  Borrar el contacto de prueba al terminar.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(papi-customers): clientes sobre Salesforce` se usa en la tarea 30, en `feat/papi-customers`.

### Tarea 17: papi-orders, parte A: registro, confirmación y catálogo

**Archivos:** en `apps/papi-orders/`:
- Reescribir: `receive-order.xml` y `process-orders.xml`.
- Crear: `catalog.xml` y `list-orders.xml`.
- Retirar: el CSV de entrada y sus `dwl`.

**Interfaces:**
- `POST /orders`: valida al cliente con papi-customers y lo registra con `sapi POST /orders`. Responde en menos de 1 s con `{orderId, status: RECEIVED}`.
- **Ciclo de confirmación**, cada 60 s con el candado de la base, o disparado con `POST /orders/process`, que responde 202. Para cada pedido `RECEIVED`:
  1. **Precio.** Usa `localPrice` si es mayor que 0. Si no, el `lastPrice` del proveedor preferente. Si no hay ninguno, cotiza con el preferente por `GET /providers/...`. Si el proveedor no responde, el pedido sigue `RECEIVED`.
  2. **Confirmación.** Hace `PATCH` a `CONFIRMED` con los precios.
  3. **Si hay stock completo:** registra una salida por línea con referencia `<orderId>-out-<itemId>`, deposita la remisión y publica `order.registered`.
  4. **Si falta stock:** el pedido queda `CONFIRMED` y la remisión espera (D8).
- `GET /products`: el catálogo, con precio local o el último precio del preferente. Nunca cotiza en vivo.
- `GET /orders?status=&from=`: pasa la consulta a sapi-oracle-core.

- [x] **Paso 1:** cambiar el contrato a Exchange.
- [x] **Paso 2:** escribir pruebas MUnit que fallen:
  - `postOrder_returnsRecibidoUnder1s`.
  - `cycle_localPrice_confirmsAndEmitsDispatchAndEvent`.
  - `cycle_lastPreferredPrice_usedWithoutQuoting`: se verifica que `GET /providers` se llamó 0 veces.
  - `cycle_noPriceAndProviderDown_staysRecibido`.
  - `cycle_shortStock_confirmedWithoutDispatchOrEvent`.
  - `catalog_neverQuotesLive`.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS.
  - Resultado (22-nov): 21 pruebas MUnit (16 de flujos y 5 HTTP) en verde, cobertura 98.44%. AMQP pasa a `com.mulesoft.connectors:mule-amqp-connector:1.9.6` (el 1.9.4 de `org.mule.connectors` ya no se resuelve). Candado del ciclo en memoria (Object Store, vence a los 5 min, D16). El `import` de poc-resilience se agrega en la tarea 18, cuando se usa.
- [x] **Paso 5:** en vivo, después de `reset-data`:
  - Resultado (22-nov, apps en Studio): pedido SKU-200 × 2 para Cumbres → 201 `RECEIVED` (0.5-0.9 s en caliente; 2.7 s la primera llamada en frío); `POST /orders/process` → 202; el pedido queda `CONFIRMED` con precio `LOCAL` 250 y total 500, el stock de SKU-200 baja de 40 a 38, la remisión llega a `pendientes` y el simulador la pasa a `firmadas`, y `orders.registered.q` recibe 1 mensaje. PED-1001 sigue `RECEIVED` (C no responde para SKU-300). Hallazgo: `poc-rabbitmq` no tenía el usuario `poc-app` (credentials.local cambió y start-infra no se volvió a correr); se creó con `rabbitmqctl add_user` y permisos `.*`. Datos restaurados con `reset-data` al final.
  1. Crear un pedido de SKU-200 × 2 para Cumbres.
  2. Disparar `POST /orders/process`.
  3. Esperado: el pedido queda `CONFIRMED`, el stock de SKU-200 baja a 38, la remisión aparece en `pendientes` y luego en `firmadas`, y hay un mensaje en `orders.registered.q`.
  4. PED-1001 sigue `RECEIVED` después del ciclo.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(papi-orders): registro y confirmación con precio, stock y remisión` se usa en la tarea 30, en `feat/papi-orders`.

### Tarea 18: papi-orders, parte B: Pedido 360, excepciones y alternativas

**Archivos:** crear en `apps/papi-orders/`:
- `order360.xml`
- `exceptions.xml`
- `alternatives.xml`
- `dataweave/order360-*.dwl`

**Interfaces:**
- `GET /orders/{id}` hace un `scatter-gather` sobre el ERP (pedido e inventario por lote), el CRM (contacto), la logística (remisión) y, si hay faltante, los proveedores (`POST /quotes`). Cada rama pasa por `resilience-call`.
- Reglas de excepción:
  - `STOCK_SHORTAGE`: el pedido está `CONFIRMED`, no tiene remisión y alguna línea pide más de lo que hay en stock.
  - `UNCONFIRMED`: el pedido sigue `RECEIVED`.
  - `DISPATCH_REJECTED`: la última remisión está `REJECTED`.
- `dispatchNote.status` vale `ON_HOLD` si no hay remisión y `UNKNOWN` si la logística no respondió.
- `GET /orders/exceptions` trae los pedidos abiertos con una sola consulta por lote a cada fuente (CRM con `?ids=` y logística con `?status=REJECTED`). Ordena primero los `STRATEGIC` y después por antigüedad.
- `GET /orders/{id}/alternatives`:
  - Con faltante, responde `{shortage, currency, quotes[], cheapest}` con tipo `RESTOCK`.
  - Con remisión rechazada, responde tipo `REISSUE`.

- [x] **Paso 1:** escribir pruebas MUnit que fallen, con las System APIs simuladas y los datos del guion:
  - `order360_ped1002_faltanteStrategicThreeQuotesCCheapest`.
  - `exceptions_orderIs_1002_1004_1001_1005`.
  - `order360_sftpDownAndCSlow_under3sWithDesconocidaAnd2de3` (foco 1).
  - `order360_crmDown_200WithCrmNoDisponible` (foco 2).
  - `alternatives_ped1004_reemitir`.
- [x] **Paso 2:** implementar.
- [x] **Paso 3:** compilar. Esperado: PASS.
  - Resultado (22-nov): suites de flujos 27/27 (16 parte A + 11 parte B), cobertura 87.14%; suite HTTP de la parte B (4 pruebas) escrita, se corre con el puerto 8083 libre. Diseño: el ERP se lee primero (pedido e inventario por lote, local); luego `scatter-gather` de CRM, logística y, con faltante, proveedores, cada rama por `resilience-call` con 2.5-2.8 s de límite. La bandeja lee las remisiones de `pendientes`, `firmadas` y `rechazadas` (una llamada por carpeta) para no marcar faltante en pedidos ya despachados.
- [x] **Paso 4:** en vivo:
  - Avance (22-nov, apps en Studio): bandeja → 1002 `STOCK_SHORTAGE`, 1004 `DISPATCH_REJECTED`, 1001 `UNCONFIRMED`, 1005 `STOCK_SHORTAGE` (en ese orden). PED-1004 alternativas → `REISSUE` "Dirección incorrecta". Con `slow-c` + `sftp-down`: Pedido 360 de PED-1002 en 2.8 s con remisión `UNKNOWN`, logistics `UNAVAILABLE`, providers `2 of 3`; alternativas en 0.5 s con 2 cotizaciones (FAK más barata). Hallazgo: el ciclo cotizaba SKU-300 con C cada minuto (C corta la conexión a propósito) y abría el interruptor de C en sapi-price-providers, así que PED-1002 salía `2 of 3` aun con todo normal. Correcciones: (1) backoff de 10 min por proveedor+producto tras una cotización fallida en el ciclo (`quote-backoff-store`), (2) límite de las ramas de CRM y logística a 2 s para dar margen bajo 3 s. Repetido con la app actualizada: con todo normal `3 of 3` y C (175) la más barata, también después de 3 ciclos (el backoff salta la cotización fallida de SKU-300; PED-1001 sigue `RECEIVED`). Con `slow-c` + `sftp-down`: Pedido 360 en 2.46-2.65 s (0.53 s cuando se abren los interruptores), alternativas en 0.84 s con 2 cotizaciones, bandeja en 0.78 s. Restaurado con `normal-c`, `sftp-up` y `reset-data`. Pendiente: suites HTTP de papi-orders con la app detenida.
  - la bandeja da PED-1002, PED-1004, PED-1001 y PED-1005, en ese orden;
  - después de `slow-c` y `sftp-down`, el Pedido 360 de PED-1002 llega en menos de 3 s con lo que falta marcado;
  - en el mismo estado, `GET /orders/{PED-1002}/alternatives` llega en menos de 3 s con 2 cotizaciones (escena 3: "dos de tres cotizaciones").

  Volver todo con `reset`.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(papi-orders): Pedido 360, excepciones priorizadas y alternativas` se usa en la tarea 30, en `feat/papi-orders`.

### Tarea 19: papi-orders, parte C: correcciones aprobadas

**Archivos:** crear `apps/papi-orders/src/main/mule/implementations/corrections.xml`.

**Interfaces:** `POST /orders/{id}/corrections {type, provider?, quantity?, key}`.
- `RESTOCK`:
  1. Registra una reposición con `reference = key`.
  2. Registra las salidas de las líneas con `reference = key + "-out-" + itemId`.
  3. Deposita la remisión.
  4. **No publica `order.registered`** (D18). El aviso al cliente sale de `correction.applied`, que publica papi-order-requests.
- `REISSUE`: deposita la remisión con `n + 1`. Tampoco publica eventos.
- Si la llave se repite, responde 200 con el mismo resultado y sin moverse otra vez (D7).

- [x] **Paso 1:** escribir pruebas MUnit que fallen:
  - `reponer_ped1002_movesStockAndEmitsDispatch`.
  - `reponer_ped1002_doesNotPublishOrderRegistered`: `amqp:publish` se llama 0 veces (D18).
  - `reponer_sameKeyTwice_stockMovedOnce` (foco 4).
  - `reemitir_ped1004_createsN2`.
  - `reemitir_ped1004_doesNotPublishOrderRegistered`.
- [x] **Paso 2:** implementar.
- [x] **Paso 3:** compilar. Esperado: PASS.
  - Resultado (22-nov): 10 pruebas de correcciones en verde (38 de flujos en total, cobertura 88.7%). Idempotencia de REISSUE sin almacén propio: solo se reemite mientras la última remisión está `REJECTED`; de RESTOCK, por las referencias únicas del ERP y reutilizando la remisión existente.
- [x] **Paso 4:** en vivo, aplicar dos veces `RESTOCK` de 3 unidades de SKU-100, proveedor C, en PED-1002. Esperado: el stock pasa de 2 a 5 y luego a 0 una sola vez, existe `remision_<PED-1002>_1.csv` y `orders.registered.q` no recibió ningún mensaje.
  - Resultado (22-nov, apps en Studio): RESTOCK de 3 SKU-100 con BOR en PED-1002 dos veces con la misma llave → 201 (stock 2 → 5 → 0) y luego 200 con el mismo resultado; el stock quedó en 0 una sola vez, existe `remision_<PED-1002>_1.csv` (el simulador la firmó) y `orders.registered.q` quedó en 0. REISSUE en PED-1004 dos veces → 201 con `_2` y luego 200 con la misma. Suites HTTP pendientes de las 4 apps corridas: papi-orders 47 pruebas (94.92%), sapi-price-providers 15, sapi-sftp-orders 14, sapi-crm 18. Datos restaurados con `reset-data`.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(papi-orders): aplicación idempotente de correcciones` se usa en la tarea 30, en `feat/papi-orders`.

### Tarea 20: papi-order-requests (nueva)

**Archivos:** `apps/papi-order-requests/`, creada desde Exchange, con la conexión de base de datos a `INTEGRATION_APP`.

**Interfaces** (sección 4 de la final):
- **Creación:** `Idempotency-Key` es obligatoria. Si se repite, devuelve el mismo `requestId`.
- **Estados:** `PENDING` → `APPROVED` → `APPLYING` → `COMPLETED` o `FAILED`. Desde `PENDING` también puede pasar a `REJECTED` o a `EXPIRED`.
- **Historia:** cada transición se escribe en `ORDER_REQUEST_EVENTS` con el actor.
- **Aprobación:**
  - `approve`, `reject` y `retry` solo se aceptan si `x-client-app` está en `approval.approverClientIds`; si no, 403 (D10).
  - Aprobar una solicitud que no está `PENDING` responde 409.
- **Al aprobar:**
  1. Pasa a `APPLYING`.
  2. Llama a `papi-orders POST /orders/{id}/corrections` con la misma llave.
  3. Termina en `COMPLETED` y publica `correction.applied` una sola vez, con `{requestId, orderId, customerId, type, detail}`. Es el único evento que avisa al cliente de una corrección (D18). Si la llamada falla, termina en `FAILED` y no publica `correction.applied`.
- **Al crear:** publica `approval.requested`. Calcula `amount` = quantity × price de la cotización (3 × 175.00 = 525.00).
- **Vencimiento:** un scheduler revisa cada 5 minutos y marca `EXPIRED` lo que pasó de `solicitudes.vencimientoHoras` (24).

- [x] **Paso 1:** escribir pruebas MUnit que fallen:
  - `create_sameKeyTwice_sameRequestId`.
  - `approve_withAgentClientApp_returns403`.
  - `approve_completesWithHistory`: la historia tiene 4 eventos y en cada uno quién y cuándo.
  - `approve_publishesCorrectionAppliedOnce`: `correction.applied` se publica 1 vez y `order.registered` 0 veces (D18).
  - `approve_sameRequestTwice_publishesOnce`: la segunda aprobación responde 409 y no publica nada.
  - `approve_alreadyRejected_returns409` (foco 3).
  - `expire_afterDeadline_vencida`.
  - `applyFails_endsFallida_retryCompletes`.
- [x] **Paso 2:** implementar.
- [x] **Paso 3:** compilar. Esperado: PASS.
  - Resultado (22-nov): 23 pruebas MUnit (18 de flujos y 5 HTTP) en verde, cobertura 91%; SQL probado contra INTEGRATION_APP con ROLLBACK. Se agregó `ORDER_REQUESTS.CUSTOMER_ID` (ALTER en poc-oracle y en `infra/oracle/sql/integration/01-schema.sql`) para los eventos; el cliente sale del Pedido 360 de papi-orders al crear. Aprobador local `aprobador-tienda`, agente `agente-mcp`. Transiciones con `UPDATE ... WHERE STATUS = origen` + historia en una transacción.
  - Corrección (22-nov, primera prueba en vivo): el `INSERT` de `ORDER_REQUESTS` daba 500 ("Could not resolve query", `IndexOutOfBoundsException` en el analizador de metadatos de ojdbc11 23.9) porque tenía literales y expresiones después de los parámetros. Se pusieron primero las columnas literales (`STATUS`, `EXPIRES_AT`) y el primer evento de la historia pasó a usar solo parámetros. Probado contra poc-oracle; 18 pruebas de flujos en verde.
- [x] **Paso 4:** en vivo:
  - crear dos veces la solicitud de PED-1002 (RESTOCK 3 con C) da un solo `requestId`;
  - aprobar con el `client_id` del agente → 403;
  - aprobar con el del aprobador → `COMPLETED`, el stock queda en 0 y la remisión se emite;
  - aprobar otra vez → 409;
  - en RabbitMQ: `correction.applied.q` recibió 1 mensaje y `orders.registered.q` ninguno.
  - Resultado (22-nov): las dos creaciones con la misma llave dieron 202 y el mismo `requestId`; `approval.requested.q` 1. Agente `agente-mcp` → 403. Aprobador → 200 `COMPLETED` en 3.2 s, historia de 4 pasos (PENDING, APPROVED, APPLYING, COMPLETED con la remisión `...1002-1`), stock de SKU-100 2 → 0, `CUSTOMER_ID` y `AMOUNT` 525 guardados. Segunda aprobación → 409. Colas: `correction.applied.q` 1, `orders.registered.q` 0. Al final, `reset-data.sh`.
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(papi-order-requests): solicitudes con llave única, estados y aprobación` se usa en la tarea 30, en `feat/papi-order-requests`.

### Tarea 21: papi-notifications

**Archivos:** en `apps/papi-notifications/`:
- Agregar los listeners de `approval.requested.q` y `correction.applied.q`, con una plantilla `dwl` por evento.
- El token pasa a ser el de la cuenta del proyecto.
- Agregar `notifications.redirectTo` (D11).

- [x] **Paso 1:** cambiar el contrato a Exchange.
- [x] **Paso 2:** escribir pruebas MUnit que fallen:
  - `correctionApplied_ped1002_emailHasCumbresName`.
  - `correctionApplied_sendsExactlyOneCustomerEmail`: un evento produce 1 llamada a MagicBell (D18).
  - `approvalRequested_sendsToApprover`.
  - `failsThreeTimes_goesToDlq`.
  - `redirectTo_overridesRecipient`.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS.
  - Resultado (22-nov): la app de la base (TIH, solo `order.registered`, RAML local) se rehízo en inglés con el contrato de Exchange. Tres listeners con ACK manual y un subflujo común: hasta 3 intentos para errores transitorios y reject sin requeue a la `*.dlq`; los permanentes (cliente inexistente, MagicBell 4xx o 422) van directo a la DLQ. Plantillas en `modules/notifications.dwl` (texto en español, D5b). `notifications.redirectTo` y `notifications.approverEmail` = `maite.diazm98@gmail.com` por ahora. Token de MagicBell (D23) cifrado desde `infra/magicbell/credentials.local`. 23 pruebas MUnit (18 de flujos y 5 HTTP) en verde, cobertura 100%. La corrida de MUnit usa destinatarios propios y reintentos de 10 ms (propiedades de sistema en el pom).
- [x] **Paso 5:** en vivo, repetir el flujo de la tarea 20. Esperado: llegan exactamente dos correos a la bandeja de `redirectTo`: uno al aprobador ("solicitud por aprobar") y uno al cliente ("corrección aplicada", que saluda a "Constructora Cumbres"). El cliente no recibe un aviso de "pedido registrado" por la corrección (D18).
  - Resultado (22-nov): PED-1002 RESTOCK 3 con BOR → `COMPLETED`, remisión `…1002-1`, stock 2 → 0. Llegaron exactamente dos correos a maite.diazm98@gmail.com: "Solicitud por aprobar: RESTOCK del pedido PED-1002" y "Corregimos tu pedido PED-1002" (saluda a Constructora Cumbres). Ningún aviso de pedido confirmado, DLQ vacías. Después `reset-data.sh`. Ajuste: el `broadcastId` se toma también de `broadcast.id` (19 pruebas de flujos en verde).
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(papi-notifications): avisos de aprobación y corrección aplicada` se usa en la tarea 30, en `feat/papi-notifications`.

**Hito 3 (un pedido de punta a punta):** un pedido se registra, se confirma, su remisión llega a logística y el cliente recibe su aviso.

---

## Fase 7 · Canales (oleada 3)

### Tarea 22: Contratos de la xapi y de las herramientas MCP, y publicación

**Archivos:** crear `specs/xapi-online-store/xapi-online-store.raml` y `specs/mcp-online-store/tools.yaml`.

**Interfaces:**
- **xapi:** las 14 operaciones de la sección 4 de la final.
- **`tools.yaml`:** las 5 herramientas con su descripción de negocio y sus parámetros.
  - `get_order(orderId)`.
  - `list_exceptions(limit?)`.
  - `propose_alternatives(orderId)`.
  - `request_correction(orderId, type, provider?, quantity?)`: la llave se deriva de orderId, type y provider.
  - `get_request(requestId)`.

  Las descripciones se traducen al inglés desde "Las herramientas del agente" (sección II.4), sin cambiar su sentido (D5).

- [x] **Paso 1:** escribir los dos archivos.
- [x] **Paso 2:** validar la xapi con el validador y con el ruleset. Esperado: 0 errores. `tools.yaml` se valida con un esquema JSON sencillo en `specs/tools/`.
  - Resultado (22-nov): xapi con las 14 operaciones; los tipos locales de las PAPIs (Product, NewOrder, Alternatives, NewOrderRequest, Rejection…) se repiten en la xapi porque no están en `poc-common` 1.0.2. AMF 0 errores y conforme con `tih-raml-conventions.yaml`. Zip en `tmp/exchange/xapi-online-store-1.0.0.zip` (dependencia `poc-common` 1.0.2). `tools.yaml` con las 5 herramientas, validado con `specs/tools/tools.schema.json` y `validate-tools.mjs` (cinco herramientas, solo `request_correction` escribe con llave `{orderId}:{type}:{provider}`, ninguna aprueba); se agregaron `yaml` y `ajv` a `specs/tools`.
- [ ] **Paso 3 (Maite):** revisar y publicar la xapi en Exchange.
- [ ] **Paso 4:** sin commit por ahora. El mensaje `feat(specs): contrato de la xapi y de las herramientas MCP (oleada 3)` se usa en la tarea 30, en `feat/xapi-online-store` y `feat/mcp-online-store`.

### Tarea 23: xapi-online-store

**Archivos:** en `apps/xapi-online-store/`:
- Las 14 operaciones; solo llaman a la capa de proceso.
- La propagación de `x-client-app` a partir de `client_id` y de `x-correlation-id`.
- `api.autodiscovery.id` en las propiedades de `cloud`.

- [x] **Paso 1:** cambiar el contrato a Exchange.
- [x] **Paso 2:** escribir pruebas MUnit que fallen:
  - `order360_passThroughFromPapiOrders`.
  - `approve_propagatesClientApp`.
  - `orders_post_noFileNameAndSalesforceId`.
  - Una prueba de enrutamiento por cada operación.
- [x] **Paso 3:** implementar.
- [x] **Paso 4:** compilar. Esperado: PASS.
  - Resultado (22-nov): la app de la base (TIH, 2 operaciones, RAML local) se rehízo en inglés con el contrato de Exchange. 14 flujos de implementación que solo nombran su llamada (método, ruta, query) y tres subflujos de llamada, uno por Process API; la respuesta se reenvía tal cual (estado, cuerpo, `Retry-After`) y la `Location` de una solicitud apunta a la xapi. `x-client-app` = `client_id` de quien llama; se propagan `x-correlation-id` e `Idempotency-Key`. `api-gateway:autodiscovery` con `api.autodiscovery.id` (`"0"` en local, marcador en `cloud-application-config.yaml`). 25 pruebas MUnit (7 de flujos y 18 HTTP, una de enrutamiento por operación con un spy que revisa método, ruta y encabezados) en verde, cobertura 100%. Los mocks de MUnit no ven las variables del flujo: para revisar a dónde va una llamada se usa un spy antes del conector.
- [x] **Paso 5:** verificar cómo arranca la app en Studio con el elemento de autodiscovery sin credenciales de plataforma.
  - Si bloquea la API, el autodiscovery se activa solo en la nube (por ejemplo, con `-M-Danypoint.platform.gatekeeper=disabled` en local).
  - Documentar lo que funcione.
  - Resultado (22-nov): en local se arranca con `-M-Danypoint.platform.gatekeeper=disabled` en poc-mule; el log muestra "Starting API Gateway Extension in STANDALONE mode" y "GateKeeper is disabled", y la API responde. En la nube el autodiscovery queda activo con el id de la instancia.
  - En vivo por la xapi (8080): bandeja 1002, 1004, 1001, 1005; Pedido 360 de PED-1002 con "3 of 3" en 0.6–0.9 s (la primera llamada tras arrancar tardó 4.9 s y marcó "0 of 3": calentar antes de la demo, tarea 25); alternativas RESTOCK BOR 175 "3 of 3"; solicitud doble → 202 con el mismo `requestId` y `Location` de la xapi; aprobar como `agente-mcp` → 403; como `aprobador-tienda` → `COMPLETED` en 3.2 s (4 pasos, remisión `…1002-1`, stock SKU-100 2 → 0) y llegaron los dos correos; aprobar otra vez → 409. Sin `client_id` → 400; `POST /orders` con un UUID como cliente → 400. Después `reset-data.sh`.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `feat(xapi-online-store): fachada REST completa` se usa en la tarea 30, en `feat/xapi-online-store`.

### Tarea 24: mcp-online-store (nueva)

**Archivos:** `apps/mcp-online-store/`.
- Usa el conector MCP de MuleSoft: la investigación del 10 de noviembre sugirió la 1.7.3; confirmar en Exchange.
- Transporte streamable HTTP en `/mcp`.
- Un tool listener por herramienta de `tools.yaml`, sin lógica de negocio.

- [x] **Paso 1:** escribir pruebas MUnit que fallen:
  - `listExceptions_equalsGetOrdersExceptions`.
  - `requestCorrection_twice_oneRequest`: se verifica que las dos llamadas llevan la misma `Idempotency-Key`.
  - `noToolApproves`: la lista de herramientas no incluye aprobar.
- [x] **Paso 2:** implementar.
- [x] **Paso 3:** compilar. Esperado: PASS.
  - Resultado (22-nov): conector MCP `com.mulesoft.connectors:mule-mcp-connector:1.7.4` (la GA actual en Exchange; el plan decía 1.7.3), `server-config` con `streamable-http-server-connection` en `/mcp` (8086). Un `mcp:tool-listener` por herramienta, con descripción y esquema copiados de `tools.yaml` por un script; respuesta `text-tool-response-content` con el JSON de la Process API y, en error, el `ErrorResponse`. `request_correction` toma de las alternativas artículo, faltante y precio, y usa la llave `{orderId}:{type}:{provider}`. `x-client-app` = `client_id` de la petición MCP (`attributes.additionalProperties`) o `agente-mcp`. El conector no soporta anotaciones de MCP (`readOnlyHint`). 16 pruebas MUnit (13 de flujos y 3 de protocolo con un cliente MCP real: 5 herramientas, ninguna aprueba, `list_exceptions` por MCP) en verde, cobertura 100%.
- [x] **Paso 4:** en vivo, con MCP Inspector (`npx --yes @modelcontextprotocol/inspector`, con la caché en `tmp/`):
  - `tools/list` devuelve 5 herramientas;
  - `list_exceptions` da la misma lista que la xapi.
  - Resultado (22-nov): el permiso para descargar y correr MCP Inspector con `npx` fue denegado en la sesión; la misma prueba se hizo con JSON-RPC directo por `curl` (initialize → `Mcp-Session-Id`, notifications/initialized, tools/list, tools/call). `tools/list` → 5 herramientas con sus esquemas; `list_exceptions` → 1002, 1004, 1001, 1005, igual que la xapi; `request_correction` dos veces sobre PED-1002 → la misma solicitud (BOR, 175, llave `…:RESTOCK:BOR`, pedida por `agente-mcp`); sobre PED-1001 → `isError` con el `ErrorResponse` `ORDER_WITHOUT_EXCEPTION`; con `client_id: agente-prueba` el log muestra ese cliente (el encabezado sí llega en `additionalProperties`); aprobada por la xapi como `aprobador-tienda`, `get_request` por MCP → `COMPLETED` con 4 pasos. Después `reset-data.sh`. MCP Inspector queda para que Maite lo use en el ensayo (tarea 25).
- [ ] **Paso 5:** sin commit por ahora. El mensaje `feat(mcp-online-store): canal de agentes con cinco herramientas` se usa en la tarea 30, en `feat/mcp-online-store`.

---

## Fase 8 · Punta a punta en local

### Tarea 25: Las cuatro escenas en local

**Archivos:**
- Crear: `tests/postman/poc-e2e.postman_collection.json`, con una carpeta por escena y aserciones.
- Crear: `tests/postman/local.postman_environment.json`. Sin secretos: los `client_id` son de ejemplo en local.
- Crear: `tests/run-e2e.ps1` y `tests/run-e2e.sh`. Ejecutan `reset-data` y luego newman: `npx --yes newman@6`, con la caché en `tmp/`.
- Crear: `docs/guion-demo.md`, con las preguntas al agente y los comandos de `demo/control` en cada escena.
- Reescribir: `README.md`.

- [x] **Paso 1:** escribir la colección con las aserciones de la sección 4 de la final:
  - **E1:** el orden de la bandeja.
  - **E2:** el Pedido 360 de PED-1002 con 3 cotizaciones y C como más barata; después de cambiar el segmento en Salesforce, el cambio se refleja.
  - **E3:** con `slow-c` y `sftp-down`, la respuesta llega en menos de 3 s y marca qué falta.
  - **E4:** la solicitud doble crea una sola; el agente recibe 403 al aprobar; con el aprobador termina `COMPLETED`, con stock y remisión.
  - Resultado (22-nov): `poc-e2e` con 25 peticiones en 10 carpetas (00 Calentamiento, E1, E2a, E2b, E2c, E3, E4a, E4b, E4c): la tienda por la xapi, el agente por MCP con JSON-RPC directo (sesión `Mcp-Session-Id`) y la aprobación con `aprobador-tienda`. `run-e2e.ps1`/`.sh` corren las carpetas con newman (`--export-environment` entre carpetas) e intercalan `demo/control`; al final restauran C, SFTP y el segmento. Nuevos controles `cumbres-regular`/`cumbres-strategic` (`demo/segment.mjs`, sesión de la CLI `sf`) y `reset` restaura también los segmentos. `docs/guion-demo.md` y `README.md` reescritos.
  - Ajuste de tiempos (escena 3): la primera consulta con C lento y el SFTP apagado tardó 3.27 s por la xapi (después 2.5–2.8 s). Se bajó el límite por proveedor de sapi-price-providers de 2 s a 1.5 s y el de cotizaciones en papi-orders de 2.8 s a 2.3 s; pruebas de flujos en verde (10 y 38). Entra al reiniciar poc-mule.
- [x] **Paso 2:** `tests/run-e2e.ps1`. Esperado: 0 aserciones fallidas, dos corridas seguidas.
  - Corrida 1 (22-nov, `./tests/run-e2e.sh` desde Claude Code): 25 peticiones, 69 aserciones, 0 fallidas; E3 en 2.1 s por la xapi y por MCP; llegaron los dos correos. Primero había fallado todo con "request url is empty": newman 6 no arma una URL que solo trae `raw`; las URLs pasaron a texto simple. `sf` no estaba en el PATH de PowerShell: `sf-session.mjs` lo busca en `C:\Program Files\sfin`.
  - Corrida 2, seguida: 25 peticiones, 69 aserciones, 0 fallidas; E3 en 2.2 s (xapi) y 2.1 s (MCP).
- [ ] **Paso 3:** recorrer las 4 escenas con el agente por MCP. Esperado: los mismos resultados que la xapi.
- [ ] **Paso 4 (Maite):** ensayar el guion con alguien ajeno al desarrollo, siguiendo solo el README. Grabar el respaldo (plan B).
- [ ] **Paso 5 (opcional):** generar una suite BAT de la xapi con la skill `generate-bat-tests` en `tests/bat/xapi-online-store/`. Esperado: todas las pruebas pasan contra la xapi local.
- [ ] **Paso 6:** sin commit por ahora. El mensaje `test: escenas de punta a punta en local y guion de la demo` se usa en la tarea 30, en `feat/e2e-tests`.

**Hito 4 y 5 (lista para mostrar, entrega v1 local):** el guion de diez minutos corre de punta a punta en local, sin intervención manual.

---

## Fase 9 · CloudHub 2.0

### Tarea 26: Túneles y ambiente nube

**Archivos:**
- Crear: `infra/tunnels/ngrok.yml.example`, con 3 túneles TCP: Oracle, RabbitMQ y SFTP.
- Crear: `infra/tunnels/start-tunnels.ps1` y `.sh`.
  - Levantan ngrok con los tres túneles.
  - Levantan `cloudflared tunnel --url http://localhost:8089` para WireMock.
- Crear: `infra/tunnels/cloud-endpoints.ps1`.
  - Lee `http://127.0.0.1:4040/api/tunnels` y la URL de cloudflared.
  - Muestra, por app, las propiedades que hay que cambiar en Runtime Manager: `db.host`, `db.port`, `rabbitmq.host`, `rabbitmq.port`, `sftp.host`, `sftp.port` y `providers.*.host`.
- Crear en las 10 apps: `cloud-application-config.yaml`, con valores marcadores y `http.port` 8081.
- Crear: `infra/tunnels/rotate-cloud-secrets.ps1` y `.sh` (D21). Antes de abrir un túnel, las dependencias dejan las contraseñas de ejemplo:
  - Genera contraseñas aleatorias de 32 caracteres para `STORE_APP`, `INTEGRATION_APP`, el usuario de la app en RabbitMQ y el usuario SFTP, y las aplica en los contenedores (`ALTER USER`, `rabbitmqctl change_password`, `chpasswd`). El SFTP acepta solo llave; la contraseña nueva queda como respaldo y la autenticación por contraseña se apaga.
  - Las escribe solo en los `credentials.local` y las muestra una vez, para ponerlas como propiedades protegidas en Runtime Manager.
  - `start-tunnels` se niega a abrir los túneles si alguna contraseña sigue igual a la del `.example`.
- Modificar: `infra/README.md` y el `README.md` de la raíz, con la sección "Apagar los túneles": `stop-tunnels` (o `teardown -OnlyTunnels`) cuando no se use el ambiente nube, porque mientras están abiertos Oracle, RabbitMQ y SFTP quedan expuestos a internet sin lista de IPs.
- Crear: `infra/tunnels/stop-tunnels.ps1` y `.sh`.

- [ ] **Paso 1 (Maite):** instalar ngrok y cloudflared. Configurar el authtoken con `! ngrok config add-authtoken ...`. Verificar que la cuenta permite TCP (P7): `ngrok tcp 2222` debe dar `tcp://…`.
  - **Alternativa opcional (C3):** RabbitMQ en el plan gratuito de CloudAMQP solo para el ambiente `cloud`. Libera un túnel de ngrok y requiere cargar las colas de `definitions.json` en CloudAMQP. Se decide aquí.
- [ ] **Paso 2:** con las contraseñas de ejemplo, correr `start-tunnels`. Esperado: se niega y pide correr `rotate-cloud-secrets`.
- [ ] **Paso 2b:** correr `rotate-cloud-secrets`, `start-tunnels` y después `cloud-endpoints`. Esperado: 3 direcciones `tcp://` y una `https://…trycloudflare.com`; la contraseña de ejemplo de `STORE_APP` ya no entra (ORA-01017) y la nueva sí.
- [ ] **Paso 2c:** `stop-tunnels`. Esperado: no queda ningún proceso `ngrok` ni `cloudflared`, y la API local de ngrok (`:4040`) ya no responde.
- [ ] **Paso 3:** prueba de foco 5. Correr sapi-oracle-core en local con `-M-Denv=cloud` y un `db.host` falso. Esperado: 503 `SERVICE_UNAVAILABLE` con `retryable: true`, no 500. Con el host del túnel responde 200, porque llega a `poc-oracle` a través de ngrok.
- [ ] **Paso 4:** sin commit por ahora. El mensaje `feat(infra): túneles y ambiente nube` se usa en la tarea 30, en `feat/cloud`.

### Tarea 27: [Maite] Despliegue en CloudHub 2.0 y API Manager

- [ ] **Paso 1 (Maite):** revisar los vCores (P6).
- [ ] **Paso 2 (Maite):** desplegar las 10 apps en el espacio compartido con 0.1 vCore y 1 réplica cada una. El orden es: primero las System, luego las Process y al final los canales. Se puede subir el `.jar` desde Runtime Manager o usar `mvn deploy` con `cloudhub2Deployment`.
- [ ] **Paso 3 (Maite):** en cada app, poner en Runtime Manager estas propiedades:
  - `env=cloud`.
  - Las de `cloud-endpoints`.
  - Las URLs públicas de las apps a las que llama.
  - Los secretos y `encryption.key`, como propiedades protegidas.
- [ ] **Paso 4 (Maite):** en API Manager, registrar xapi-online-store y mcp-online-store y aplicar Client ID Enforcement. Crear tres aplicaciones cliente: tienda, agente y aprobador. Poner el `client_id` del aprobador en `approval.approverClientIds` de papi-order-requests.
- [ ] **Paso 4b (Maite, si alcanza el tiempo):** aplicar la política Rate Limiting – SLA Based (o Rate Limiting) en las mismas dos APIs, con un límite por aplicación cliente (sugerido: 60 por minuto). La PoC pide client_id y límite de uso; si no se hace, queda como pendiente en el diseño.
- [ ] **Paso 5:** verificar. Esperado:
  - las 10 apps quedan en `Running`;
  - una llamada sin `client_id` a la xapi responde 401;
  - si se aplicó el paso 4b, la llamada 61 dentro del mismo minuto responde 429.

### Tarea 28: Las cuatro escenas en CloudHub

**Archivos:** crear `tests/postman/cloud.postman_environment.json.example`. El archivo real lleva las URLs y los `client_id` de la org y no se versiona.

- [ ] **Paso 1:** correr `tests/run-e2e.ps1 -Environment cloud`. Esperado: 0 aserciones fallidas.
- [ ] **Paso 2:** probar el agente con MCP Inspector contra la URL de mcp-online-store en CloudHub. Esperado: las mismas 4 escenas.
- [ ] **Paso 3:** sin commit por ahora. El mensaje `test: escenas de punta a punta en CloudHub` se usa en la tarea 30, en `feat/e2e-tests`.

---

## Fase 10 · Cierre

### Tarea 29: Repositorio listo para clonar

**Archivos:**
- Modificar: `README.md`, con estas secciones:
  - requisitos;
  - arranque local en 5 pasos;
  - Salesforce y MagicBell;
  - ambiente nube, con "Apagar los túneles";
  - retiro del entorno (`teardown`);
  - estructura;
  - problemas comunes;
  - pendientes y desviaciones respecto a la final (enlace al diseño).
- Modificar: `.gitignore`.
- Crear: `docs/README.md`, como índice de las decisiones, los diagramas y el guion.

- [ ] **Paso 1:** buscar secretos en lo versionado con `git ls-files | xargs grep -nEi "password|secret|token|BEGIN (RSA )?PRIVATE KEY|ACCESS_TOKEN=|ngrok-free|trycloudflare|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}.*orgId"`. Esperado: solo nombres de propiedades y ejemplos, ningún valor real.
- [ ] **Paso 2:** clonar la rama en una carpeta temporal dentro de `tmp/` y seguir el README hasta compilar las 10 apps y levantar `start-infra`. Esperado: funciona sin archivos que no estén en el repositorio, salvo los `.local` que el README pide crear.
- [ ] **Paso 3:** sin commit por ahora. El mensaje `docs: guía de arranque y cierre de la v1` se usa en la tarea 30, en `feat/closing`.

### Tarea 30: [Maite aprueba] Una rama por pieza e integración a `main`

**Precondición:** las cuatro escenas pasan en local (tarea 25) y en CloudHub (tarea 28), y la tarea 29 está hecha.

**Ramas y orden de integración** (cada una sale de `main` ya integrado con las anteriores):

| # | Rama | Contenido |
|---|---|---|
| 1 | `feat/repository` | `.gitignore`, carpetas `libs/ data/ demo/ tests/` con su README, salida de las copias `*-tih` de la raíz, borrados de la tarea 1, `docs/superpowers/` |
| 2 | `feat/local-infra` | `infra/` (salvo túneles), `data/`, `demo/` y los scripts de operación y retiro (tareas 6 a 9) |
| 3 | `feat/common-fragment` | `specs/fragments/poc-common/` y `specs/tools/` (tarea 2) |
| 4 | `feat/resilience-library` | `libs/poc-resilience/` (tarea 10) |
| 5–8 | `feat/sapi-oracle-core`, `feat/sapi-price-providers`, `feat/sapi-sftp-orders`, `feat/sapi-crm` | `specs/<app>/` y `apps/<app>/` (contrato primero, luego la app; incluye el renombre desde `apps/<app>-tih`) |
| 9–12 | `feat/papi-customers`, `feat/papi-orders`, `feat/papi-order-requests`, `feat/papi-notifications` | igual que las System APIs |
| 13–14 | `feat/xapi-online-store`, `feat/mcp-online-store` | igual, con `specs/mcp-online-store/` |
| 15 | `feat/diagrams` | `docs/diagrams/` (tarea 5) |
| 16 | `feat/cloud` | `infra/tunnels/` (tarea 26) |
| 17 | `feat/e2e-tests` | `tests/` (tareas 25 y 28) |
| 18 | `feat/closing` | `README.md`, `docs/README.md` y los ajustes finales de la tarea 29 |

- [ ] **Paso 1:** escribir `tmp/branch-map.json` (ruta → rama) y comprobar que cada archivo cambiado del árbol de trabajo (`git status --porcelain`) cae en exactamente una rama. Esperado: 0 archivos sin rama y 0 en dos ramas.
- [ ] **Paso 2 (Maite):** revisar la tabla y el mapa, y aprobar.
- [ ] **Paso 3:** por cada rama, en orden: `git switch -c feat/<pieza> main`, `git add -A -- <rutas>`, commit con los mensajes de sus tareas (sin `Co-Authored-By` ni mención de Claude) y `git switch main`. El resto de los cambios sigue en el árbol de trabajo.
- [ ] **Paso 4:** verificar cada rama de app aislada: `git worktree add tmp/verify feat/<app>` y `mvn -B -f tmp/verify/apps/<app>/pom.xml clean test`. Esperado: `BUILD SUCCESS` con la misma cantidad de pruebas que en el árbol completo. Después `git worktree remove tmp/verify`.
- [ ] **Paso 5 (Maite):** integrar cada rama a `main` en el orden de la tabla: `git merge --no-ff feat/<pieza>` en local, o push de las ramas y pull requests en GitHub, como prefiera. Se integra cuando la pieza cumple sus criterios de aceptación.
- [ ] **Paso 6:** al terminar, `git status --porcelain` no muestra cambios (solo lo ignorado), y `main` compila las 10 apps.
- [ ] **Paso 7 (Maite):** push de `main` y de las ramas al repositorio que se decida (P1). `poc/agentica-v1` queda como rama de trabajo y se puede borrar.
