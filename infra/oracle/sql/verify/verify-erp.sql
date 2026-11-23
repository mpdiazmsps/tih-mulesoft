-- Verificación del esquema STORE_APP (ERP). Se ejecuta como STORE_APP; no deja cambios (todo termina en ROLLBACK).
-- Lo corre infra/oracle/verify-schema.ps1 o .sh. Cada prueba imprime OK o FALLO; al final, el resumen.
SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF HEADING ON PAGESIZE 100 LINESIZE 200
SET DEFINE OFF

PROMPT === STORE_APP: filas por tabla
SELECT 'INVENTORY' AS TABLA, COUNT(*) AS FILAS FROM INVENTORY
UNION ALL SELECT 'INVENTORY_PROVIDERS', COUNT(*) FROM INVENTORY_PROVIDERS
UNION ALL SELECT 'ORDERS', COUNT(*) FROM ORDERS
UNION ALL SELECT 'ORDER_ITEMS', COUNT(*) FROM ORDER_ITEMS
UNION ALL SELECT 'INVENTORY_MOVEMENTS', COUNT(*) FROM INVENTORY_MOVEMENTS;

PROMPT === STORE_APP: pruebas
DECLARE
  ok   PLS_INTEGER := 0;
  bad  PLS_INTEGER := 0;
  tabs VARCHAR2(4000);
  n    NUMBER;
  PROCEDURE expect(p_name VARCHAR2, p_sql VARCHAR2, p_code NUMBER) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('FALLO  ' || p_name || ': no dio error (se esperaba ORA' || p_code || ')');
    bad := bad + 1;
    ROLLBACK;
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    IF SQLCODE = p_code THEN
      DBMS_OUTPUT.PUT_LINE('OK     ' || p_name || ': ORA' || SQLCODE);
      ok := ok + 1;
    ELSE
      DBMS_OUTPUT.PUT_LINE('FALLO  ' || p_name || ': ' || SQLERRM || ' (se esperaba ORA' || p_code || ')');
      bad := bad + 1;
    END IF;
  END;
  PROCEDURE check_eq(p_name VARCHAR2, p_got VARCHAR2, p_want VARCHAR2) IS
  BEGIN
    IF p_got = p_want THEN
      DBMS_OUTPUT.PUT_LINE('OK     ' || p_name || ': ' || p_got); ok := ok + 1;
    ELSE
      DBMS_OUTPUT.PUT_LINE('FALLO  ' || p_name || ': ' || p_got || ' (se esperaba ' || p_want || ')'); bad := bad + 1;
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO n FROM ORDERS;               check_eq('5 pedidos', n, '5');
  SELECT COUNT(*) INTO n FROM ORDER_ITEMS;          check_eq('5 líneas', n, '5');
  SELECT COUNT(*) INTO n FROM INVENTORY;            check_eq('3 productos', n, '3');
  SELECT COUNT(*) INTO n FROM INVENTORY_PROVIDERS;  check_eq('7 filas de proveedores', n, '7');
  SELECT STOCK_QTY INTO n FROM INVENTORY WHERE SKU = 'SKU-100'; check_eq('SKU-100 con stock 2', n, '2');
  SELECT LISTAGG(PROVIDER_ABV || ':' || IS_PREFERRED, ',') WITHIN GROUP (ORDER BY PROVIDER_ABV) INTO tabs
    FROM INVENTORY_PROVIDERS P JOIN INVENTORY I ON I.ID = P.ITEM_ID WHERE I.SKU = 'SKU-100';
  check_eq('SKU-100 con 3 proveedores y FAK preferente', tabs, 'BOR:0,ESC:0,FAK:1');

  expect('stock negativo (salida de 3 de SKU-100)',
         'UPDATE INVENTORY SET STOCK_QTY = STOCK_QTY - 3 WHERE SKU = ''SKU-100''', -2290);
  expect('segundo preferente para SKU-100',
         'UPDATE INVENTORY_PROVIDERS SET IS_PREFERRED = 1 WHERE PROVIDER_ABV = ''ESC'' AND ITEM_ID = (SELECT ID FROM INVENTORY WHERE SKU = ''SKU-100'')', -1);
  expect('REFERENCE repetida en INVENTORY_MOVEMENTS',
         'INSERT INTO INVENTORY_MOVEMENTS (ID, ITEM_ID, MOVEMENT_TYPE, QTY, REFERENCE, RESULTING_STOCK) ' ||
         'SELECT ''40000000-0000-4000-8000-0000000009ff'', ITEM_ID, MOVEMENT_TYPE, QTY, REFERENCE, RESULTING_STOCK FROM INVENTORY_MOVEMENTS WHERE ROWNUM = 1', -1);
  expect('STORE_APP no ve INTEGRATION_APP.ORDER_REQUESTS',
         'SELECT COUNT(*) FROM INTEGRATION_APP.ORDER_REQUESTS', -942);

  SELECT LISTAGG(TABLE_NAME, ',') WITHIN GROUP (ORDER BY TABLE_NAME) INTO tabs FROM USER_TABLES;
  check_eq('tablas de STORE_APP (sin CUSTOMERS ni remisiones)', tabs,
           'INVENTORY,INVENTORY_MOVEMENTS,INVENTORY_PROVIDERS,ORDERS,ORDER_ITEMS');

  DBMS_OUTPUT.PUT_LINE('VERIFY STORE_APP: ' || ok || ' OK, ' || bad || ' FALLOS');
END;
/
EXIT
