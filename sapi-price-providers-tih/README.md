# sapi-price-providers-tih

SAPI que consulta el precio de un artículo con los proveedores externos. Contrato: `specs/sapi-price-providers-tih/sapi-price-providers-tih.raml`.

| Proveedor | Clave | Origen | Estado |
|---|---|---|---|
| Fakestore | `FAK` | `https://fakestoreapi.com/products/{id}` | Implementado |
| Escuelajs | `ESC` | `https://api.escuelajs.co/api/v1/products/{id}` | Implementado |
| Borland | `BOR` | SOAP 1.1, servicio `OrderService`, operación `GetArticleById` (en local, el mock de SoapUI en `http://localhost:8088/mockOrderServiceSoap`) | Implementado |

## Operación

`GET /api/v1/price-providers/providers/{providerAbv}/products/{externalId}/price` (puerto local 8093) → `Price`:

```json
{ "externalId": 1, "providerAbv": "FAK", "name": "Backpack", "price": 109.95, "currency": "USD" }
```

## Errores

| Situación | HTTP | code |
|---|---|---|
| Fakestore responde vacío / Escuelajs responde 400 | 404 | `PRODUCT_NOT_FOUND` |
| Borland (BOR) no conoce el artículo (respuesta sin `GetArticleByIdResult`) | 404 | `PRODUCT_NOT_FOUND` |
| Borland (BOR) sin conexión o sin respuesta (`WSC:CANNOT_DISPATCH`, `WSC:TIMEOUT`) | 503 + `Retry-After` | `SERVICE_UNAVAILABLE` |
| Proveedor caído o sin respuesta | 503 + `Retry-After` | `SERVICE_UNAVAILABLE` |
| Proveedor responde 5xx | 502 | `PROVIDER_ERROR` |
| Proveedor fuera del RAML / parámetros inválidos | 400 | `VALIDATION_ERROR` |

## Ejecución

- Propiedades: `src/main/resources/properties/dev-application-config.yaml` (sin credenciales; APIs públicas).
- Requiere salida a internet por HTTPS (443) al ejecutarla.
- Pruebas: `mvn -o -B clean package` (18 MUnit: 10 de flujo y 8 HTTP, cobertura 100 %). Los proveedores se simulan; la suite HTTP necesita el puerto 8093 libre y no usa internet.

## Borland (BOR) por SOAP

- Conector: Web Service Consumer 2.1.2 (`wsc:consume`, operación `GetArticleById`, SOAP 1.1). El WSDL va empaquetado en `src/main/resources/wsdl/borland-orderservice.wsdl`.
- Dirección del servicio: propiedad `provider.bor.address` (`dev-application-config.yaml` y `dev-application-config.yaml`). En local apunta al mock de SoapUI.
- Mock: `borland-mock/` trae el proyecto de SoapUI listo para importar (`OrderService-Borland-Mock-soapui-project.xml`) con los artículos 1 a 5; ver su `README.md`.
- Un id que Borland no conoce responde `GetArticleByIdResponse` vacío; la app lo traduce a 404.
- Errores del conector: `WSC:CANNOT_DISPATCH` y `WSC:TIMEOUT` → 503; `WSC:SOAP_FAULT`, `BAD_RESPONSE`, `EMPTY_RESPONSE`, `BAD_REQUEST`, `ENCODING` e `INVALID_WSDL` → 502.

## Ambientes

Hay tres ambientes: `dev` (por defecto), `qa` y `prod`. El archivo se elige con la propiedad `env` (`properties/${env}-application-config.yaml`, y `${env}-secure-application-config.yaml` donde hay credenciales cifradas). Para cambiar de ambiente, agrega la VM arg `-M-Denv=qa` (o `prod`) en Run Configurations. Los archivos de `qa` y `prod` empezaron como copia de `dev`: cambia sus hosts, puertos y valores cifrados antes de usarlos.
