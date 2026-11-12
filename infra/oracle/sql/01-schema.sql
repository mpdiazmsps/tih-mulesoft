-- Esquema del proyecto TIH (tienda en línea). Se ejecuta como el usuario de aplicación STORE_APP en FREEPDB1.
-- Mismos nombres de tablas y columnas que usa sapi-oracle-core-tih, con las restricciones que exige el requerimiento.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF

-- ------------------------------------------------------------------ CUSTOMERS
-- Requerimiento: nombre obligatorio; correo y teléfono opcionales pero al menos uno de los dos.
CREATE TABLE CUSTOMERS (
    ID               VARCHAR2(36)  NOT NULL,
    CLIENT_NAME      VARCHAR2(100) NOT NULL,
    CLIENT_LAST_NAME VARCHAR2(100),
    CLIENT_EMAIL     VARCHAR2(200),
    CLIENT_PHONE     VARCHAR2(15),
    CREATION_DATE    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_CUSTOMERS         PRIMARY KEY (ID),
    CONSTRAINT UQ_CUSTOMERS_EMAIL   UNIQUE (CLIENT_EMAIL),
    CONSTRAINT UQ_CUSTOMERS_PHONE   UNIQUE (CLIENT_PHONE),
    CONSTRAINT CHK_CUSTOMER_CONTACT CHECK (CLIENT_EMAIL IS NOT NULL OR CLIENT_PHONE IS NOT NULL),
    CONSTRAINT CHK_CUSTOMER_ID_UUID CHECK (REGEXP_LIKE(ID, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'))
);

-- ------------------------------------------------------------------ INVENTORY
-- Requerimiento: si LOCAL_PRICE es 0 el precio se consulta al proveedor, y entonces EXTERNAL_ID y PROVIDER_ABV son obligatorios.
CREATE TABLE INVENTORY (
    ID            VARCHAR2(36)  NOT NULL,
    NAME          VARCHAR2(100) NOT NULL,
    DESCRIPTION   VARCHAR2(255),
    STOCK_QTY     NUMBER(10)    DEFAULT 1 NOT NULL,
    LOCAL_PRICE   NUMBER(12,2)  DEFAULT 0 NOT NULL,
    EXTERNAL_ID   NUMBER(10),
    PROVIDER_ABV  VARCHAR2(100),
    CREATION_DATE TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_INVENTORY          PRIMARY KEY (ID),
    CONSTRAINT CHK_STOCK_POSITIVE    CHECK (STOCK_QTY >= 0),
    CONSTRAINT CHK_PRICE_POSITIVE    CHECK (LOCAL_PRICE >= 0),
    CONSTRAINT CHK_PROVIDER_ABV      CHECK (PROVIDER_ABV IS NULL OR PROVIDER_ABV IN ('FAK', 'ESC', 'BOR')),
    CONSTRAINT CHK_PRICE_SOURCE      CHECK (LOCAL_PRICE > 0 OR (EXTERNAL_ID IS NOT NULL AND PROVIDER_ABV IS NOT NULL))
);

-- ------------------------------------------------------------------ ORDERS
-- Una fila por artículo del pedido, por eso la llave primaria es (ID, ITEM_ID): evita pedidos duplicados
-- y el mismo artículo repetido dentro de un pedido.
-- Los nombres FK_ORDERS_CUSTOMER y FK_ORDERS_INVENTORY los usa sapi-oracle-core-tih para traducir ORA-02291.
CREATE TABLE ORDERS (
    ID            VARCHAR2(36) NOT NULL,
    CLIENT_ID     VARCHAR2(36) NOT NULL,
    ITEM_ID       VARCHAR2(36) NOT NULL,
    ITEM_QTY      NUMBER(10)   NOT NULL,
    ITEM_PRICE    NUMBER(12,2) NOT NULL,
    CREATION_DATE TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_ORDERS           PRIMARY KEY (ID, ITEM_ID),
    CONSTRAINT FK_ORDERS_CUSTOMER  FOREIGN KEY (CLIENT_ID) REFERENCES CUSTOMERS (ID),
    CONSTRAINT FK_ORDERS_INVENTORY FOREIGN KEY (ITEM_ID)   REFERENCES INVENTORY (ID),
    CONSTRAINT CHK_ORDER_QTY       CHECK (ITEM_QTY > 0),
    CONSTRAINT CHK_ORDER_PRICE     CHECK (ITEM_PRICE >= 0)
);

CREATE INDEX IDX_ORDERS_CLIENT ON ORDERS (CLIENT_ID);
CREATE INDEX IDX_ORDERS_ITEM   ON ORDERS (ITEM_ID);

EXIT
