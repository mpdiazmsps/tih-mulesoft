# Diagramas de secuencia de la PoC

Los cuatro recorridos de la sección II.2 de la final. La fuente de cada diagrama es su archivo `.mmd` en esta carpeta; este documento los reúne para verlos en GitHub o VS Code.

## 1. La vida de un pedido

Fuente: [`seq-1-vida-del-pedido.mmd`](seq-1-vida-del-pedido.mmd)

```mermaid
sequenceDiagram
    autonumber
    actor T as Tienda en línea
    participant X as xapi-online-store
    participant PO as papi-orders
    participant PC as papi-customers
    participant CRM as sapi-crm
    participant ERP as sapi-oracle-core
    participant PP as sapi-price-providers
    participant SF as sapi-sftp-orders
    participant MQ as RabbitMQ
    participant PN as papi-notifications
    participant LOG as Logística (SFTP + simulador)
    participant MB as MagicBell

    Note over T,MB: Toda llamada HTTP lleva client_id / client_secret y x-correlation-id

    rect rgb(232, 243, 255)
    Note over T,ERP: Registro: la tienda no espera (menos de 1 s)
    T->>X: POST /orders {customerId, lines}
    X->>PO: POST /orders
    PO->>PC: GET /customers/{customerId}
    PC->>CRM: GET /contacts/{id}
    CRM-->>PC: 200 Customer (Salesforce)
    PC-->>PO: 200
    PO->>ERP: POST /orders {orderId, customerId, currency, lines}
    ERP-->>PO: 201 Order status RECEIVED
    PO-->>X: 201 {orderId, status: RECEIVED}
    X-->>T: 201
    end

    rect rgb(240, 250, 240)
    Note over PO,LOG: Confirmación: scheduler cada 60 s, sin traslapes (o POST /orders/process)
    PO->>ERP: GET /orders?status=RECEIVED
    ERP-->>PO: pedidos RECEIVED
    PO->>ERP: GET /inventory/items?ids=
    ERP-->>PO: stock, localPrice y providers
    alt localPrice > 0
        Note over PO: priceSource LOCAL
    else lastPrice del preferente
        Note over PO: priceSource LAST_PRICE
    else sin precio
        PO->>PP: GET /providers/{abv}/products/{externalId}/price
        PP-->>PO: 200 Quote (o 503: el pedido sigue RECEIVED)
    end
    PO->>ERP: PATCH /orders/{orderId} {status: CONFIRMED, lines}
    ERP-->>PO: 200 Order CONFIRMED (guarda lastPrice)
    alt stock completo
        PO->>ERP: POST /inventory/movements OUTBOUND por línea
        PO->>PC: GET /customers?ids=
        PO->>SF: POST /dispatch-notes
        SF->>LOG: remision_<orderId>_1.csv en /despachos/pendientes
        SF-->>PO: 201 DispatchNote PENDING
        PO->>MQ: order.registered (orders.events)
    else falta stock
        Note over PO: CONFIRMED con faltante: dispatchNote ON_HOLD, sin evento
    end
    end

    rect rgb(255, 246, 230)
    Note over LOG,MB: Logística y aviso
    LOG->>LOG: simulador: pendientes → firmadas (+ acuse) o rechazadas (+ motivo)
    MQ->>PN: order.registered (ACK manual, 2 reintentos, DLQ)
    PN->>PC: GET /customers/{customerId}
    PC-->>PN: nombre y correo
    PN->>MB: POST /broadcasts (correo al cliente)
    end
```

**Puntos clave**

- **Registro sin espera:** la tienda recibe `201 RECEIVED` en menos de 1 s; papi-orders solo valida al cliente en Salesforce (papi-customers → sapi-crm) y crea el pedido en el ERP.
- **Confirmación programada:** cada 60 s, sin traslapes, papi-orders toma los `RECEIVED` y fija el precio: `localPrice`, si no `lastPrice` del preferente, si no cotiza; si el proveedor no responde, el pedido sigue `RECEIVED`.
- **Stock completo:** salidas de inventario, remisión al SFTP y evento `order.registered`. **Falta stock:** queda `CONFIRMED` con la remisión `ON_HOLD` y sin evento (D8).
- **Logística y aviso:** el simulador firma o rechaza la remisión; papi-notifications consume el evento y envía el correo por MagicBell.

## 2. El Pedido 360 (escenas 1 y 2)

Fuente: [`seq-2-pedido-360.mmd`](seq-2-pedido-360.mmd)

```mermaid
sequenceDiagram
    autonumber
    actor A as Agente de IA (cliente MCP)
    participant M as mcp-online-store
    participant PO as papi-orders
    participant ERP as sapi-oracle-core
    participant CRM as sapi-crm
    participant SF as sapi-sftp-orders
    participant PP as sapi-price-providers
    participant PA as Proveedor A (REST)
    participant PB as Proveedor B (REST)
    participant PCs as Proveedor C (SOAP)

    Note over A,PCs: La tienda obtiene lo mismo por xapi-online-store (GET /orders/exceptions y GET /orders/{orderId})

    rect rgb(232, 243, 255)
    Note over A,SF: Escena 1: ¿qué pedidos requieren mi atención?
    A->>M: list_exceptions(limit?)
    M->>PO: GET /orders/exceptions
    par fuentes en paralelo
        PO->>ERP: GET /orders?status=
        ERP-->>PO: pedidos, líneas y stock
    and
        PO->>CRM: GET /contacts?ids= (un solo lote)
        CRM-->>PO: segmento de cada cliente
    and
        PO->>SF: GET /dispatch-notes?status=REJECTED
        SF-->>PO: remisiones rechazadas
    end
    PO->>PO: STOCK_SHORTAGE, UNCONFIRMED, DISPATCH_REJECTED · primero STRATEGIC, luego los más antiguos
    PO-->>M: 200 OrderException[]
    M-->>A: PED-1002, PED-1004, PED-1001, PED-1005
    end

    rect rgb(240, 250, 240)
    Note over A,PCs: Escena 2: ¿qué hago con PED-1002? (menos de 3 s)
    A->>M: get_order(orderId)
    M->>PO: GET /orders/{orderId}
    par
        PO->>ERP: GET /orders/{orderId} y GET /inventory/items?ids=
        ERP-->>PO: CONFIRMED · SKU-100 ordered 5, available 2
    and
        PO->>CRM: GET /contacts/{id}
        CRM-->>PO: Constructora Cumbres · STRATEGIC
    and
        PO->>SF: GET /dispatch-notes/{orderId}
        SF-->>PO: 404 → dispatchNote ON_HOLD
    end
    PO->>PP: POST /quotes [FAK 7, ESC 122, BOR 3]
    par cotización en paralelo (2 s por proveedor)
        PP->>PA: GET /products/7
        PA-->>PP: 189.00 MXN
    and
        PP->>PB: GET /api/v1/products/122
        PB-->>PP: 194.00 MXN
    and
        PP->>PCs: GetArticleById(3)
        PCs-->>PP: 175.00 MXN
    end
    PP-->>PO: {quotes: 3, noResponse: []}
    PO->>PO: alternatives: RESTOCK 3 con BOR (cheapest) · sources 3 of 3
    PO-->>M: 200 Order360
    M-->>A: Pedido 360 de PED-1002
    end
```

**Puntos clave**

- **Escena 1:** `list_exceptions` consulta ERP, CRM y logística en paralelo, detecta `STOCK_SHORTAGE`, `UNCONFIRMED` y `DISPATCH_REJECTED`, y ordena primero a los clientes `STRATEGIC`.
- **Escena 2:** `get_order` arma el Pedido 360 de PED-1002 en menos de 3 s: pedido y stock del ERP, cliente de Salesforce, remisión de logística y cotización en paralelo de los tres proveedores.
- **Alternativa:** reponer 3 de SKU-100 con el proveedor C (175.00 MXN), marcada como la más barata; `sources.providers = "3 of 3"`.
- La tienda obtiene exactamente lo mismo por xapi-online-store.

## 3. Cuando algo falla (escena 3)

Fuente: [`seq-3-fallas.mmd`](seq-3-fallas.mmd)

```mermaid
sequenceDiagram
    autonumber
    actor A as Agente o tienda
    participant PO as papi-orders
    participant PP as sapi-price-providers
    participant PCs as Proveedor C (SOAP)
    participant SF as sapi-sftp-orders
    participant FS as SFTP
    participant POR as papi-order-requests

    rect rgb(255, 240, 240)
    Note over A,PCs: Tiempo límite: el proveedor C responde en 5 s (demo/control slow-c)
    A->>PO: GET /orders/{orderId}
    PO->>PP: POST /quotes [FAK, ESC, BOR]
    PP->>PCs: GetArticleById(3)
    Note over PP,PCs: Tiempo límite de 2 s. Sin reintento: solo se reintenta una falla de conexión (D9)
    PP-->>PO: {quotes: 2, noResponse: [BOR TIMEOUT]}
    PO-->>A: 200 Order360 · sources.providers = "2 of 3" (menos de 3 s)
    end

    rect rgb(255, 246, 230)
    Note over A,FS: Interruptor automático: el SFTP no responde (demo/control sftp-down)
    loop fallas 1 a 3
        PO->>SF: GET /dispatch-notes/{orderId}
        SF->>FS: conexión (3 s)
        FS--xSF: sin respuesta
        SF-->>PO: 503 retryable
    end
    Note over SF: 3 fallas seguidas: interruptor ABIERTO durante 30 s
    A->>PO: GET /orders/{orderId}
    PO->>SF: GET /dispatch-notes/{orderId}
    SF-->>PO: 503 inmediato, sin llamar al SFTP
    PO-->>A: 200 Order360 · dispatchNote.status = UNKNOWN · sources.logistics = UNAVAILABLE
    Note over SF,FS: A los 30 s, una llamada de prueba (semiabierto). Si responde, se cierra solo (demo/control sftp-up)
    end

    rect rgb(240, 250, 240)
    Note over A,POR: Llave única: el agente repite la solicitud de corrección
    A->>POR: POST /order-requests (Idempotency-Key k1)
    POR-->>A: 202 requestId R1
    A->>POR: POST /order-requests (Idempotency-Key k1)
    POR-->>A: 202 requestId R1 (la misma; no se crea otra)
    end
```

**Puntos clave**

- **Tiempo límite:** con el proveedor C a 5 s, la cotización corta a los 2 s y responde con dos de tres; C aparece en `noResponse` (sin reintento por tiempo agotado, D9).
- **Interruptor automático:** tras 3 fallas del SFTP se abre 30 s; las respuestas siguientes no esperan y el Pedido 360 muestra la remisión `UNKNOWN` con `sources.logistics = UNAVAILABLE`.
- **Recuperación:** al volver el SFTP, una llamada de prueba cierra el interruptor solo.
- **Llave única:** repetir la solicitud con la misma `Idempotency-Key` devuelve el mismo `requestId`.

## 4. Corrección con aprobación (escena 4)

Fuente: [`seq-4-correccion.mmd`](seq-4-correccion.mmd)

```mermaid
sequenceDiagram
    autonumber
    actor A as Agente de IA (cliente MCP)
    participant M as mcp-online-store
    participant POR as papi-order-requests
    participant DBI as Oracle INTEGRATION_APP
    participant MQ as RabbitMQ
    participant PN as papi-notifications
    participant MB as MagicBell
    actor AP as Aprobador (Postman)
    participant X as xapi-online-store
    participant PO as papi-orders
    participant ERP as sapi-oracle-core
    participant SF as sapi-sftp-orders

    rect rgb(232, 243, 255)
    Note over A,MB: Solicitud: única acción del agente que escribe datos
    A->>M: request_correction(orderId, RESTOCK, BOR, 3)
    M->>POR: POST /order-requests (Idempotency-Key derivada de orderId, type y provider)
    POR->>DBI: INSERT ORDER_REQUESTS (PENDING, vence en 24 h) + ORDER_REQUEST_EVENTS
    POR->>MQ: approval.requested
    POR-->>M: 202 {requestId, status: PENDING}
    M-->>A: recibido: consulta más tarde
    MQ->>PN: approval.requested
    PN->>MB: POST /broadcasts (correo al aprobador)
    end

    rect rgb(240, 250, 240)
    Note over AP,SF: Aprobación y aplicación
    AP->>X: POST /order-requests/{requestId}/approve
    X->>POR: POST /order-requests/{requestId}/approve (x-client-app = aprobador)
    alt client_id no es aprobador (por ejemplo, el del agente)
        POR-->>X: 403 FORBIDDEN
    else solicitud no PENDING (aprobada, rechazada o vencida)
        POR-->>X: 409 INVALID_TRANSITION
    else aprobador y PENDING
        POR->>DBI: APPROVED → APPLYING (con actor y hora)
        POR->>PO: POST /orders/{orderId}/corrections {type, provider, quantity, key}
        PO->>ERP: POST /inventory/movements RESTOCK 3 (reference = key)
        ERP-->>PO: 201 (o 200 si la reference ya existía: el stock no se mueve dos veces)
        PO->>ERP: POST /inventory/movements OUTBOUND por línea (reference = key-out-itemId)
        PO->>SF: POST /dispatch-notes
        SF-->>PO: 201 DispatchNote PENDING
        Note over PO: No publica order.registered (D18)
        PO-->>POR: 200 corrección aplicada
        POR->>DBI: COMPLETED + historia
        POR->>MQ: correction.applied (una sola vez)
        POR-->>X: 200 OrderRequest COMPLETED
        X-->>AP: 200
    end
    end

    rect rgb(255, 246, 230)
    Note over A,MB: Aviso al cliente y consulta del agente
    MQ->>PN: correction.applied
    PN->>MB: POST /broadcasts (correo a Constructora Cumbres)
    A->>M: get_request(requestId)
    M->>POR: GET /order-requests/{requestId}
    POR-->>M: COMPLETED con su historia (quién y cuándo)
    M-->>A: solicitud completada
    end
```

**Puntos clave**

- **El agente propone:** `request_correction` crea la solicitud `PENDING` (vence en 24 h), publica `approval.requested` y responde `202`; el aprobador recibe un correo.
- **Una persona decide:** solo la aplicación del aprobador puede aprobar (403 para el agente); aprobar algo que no está `PENDING` da 409.
- **Se aplica una sola vez:** papi-orders repone y descuenta con la misma llave como `reference`, y emite la remisión. No publica `order.registered` (D18).
- **Un solo aviso al cliente:** papi-order-requests termina en `COMPLETED` y publica `correction.applied` una vez; el cliente recibe un correo y el agente ve la historia completa.
