# infra: dependencias locales de la PoC

Todo corre en Docker con el proyecto `poc-infra` (`docker-compose.yml`). Los contenedores llevan el prefijo `poc-`
y no tocan `oracle-store`, `ngrok-oracle` ni los `tih-*` de la base.

| Contenedor | Perfiles | Puerto local | Qué es |
|---|---|---|---|
| `poc-oracle` | erp, integracion, local | 1523 | Oracle Free, servicio `FREEPDB1`: esquemas `STORE_APP` (ERP) e `INTEGRATION_APP` (solicitudes) |
| `poc-rabbitmq` | integracion, local | 5673 (consola 15673) | `orders.events` con `order.registered`, `approval.requested` y `correction.applied`, cada una con DLQ |
| `poc-sftp` | logistica, local | 2223 | SFTP de logística, usuario `pocsftp` **solo con llave**; carpetas `/despachos/pendientes`, `firmadas` y `rechazadas` |
| `poc-logistics-sim` | logistica, local | — | Simulador del operador: firma o rechaza lo que llega a `pendientes` y deja el acuse |
| `poc-wiremock` | proveedores, local | 8089 | Proveedores A (REST), B (REST) y C (SOAP) simulados |

Los puertos no chocan con la base (1521, 1522, 5672/15672, 2222). Si alguno está ocupado en tu equipo,
cámbialo en `infra/.env` (ver `.env.example`).

## Requisitos

Docker Desktop y Node.js (para generar las semillas).

## Credenciales (no se versionan)

| Archivo | Plantilla | Contenido |
|---|---|---|
| `oracle/credentials.local` | `credentials.local.example` | `ORACLE_PWD`, `APP_USER`/`APP_USER_PASSWORD` (STORE_APP), `INT_USER`/`INT_USER_PASSWORD` (INTEGRATION_APP) |
| `rabbitmq/credentials.local` | `credentials.local.example` | usuario administrador y usuario de las apps |
| `sftp/keys/poc_sftp_rsa` | — | llave del SFTP; la genera `start-infra` (ver `sftp/keys/README.md`) |

Las claves de las plantillas solo sirven en local. Antes de abrir los túneles para CloudHub se cambian por claves
fuertes (`infra/tunnels/rotate-cloud-secrets`, tarea 26).

## Operación

```powershell
.\infra\scripts\start-infra.ps1            # levanta todo (perfil local); -Profile erp|integracion|logistica|proveedores
.\infra\scripts\reset-data.ps1             # datos del guion en todas las dependencias
.\infra\oracle\verify-schema.ps1           # verifica los dos esquemas de Oracle
.\demo\control.ps1 slow-c                  # control de la demo: slow-c | normal-c | sftp-down | sftp-up | reset
```

En Linux, macOS o Git Bash, los mismos scripts con extensión `.sh`.

- `start-infra` revisa Docker, Node y las credenciales (si falta un archivo lo crea desde su plantilla y pide llenarlo),
  avisa si corren contenedores de la base, genera las semillas y la llave del SFTP, levanta el perfil y crea los
  usuarios de RabbitMQ. Se puede ejecutar varias veces.
- `reset-data` vuelve a sembrar `STORE_APP`, vacía `INTEGRATION_APP`, deja en el SFTP las remisiones semilla
  (PED-1003 firmada y PED-1004 rechazada), quita los retardos de WireMock y purga las colas.

## Datos

Todo sale de `data/scenario.json` con `node data/tools/build-seeds.mjs`, que genera (sin versionar):
la semilla del ERP (`oracle/sql/erp/20-seed.generated.sql`), las remisiones semilla (`sftp/seed/`),
las reglas del simulador (`data/logistics-rules.json`) y los mappings de WireMock (`wiremock/mappings/`).
