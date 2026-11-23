# Integración en la era agéntica: PoC con MuleSoft

Una capa de integración API-led que deja a cualquier canal, la tienda en línea o un agente de IA, trabajar con cinco
sistemas de registro distintos sin unificarlos y sin riesgo. El agente es un consumidor más: consulta, propone y pide;
una persona decide.

Esta es la **v1 local**: las 10 apps Mule corren en Anypoint Studio y las dependencias en Docker, con Salesforce
Developer Edition como CRM real. Con este README se levanta todo y se recorren las cuatro escenas de la demo.

## Contenido

1. [Qué hay](#1-qué-hay)
2. [Requisitos](#2-requisitos)
3. [Levantar las dependencias](#3-levantar-las-dependencias)
4. [Configurar las apps](#4-configurar-las-apps)
5. [Correr las apps en Studio](#5-correr-las-apps-en-studio)
6. [Verificar de punta a punta](#6-verificar-de-punta-a-punta)
7. [Dar la demo](#7-dar-la-demo)
8. [Estructura del repositorio](#8-estructura-del-repositorio)
9. [Problemas comunes](#9-problemas-comunes)

---

## 1. Qué hay

### Sistemas de registro (cada uno es dueño de su dato)

| Sistema | Tecnología | Dónde corre |
|---|---|---|
| ERP: pedidos e inventario | Oracle (esquema `STORE_APP`) | Docker `poc-oracle` |
| CRM: clientes y su segmento | Salesforce Developer Edition | La nube (requiere internet) |
| Logística: remisiones y acuses | Archivos por SFTP y un simulador del operador | Docker `poc-sftp`, `poc-logistics-sim` |
| Proveedores A, B y C | REST, REST y SOAP simulados | Docker `poc-wiremock` |
| Avisos por correo | MagicBell | La nube |

Además: RabbitMQ (`poc-rabbitmq`) para los eventos y el esquema `INTEGRATION_APP` de Oracle para las solicitudes de
corrección.

### Las apps (Mule 4.11.4, Java 17)

| App | Capa | Puerto | Qué hace |
|---|---|---|---|
| `xapi-online-store` | Experience | 8080 | La única puerta REST de la tienda y el aprobador (14 operaciones) |
| `mcp-online-store` | Experience | 8086 | El canal de agentes: servidor MCP con 5 herramientas en `/mcp` |
| `papi-customers` | Process | 8082 | Clientes sobre el CRM |
| `papi-orders` | Process | 8083 | Pedidos, ciclo de confirmación, Pedido 360, excepciones, alternativas y correcciones |
| `papi-notifications` | Process | 8084 | Correos por evento (pedido confirmado, solicitud por aprobar, corrección aplicada) |
| `papi-order-requests` | Process | 8085 | Solicitudes de corrección: llave única, estados, aprobación por personas |
| `sapi-oracle-core` | System | 8091 | ERP en Oracle |
| `sapi-sftp-orders` | System | 8092 | Remisiones y acuses por SFTP |
| `sapi-price-providers` | System | 8093 | Cotizaciones de los proveedores A, B (REST) y C (SOAP) |
| `sapi-crm` | System | 8094 | Contactos de Salesforce (conector con JWT) |

Librerías: `libs/poc-resilience` (tiempo límite, reintento y circuito por fuente) y el fragmento RAML `poc-common`.
Los contratos viven en `specs/` y se publican en Exchange; cada app toma su contrato de ahí. Cada app tiene su README.

## 2. Requisitos

| Herramienta | Para qué |
|---|---|
| Docker Desktop (Compose v2) | Las dependencias locales |
| Anypoint Studio 7 con el runtime Mule 4.11 EE | Correr las apps |
| Java 17 y Maven 3.9 | Compilar y correr las pruebas MUnit fuera de Studio |
| Node.js 18 o superior | Semillas de datos, validación de contratos y scripts de la demo |
| CLI de Salesforce (`sf`) | Cargar los clientes y cambiar el segmento en la escena 2 |
| Cuenta de Anypoint Platform | Descargar los contratos de Exchange al compilar |
| Postman (opcional) y un cliente MCP | La tienda y el agente durante la demo |

Al menos 8 GB de RAM libres para Docker y Studio.

## 3. Levantar las dependencias

1. **Docker:** sigue `infra/README.md`. En resumen:
   ```powershell
   .\infra\scripts\start-infra.ps1     # crea las credenciales locales desde sus plantillas, la llave del SFTP y las semillas
   ```
   Los contenedores llevan el prefijo `poc-` y no tocan otros proyectos. Si un puerto está ocupado, cámbialo en
   `infra/.env` (la base de Oracle queda en 1523 por omisión).
2. **Salesforce:** sigue `infra/salesforce/README.md`: org Developer Edition, `sf org login web --alias poc`,
   despliegue de los campos y la aplicación conectada con JWT, y la carga de los 4 clientes del guion
   (`node infra/salesforce/seed-contacts.mjs`).
3. **MagicBell:** sigue `infra/magicbell/README.md` y deja el token en `infra/magicbell/credentials.local`.
4. **Datos del guion:**
   ```powershell
   .\demo\control.ps1 reset
   ```

## 4. Configurar las apps

### Clave de cifrado

Las propiedades seguras se cifran con AES/CBC. Define tu clave (16 caracteres) en la variable de entorno de usuario
`POC_ENC_KEY`; las apps la reciben con `-M-Dencryption.key` y Maven con `-Dencryption.key`. La clave nunca va en el
repositorio.

### Propiedades seguras (no se versionan)

Cinco apps tienen `src/main/resources/properties/local-secure-application-config.yaml`. Cópialo de su `.example` y
llénalo con valores cifrados con tu clave (skill `secure-mule-app` o la Secure Properties Tool):

| App | Valores |
|---|---|
| `sapi-oracle-core` | Usuario y clave de `STORE_APP` (`infra/oracle/credentials.local`) |
| `papi-order-requests` | Usuario y clave de `INTEGRATION_APP`, y el usuario de las apps de RabbitMQ |
| `papi-orders` | Usuario de las apps de RabbitMQ (`infra/rabbitmq/credentials.local`) |
| `papi-notifications` | Token de MagicBell y usuario de las apps de RabbitMQ |
| `sapi-crm` | Consumer key de la aplicación conectada, usuario de Salesforce y clave del keystore `poc-sf.p12` |

## 5. Correr las apps en Studio

1. **Importar:** File → Import → Anypoint Studio project from File System, cada carpeta de `apps/` y
   `libs/poc-resilience`. **Desmarca "Copy project into workspace"** para trabajar sobre el repositorio.
2. **Una sola configuración de ejecución** (Run → Run Configurations), por ejemplo `poc-mule`, con las 10 apps
   marcadas y estos VM arguments:
   ```
   -M-Denv=local -M-Dencryption.key=<POC_ENC_KEY> -M-Ddb.port=<puerto de poc-oracle>
   -M-Dsftp.identityFile=<ruta del repo>/infra/sftp/keys/poc_sftp_rsa
   -M-Dsalesforce.keyStore=<ruta del repo>/infra/salesforce/certs/poc-sf.p12
   -M-Danypoint.platform.gatekeeper=disabled
   ```
   - `-M-Denv=local` hace falta si tu sistema tiene una variable de entorno `env` (gana sobre el valor por omisión).
   - `gatekeeper=disabled` deja la xapi responder en local sin API Manager; en CloudHub aplica Client ID Enforcement.
3. **Run.** Espera a que las 10 apps digan `DEPLOYED`.

En local no hay API Manager: cualquier `client_id`/`client_secret` funciona. El `client_id` identifica a quien llama:
`tienda-web` (tienda), `aprobador-tienda` (el único que aprueba) y `agente-mcp` (el agente).

### Compilar y probar con Maven

```bash
mvn -B -f apps/<app>/pom.xml clean package "-Dencryption.key=$POC_ENC_KEY"
```

Corre las pruebas MUnit de la app (cobertura mínima 80%). Las suites HTTP necesitan libre el puerto de la app, así que
se corren con Studio detenido.

## 6. Verificar de punta a punta

Con las 10 apps corriendo:

```powershell
.\tests\run-e2e.ps1          # Linux, macOS o Git Bash: ./tests/run-e2e.sh
```

Restaura los datos, corre las cuatro escenas con newman (colección `tests/postman/poc-e2e.postman_collection.json`,
ambiente `local.postman_environment.json`) intercalando los cambios de la demo (segmento en Salesforce, proveedor C
lento, SFTP apagado) y al final deja todo normal. Esperado: 0 aserciones fallidas, también si se corre dos veces
seguidas. La tienda pasa por la xapi y el agente por MCP, con los mismos resultados.

## 7. Dar la demo

El guion de diez minutos, con las preguntas al agente y los comandos de cada escena, está en `docs/guion-demo.md`.
La versión explicada (camino feliz, cómo funciona por dentro, qué mirar en cada sistema) está en
`docs/guia-demo-explicada.md`, con la colección `tests/postman/poc-demo-guiada.postman_collection.json`.
Los controles:

```powershell
.\demo\control.ps1 reset                # datos del guion y segmentos de Salesforce
.\demo\control.ps1 cumbres-regular      # escena 2: Cumbres pasa a Regular en Salesforce (cumbres-strategic lo regresa)
.\demo\control.ps1 slow-c               # escena 3: el proveedor C tarda 5 s (normal-c lo regresa)
.\demo\control.ps1 sftp-down            # escena 3: logística apagada (sftp-up la enciende)
.\demo\inspect.ps1 pedidos              # registros: pedidos|inventario|movimientos|solicitudes|historia|sftp|colas
```

## 8. Estructura del repositorio

```
apps/        Las 10 apps Mule (código, MUnit, propiedades y README de cada una)
libs/        poc-resilience: patrones de resiliencia compartidos
specs/       Contratos RAML (y tools.yaml del servidor MCP), fragmento poc-common, validadores y empaquetador para Exchange
data/        Los datos del guion (scenario.json) y el generador de semillas
infra/       Docker compose, Oracle, RabbitMQ, SFTP, WireMock, Salesforce, MagicBell y scripts de arranque
demo/        Controles de la demo (fallas, segmento, reset) y el simulador de logística
tests/       Colecciones de Postman (por app y de las cuatro escenas) y run-e2e
docs/        Guion de la demo, diseño y plan de la PoC (docs/superpowers/) y diagramas
```

Las carpetas `*-tih` y las copias de proyectos en la raíz (por ejemplo `papi-orders/`) no son parte de la PoC: son la
base anterior y copias de trabajo de Studio, ignoradas por Git.

## 9. Problemas comunes

| Síntoma | Qué hacer |
|---|---|
| Studio da `NoClassDefFoundError` (`scala/collection/GenSet$`) al volver a desplegar una app | Detén toda la configuración y dale Run de nuevo; no redespliegues una app con el runtime encendido |
| Una app no encuentra `dev-application-config.yaml` | Falta `-M-Denv=local` en los VM arguments |
| La primera consulta del Pedido 360 tarda unos 5 s y marca "0 of 3" | Arranque en frío: repítela. `run-e2e` y el guion calientan antes |
| Tras apagar logística o retrasar C, la fuente sigue faltando | Su circuito se abrió (3 fallas seguidas): espera 30 s |
| `cumbres-regular` dice que la org no tiene sesión | `sf org login web --alias poc` |
| `ACCESS_REFUSED` en RabbitMQ | Vuelve a correr `start-infra` (crea los usuarios) y revisa las propiedades seguras |
| No llega un correo | Revisa spam, el token de MagicBell y las colas `*.dlq` en la consola de RabbitMQ (`http://localhost:15673`) |
