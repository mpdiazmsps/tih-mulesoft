-- Datos de ejemplo del inventario: 5 artículos con precio de la tienda y 10 con precio de proveedor.
-- Fakestore (FAK) ids 1-5 y Escuelajs (ESC) ids 26-30. Los de Borland (BOR) están en 03-seed-inventory-borland.sql.
-- Se puede ejecutar varias veces: solo agrega los artículos que falten y no modifica los que ya existen.
-- Lo carga el primer arranque del contenedor; para volver a cargarlo usa scripts/load-inventory.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF

DECLARE
  PROCEDURE add_item(p_id VARCHAR2, p_name VARCHAR2, p_desc VARCHAR2, p_stock NUMBER, p_price NUMBER,
                     p_external_id NUMBER, p_provider VARCHAR2) IS
  BEGIN
    INSERT INTO INVENTORY (ID, NAME, DESCRIPTION, STOCK_QTY, LOCAL_PRICE, EXTERNAL_ID, PROVIDER_ABV)
    VALUES (p_id, p_name, p_desc, p_stock, p_price, p_external_id, p_provider);
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN NULL; -- el artículo ya existe: se deja como está
  END;
BEGIN
  -- Precio de la tienda
  add_item('c1a2b3c4-d5e6-4789-a012-3456789abc01', 'Teclado Mecanico',    'Teclado mecanico retroiluminado', 100, 1250.00, NULL, NULL);
  add_item('f81d4fae-7dec-41d0-a765-00a0c91e6bf6', 'Mouse Inalambrico',   'Mouse inalambrico ergonomico',    100,  450.50, NULL, NULL);
  add_item('a0eebc99-9c0b-4ef8-b6d6-6bb9bd380a11', 'Monitor 27 Pulgadas', 'Monitor 27 pulgadas 4K',          100, 5800.00, NULL, NULL);
  add_item('3b9d0389-1300-4f51-a982-f472856f6f92', 'Auriculares Gamer',   'Auriculares con microfono',       100,  899.99, NULL, NULL);
  add_item('e3d4c5b6-7a8b-49c0-91d2-e3f4a5b6c7d8', 'Pad Mouse XL',        'Tapete de escritorio XL',         100,  250.00, NULL, NULL);

  -- Fakestore (FAK)
  add_item('7a8b9c0d-1e2f-43a4-b5c6-d7e8f9a0b1c2', 'Mochila Casual',    NULL, 100, 0,  1, 'FAK');
  add_item('123e4567-e89b-42d3-a456-426614174000', 'Chamarra Slim Fit', NULL, 100, 0,  2, 'FAK');
  add_item('b2c3d4e5-f6a7-48b9-90c1-d2e3f4a5b6c7', 'Chamarra Algodon',  NULL, 100, 0,  3, 'FAK');
  add_item('d4e5f6a7-b8c9-40d1-a2e3-f4a5b6c7d8e9', 'Playera Casual',    NULL, 100, 0,  4, 'FAK');
  add_item('f4a5b6c7-d8e9-40f1-b2c3-d4e5f6a7b8c9', 'Pulsera Dragon',    NULL, 100, 0,  5, 'FAK');

  -- Escuelajs (ESC)
  add_item('9a0b1c2d-3e4f-45a6-b7c8-d9e0f1a2b3c4', 'Tenis Deportivos',  NULL, 100, 0, 26, 'ESC');
  add_item('8b9c0d1e-2f3a-44b5-a6d7-e8f9a0b1c2d3', 'Lentes de Sol',     NULL, 100, 0, 27, 'ESC');
  add_item('5c6d7e8f-9a0b-41c2-83e4-f5a6b7c8d9e0', 'Gorra Urbana',      NULL, 100, 0, 28, 'ESC');
  add_item('2d3e4f5a-6b7c-48d9-90f1-a2b3c4d5e6f7', 'Reloj Inteligente', NULL, 100, 0, 29, 'ESC');
  add_item('6b7c8d9e-0f1a-42b3-84d5-e6f7a8b9c0d1', 'Silla Ergonomica',  NULL, 100, 0, 30, 'ESC');

  COMMIT;
END;
/

EXIT
