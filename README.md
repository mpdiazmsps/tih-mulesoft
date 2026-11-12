# TIH MuleSoft: tienda en línea con API-led connectivity

Integración de una tienda en línea con MuleSoft. Cubre el registro de clientes, la recepción de pedidos como CSV en un SFTP, el procesamiento programado con cotización de tres proveedores, el registro en Oracle y la notificación por correo con RabbitMQ y MagicBell.

Este README explica cómo levantar todo **en tu equipo**: la infraestructura en Docker y las 7 apps Mule en Anypoint Studio.

## Contenido

1. [Arquitectura](#1-arquitectura)
2. [Requisitos](#2-requisitos)
3. [Levantar la infraestructura](#3-levantar-la-infraestructura)
4. [Configurar las apps](#4-configurar-las-apps)
5. [Ejecutar las apps en Studio](#5-ejecutar-las-apps-en-studio)
6. [Probar la integración](#6-probar-la-integración)
7. [Estructura del repositorio](#7-estructura-del-repositorio)
8. [Problemas comunes](#8-problemas-comunes)

---

## 1. Arquitectura

| App | Capa | Puerto | Qué hace |
|---|---|---|---|
| `xapi-online-store-tih` | Experience | 8080 | Entrada de la tienda: alta de clientes y pedidos |
| `papi-customers-tih` | Process | 8082 | Valida y registra clientes |
| `papi-orders-tih` | Process | 8083 | Recibe pedidos como CSV y los procesa cada 60 s (cotiza, registra y publica el evento) |
| `papi-notifications-tih` | Process | 8084 | Consume el evento de RabbitMQ y envía el correo por MagicBell |
| `sapi-oracle-core-tih` | System | 8091 | Acceso a Oracle: clientes, inventario y pedidos |
| `sapi-sftp-orders-tih` | System | 8092 | Archivos CSV en `/orders/pending`, `processed` y `error` |
| `sapi-price-providers-tih` | System | 8093 | Precios de Fakestore y Escuelajs (REST) y Borland (SOAP) |

Dependencias externas:

| Dependencia | Cómo se levanta | Puerto |
|---|---|---|
| Oracle 26ai Free (`tih-oracle`) | Docker | 1521 |
| RabbitMQ 3.13 (`tih-rabbitmq`) | Docker | 5672, consola 15672 |
| SFTP (`tih-sftp`) | Docker | 2222 |
| Mock SOAP de Borland | SoapUI | 8088 |
| Fakestore y Escuelajs | APIs públicas en internet | — |
| MagicBell | Servicio en la nube, opcional | — |

Los diagramas están en `docs/diagrams/` y los contratos RAML en `specs/`.

## 2. Requisitos

### Obligatorios

| Herramienta | Versión | Para qué |
|---|---|---|
| [Git](https://git-scm.com/) | 2.40 o superior | Clonar el repositorio |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) (o Docker Engine con Compose v2) | Compose 2.20 o superior | Oracle, RabbitMQ y SFTP |
| [Anypoint Studio](https://www.mulesoft.com/lp/dl/anypoint-mule-studio) | 7.x con runtime **Mule 4.11 EE** | Ejecutar las apps (las apps declaran `4.11.4`) |
| Java | **17** | Lo incluye Studio. Solo hace falta instalarlo aparte para compilar con Maven |
| [SoapUI](https://www.soapui.org/downloads/soapui/) (open source) | 5.x | Mock del proveedor Borland |
| Acceso a internet | — | Descargar imágenes y consultar Fakestore y Escuelajs |

**Recursos:** al menos 8 GB de RAM libres para Docker y Studio, y unos 15 GB de disco (la imagen de Oracle ocupa varios GB).

**Oracle:** la imagen sale de `container-registry.oracle.com/database/free`. Si al descargarla pide autenticación, inicia sesión en ese sitio, acepta la licencia y ejecuta `docker login container-registry.oracle.com`.

### Opcionales

| Herramienta | Para qué |
|---|---|
| [Postman](https://www.postman.com/downloads/) | Probar las APIs con la colección de `postman/` |
| Cuenta de [MagicBell](https://www.magicbell.com/) | Envío real de correos. Sin ella todo funciona menos el correo |
| Maven 3.9 | Compilar y correr MUnit fuera de Studio |
| Node.js 18 o superior | Validar los RAML (`specs/tools`) |
| [BAT CLI](https://docs.mulesoft.com/api-functional-monitoring/bat-install-task) | Correr las pruebas BAT de `apps/*/bat-generated/` |

## 3. Levantar la infraestructura

### 3.1 Clonar

```bash
git clone <url-del-repositorio> tih-mulesoft
cd tih-mulesoft
```

### 3.2 Crear las credenciales locales

Cada dependencia tiene una plantilla `credentials.local.example`. Cópiala como `credentials.local` y cambia las claves. Esos archivos están en `.gitignore` y nunca se suben.

```powershell
# Windows (PowerShell)
foreach ($d in 'oracle','rabbitmq','sftp') { Copy-Item "infra\$d\credentials.local.example" "infra\$d\credentials.local" }
```

```bash
# Linux / macOS
for d in oracle rabbitmq sftp; do cp "infra/$d/credentials.local.example" "infra/$d/credentials.local"; done
```

| Archivo | Qué definir |
|---|---|
| `infra/oracle/credentials.local` | `ORACLE_PWD` (SYS y SYSTEM) y `APP_USER_PASSWORD` (usuario `STORE_APP`) |
| `infra/rabbitmq/credentials.local` | Claves de `tih-admin` (consola) y `tih-app` (apps) |
| `infra/sftp/credentials.local` | Clave de `tihsftp`, repetida en `SFTP_PASSWORD` y en `SFTP_USERS` |

Si el script del paso siguiente no encuentra alguno de estos archivos, lo crea desde su plantilla y se detiene para que lo llenes.

### 3.3 Arrancar los contenedores

```powershell
# Windows
.\infra\scripts\start-infra.ps1
```

```bash
# Linux / macOS
chmod +x infra/scripts/*.sh
./infra/scripts/start-infra.sh
```

El script:
1. Levanta `tih-oracle`, `tih-rabbitmq` y `tih-sftp` con `docker compose`.
2. Crea los usuarios de RabbitMQ con los datos de `credentials.local`. Las colas, exchanges y la DLQ se cargan solos desde `infra/rabbitmq/definitions.json`.
3. Espera a que Oracle quede listo. **El primer arranque tarda varios minutos**: crea la base, el usuario `STORE_APP`, las tablas y los datos de ejemplo.

Se puede ejecutar todas las veces que quieras. Para detener los contenedores sin perder datos: `docker compose -f infra/docker-compose.yml --profile sftp stop`.

### 3.4 Datos de ejemplo del inventario

El primer arranque de Oracle carga 20 artículos en `INVENTORY`:

| Origen del precio | Artículos | IDs en el proveedor |
|---|---|---|
| Tienda (`LOCAL_PRICE` > 0) | 5 | — |
| Fakestore (`FAK`) | 5 | 1 a 5 |
| Escuelajs (`ESC`) | 5 | 26 a 30 |
| Borland (`BOR`) | 5 | 1 a 5 (los del mock de SoapUI) |

Para volver a cargarlos, por ejemplo si borraste artículos, ejecuta el script. Solo agrega los que falten:

```powershell
.\infra\scripts\load-inventory.ps1      # Windows
```
```bash
./infra/scripts/load-inventory.sh       # Linux / macOS
```

Los archivos están en `infra/oracle/sql/`: `01-schema.sql` (tablas y restricciones), `02-seed-inventory.sql` y `03-seed-inventory-borland.sql`.

### 3.5 Mock SOAP de Borland

1. Abre SoapUI y elige **File → Import Project**.
2. Selecciona `apps/sapi-price-providers-tih/borland-mock/OrderService-Borland-Mock-soapui-project.xml`.
3. Abre el MockService **OrderServiceSoap MockService** y pulsa **Start**. Queda en `http://localhost:8088/mockOrderServiceSoap`.

Sin el mock, los artículos `BOR` responden 502 y su pedido se queda en `pending` para reintentarse. El resto funciona.

### 3.6 Si un puerto ya está ocupado

Copia `infra/.env.example` como `infra/.env` y cambia el puerto. Si cambias el de Oracle, actualiza también `db.url` en `apps/sapi-oracle-core-tih/src/main/resources/properties/dev-application-config.yaml`.

## 4. Configurar las apps

Las credenciales de las apps van en `src/main/resources/properties/dev-secure-application-config.yaml`, que tampoco se sube. Hay que crearlo en estas 4 apps a partir de su `.example`:

| App | Valores |
|---|---|
| `sapi-oracle-core-tih` | `db.user` y `db.password` = `APP_USER` y `APP_USER_PASSWORD` de Oracle |
| `sapi-sftp-orders-tih` | `sftp.user` y `sftp.password` = `tihsftp` y su clave |
| `papi-orders-tih` | `rabbitmq.user` y `rabbitmq.password` = `tih-app` y su clave |
| `papi-notifications-tih` | Los mismos de RabbitMQ y `magicbell.token` (opcional) |

```powershell
# Windows
foreach ($a in 'sapi-oracle-core-tih','sapi-sftp-orders-tih','papi-orders-tih','papi-notifications-tih') {
  $p = "apps\$a\src\main\resources\properties\dev-secure-application-config.yaml"
  Copy-Item "$p.example" $p
}
```

```bash
# Linux / macOS
for a in sapi-oracle-core-tih sapi-sftp-orders-tih papi-orders-tih papi-notifications-tih; do
  p="apps/$a/src/main/resources/properties/dev-secure-application-config.yaml"; cp "$p.example" "$p"
done
```

### Cifrado de los valores

Las apps leen esos archivos con el módulo *Secure Configuration Properties* (AES/CBC) y necesitan una clave en el argumento `-M-Dencryption.key`.

- **Lo más simple para local:** deja los valores en claro. El módulo devuelve tal cual los valores que no están en formato `![...]`. Aun así, pasa una clave de 16 caracteres cualquiera.
- **Si quieres cifrarlos:** usa tu propia clave de 16 caracteres con la [Secure Properties Tool](https://docs.mulesoft.com/mule-runtime/latest/secure-configuration-properties#secure_props_tool) y pega el resultado como `![valor]`:

  ```
  java -cp secure-properties-tool.jar com.mulesoft.tools.SecurePropertiesTool string encrypt AES CBC <tu-clave> "<valor>"
  ```

  Guarda tu clave en `infra/secure/credentials.local` (plantilla en el `.example`).

### Ambiente

Las apps arrancan con `env=dev`, que es el valor por defecto en `common/global.xml`. Los archivos `qa-` y `prod-` existen, pero hoy apuntan a `localhost` igual que dev.

## 5. Ejecutar las apps en Studio

1. **Importar:** en Studio, elige **File → Import → Anypoint Studio → Anypoint Studio project from File System** y selecciona cada carpeta de `apps/`. Desmarca la opción de copiar el proyecto al workspace para trabajar sobre el repositorio.
2. **Argumento de cada app:** en **Run → Run Configurations →** *la app* **→ Arguments → VM arguments** agrega:
   ```
   -M-Dencryption.key=<tu-clave-de-16-caracteres>
   ```
   Sin este argumento la app no arranca.
3. **Orden de arranque recomendado:** primero las System API, después las Process API y al final la Experience API.

   `sapi-oracle-core-tih` → `sapi-sftp-orders-tih` → `sapi-price-providers-tih` → `papi-customers-tih` → `papi-orders-tih` → `papi-notifications-tih` → `xapi-online-store-tih`

   Puedes correrlas juntas en una sola configuración de ejecución (pestaña **General**, marca las 7 apps).

**Client ID Enforcement:** en local no hay API Manager, así que las apps no validan `client_id` ni `client_secret`. Postman los envía con valores de ejemplo.

### Compilar con Maven (opcional)

```bash
cd apps/<app>
mvn clean package -Dencryption.key=<tu-clave>
```

Esto también corre las pruebas MUnit. Maven necesita acceso a los repositorios de MuleSoft. Si falla al descargar dependencias Enterprise, usa Studio o configura tu `settings.xml` con credenciales de Anypoint.

## 6. Probar la integración

1. Importa `postman/tih-all-apis.postman_collection.json` en Postman.
2. En las variables de la colección, cambia `testEmail` por tu correo.
3. Ejecuta la carpeta **0. Cadena completa** en orden:
   - Crear cliente (xapi).
   - Crear pedido. El CSV queda en `/orders/pending`.
   - Procesar pedidos ahora, o espera hasta 60 s al scheduler.
   - Consultar el pedido en Oracle.

Qué deberías ver:
- El pedido registrado en `ORDERS` con su total.
- El CSV movido a `/orders/processed`.
- Un mensaje procesado en la cola `orders.registered.q` (consola de RabbitMQ en `http://localhost:15672`).
- El correo en tu bandeja, si configuraste MagicBell.

La colección tiene además una carpeta por app con casos de éxito y de error.

**Pruebas automáticas:**
- **MUnit:** dentro de Studio (clic derecho en la app → *Run MUnit tests*) o con Maven.
- **BAT:** están en `apps/<app>/bat-generated/`. Corren contra las apps en ejecución y cada una trae su `REPORT.md`.

## 7. Estructura del repositorio

```
apps/                  7 apps Mule (código, MUnit, propiedades, BAT). Es la versión de referencia
papi-*/ sapi-*/ xapi-*/  Proyectos de Anypoint Studio de las mismas 7 apps (copias de trabajo importadas en Studio)
specs/                 Contratos RAML 1.0, fragments compartidos y validador (npm run validate)
infra/
  docker-compose.yml   Oracle, RabbitMQ y SFTP
  scripts/             start-infra y load-inventory (PowerShell y bash)
  oracle/              Script de inicio, esquema y datos de ejemplo
  rabbitmq/            Exchanges, colas y DLQ
  sftp/                SFTP en Docker (y guía de Rebex para Windows en infra/README.md)
  governance/          Ruleset de convenciones RAML
postman/               Colección de todas las APIs
docs/                  Plan del proyecto (PLAN-tih-mulesoft.md) y diagramas (docs/diagrams/)
```

## 8. Problemas comunes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `start-infra` se queda esperando a `tih-oracle` | Primer arranque de Oracle | Espera. Para ver el avance: `docker logs -f tih-oracle` |
| `port is already allocated` | Otro servicio usa el puerto | Cambia el puerto en `infra/.env` (sección 3.6) |
| La app no arranca y menciona `encryption.key` | Falta el argumento de VM | Agrega `-M-Dencryption.key=...` (sección 5) |
| `ORA-01017` en `sapi-oracle-core` | Usuario o clave distintos a los de `credentials.local` | Revisa `dev-secure-application-config.yaml` |
| `ACCESS_REFUSED` en RabbitMQ | Usuario `tih-app` sin crear o con otra clave | Vuelve a ejecutar `start-infra` y revisa el YAML de las PAPI |
| El pedido se queda en `pending` | Un backend no responde (Oracle, proveedor o mock) | Revisa la consola de `papi-orders`; se reintenta en cada ciclo |
| El pedido va a `error` | Datos inválidos: artículo inexistente o CSV mal formado | Revisa el log; el archivo queda en `/orders/error` |
| El correo no llega | Sin token de MagicBell o canal de email sin habilitar | El mensaje queda en `orders.registered.dlq`; configura MagicBell |
| Error al cargar scripts `.sh` en el contenedor (`\r`) | El repositorio se clonó con finales de línea de Windows | Clona de nuevo con el `.gitattributes` incluido, o convierte los `.sh` a LF |
