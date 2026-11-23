# Muestra lo que guardan los sistemas durante la demo, sin pedir credenciales (sqlplus como SYSDBA dentro de poc-oracle,
# ls dentro de poc-sftp y rabbitmqctl dentro de poc-rabbitmq). Solo lee. Hace lo mismo que inspect.sh.
# Uso: .\demo\inspect.ps1 pedidos|inventario|movimientos|solicitudes|historia|sftp|colas
param([Parameter(Mandatory = $true)][ValidateSet('pedidos', 'inventario', 'movimientos', 'solicitudes', 'historia', 'sftp', 'colas')][string]$What)
$ErrorActionPreference = "Continue"
function Invoke-Sql([string]$query) {
    $head = "SET LINESIZE 220 PAGESIZE 100 FEEDBACK OFF TRIMSPOOL ON`nALTER SESSION SET CONTAINER=FREEPDB1;`nALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SS';`n"
    # El SQL viaja en base64 como argumento: por la tubería PowerShell 5.1 antepone un BOM que sqlplus no entiende.
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($head + $query))
    docker exec poc-oracle bash -c "echo $b64 | base64 -d | sqlplus -s / as sysdba"
}
$queries = @{
    'pedidos' = @'
COLUMN PEDIDO FORMAT A9
COLUMN ESTADO FORMAT A9
COLUMN CLIENTE FORMAT A18
COLUMN LINEAS FORMAT A45
COLUMN CONFIRMADO FORMAT A19
SELECT 'PED-' || SUBSTR(o.ID, -4) PEDIDO, o.STATUS ESTADO, o.CUSTOMER_ID CLIENTE, o.TOTAL,
       (SELECT LISTAGG(i.SKU || ' x' || oi.QTY || NVL2(oi.UNIT_PRICE, ' @' || oi.UNIT_PRICE || ' ' || oi.PRICE_SOURCE || NVL2(oi.PRICE_PROVIDER, '/' || oi.PRICE_PROVIDER, ''), ''), ', ')
          FROM STORE_APP.ORDER_ITEMS oi JOIN STORE_APP.INVENTORY i ON i.ID = oi.ITEM_ID WHERE oi.ORDER_ID = o.ID) LINEAS,
       TO_CHAR(o.CONFIRMED_AT, 'YYYY-MM-DD HH24:MI:SS') CONFIRMADO
  FROM STORE_APP.ORDERS o ORDER BY o.CREATED_AT;
'@
    'inventario' = @'
COLUMN SKU FORMAT A8
COLUMN NOMBRE FORMAT A14
COLUMN PROVEEDORES FORMAT A70
SELECT i.SKU, i.NAME NOMBRE, i.STOCK_QTY STOCK, i.LOCAL_PRICE PRECIO_LOCAL,
       (SELECT LISTAGG(p.PROVIDER_ABV || DECODE(p.IS_PREFERRED, 1, '*', '') || ' ' || NVL(TO_CHAR(p.LAST_PRICE), '-'), ', ')
          FROM STORE_APP.INVENTORY_PROVIDERS p WHERE p.ITEM_ID = i.ID) PROVEEDORES
  FROM STORE_APP.INVENTORY i ORDER BY i.SKU;
PROMPT (* proveedor preferente; el numero es su ultimo precio confirmado)
'@
    'movimientos' = @'
COLUMN SKU FORMAT A8
COLUMN TIPO FORMAT A8
COLUMN REFERENCIA FORMAT A80
COLUMN PEDIDO FORMAT A9
SELECT i.SKU, m.MOVEMENT_TYPE TIPO, m.QTY CANTIDAD, m.RESULTING_STOCK STOCK_FINAL, 'PED-' || SUBSTR(m.ORDER_ID, -4) PEDIDO,
       m.REFERENCE REFERENCIA
  FROM STORE_APP.INVENTORY_MOVEMENTS m JOIN STORE_APP.INVENTORY i ON i.ID = m.ITEM_ID ORDER BY m.CREATED_AT;
PROMPT (REFERENCIA es unica: la misma llave nunca mueve el inventario dos veces)
'@
    'solicitudes' = @'
COLUMN SOLICITUD FORMAT A8
COLUMN PEDIDO FORMAT A9
COLUMN TIPO FORMAT A8
COLUMN ESTADO FORMAT A10
COLUMN LLAVE FORMAT A55
COLUMN PIDIO FORMAT A12
COLUMN DECIDIO FORMAT A16
SELECT SUBSTR(ID, 1, 8) SOLICITUD, 'PED-' || SUBSTR(ORDER_ID, -4) PEDIDO, REQUEST_TYPE TIPO, STATUS ESTADO,
       PROVIDER_ABV PROV, QTY, AMOUNT MONTO, REQUESTED_BY PIDIO, DECIDED_BY DECIDIO, IDEMPOTENCY_KEY LLAVE
  FROM INTEGRATION_APP.ORDER_REQUESTS ORDER BY CREATED_AT;
PROMPT (IDEMPOTENCY_KEY es unica: repetir la llave devuelve la misma solicitud)
'@
    'historia' = @'
COLUMN SOLICITUD FORMAT A8
COLUMN DE FORMAT A10
COLUMN A FORMAT A10
COLUMN ACTOR FORMAT A20
COLUMN CUANDO FORMAT A19
COLUMN DETALLE FORMAT A60
SELECT SUBSTR(REQUEST_ID, 1, 8) SOLICITUD, FROM_STATUS DE, TO_STATUS A, ACTOR, TO_CHAR(EVENT_AT, 'YYYY-MM-DD HH24:MI:SS') CUANDO, DETAIL DETALLE
  FROM INTEGRATION_APP.ORDER_REQUEST_EVENTS ORDER BY EVENT_AT, ID;
'@
}
switch ($What) {
    'sftp' { foreach ($d in 'pendientes', 'firmadas', 'rechazadas') { "/despachos/${d}:"; docker exec poc-sftp sh -c "ls -1 /home/pocsftp/despachos/$d 2>/dev/null | sed 's/^/  /'" } }
    'colas' { docker exec poc-rabbitmq rabbitmqctl list_queues name messages consumers --quiet }
    default { Invoke-Sql $queries[$What] }
}
