# specs: contratos RAML de la PoC

Contrato primero: un cambio de comportamiento empieza aquí. Esta carpeta es la fuente que se edita;
lo que se publica en Exchange sale de aquí con `package-exchange.mjs`. Ninguna app guarda copia de su contrato.

```
specs/
  fragments/poc-common/
    poc-common.raml   # la librería común (main en Exchange): declara cada tipo y cada trait con !include
    types/            # un fragmento DataType por tipo, en una carpeta por sección:
      identifiers/  catalogs/  customers/  orders/  inventory/  quotes/
      dispatch-notes/  order-360/  order-requests/  errors/
    traits/           # un fragmento Trait por trait: secured, validated, paged, not-found, conflict, bad-gateway, retryable
  sapi-oracle-core/sapi-oracle-core.raml          # oleada 1
  sapi-crm/sapi-crm.raml                          # oleada 1
  sapi-sftp-orders/sapi-sftp-orders.raml          # oleada 1
  sapi-price-providers/sapi-price-providers.raml  # oleada 1
  papi-customers/  papi-orders/  papi-order-requests/  papi-notifications/   # oleada 2
  xapi-online-store/xapi-online-store.raml        # oleada 3: la fachada REST (14 operaciones)
  mcp-online-store/tools.yaml                     # oleada 3: las 5 herramientas del agente (no es RAML)
  tools/              # validadores (RAML y tools.yaml) y empaquetador
```

Las carpetas `*-tih` son los contratos de la base, ya reemplazados por los de la PoC; se conservan como referencia y el validador las ignora.

## Convenciones

- Todo el contrato va en inglés (D5): campos en camelCase (`orderId`, `lines`, `dispatchNote`), enums (`RECEIVED`, `STOCK_SHORTAGE`), descripciones y `displayName`. Los datos del guion en los ejemplos se quedan como son.
- Pedidos, artículos y solicitudes se identifican con UUID; el cliente, con el Id de Salesforce de 18 caracteres.
- Moneda ISO 4217 (siempre `MXN`) y fechas ISO 8601 con zona horaria.
- `baseUri` genérico y solo HTTPS, como desplegado en CloudHub 2.0: `https://{host}/api/{version}/<ruta>`, con `baseUriParameters.host` (el endpoint público de la app en CloudHub) y `protocols: [HTTPS]`. El contrato no menciona el ambiente local; en local las apps escuchan en HTTP con la misma ruta.
- Todos los métodos llevan `secured` (`client_id`, `client_secret` y `x-correlation-id`). Los `503` llevan `Retry-After`.
- Los ejemplos usan los datos del guion (ver `data/README.md`).

Cada archivo de `types/` es un fragmento `#%RAML 1.0 DataType` y cada uno de `traits/` un `#%RAML 1.0 Trait`.
- Un tipo que usa a otro lo referencia con `!include` y ruta relativa (`segment: !include ../catalogs/Segment.raml`),
  nunca por su nombre: dentro de un fragmento un nombre suelto no se resuelve y el validador no lo avisa.
- Un trait toma `ErrorResponse` con `!include ../types/errors/ErrorResponse.raml` (no puede usar `poc-common.raml`: sería un ciclo).
- Las APIs usan una sola librería: `uses: common: ../fragments/poc-common/poc-common.raml`, y `common.Customer`, `common.secured`.
- Para agregar un tipo: crear `types/<sección>/<Tipo>.raml` con su cabecera y agregar `<Tipo>: !include ...` en `poc-common.raml`.

## Validar

Requiere Node.js. La primera vez: `npm --prefix specs/tools install`.

```
npm --prefix specs/tools run validate
```

Sin argumentos valida el fragmento y cada `specs/<api>/<api>.raml`. Usa el parser AMF de MuleSoft:
sintaxis, referencias y que los ejemplos cumplan sus tipos.

El contrato del servidor MCP (`mcp-online-store/tools.yaml`) se valida aparte, con el esquema JSON
`tools/tools.schema.json` y reglas extra (cinco herramientas, solo `request_correction` escribe y con llave derivada,
ninguna aprueba ni aplica):

```
npm --prefix specs/tools run validate-tools
```

Gobernanza (opcional, unos 4 minutos por API, usa la CLI de Anypoint):

```
node specs/tools/package-exchange.mjs --group <orgId> --version 1.0.0 --only <api> --bundle --out tmp/gov
# descomprimir tmp/gov/<api>-1.0.0.zip en tmp/gov/<api>/ y luego:
anypoint-cli-v4 governance:api:validate tmp/gov/<api> --rulesets infra/governance/tih-raml-conventions.yaml
```

## Empaquetar para Exchange

```
node specs/tools/package-exchange.mjs --group <orgId> --version 1.0.0 [--only <asset>] [--bundle]
```

Deja un zip por asset en `tmp/exchange/`:
- `poc-common-<v>.zip`: el fragmento (`classifier: raml-fragment`).
- `<api>-<v>.zip`: el RAML con los `uses` reescritos a `exchange_modules/<orgId>/poc-common/<v>/...`
  y `poc-common` declarado como dependencia en `exchange.json`.
- `--bundle` (plan B): mete el fragmento dentro de cada zip y no declara la dependencia.

Orden de publicación: primero `poc-common`, después las APIs.
