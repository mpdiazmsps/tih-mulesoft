# Guía de la demo, explicada

Para quien presenta: qué se construyó, cómo funciona por dentro y qué mostrar en cada momento. Se acompaña de la
colección **`tests/postman/poc-demo-guiada.postman_collection.json`** (ambiente **PoC local**), que sigue este mismo
orden, y del guion corto `docs/guion-demo.md`.

## 1. La idea en una frase

> Un agente es tan confiable como la integración que tiene detrás.

La PoC no vende un agente: vende la capa que deja a cualquier canal (la tienda, un agente de IA) trabajar con cinco
sistemas distintos **sin unificarlos ni copiar datos**, y **sin riesgo**: el agente consulta, propone y pide; una
persona decide.

## 2. Cómo está armada (API-led, tres capas)

```
 Canales        Tienda / Postman (REST)                  Agente de IA (MCP)
                        │                                       │
 Experience     xapi-online-store :8080                 mcp-online-store :8086
                        └──────────────┬────────────────────────┘
 Process        papi-customers :8082   papi-orders :8083   papi-order-requests :8085   papi-notifications :8084
                        │                 │   │   │   │            │   (Oracle INTEGRATION_APP)    │ (RabbitMQ → MagicBell)
 System         sapi-crm :8094   sapi-oracle-core :8091   sapi-sftp-orders :8092   sapi-price-providers :8093
                        │                 │                     │                        │
 Sistemas       Salesforce        Oracle STORE_APP (ERP)   SFTP + operador logístico   Proveedores A, B (REST) y C (SOAP)
```

- **System APIs:** una puerta por sistema. Ocultan la tecnología: SOQL, SQL, archivos CSV por SFTP, SOAP.
- **Process APIs:** la lógica de negocio: confirmar pedidos, componer el Pedido 360, detectar excepciones, manejar
  solicitudes, avisar por correo. Cada sistema conserva su dato; papi-orders **compone al consultar**.
- **Experience APIs:** una por canal. La xapi (REST, 14 operaciones) para la tienda y el aprobador; el servidor MCP
  (5 herramientas en lenguaje de negocio) para el agente. Las dos llaman a las mismas Process APIs, por eso ven lo
  mismo.
- **Eventos:** RabbitMQ (exchange `orders.events`) desacopla los avisos: papi-orders y papi-order-requests publican;
  papi-notifications escucha y manda el correo por MagicBell.
- **Quién llama:** cada canal manda su `client_id` (`tienda-web`, `aprobador-tienda`, `agente-mcp`). Viaja a la capa de
  proceso como `x-client-app`: así se sabe quién pidió y solo el aprobador puede aprobar. En la nube, API Manager
  aplica Client ID Enforcement.

## 3. Los datos del guion

| Pedido | Cliente (Salesforce) | Segmento | Líneas | Situación |
|---|---|---|---|---|
| PED-1001 | Ferretería Angelópolis | Regular | SKU-300 × 2 | `RECEIVED`: sin precio y su proveedor (C) no cotiza ese producto |
| PED-1002 | Constructora Cumbres | Estratégico | SKU-100 × 5 | `CONFIRMED`, faltante: hay 2 de 5. Es el que corrige el agente |
| PED-1003 | Constructora Cumbres | Estratégico | SKU-200 × 3 | `CONFIRMED`, remisión firmada: el caso sin problemas |
| PED-1004 | Grupo Hotelero Tapatío | Estratégico | SKU-200 × 1 | `CONFIRMED`, remisión rechazada: "Dirección incorrecta" |
| PED-1005 | Papelería Coyoacán | Regular | SKU-100 × 4 | `CONFIRMED`, faltante |

Productos: SKU-100 (stock 2, último precio de A 189; cotizan A 189, B 194, C 175), SKU-200 (stock 40, precio local
250), SKU-300 (stock 15, sin precio). Los ids reales son UUID (`10000000-0000-4000-8000-000000001002` es PED-1002) y
los clientes tienen su Id de Salesforce.

## 4. Los estados que vas a ver

| Qué | Estados | Significado |
|---|---|---|
| Pedido (ERP) | `RECEIVED` → `CONFIRMED` (o `REJECTED`) | Nace recibido; el ciclo lo confirma con precio |
| Remisión (logística) | `ON_HOLD`, `PENDING`, `SIGNED`, `REJECTED`, `UNKNOWN` | Sin remisión aún (faltante) · en `/despachos/pendientes` · firmada con acuse · rechazada con motivo · logística no respondió |
| Excepción | `STOCK_SHORTAGE`, `UNCONFIRMED`, `DISPATCH_REJECTED` | Faltante · sigue recibido · remisión rechazada |
| Origen del precio | `LOCAL`, `LAST_PRICE`, `QUOTE` | Precio de la tienda · último precio del proveedor preferente · cotización en vivo |
| Solicitud de corrección | `PENDING` → `APPROVED` → `APPLYING` → `COMPLETED` o `FAILED`; desde `PENDING`: `REJECTED` o `EXPIRED` | Cada paso queda en la historia con quién y cuándo |
| Fuentes del Pedido 360 | `OK`, `UNAVAILABLE`, `"3 of 3"`, `"2 of 3"` | Qué sistema respondió y cuántos proveedores cotizaron |

## 5. Antes de presentar

1. Las 10 apps `DEPLOYED` en Studio (`poc-mule`) y los contenedores `poc-*` arriba.
2. `.\demo\control.ps1 reset` (datos del guion y segmentos de Salesforce).
3. Postman: importa `poc-demo-guiada` y el ambiente `local.postman_environment.json`; elige **PoC local**; corre la
   carpeta **0 Preparación** (calienta las conexiones: la primera consulta tras arrancar tarda unos 5 s).
4. Pestañas abiertas: Postman, el agente (Claude Code con el MCP, o el MCP de Postman), Gmail, MagicBell, la consola
   de RabbitMQ, Salesforce y una terminal en la raíz del repo.
5. **RabbitMQ, una sola vez:** la consola es `http://localhost:15673` con el usuario administrador de
   `infra/rabbitmq/credentials.local` (`RABBITMQ_ADMIN_USER` y `RABBITMQ_ADMIN_PASSWORD`). Si no entra, corre
   `.\infra\scripts\start-infra.ps1` en PowerShell (en Git Bash: `./infra/scripts/start-infra.sh`); crea los usuarios.
   Si no existe la cola **`demo.eventos.q`**, cárgala desde las definiciones (solo agrega lo que falta):
   `docker exec poc-rabbitmq rabbitmqctl import_definitions /etc/rabbitmq/definitions.json`.
   Nadie la consume: guarda una copia de cada evento (hasta 200) para poder mostrarlo; el reset la vacía.

Para revisar registros durante la demo, en la terminal:

```powershell
.\demo\inspect.ps1 pedidos        # ORDERS con sus líneas, precio y origen del precio
.\demo\inspect.ps1 inventario     # stock, precio local y último precio por proveedor
.\demo\inspect.ps1 movimientos    # salidas y reposiciones con su referencia única
.\demo\inspect.ps1 solicitudes    # ORDER_REQUESTS: estado, quién pidió, quién decidió y la llave
.\demo\inspect.ps1 historia       # ORDER_REQUEST_EVENTS: cada transición con actor y hora
.\demo\inspect.ps1 sftp           # remisiones en pendientes, firmadas y rechazadas, con sus acuses
.\demo\inspect.ps1 colas          # mensajes y consumidores de cada cola
```

(Solo lee. Usa `sqlplus` dentro del contenedor, sin credenciales. Con SQL Developer: `localhost`, el puerto de
`poc-oracle`, servicio `FREEPDB1`, usuario `STORE_APP` o `INTEGRATION_APP`.)

## 6. Parte 1 · El camino feliz (cómo funciona)

Carpeta **1 Camino feliz** de la colección. Cuenta la historia de un cliente nuevo que compra.

| Paso | Petición | Qué pasa por dentro | Qué mostrar |
|---|---|---|---|
| 1 | 1.1 Catálogo | xapi → papi-orders → sapi-oracle-core. El precio es el local o el último del proveedor preferente: **el catálogo nunca cotiza en vivo** | SKU-200 con 40 piezas a 250 |
| 2 | 1.2 Registrar cliente | xapi → papi-customers (busca el correo) → sapi-crm → Salesforce crea el contacto | 201 con el Id de Salesforce. En Salesforce, *Contacts*: "Mueblería Del Bajío", segmento Regular |
| 3 | 1.3 Registrarlo otra vez | La búsqueda lo encuentra; y si llegaran dos altas a la vez, el campo único `Email_Key__c` de Salesforce rechaza la segunda | 409 `CUSTOMER_ALREADY_EXISTS`: nada se duplicó |
| 4 | 1.4 Clientes | Lista paginada desde Salesforce (cuida el límite diario de su API) | El cliente nuevo aparece |
| 5 | 1.5 Crear pedido | papi-orders valida al cliente con papi-customers y registra el pedido `RECEIVED` en el ERP. Responde en menos de 1 s | `RECEIVED`. `inspect pedidos`: la fila nueva sin total |
| 6 | 1.6 Pedidos recibidos | — | El pedido nuevo junto a PED-1001 (que nunca se confirma: su producto no tiene precio) |
| 7 | 1.7 Correr el ciclo | El **ciclo de confirmación** corre solo cada 60 s; esto lo adelanta. Un solo ciclo a la vez (candado). Por cada `RECEIVED`: precio por línea (LOCAL, LAST_PRICE o QUOTE), confirma, y con stock completo registra la salida de inventario, deja la remisión en el SFTP y publica `order.registered` | 202 `STARTED` |
| 8 | 1.8 Pedido 360 (espera 2-3 s) | Compone ERP + CRM + logística | `CONFIRMED` a 250, remisión `PENDING` o ya `SIGNED`, cliente desde Salesforce |
| 9 | 1.9 Catálogo después | — | SKU-200 bajó 2 piezas. `inspect movimientos`: `OUTBOUND` con referencia `<pedido>-out-<artículo>` |
| 10 | 1.10 La remisión en logística | sapi-sftp-orders lee los archivos. El simulador del operador firma lo que llega a `/pendientes` y deja un acuse `.acuse.json` | `remision_<pedido>_1.csv` firmada. `inspect sftp`: el CSV y su acuse en `/firmadas` |

**El aviso al cliente:** papi-orders publicó `order.registered`. Muestra:
- **RabbitMQ:** *Queues → `demo.eventos.q` → Get messages*: el evento con el pedido, el cliente, las líneas y el total.
  En `orders.registered.q` no se queda: papi-notifications lo consumió (columna *consumers* 4; *Message rates*).
- **papi-notifications:** buscó el correo del cliente en papi-customers y mandó un *broadcast* a MagicBell. En el
  dashboard de MagicBell (*Broadcasts*) aparece con su título.
- **Gmail:** "Tu pedido PED-xxxx está confirmado" saludando a Mueblería Del Bajío. Llega a tu bandeja porque los
  correos de la demo se redirigen (`notifications.redirectTo`, D11): los clientes del guion tienen correos ficticios.
- **Si falla el envío:** el mensaje se reintenta 3 veces y luego va a `orders.registered.dlq` (cola de fallidos).

## 7. Parte 2 · Las cuatro escenas

Carpetas **2 a 5** (son las mismas peticiones y aserciones de `poc-e2e`, que `tests/run-e2e` corre solas). El agente
puede ser Claude Code con el MCP (preguntas en lenguaje natural) o el MCP de Postman (eliges la herramienta). Las
peticiones "Agente: …" de la colección hablan MCP directo; si usas otro cliente, sáltalas, pero corre "Agente: abre
sesión MCP" antes de cualquier otra petición MCP de Postman.

### Escena 1 · ¿Qué requiere mi atención hoy?

- **Agente:** "¿Qué pedidos requieren mi atención hoy?" → herramienta `list_exceptions`.
- **Por dentro:** papi-orders hace **una llamada por lote a cada sistema** (no una por pedido): ERP (pedidos e
  inventario), CRM (clientes con `?ids=`) y logística (remisiones), detecta las tres excepciones y ordena: primero los
  clientes `STRATEGIC`, después por antigüedad.
- **Se ve:** PED-1002, PED-1004 (estratégicos), PED-1001, PED-1005. PED-1003 no aparece.
- **Postman:** 2 → "Pedidos en riesgo (tienda)": la misma lista por la xapi.

### Escena 2 · ¿Qué hago con este pedido?

- **Agente:** "Abre el PED-1002. ¿Qué opciones tengo?" → `get_order` y `propose_alternatives`.
- **Por dentro (Pedido 360):** primero el ERP (el pedido y su inventario) y después, **en paralelo** (scatter-gather):
  CRM, logística y, porque hay faltante, la cotización de los tres proveedores para las 3 piezas que faltan. A y B son
  REST, C es SOAP: sapi-price-providers lo oculta.
- **Se ve:** 2 de 5 disponibles, remisión `ON_HOLD`, A 189, B 194, **C 175 la más barata**, `sources` todo `OK`.
- **Cambio en Salesforce:** `.\demo\control.ps1 cumbres-regular` y "Repite la consulta" → el cliente sale Regular.
  Puedes mostrar el contacto en Salesforce (campo *Segmento*). `cumbres-strategic` lo regresa. Mensaje: no se copia ni
  se sincroniza, se compone al consultar.
- **Postman:** 3a, y después de cada comando 3b y 3c.

### Escena 3 · ¿Y si un sistema falla justo hoy?

- **Comandos:** `.\demo\control.ps1 slow-c` (C tarda 5 s) y `.\demo\control.ps1 sftp-down` (logística apagada).
- **Agente:** "Vuelve a revisar el PED-1002" (una sola vez).
- **Por dentro:** cada rama pasa por **`poc-resilience`**: tiempo límite por fuente (proveedores 1.5 s, CRM y logística
  2 s), un reintento solo si falla la conexión, y circuito por fuente. La respuesta compuesta llega en menos de 3 s y
  marca lo que falta.
- **Se ve:** en unos 2 s, remisión `UNKNOWN`, `logistics: UNAVAILABLE`, `providers: "2 of 3"` (sin C); el resto completo.
- **Después:** `normal-c` y `sftp-up`; espera a que el Pedido 360 vuelva a "3 of 3" antes de la escena 4.
- **Postman:** 4.

### Escena 4 · Lo resuelvo y aviso al cliente

1. **Agente:** "Repón el faltante del PED-1002 con el proveedor más barato" → `request_correction`. El servidor MCP
   toma de las alternativas el artículo, las 3 piezas y el precio de C, y llama a papi-order-requests con la llave
   `PED-1002:RESTOCK:BOR`. La solicitud queda **`PENDING`; no se aplica nada**.
2. **Agente:** "Pídelo otra vez" → la misma solicitud (idempotencia).
3. **Llega al aprobador:** papi-order-requests publicó `approval.requested` (RabbitMQ `demo.eventos.q`) y
   papi-notifications mandó "Solicitud por aprobar…" (MagicBell y Gmail). Postman 5a → "Solicitudes por aprobar".
   `inspect solicitudes`: una fila `PENDING`, pedida por `agente-mcp`, monto 525.
4. **El agente no puede aprobar:** 5b → "El agente intenta aprobar" → 403. Además, el agente no tiene ninguna
   herramienta para aprobar.
5. **La persona aprueba:** 5b → "El aprobador aprueba" → `COMPLETED`. Por dentro: `APPROVED`, `APPLYING`, papi-orders
   aplica la corrección con la llave de la solicitud (reposición de 3, salida de 5, remisión), `COMPLETED` y publica
   `correction.applied`. `inspect historia`: los cuatro pasos con actor y hora.
6. **Aprobar otra vez** → 409.
7. **Resultado (5c):** stock de SKU-100 en 0 (2 + 3 − 5), remisión `…1002-1`, y en Gmail "Corregimos tu pedido
   PED-1002" saludando a Constructora Cumbres: **el único correo al cliente por la corrección** (D18: la corrección no
   publica `order.registered`). `inspect movimientos`: `RESTOCK` con la llave y `OUTBOUND` con `llave-out-artículo`.

## 8. Parte 3 · Lo que hay debajo (para preguntas técnicas)

### Reemisión (carpeta 6)

PED-1004 tiene la remisión `_1` rechazada ("Dirección incorrecta"). 6.1 muestra la excepción y la alternativa
`REISSUE`; 6.2 la pide (llave `demo-reissue-1004`); 6.3 la repite y devuelve la misma; 6.4 el aprobador aprueba y
papi-orders deja la remisión `_2` en el SFTP; el operador la firma. 6.5: remisión `_2` firmada y sin excepción.
`inspect sftp`: `_1` en `/rechazadas`, `_2` en `/firmadas`. Gmail: "Corregimos tu pedido PED-1004 … reemitimos la
remisión …-2".

### Idempotencia (carpeta 7): nada se aplica dos veces

| Candado | Dónde | Cómo se muestra |
|---|---|---|
| Llave de la solicitud | `ORDER_REQUESTS.IDEMPOTENCY_KEY` única. El agente la deriva de pedido + tipo + proveedor | Pedir dos veces → la misma solicitud (5a, 6.3) |
| Transición condicional | `UPDATE … WHERE STATUS = <origen>` y la historia en una transacción | Aprobar dos veces → 409 (5b, 7.1) |
| Llave de la corrección | papi-orders: la misma llave devuelve el mismo resultado sin mover nada | 7.2: 200 con la misma remisión `_2`, no una `_3` |
| Referencia del movimiento | `INVENTORY_MOVEMENTS.REFERENCE` única en el ERP | `inspect movimientos` |
| Cliente único | `Contact.Email_Key__c` único en Salesforce | 1.3 → 409 |
| Un ciclo a la vez | Candado en el Object Store de papi-orders | 1.7 otra vez mientras el ciclo sigue corriendo → 409 `PROCESS_ALREADY_RUNNING` (el ciclo dura pocos segundos) |

### Circuit breaker (carpeta 8)

`poc-resilience` (librería compartida) guarda por fuente las fallas seguidas. Con **3 fallas seguidas** el circuito se
**abre 30 s**: durante ese tiempo no se llama a la fuente y se responde de inmediato `CIRCUIT_OPEN`. Pasados los 30 s,
la siguiente llamada la vuelve a intentar y, si responde, se cierra. Así un proveedor lento no hace lenta toda la
respuesta.

Con 8.1 (sapi-price-providers dice por qué falta cada proveedor):
1. Normal: A 189, B 194, C 175.
2. `slow-c` y cuatro envíos: `BOR no responde: TIMEOUT` (unos 1.8 s) tres veces y luego `CIRCUIT_OPEN` en 0.25 s.
3. `normal-c`: sigue `CIRCUIT_OPEN` (el circuito no sabe que C ya está bien).
4. A los 30 s: C regresa con 175.

Detalle: un reintento solo si falla la conexión (no si tarda); el estado vive en memoria de cada app.

### Las System APIs (carpeta 9)

Para explicar de dónde sale cada dato: el pedido como lo guarda el ERP, el inventario, el contacto en Salesforce, la
remisión leída de los archivos del SFTP y el precio de C por SOAP.

## 9. Qué hay en cada sistema

| Sistema | Qué ver | Dónde |
|---|---|---|
| Oracle `STORE_APP` (ERP) | `ORDERS`, `ORDER_ITEMS`, `INVENTORY`, `INVENTORY_PROVIDERS`, `INVENTORY_MOVEMENTS` | `inspect pedidos/inventario/movimientos` |
| Oracle `INTEGRATION_APP` | `ORDER_REQUESTS` (la solicitud y su llave única), `ORDER_REQUEST_EVENTS` (cada transición) | `inspect solicitudes/historia` |
| Salesforce | *Contacts*: los 4 clientes `POC-*` con *Segmento*, *External Id* y *Email Key* (único). *Setup → App Manager*: la aplicación conectada con JWT que usa sapi-crm. Reglas de duplicados | La org de Developer Edition |
| SFTP de logística | `/despachos/pendientes`, `firmadas`, `rechazadas`: `remision_<pedido>_<n>.csv` y su `.acuse.json` | `inspect sftp` |
| RabbitMQ | Exchange `orders.events` (topic) con `order.registered`, `approval.requested`, `correction.applied`; cada cola con su DLQ; `demo.eventos.q` con copia de todo | `http://localhost:15673`, `inspect colas` |
| MagicBell | *Broadcasts*: un registro por correo enviado | Dashboard de MagicBell |
| Gmail | Los tres avisos: pedido confirmado, solicitud por aprobar, corrección aplicada | La bandeja de `notifications.redirectTo` |

## 10. Orden sugerido (unos 25 minutos)

| Tiempo | Bloque | Carpetas |
|---|---|---|
| 2 min | La idea y la arquitectura (sección 1 y 2) | — |
| 7 min | El camino feliz, con RabbitMQ, MagicBell, Gmail, el ERP, el SFTP y Salesforce | 1 |
| 10 min | Las cuatro escenas con el agente | 2 a 5 |
| 5 min | Reemisión, idempotencia y circuit breaker (si hay preguntas técnicas) | 6 a 8 |
| 1 min | Cierre: "¿Y con mis sistemas?" Cada sistema entra por una sola puerta | — |

Después: `.\demo\control.ps1 reset`. El cliente "Mueblería Del Bajío" se queda en Salesforce; en la siguiente demo el
registro dará 409 (la colección lo acepta). Para empezar de cero, bórralo en Salesforce.

## 11. Preguntas que te pueden hacer

- **¿Por qué no un lago de datos?** Esto no lo reemplaza: compone al consultar, sin copiar ni sincronizar; si cambia un
  dato en su origen (el segmento), la respuesta ya lo refleja.
- **¿Y si el agente se equivoca?** No actúa solo: solo lee o pide; no tiene herramienta para aprobar, la xapi rechaza
  con 403 cualquier aprobación que no venga del aprobador y cada paso queda en la historia.
- **¿Qué pasa si pide dos veces?** La llave hace que sea la misma solicitud; y aunque se aprobara dos veces, papi-orders
  no mueve el inventario dos veces.
- **¿Y si un sistema se cae?** La respuesta llega a tiempo y dice qué falta; el circuito evita insistir con la fuente
  caída; los correos que fallan se reintentan y quedan en la DLQ.
- **¿Sistemas antiguos?** La PoC integra SOAP y archivos por SFTP junto a Salesforce: la antigüedad no frena al agente.
- **¿Es solo una demo?** Los patrones son los de producción; las cifras de desempeño son objetivos de diseño.
