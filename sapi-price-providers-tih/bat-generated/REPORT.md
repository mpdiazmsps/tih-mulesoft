# Reporte de la suite BAT — sapi-price-providers-tih

Ejecutada el 2026-10-14 contra la app en `http://localhost:8093/api/v1/price-providers` y el mock de SoapUI de Borland en `http://localhost:8088/mockOrderServiceSoap`.

## Resultado

**16/16 pruebas aprobadas · 60/60 aserciones aprobadas.** Reportes en `reports/bat-report.html` y `reports/bat-report.json`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 5 |
| Robustness | 9 |
| Security | 2 |
| **Total** | **16** |

| Procedencia | Pruebas |
| --- | --- |
| existing | 12 |
| refined | 1 (`get-price-fak-unknown-product`: ahora afirma 404 tras corregir el defecto) |
| new | 3 (`get-price-bor-happy-path`, `get-price-bor-last-article`, `get-price-bor-unknown-product`) |
| dropped | 1 (`get-price-bor-not-supported`: BOR ya no responde 501) |

## Cobertura

Endpoint: `GET /providers/{providerAbv}/products/{externalId}/price` (único listener) y `POST` sobre el mismo recurso (405).

| Tipo de error (`raise-error`) | Prueba que lo cubre |
| --- | --- |
| `APP:PRODUCT_NOT_FOUND` | `get-price-esc-unknown-product`, `get-price-fak-unknown-product`, `get-price-bor-unknown-product` |
| `APP:PROVIDER_NOT_SUPPORTED` | No cubierto: ya no es alcanzable por HTTP (el enum de la API rechaza proveedores no soportados con 400) |
| `APP:PROVIDER_UNAVAILABLE` / `WSC:CANNOT_DISPATCH` / `WSC:TIMEOUT` (503) | No cubierto en BAT (cubierto en MUnit) |
| Errores de proveedor 502 | No cubierto en BAT (cubierto en MUnit) |
| Validación APIkit 400/405 | invalid-provider, external-id-not-integer/zero/negative, price-method-not-allowed, missing-client-headers, missing-client-secret |

| Proveedor | Pruebas |
| --- | --- |
| FAK | happy-path, idempotent, unknown-product |
| ESC | happy-path, unknown-product, error-echoes-correlation-id |
| BOR (SOAP) | happy-path (id 1), last-article (id 5), unknown-product (id 99) |

## Discrepancias y notas para revisión humana

1. **`PROVIDER_NOT_SUPPORTED` inalcanzable por HTTP.** Con BOR implementado, la rama `otherwise` del `choice` solo se alcanza si el enum del RAML cambia sin tocar el flujo. Se valida solo en MUnit.
2. **502/503 sin cobertura BAT.** Provocarlos exige apagar el mock o el proveedor, algo que una suite black-box no debe hacer sola. Siguen cubiertos en MUnit (BOR 503 + `Retry-After`).
3. **Dependencia del mock.** Las 3 pruebas BOR requieren el mock de SoapUI encendido en 8088 con el catálogo fijo (ids 1 a 5; el 99 no existe). Si el mock está apagado, fallarán por 503, no por defecto de la app.
4. **Datos mutables.** Las pruebas de FAK y ESC dependen de APIs públicas; ESC solo valida estructura por eso. FAK fija el precio 109.95 del producto 1.
5. **Seguridad local.** Sin la política de API Manager, la ausencia de `client_id`/`client_secret` da 400 (APIkit) y no 401.
6. **FAK y Content-Length.** El defecto original (200 con cuerpo vacío) está corregido; la detección depende de `Content-Length: 0` o payload vacío.

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
