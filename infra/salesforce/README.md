# Salesforce: el CRM de la PoC

Los clientes de la PoC viven solo en Salesforce (Developer Edition); el ERP guarda únicamente el Id de 18 caracteres.
Este proyecto `sf` deja la org lista:

| Metadato | Qué es |
|---|---|
| `Contact.Segmento__c` | Picklist `Estratégico` / `Regular`; sapi-crm lo traduce a `STRATEGIC` / `REGULAR` |
| `Contact.External_Id__c` | Llave externa única de los contactos del guion (`POC-...`) |
| `POC_Integracion` | Conjunto de permisos del usuario de integración (contactos y los dos campos) |
| `POC_Email_Exacto` + `POC_Bloquear_Correo_Duplicado` | Regla de coincidencia por correo exacto y regla de duplicados que **bloquea** crear o editar un contacto con un correo que ya existe, también por API (D22). La regla va con `sortOrder` 2 porque la org ya trae `Standard_Contact_Duplicate_Rule` en el 1. |

Así quedó la org de la v1 (20 de noviembre de 2026): org Developer Edition con alias `poc`, 4 contactos `POC-*` y la
aplicación de cliente externo `POC sapi-crm`.

## 1. Org y CLI (una vez)

1. Crea una org de Salesforce Developer Edition: <https://developer.salesforce.com/signup>.
2. Instala la Salesforce CLI (`sf`): <https://developer.salesforce.com/tools/salesforcecli>.
   - En Windows se instala en `C:\Program Files\sf\bin` y **puede no quedar en el PATH**. Agrégalo a tu PATH de usuario
     (los scripts llaman a `sf`) o llámala con la ruta completa. Desde Git Bash: `"/c/Program Files/sf/bin/sf"`.
3. Inicia sesión y deja el alias `poc` (lo usan todos los scripts). Se abre el navegador para autorizar:
   ```
   sf org login web --alias poc
   ```

## 2. Metadatos y contactos

Desde `infra/salesforce`:

```
sf project deploy start --source-dir force-app --target-org poc
sf org assign permset --name POC_Integracion --target-org poc
```

Desde la raíz del repo, carga los 4 clientes del guion (se puede repetir: hace upsert por `External_Id__c`) y vuelve
a generar la semilla del ERP con los Ids reales:

```
node infra/salesforce/seed-contacts.mjs
.\infra\scripts\reset-data.ps1        # regenera las semillas y recarga el ERP
```

`seed-contacts` escribe `data/salesforce-ids.local.json` (no se versiona).

Notas de la CLI `sf` 2.159 (las resuelve `sf-session.mjs`):
- `sf org display` ya no entrega el token de sesión real; por eso los scripts llaman a la API con
  `sf api request rest` (autentica por dentro) y la PoC nunca lee ni guarda el token.
- `sf api request rest` falla en un `DELETE` sin cuerpo; para borrar se usa `sf data delete record`.

## 3. Certificado y aplicación para sapi-crm (JWT)

sapi-crm entra a Salesforce sin intervención humana con el flujo **OAuth 2.0 JWT Bearer**: firma con una llave
privada (en un `.jks`) y Salesforce la valida con el certificado público cargado en la aplicación.

### 3.1 Certificado (en una terminal tuya, no en un chat)

`keytool` pide la contraseña de forma interactiva: **la contraseña la eliges tú en ese momento** (mínimo 6
caracteres) y crea el almacén con ella. Guárdala en tu gestor de contraseñas; sapi-crm la necesita (tarea 14).

```powershell
cd C:\Users\<usuario>\AnypointStudio\mule-skills-demo
New-Item -ItemType Directory -Force infra\salesforce\certs | Out-Null
& "C:\Program Files\Java\jdk-17\bin\keytool.exe" -genkeypair -alias poc-sf -keyalg RSA -keysize 2048 -validity 365 -dname "CN=poc-sapi-crm" -keystore infra\salesforce\certs\poc-sf.jks -storetype JKS
& "C:\Program Files\Java\jdk-17\bin\keytool.exe" -exportcert -rfc -alias poc-sf -keystore infra\salesforce\certs\poc-sf.jks -file infra\salesforce\certs\poc-sf.crt
```

- El primer comando pide la contraseña dos veces; si pregunta por la clave de la llave, Enter (la misma).
- El segundo pide la misma contraseña y genera `poc-sf.crt`, el que se sube a Salesforce.
- `infra/salesforce/certs/` y `*.jks` están en `.gitignore`.
- El `!` de Claude Code no es interactivo: ahí `keytool` falla con "password is too short".

### 3.2 Aplicación de cliente externo (interfaz en español)

Las orgs nuevas ofrecen **aplicaciones de cliente externo** en lugar de las aplicaciones conectadas clásicas.

1. **Configuración** (engrane ⚙️) → *Búsqueda rápida*: `Gestor de aplicaciones de cliente externo` → **Nueva aplicación
   de cliente externo**.
   - Si prefieres una aplicación conectada clásica: *Búsqueda rápida* → `Configuración de aplicaciones de cliente
     externo` → activa **Permitir la creación de aplicaciones conectadas**; aparece **Nueva aplicación conectada** en el
     *Gestor de aplicaciones*.
2. **Datos básicos**
   - Nombre de la aplicación: `POC sapi-crm`.
   - **Nombre de API**: `POC_sapi_crm` (solo letras, números y guion bajo; un guion `-` da error).
   - Correo electrónico de contacto: el del equipo.
3. **API (Activar configuración de OAuth)** → marca **Activar OAuth**.
   - URL de devolución de llamada: `http://localhost:1717/OauthRedirect` (JWT no la usa, pero es obligatoria).
   - Ámbitos de OAuth: *Gestionar datos de usuario mediante API (api)* y *Realizar solicitudes en cualquier momento
     (refresh_token, offline_access)*.
   - **Configuración de flujo** → marca **Activar flujo de portador JWT** y carga `poc-sf.crt`
     (en una aplicación conectada clásica: **Usar firmas digitales**, que aparece al marcar *Activar parámetros de OAuth*).
   - Guarda.
4. **Clave del consumidor (Consumer Key).** En la aplicación → pestaña **Configuración** → sección *Configuración de
   OAuth* → **Clave del consumidor y secreto**. Salesforce envía un código por correo para verificar. Copia la
   **Clave del consumidor** (el secreto no se usa con JWT) y guárdala; se cifra en sapi-crm (tarea 14).
5. **Políticas.** En la aplicación → pestaña **Políticas** → **Modificar**:
   - *Políticas de OAuth* → **Usuarios permitidos**: *Los usuarios aprobados por el administrador están autorizados previamente*.
   - *Políticas de la aplicación* → **Conjuntos de permisos**: pasa **POC Integración** a *Seleccionados*.
   - Guarda. Los cambios pueden tardar de 2 a 10 minutos en activarse.

### 3.3 Prueba del JWT (opcional, en tu terminal)

La CLI necesita la llave privada en PEM; sacarla del `.jks` pide la contraseña del almacén:

```powershell
& "C:\Program Files\Java\jdk-17\bin\keytool.exe" -importkeystore -srckeystore infra\salesforce\certs\poc-sf.jks -srcalias poc-sf -destkeystore infra\salesforce\certs\poc-sf.p12 -deststoretype PKCS12
& "C:\Program Files\Git\usr\bin\openssl.exe" pkcs12 -in infra\salesforce\certs\poc-sf.p12 -nocerts -nodes -out infra\salesforce\certs\poc-sf.key
sf org login jwt --client-id <Clave del consumidor> --jwt-key-file infra\salesforce\certs\poc-sf.key --username <usuario de la org> --alias poc-jwt
```

"Successfully authorized" confirma la aplicación. Los archivos quedan en `certs/` (ignorado por git).

### 3.4 Lo que necesita sapi-crm (tarea 14)

En sus propiedades seguras: la Clave del consumidor, el usuario de Salesforce, la ruta del `.jks`, su contraseña y el
alias `poc-sf`.

### Correo único (D22, ajuste del 22-nov)

`Contact.Email_Key__c` (texto 80, **único**, sin distinguir mayúsculas) guarda el correo en minúsculas. Lo llena
sapi-crm al crear y la semilla (`seed-contacts.mjs`) en los 4 contactos. La regla de duplicados solo compara contra
registros ya guardados: dos altas simultáneas con el mismo correo pasaban las dos. Con el campo único, Salesforce
rechaza la segunda con `DUPLICATE_VALUE` y sapi-crm responde 409 `CONTACT_ALREADY_EXISTS`. El conjunto
`POC Integración` tiene permiso de edición sobre el campo y el retiro lo borra.

La org tiene listas de estados y países: un estado necesita su país y el valor válido es `Mexico` (no `México` ni
`MX`). sapi-crm manda `MailingCountry = Mexico` cuando hay dirección.

## 4. Retiro

`infra/scripts/teardown` borra los contactos `POC-*` y estos metadatos (`teardown-salesforce.mjs`: primero desactiva
la regla de duplicados, después la de coincidencia (Salesforce no deja desactivarlas juntas) y al final aplica `destructiveChangesPost.xml`). Al volver a desplegar hay que
reasignar el conjunto `POC_Integracion` al usuario y volver a agregarlo en las *Políticas* de la aplicación. La
aplicación de cliente externo y el certificado se quitan a mano.
