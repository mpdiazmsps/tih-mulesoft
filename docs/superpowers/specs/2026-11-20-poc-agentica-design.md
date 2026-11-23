# PoC «Integración en la era agéntica» · v1 · Diseño y decisiones

**Fecha:** 20 de noviembre de 2026
**Fuente de verdad:** `docs/final integracion-en-la-era-agentica-poc.html` (presentación final de SPS: propuesta y plan de trabajo). Las secciones citadas abajo son de ese documento.
**Historia:** `docs/SPS Tech is Now.html` (primera propuesta) y `docs/respuestas-preguntas-abiertas-poc.html` (respuestas del equipo de integración).
**Base de código:** commit `6f220ee` (7 apps `*-tih`), respaldo completo en `C:\Users\MaiteDiaz\AnypointStudio\mule-skills-demo-respaldo-2026-11-20.zip`.

## Para qué

Maite construye ahora una primera versión completa y funcional de la PoC, siguiendo la presentación final, para entregarla a Solutions Offering. Así sus cambios se aplican sobre algo que ya corre.

## Hecho cuando

1. Las cuatro escenas de la sección I.3 corren de punta a punta **en local**, con Mule en Studio y las dependencias en Docker. Por la xapi (tienda) y por el servidor MCP (agente) dan el mismo resultado, y no hace falta intervenir a mano.
2. Las mismas cuatro escenas corren **en CloudHub 2.0**, en una org trial de Maite. Las apps están en CloudHub y las dependencias se exponen desde la máquina de Maite con túneles.
3. Los contratos RAML están ajustados al diseño final y publicados en Exchange. Cada app toma su contrato de Exchange, sin copias dentro de la app.
4. Hay diagramas de secuencia (los recorridos de II.2) y diagramas C4 (contexto, contenedores y componentes).
5. Cualquier colaborador clona el repositorio, sigue el README y levanta todo en su máquina. Lo que no es indispensable queda en `.gitignore`.

## No objetivos (v1)

- **Infraestructura en la nube:** no se crea infraestructura en OCI, AWS ni GCP.
- **Observabilidad:** ni la tienda de Observabilidad ni la traza con OCI APM, que son de la v1.1 de SPS.
- **Vista web de aprobación:** se aprueba desde Postman, como permite la sección 7 de la final.
- **Automatización:** no hay CI.
- **Producción:** sin alta disponibilidad ni volumen de producción. Tampoco compras, pagos, envíos ni firmas reales (sección I.5, "Fuera").

## Anti-objetivos (fallaría aunque "funcione")

- Tocar `oracle-store` o `ngrok-oracle`.
- Que un secreto llegue al repositorio.
- Que la demo dependa de APIs públicas de terceros: los proveedores son simuladores propios (I.5).
- Que el agente pueda aprobar o aplicar una corrección por su cuenta.

## Lo que se toma tal cual de la final

Se respetan sin cambios:
- **Servicios:** las operaciones, reglas y criterios de aceptación de las 12 piezas (plan de trabajo, sección 4 · Servicios).
- **Datos del guion:** los de la sección 6: 5 pedidos, 4 clientes, 3 productos y precios en MXN.
- **Contratos:** las tres oleadas (sección 2).
- **Repositorio:** la estructura y la forma de trabajo (sección 3: contrato primero, una rama por pieza y pruebas en local).
- **Decisiones de diseño:** las de III.1, salvo las desviaciones de abajo.

## Decisiones tomadas en la conversación (20-nov)

| # | Decisión |
|---|---|
| C1 | Maite construye toda la PoC: las 12 piezas, las dependencias locales, Salesforce y MagicBell. |
| C2 | **Opción B: una sola instancia de Oracle con dos esquemas.** `STORE_APP` es el ERP e `INTEGRATION_APP` guarda las solicitudes. |
| C3 | RabbitMQ sigue en local y se expone por túnel. CloudAMQP (plan gratuito) queda como alternativa opcional, a decidir al final. |
| C4 | **Túneles hacia CloudHub:** ngrok gratuito con 3 túneles TCP (Oracle, RabbitMQ y SFTP). WireMock sale por un túnel HTTP gratuito de Cloudflare (`cloudflared`). El control de demostración y el simulador de logística no necesitan túnel. |
| C5 | **Org trial de Anypoint:** la crea Maite. También publica en Exchange y despliega en CloudHub 2.0. |
| C6 | Los contratos se publican en Exchange. Las apps nuevas se crean desde Exchange y las existentes cambian a consumir su contrato desde Exchange, para que queden sincronizados. |

## Decisiones mías, para que Maite las revise

| # | Decisión | Por qué |
|---|---|---|
| D1 | Se trabaja en la rama `poc/agentica-v1` de este repositorio. `main` queda como la base (`6f220ee`). | Sin pérdida: la base sigue intacta y está el respaldo zip. |
| D2 | **Estructura del repositorio de la final** (`apps/ libs/ specs/ data/ infra/ demo/ tests/ docs/`): nombres sin `-tih` y contenedores con prefijo `poc-`. | Es lo que pide la sección 3. El prefijo evita choques con los contenedores `tih-*` de tu máquina. |
| D3 | **Copias de Studio en la raíz:** Studio importa directo de `apps/`. Las copias `*-tih/` de la raíz y `sapi-stores/` quedan en `.gitignore` y ya no se sincronizan. | Con los nombres nuevos, las copias quedarían viejas. **Esto cambia tu preferencia de replicar en la raíz.** |
| D4 | **Contratos.** `specs/` es la fuente que se edita. En Exchange se publica un fragmento `poc-common` (tipos y traits) y 9 especificaciones RAML. El contrato MCP (`specs/mcp-online-store/tools.yaml`) no es RAML y no se publica como API REST. Las rutas `uses` del repositorio son relativas; el script de empaquetado las reescribe a `exchange_modules/<orgId>/...`. | El repositorio no depende de una org en particular: SPS puede republicar en su org. |
| D5 | **Contratos completamente en inglés** (decisión de Maite, 20-nov, reemplaza la propuesta en español): nombres de campos en camelCase (`orderId`, `customer`, `lines`, `dispatchNote`, `quotes`, `localPrice`), valores de enums (`RECEIVED`, `STOCK_SHORTAGE`, `ON_HOLD`), descripciones y `displayName`, también los nombres de las herramientas MCP (`get_order`, `list_exceptions`, `propose_alternatives`, `request_correction`, `get_request`). Los datos del guion en los ejemplos se quedan como son. Los nombres de archivos y carpetas de logística (`remision_<orderId>_<n>.csv`, `/despachos/...`) y `data/scenario.json` no son contrato y no cambian. | La final muestra ejemplos en español, pero Maite prefiere el estándar en inglés. |
| D5b | **Implementación en inglés** (Maite, 21-nov): en las apps y bibliotecas Mule van en inglés los nombres (`doc:name`, flujos, variables), `doc:description`, comentarios, mensajes de log y mensajes de error. Los datos del guion siguen en español. | Coherencia con los contratos (D5). |
| D6 | **Puertos locales:** xapi 8080, papi-customers 8082, papi-orders 8083, papi-notifications 8084, papi-order-requests 8085, mcp-online-store 8086, sapi-oracle-core 8091, sapi-sftp-orders 8092, sapi-price-providers 8093 y sapi-crm 8094. En CloudHub, todas usan `http.port` 8081. | Se conservan los de la base. |
| D7 | **Corrección aplicada una sola vez.** Se garantiza con `INVENTORY_MOVEMENTS.REFERENCE UNIQUE` (la referencia es la llave de la solicitud). | Hace cumplir "aplicar dos veces mueve el stock una vez", aun con dos llamadas a la vez. |
| D8 | **Eventos:** `order.registered` se publica solo cuando el pedido se confirma con stock completo y su remisión ya salió. papi-order-requests publica `approval.requested` y `correction.applied`. | Es la lectura de la regla de papi-orders en la sección 4. |
| D9 | **Reintento solo ante fallas de conexión, no cuando se agota el tiempo.** | 2 s + 2 s de reintento rompería el "menos de 3 s" con el proveedor C en 5 s. |
| D10 | **Quién puede aprobar:** la xapi pasa a papi-order-requests el `client_id` de quien llama (cabecera `x-client-app`). papi-order-requests compara contra `approval.approverClientIds` y responde 403 si no es un aprobador. En CloudHub, Client ID Enforcement valida además la credencial. | En local no hay API Manager, y aun así el criterio "el agente no puede aprobar" tiene que cumplirse. |
| D11 | **Destino de los correos:** la propiedad `notifications.redirectTo` manda todos los correos de la demo a la bandeja de quien presenta. | Los contactos del guion tienen correos ficticios (`*.ejemplo.mx`). |
| D12 | **Simulador de logística:** un contenedor `alpine` comparte el volumen del SFTP. Cada 5 s mueve lo de `pendientes` a `firmadas`, o a `rechazadas` si el pedido está en `data/logistics-rules.json`, y deja un acuse `*.acuse.json` al lado. | Es lo más simple que cumple "el estado es la carpeta". |
| D13 | **Control de demostración:** scripts `demo/control.ps1` y `demo/control.sh` con las acciones `slow-c`, `normal-c`, `sftp-down`, `sftp-up` y `reset`. El retardo del proveedor C se pone por la API de administración de WireMock. | Funciona igual en local y en la nube, porque las dependencias siempre están en tu máquina. |
| D14 | **Diagramas en Mermaid** (`.mmd` y `.svg`): de secuencia, y C4 de contexto, contenedores y componentes de papi-orders. | Sigue el formato de los diagramas que ya están en `docs/diagrams/`. |
| D15 | **Datos que la final no define.** Nombres de producto: "Producto 100", "Producto 200" y "Producto 300". IDs en los proveedores: SKU-100 A 7, B 122 y C 3 (vienen de la final); SKU-200 A 8, B 123 y C 4; SKU-300 C 5. Correos y teléfonos ficticios. | Es lo mínimo necesario para sembrar los datos. |
| D16 | **CloudHub 2.0:** espacio compartido, 0.1 vCore y 1 réplica por app. Las direcciones de los túneles van en las propiedades de Runtime Manager y los secretos como propiedades protegidas. | Con 1 réplica, el candado en memoria del scheduler basta. Cambiar un túnel no obliga a recompilar. |
| D17 | **Salesforce desde scripts:** un proyecto `sf` en `infra/salesforce/` agrega `Segmento__c`, `External_Id__c` y un permission set, y hace upsert de los 4 contactos por `External_Id__c`. La autenticación de Mule es JWT con una aplicación conectada. | Es la sección III.4 de la final ("levantar el CRM"). |
| D18 | **Un solo aviso al cliente por corrección.** Al aplicar una corrección (REPONER o REEMITIR), papi-orders **no** publica `order.registered`. papi-order-requests publica `correction.applied` una sola vez, al quedar `COMPLETADA`, y ese es el único evento que produce el correo al cliente. `order.registered` sale solo del ciclo normal de confirmación (D8). | Ajuste de Maite (20-nov): con los dos eventos el cliente recibiría dos correos por la misma corrección. |
| D19 | **orgId literal.** Decisión de Maite (21-nov): el orgId `9885f017-0660-4c80-a27f-eb006d124bd8` va escrito tal cual en el `<groupId>` de cada pom (apps y libs), en la dependencia del contrato (`classifier raml`, `type zip`) y en el `api` de APIkit: `api="resource::9885f017-…:<asset>:<versión>:raml:zip:<asset>.raml"`, como lo genera Studio. Sin propiedad `anypoint.orgId` ni archivos filtrados. Cambiar de org o de versión del contrato: editar pom e `interface.xml` (y `data/org.local.json`). | La cuenta de Anypoint es la de la PoC; el valor literal compila igual en Maven y en Studio, sin configuración extra. |
| D20 | **Retiro programático** con `infra/scripts/teardown`: túneles, contenedores y volúmenes `poc-*`, archivos generados, contactos `POC-*` y metadatos de Salesforce (cambios destructivos). Lo que no se puede borrar por script se lista al final. | La final pide "levantamiento y retiro programáticos". |
| D21 | **Contraseñas fuertes para la nube.** Antes de abrir un túnel, `rotate-cloud-secrets` reemplaza las contraseñas de ejemplo de Oracle, RabbitMQ y SFTP por valores aleatorios de 32 caracteres, y `start-tunnels` se niega a abrir con contraseñas de ejemplo. El README pide apagar los túneles cuando no se usen. | Ajuste de Maite (20-nov): los túneles exponen las dependencias a internet. |
| D22 | **Un correo no se repite en Salesforce.** Matching rule de correo exacto y duplicate rule con acción Block (al crear y editar, también por API), desplegadas con el proyecto `sf` de la tarea 9. sapi-crm traduce `DUPLICATES_DETECTED` a 409 `CONTACT_ALREADY_EXISTS`; papi-customers conserva la búsqueda previa y traduce ese 409 a `CUSTOMER_ALREADY_EXISTS`, el código de la final. `teardown` desactiva y borra las dos reglas. | Pedido de Maite (20-nov): la búsqueda previa sola no cubre dos altas simultáneas. **Ajuste 22-nov:** la regla de duplicados no ve inserciones simultáneas (en vivo dos altas a la vez crearon dos contactos). Se agregó `Contact.Email_Key__c` (texto, **único**, correo en minúsculas) que llena sapi-crm: Salesforce rechaza la segunda con `DUPLICATE_VALUE` y sapi-crm responde el mismo 409. |
| D23 | **MagicBell con la cuenta personal de Maite en la v1.** La final pide el token de un proyecto del equipo; hasta que el equipo tenga su infraestructura se usa el token de la cuenta personal, cifrado en papi-notifications. Cambiarlo es crear el proyecto (pasos en `infra/magicbell/README.md`), poner su token y volver a cifrarlo. | Decisión de Maite (20-nov). |

## Desviaciones respecto a la final (para avisar a SPS)

1. **Una sola Oracle** con dos esquemas, en lugar de dos instancias (C2). La final pide una instancia Oracle separada para la integración; aquí es otro esquema en la misma instancia. El estado de la integración sigue fuera del esquema del ERP:
   - `STORE_APP` (ERP): `ORDERS`, `ORDER_ITEMS`, `INVENTORY`, `INVENTORY_PROVIDERS` e `INVENTORY_MOVEMENTS`. Sin `CUSTOMERS` (los clientes viven en Salesforce) y sin remisiones (viven en el SFTP).
   - `INTEGRATION_APP`: `ORDER_REQUESTS` y `ORDER_REQUEST_EVENTS`.
   - Ningún usuario tiene permisos sobre el otro esquema. sapi-oracle-core se conecta solo como `STORE_APP`; papi-order-requests, solo como `INTEGRATION_APP`. Se confirma en la tarea 6.
2. **Dependencias en la máquina de Maite con túneles**, en lugar de OCI, AWS, GCP y una VM (C4). La demo en la nube funciona mientras esa máquina y los túneles estén encendidos.
3. **Org trial personal:** vence a los 30 días. Para que otro colaborador compile, necesita acceso al Exchange de esa org (ver P3).
4. **MagicBell con la cuenta personal de Maite** en la v1, en lugar del proyecto del equipo (D23).
5. **Salesforce con una aplicación de cliente externo** (la org nueva no ofrece aplicaciones conectadas clásicas); el flujo JWT es el mismo.

## Pendientes conocidos (no bloquean la v1)

| # | Pendiente | Situación en la v1 |
|---|---|---|
| N1 | **Rate limiting.** La final pide client_id y límite de uso. | Client ID Enforcement en CloudHub (tarea 27). El límite de uso se agrega en API Manager en la tarea 27, paso 4b, si alcanza el tiempo. |
| N2 | **Políticas en local.** | En local no hay API Manager: el 401 sin credenciales solo se demuestra en CloudHub. En local, el 403 al aprobar depende de la cabecera `x-client-app` (D10). |
| N3 | **Gobierno de las herramientas MCP.** | `specs/mcp-online-store/tools.yaml` no es RAML: se valida con un esquema JSON, no con el ruleset de gobernanza. |
| N4 | **Túneles sin lista de IPs.** La final pide restringir el acceso a las dependencias en la nube. | ngrok gratuito no filtra por IP. Se mitiga con contraseñas fuertes (D21), SFTP solo con llave y apagando los túneles cuando no se usan. |

## Forma de trabajo

- Ningún commit durante las tareas: se trabaja sin commit en `poc/agentica-v1` hasta validar en local y en CloudHub (decisión de Maite, 20-nov).
- Al final, una rama por pieza (`feat/<pieza>`, sección 3 de la final) que se integra a `main` en orden de dependencias, con la aprobación de Maite (tarea 30). El push lo hace Maite.
- Riesgo: sin commits intermedios, el trabajo solo vive en disco. Se sugiere un respaldo zip al cerrar cada fase.
- Entrega: lunes, con la v1 en local y en CloudHub 2.0 (la fase 9 se mantiene).

## Preguntas abiertas (el plan avanza con el valor por defecto)

| # | Pregunta | Por defecto mientras tanto |
|---|---|---|
| P1 | ¿El repositorio final es `SPS-Tech-is-now/mule-agentic-integration-poc` o el tuyo? | Se construye en este repo, en la rama D1, y tú haces el push al que se decida. |
| P2 | ¿Los nombres de campos van en español (D5)? | **Cerrada (20-nov):** todo en inglés. |
| P3 | Depender de Exchange de una org trial obliga a los colaboradores a tener acceso a ella, y deja de funcionar cuando vence. ¿Se acepta? | Sí, por la v1. Cuando SPS tenga su org, se republica y se cambian las versiones con la skill `manage-api-version`. |
| P4 | ¿Qué cliente MCP se usa en la demo? | MCP Inspector para probar. El agente de la demo se elige en el ensayo. |
| P5 | ¿Se versionan las presentaciones HTML de SPS en `docs/`? Son de uso interno. | No, siguen en `.gitignore`. |
| P6 | ¿La org trial tiene vCores suficientes para 10 apps de 0.1? | Se verifica en la tarea 4, al crear la org, y otra vez en la tarea 27 antes de desplegar. |
| P7 | ¿Tu ngrok gratuito permite túneles TCP? Puede pedir una tarjeta. | Se verifica en la tarea 26. Si no los permite, la salida es ngrok de pago o CloudAMQP con otro arreglo. |
