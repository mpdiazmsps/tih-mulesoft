-- Verifica el esquema TIH: lista restricciones y prueba cada una intentando violarla.
-- Todo se ejecuta dentro de una transacción que termina en ROLLBACK: no deja datos.
-- Uso (desde infra/oracle): .\verify-schema.ps1
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 100 LINESIZE 150 FEEDBACK OFF
COL table_name FORMAT A12
COL constraint_name FORMAT A24
PROMPT === Restricciones
SELECT table_name, constraint_name, constraint_type FROM user_constraints
 WHERE constraint_name NOT LIKE 'SYS_%' ORDER BY table_name, constraint_type, constraint_name;
PROMPT === Filas
SELECT 'CUSTOMERS' tabla, COUNT(1) filas FROM CUSTOMERS UNION ALL
SELECT 'INVENTORY', COUNT(1) FROM INVENTORY UNION ALL
SELECT 'ORDERS', COUNT(1) FROM ORDERS;
PROMPT === Inventario por proveedor
SELECT NVL(provider_abv, '(precio local)') proveedor, COUNT(1) articulos FROM INVENTORY GROUP BY provider_abv ORDER BY 1;
PROMPT === Pruebas de restricciones (cada violación debe fallar)

DECLARE
  v_fail NUMBER := 0;
  PROCEDURE expect_error(p_name VARCHAR2, p_sql VARCHAR2, p_code NUMBER, p_text VARCHAR2 DEFAULT NULL) IS
  BEGIN
    BEGIN
      EXECUTE IMMEDIATE p_sql;
      DBMS_OUTPUT.PUT_LINE('FALLO  ' || p_name || ': no hubo error');
      v_fail := v_fail + 1;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE = p_code AND (p_text IS NULL OR INSTR(SQLERRM, p_text) > 0) THEN
        DBMS_OUTPUT.PUT_LINE('PASO   ' || p_name || ' -> ORA' || TO_CHAR(SQLCODE));
      ELSE
        DBMS_OUTPUT.PUT_LINE('FALLO  ' || p_name || ': ' || SUBSTR(SQLERRM, 1, 120));
        v_fail := v_fail + 1;
      END IF;
    END;
  END;
  PROCEDURE expect_ok(p_name VARCHAR2, p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('PASO   ' || p_name);
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('FALLO  ' || p_name || ': ' || SUBSTR(SQLERRM, 1, 120));
    v_fail := v_fail + 1;
  END;
BEGIN
  -- CUSTOMERS
  expect_ok('cliente válido', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME, CLIENT_EMAIL, CLIENT_PHONE) VALUES ('11111111-1111-4111-8111-111111111111','Ana','a@x.com','+5215500000001')]');
  expect_error('cliente sin email ni teléfono', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME) VALUES ('22222222-2222-4222-8222-222222222222','X')]', -2290, 'CHK_CUSTOMER_CONTACT');
  expect_error('email duplicado', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME, CLIENT_EMAIL) VALUES ('33333333-3333-4333-8333-333333333333','B','a@x.com')]', -1, 'UQ_CUSTOMERS_EMAIL');
  expect_error('teléfono duplicado', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME, CLIENT_PHONE) VALUES ('44444444-4444-4444-8444-444444444444','C','+5215500000001')]', -1, 'UQ_CUSTOMERS_PHONE');
  expect_error('id duplicado', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME, CLIENT_EMAIL) VALUES ('11111111-1111-4111-8111-111111111111','D','d@x.com')]', -1, 'PK_CUSTOMERS');
  expect_error('id que no es UUID', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME, CLIENT_EMAIL) VALUES ('no-es-uuid','E','e@x.com')]', -2290, 'CHK_CUSTOMER_ID_UUID');
  expect_error('nombre nulo', q'[INSERT INTO CUSTOMERS (ID, CLIENT_NAME, CLIENT_EMAIL) VALUES ('55555555-5555-4555-8555-555555555555',NULL,'f@x.com')]', -1400);
  -- INVENTORY
  expect_ok('artículo con precio local', q'[INSERT INTO INVENTORY (ID, NAME, LOCAL_PRICE) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Local',10.5)]');
  expect_ok('artículo con proveedor', q'[INSERT INTO INVENTORY (ID, NAME, LOCAL_PRICE, EXTERNAL_ID, PROVIDER_ABV) VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Prov',0,7,'FAK')]');
  expect_error('precio 0 sin proveedor', q'[INSERT INTO INVENTORY (ID, NAME, LOCAL_PRICE) VALUES ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Sin precio',0)]', -2290, 'CHK_PRICE_SOURCE');
  expect_error('proveedor inválido', q'[INSERT INTO INVENTORY (ID, NAME, LOCAL_PRICE, EXTERNAL_ID, PROVIDER_ABV) VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','Mal',0,1,'XXX')]', -2290, 'CHK_PROVIDER_ABV');
  expect_error('stock negativo', q'[INSERT INTO INVENTORY (ID, NAME, STOCK_QTY, LOCAL_PRICE) VALUES ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Neg',-1,5)]', -2290, 'CHK_STOCK_POSITIVE');
  expect_error('precio negativo', q'[INSERT INTO INVENTORY (ID, NAME, LOCAL_PRICE, EXTERNAL_ID, PROVIDER_ABV) VALUES ('ffffffff-ffff-4fff-8fff-ffffffffffff','Neg',-5,1,'ESC')]', -2290, 'CHK_PRICE_POSITIVE');
  -- ORDERS
  expect_ok('línea de pedido válida', q'[INSERT INTO ORDERS (ID, CLIENT_ID, ITEM_ID, ITEM_QTY, ITEM_PRICE) VALUES ('99999999-9999-4999-8999-999999999999','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',2,10.5)]');
  expect_error('mismo artículo repetido en el pedido', q'[INSERT INTO ORDERS (ID, CLIENT_ID, ITEM_ID, ITEM_QTY, ITEM_PRICE) VALUES ('99999999-9999-4999-8999-999999999999','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,10.5)]', -1, 'PK_ORDERS');
  expect_error('cantidad 0', q'[INSERT INTO ORDERS (ID, CLIENT_ID, ITEM_ID, ITEM_QTY, ITEM_PRICE) VALUES ('88888888-8888-4888-8888-888888888888','11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',0,5)]', -2290, 'CHK_ORDER_QTY');
  expect_error('precio negativo en línea', q'[INSERT INTO ORDERS (ID, CLIENT_ID, ITEM_ID, ITEM_QTY, ITEM_PRICE) VALUES ('88888888-8888-4888-8888-888888888888','11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',1,-5)]', -2290, 'CHK_ORDER_PRICE');
  expect_error('cliente inexistente', q'[INSERT INTO ORDERS (ID, CLIENT_ID, ITEM_ID, ITEM_QTY, ITEM_PRICE) VALUES ('77777777-7777-4777-8777-777777777777','00000000-0000-4000-8000-000000000000','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,10)]', -2291, 'FK_ORDERS_CUSTOMER');
  expect_error('artículo inexistente', q'[INSERT INTO ORDERS (ID, CLIENT_ID, ITEM_ID, ITEM_QTY, ITEM_PRICE) VALUES ('66666666-6666-4666-8666-666666666666','11111111-1111-4111-8111-111111111111','00000000-0000-4000-8000-000000000000',1,10)]', -2291, 'FK_ORDERS_INVENTORY');
  expect_error('borrar cliente con pedidos', q'[DELETE FROM CUSTOMERS WHERE ID = '11111111-1111-4111-8111-111111111111']', -2292);

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN v_fail = 0 THEN 'RESULTADO: todas las pruebas pasaron' ELSE 'RESULTADO: ' || v_fail || ' prueba(s) fallaron' END);
END;
/
PROMPT === Filas tras el ROLLBACK (deben ser las mismas)
SELECT 'CUSTOMERS' tabla, COUNT(1) filas FROM CUSTOMERS UNION ALL
SELECT 'INVENTORY', COUNT(1) FROM INVENTORY UNION ALL
SELECT 'ORDERS', COUNT(1) FROM ORDERS;
EXIT
