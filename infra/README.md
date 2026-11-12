# Infraestructura local TIH (Fase 0)

> **¿Acabas de clonar el repositorio?** Sigue el [README de la raíz](../README.md), sección 3: `scripts/start-infra` levanta Oracle, RabbitMQ y el SFTP en Docker, y `scripts/load-inventory` recarga el inventario de ejemplo. Este documento es la bitácora del equipo original: describe además el SFTP con Rebex en Windows y el contenedor `oracle-store` de ese equipo, que no hacen falta para correr el proyecto.

Todo lo que se crea aquí vive dentro de este repositorio. **No se modifica** el contenedor Oracle existente (`oracle-store`) ni su túnel ngrok (`ngrok-oracle`).

| Componente | Estado | Acceso |
|---|---|---|
| Oracle 26ai Free (`oracle-store`, esquema `STORE_APP`) | Preexistente, sin cambios | `localhost:1521`, servicio `FREEPDB1` |
| RabbitMQ 3.13 (`tih-rabbitmq`) | Creado en Fase 0 | AMQP `localhost:5672`, consola `http://localhost:15672` |
| SFTP Rebex Tiny (`RebexTinySftpServer.exe`) | Creado en Fase 0 | `localhost:2222` |
| MagicBell | Cuenta creada; token en `magicbell/credentials.local`; lo usa `papi-notifications-tih` directo | — |

Las credenciales generadas están en archivos `credentials.local` (excluidos por `.gitignore`):
- `rabbitmq/credentials.local`
- `sftp/credentials.local`

## Oracle del proyecto (`tih-oracle`)

Contenedor nuevo e independiente: **no toca** `oracle-store` ni `ngrok-oracle` (siguen como estaban).
Imagen `container-registry.oracle.com/database/free:latest` (Oracle 26ai Free), servicio `FREEPDB1`.

| Dato | Valor |
|---|---|
| Listener | `localhost:1522` (el 1521 es de `oracle-store`) |
| URL JDBC | `jdbc:oracle:thin:@//localhost:1522/FREEPDB1` |
| Consola EM Express | `https://localhost:5501/em` |
| Usuario de la aplicación | `STORE_APP` |
| Contraseñas (SYS/SYSTEM y STORE_APP) | `oracle/credentials.local` (ignorado por Git) |

```
cd infra
docker compose up -d oracle-tih     # crear o arrancar (primera vez: ~2 min)
docker compose stop oracle-tih      # detener, conserva los datos
```

- Datos en el volumen Docker `tih-infra_tih-oracle-data`. `docker compose down -v` los borra.
- `oracle/init/01-create-app-user.sh` se ejecuta en cada arranque y es idempotente: si `STORE_APP` no existe, lo crea y carga `oracle/sql/01-schema.sql` y `02-seed-inventory.sql`.
- Para recrear el esquema desde cero: borrar el usuario (`DROP USER STORE_APP CASCADE` en `FREEPDB1`) y reiniciar el contenedor.

**Esquema** (mismos nombres que usa `sapi-oracle-core-tih`):

| Tabla | Restricciones |
|---|---|
| `CUSTOMERS` | PK `ID`; `CLIENT_NAME` obligatorio; email único; teléfono único; email o teléfono obligatorio; `ID` con formato UUID |
| `INVENTORY` | PK `ID`; stock y precio ≥ 0; `PROVIDER_ABV` en (FAK, ESC, BOR); si `LOCAL_PRICE` = 0 exige `EXTERNAL_ID` y `PROVIDER_ABV` |
| `ORDERS` | PK `(ID, ITEM_ID)` (evita pedidos y líneas duplicadas); FK `FK_ORDERS_CUSTOMER` y `FK_ORDERS_INVENTORY`; cantidad > 0; precio ≥ 0 |

Datos de ejemplo: 15 artículos (5 con precio local, 5 FAK y 5 ESC; sin Borland).

Verificación: `oracle/verify-schema.ps1` lista las restricciones y prueba 20 violaciones y casos válidos dentro de una transacción que se revierte (no deja datos).

## RabbitMQ

```
cd infra
docker compose up -d      # arrancar
docker compose down       # detener (las definiciones se vuelven a cargar al arrancar)
```

- Consola web: `http://localhost:15672` con el usuario `tih-admin`.
- Usuario de aplicación para Mule: `tih-app` (solo AMQP, sin acceso a la consola).
- Definiciones en `rabbitmq/definitions.json`:

| Elemento | Nombre | Detalle |
|---|---|---|
| Exchange | `orders.events` | topic, durable |
| Exchange | `orders.events.dlx` | direct, durable (dead-letter) |
| Cola | `orders.registered.q` | DLX `orders.events.dlx`, routing key de dead-letter `order.registered.dead` |
| Cola | `orders.registered.dlq` | recibe los mensajes rechazados sin requeue |
| Binding | `orders.events` → `orders.registered.q` | routing key `order.registered` |
| Binding | `orders.events.dlx` → `orders.registered.dlq` | routing key `order.registered.dead` |

Verificado: publicar con `order.registered` llega a `orders.registered.q`; rechazar sin requeue lo manda a `orders.registered.dlq`.

## SFTP (Rebex Tiny SFTP Server)

- Binario oficial de rebex.net, con firma digital válida (REBEX ČR s.r.o.), en `sftp/rebex/app/`.
- Configuración en `sftp/rebex/app/RebexTinySftpServer.exe.config`: usuario `tihsftp`, puerto `2222`, arranque automático.
- Raíz del usuario: `sftp/data/`, con `orders/pending`, `orders/processed` y `orders/error`.
- Para arrancarlo: ejecutar `sftp/rebex/app/RebexTinySftpServer.exe`.
- Es una aplicación de ventana: mientras el proceso esté abierto, el servidor está activo.
- Prueba de humo (crear, listar, leer, mover): `sftp\.venv\Scripts\python.exe -I sftp\smoke-test-sftp.py`.
  El entorno virtual se crea con `python -I -m venv sftp\.venv` y `pip install paramiko`.

## Pendientes de la Fase 0

1. **MagicBell**: cuenta creada. Falta habilitar el canal de email en el dashboard y probar un envío real.

Decisiones tomadas:
- **MagicBell**: sin SAPI propia desde 2026-10-12; la llama papi-notifications.
- El runtime corre en esta misma máquina, así que Oracle se alcanza por `localhost:1521` (el túnel ngrok no se usa).
- **Borland SOAP (Provider-C)**: `sapi-price-providers` lo consulta a un mock de SoapUI (`apps/sapi-price-providers-tih/borland-mock/`) en `http://localhost:8088/mockOrderServiceSoap`. Los artículos `BOR` de `INVENTORY` solo funcionan con el mock encendido; los datos de ejemplo actuales no incluyen artículos `BOR`.
- **Oracle no se altera.** Las credenciales de aplicación se piden al llegar a la Fase 2 y se guardan cifradas.
- **Runtime:** se desarrolla con el Mule EE 4.11 embebido en Anypoint Studio. El runtime on-premise se resuelve antes de la Fase 6.

## Secure properties (cifrado de credenciales)

Los `*-secure-application-config.yaml` de las apps con secretos (`papi-notifications`, `papi-orders`, `sapi-oracle-core`, `sapi-sftp-orders`) guardan los valores cifrados (`![...]`, AES/CBC) con el módulo `mule-secure-configuration-property-module`. En los XML se leen como `${secure::clave}` o `p('secure::clave')`.

- La clave de cifrado está en `secure/credentials.local` (`ENCRYPTION_KEY`, fuera de control de versiones).
- **Studio:** cada app necesita el VM argument `-M-Dencryption.key=<ENCRYPTION_KEY>` en su Run Configuration (pestaña Arguments). Sin él, la app no arranca.
- **Maven/MUnit:** `mvn -o -B clean package -Dencryption.key=<ENCRYPTION_KEY>`.
- **Cifrar un valor nuevo:** `java -cp .claude/skills/secure-mule-app/assets/secure-properties-tool.jar com.mulesoft.tools.SecurePropertiesTool string encrypt AES CBC <ENCRYPTION_KEY> "<valor>"` y pegar el resultado como `![...]`.
- Para verlo en claro: mismo comando con `decrypt` en lugar de `encrypt`.
