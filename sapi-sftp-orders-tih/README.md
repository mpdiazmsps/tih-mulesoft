# sapi-sftp-orders-tih

System API sobre el servidor SFTP de pedidos. Implementa el contrato `src/main/resources/api/sapi-sftp-orders-tih.raml` (copia del RAML de `specs/`).

- Mule Runtime 4.11.4 (EE), Java 17. Conectores: HTTP 1.12.1, APIkit 1.11.16 y SFTP 2.7.1.
- Sin conexión a Anypoint Platform: no hay Autodiscovery ni política Client ID.
- Carpetas en el servidor: `/orders/pending` (por procesar), `/orders/processed` y `/orders/error`.

## Recursos

Base: `http://localhost:8092/api/v1/sftp/orders`. Todas las peticiones llevan los headers `client_id` y `client_secret` (en local sirve cualquier valor).

| Método | Recurso | Respuestas |
|---|---|---|
| GET | `/files?status=pending\|processed\|error` | 200, 400, 503 |
| PUT | `/files/{fileName}` (cuerpo `text/csv`) | 201, 400, 409, 503 |
| GET | `/files/{fileName}?status=` | 200 (`text/csv`), 400, 404, 503 |
| POST | `/files/{fileName}/move` (cuerpo `{"target": "processed"\|"error"}`) | 200, 400, 404, 409, 503 |

- `PUT` escribe primero `<nombre>.tmp` y luego lo renombra, para que nadie lea un archivo a medio escribir. No sobrescribe: si ya existe responde 409 y borra el `.tmp`.
- `move` va de `pending` a `processed` o `error` sin sobrescribir.
- El nombre del archivo solo admite letras, números, guion y guion bajo, con extensión `.csv` (el contrato rechaza `..` y rutas).

## Estructura (estándar MADO v1.1)

```
src/main/mule/
  interface.xml                       # listener, APIkit y flujos de interfaz (solo flow-ref)
  common/global.xml                   # propiedades por ambiente y conexión SFTP
  handlers/global-error-handlers.xml  # traduce cualquier error al ErrorResponse del contrato
  implementations/*.xml               # list-files, put-file, get-file, move-file
src/main/resources/{api,dataweave,properties}
src/test/munit/                       # 20 pruebas, cobertura 100 %
```

## Configuración

- `properties/dev-application-config.yaml`: puerto del listener (8092), host y puerto del SFTP (`localhost:2222`).
- `properties/dev-secure-application-config.yaml` (ignorado por Git): usuario y contraseña del SFTP. Ya está llena con las del Rebex del proyecto (`infra/sftp/credentials.local`). Plantilla: `...yaml.example`. Por ahora en claro y solo para local.

## Compilar y probar

Requiere **el Rebex corriendo** (`infra/sftp/rebex/app/RebexTinySftpServer.exe`, puerto 2222), porque las pruebas hacen operaciones reales de crear, listar, leer y mover un archivo `it-*.csv` y lo borran al terminar. Si el puerto 8092 está ocupado (la app corriendo en Studio), la suite HTTP falla: detén la app primero.

```
cd apps/sapi-sftp-orders-tih
mvn -o -B clean package
```

Resultado esperado: 20 pruebas, 0 fallos, cobertura 100 % y `target/sapi-sftp-orders-tih-1.0.0-SNAPSHOT-mule-application.jar`.

## Ejecutar en Anypoint Studio

1. **File → Import → Anypoint Studio → Mule Project from File System** y elige esta carpeta.
2. **Run As → Mule Application**. Ambiente por defecto: `dev`.
3. Ejemplo:

```
curl -X PUT -H "client_id: x" -H "client_secret: y" -H "Content-Type: text/csv" --data-binary $'item,qty\nabc,1\n' http://localhost:8092/api/v1/sftp/orders/files/mi-pedido.csv
curl -H "client_id: x" -H "client_secret: y" http://localhost:8092/api/v1/sftp/orders/files
```

## Notas de diseño

- Los conectores reemplazan los `attributes`: nombre y carpeta se guardan en variables antes de la primera operación SFTP.
- Con el payload tipado `text/csv`, DataWeave lo interpreta como tabla; por eso `PUT` lo trata como bytes crudos para medirlo y escribirlo intacto.
- El conector SFTP responde `SFTP:ILLEGAL_PATH` (no `FILE_DOESNT_EXIST`) cuando el archivo no existe; ambos se traducen en 404 `FILE_NOT_FOUND`.
- Los errores de conexión (`SFTP:CONNECTIVITY`, credenciales, servicio no disponible) responden 503 `retryable: true` con `Retry-After`.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
