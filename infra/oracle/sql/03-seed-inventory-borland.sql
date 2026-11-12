-- Datos de ejemplo de Borland (BOR): los 5 artículos del mock SOAP de SoapUI (ArticleId 1 al 5).
-- Su precio solo se obtiene con el MockService OrderServiceSoap encendido en http://localhost:8088.
-- Se puede ejecutar varias veces: solo agrega los artículos que falten.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF

DECLARE
  PROCEDURE add_item(p_id VARCHAR2, p_name VARCHAR2, p_external_id NUMBER) IS
  BEGIN
    INSERT INTO INVENTORY (ID, NAME, STOCK_QTY, LOCAL_PRICE, EXTERNAL_ID, PROVIDER_ABV)
    VALUES (p_id, p_name, 100, 0, p_external_id, 'BOR');
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN NULL; -- el artículo ya existe: se deja como está
  END;
BEGIN
  add_item('0b1c2d3e-4f5a-46b7-88c9-d0e1f2a3b401', 'Lord of the Rings - Fellowship of the Ring', 1);
  add_item('0b1c2d3e-4f5a-46b7-88c9-d0e1f2a3b402', 'Jurassic Park',                              2);
  add_item('0b1c2d3e-4f5a-46b7-88c9-d0e1f2a3b403', 'The Breakfast Club',                         3);
  add_item('0b1c2d3e-4f5a-46b7-88c9-d0e1f2a3b404', 'Gladiator II',                               4);
  add_item('0b1c2d3e-4f5a-46b7-88c9-d0e1f2a3b405', 'Toy Story 4',                                5);
  COMMIT;
END;
/

EXIT
