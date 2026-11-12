# Reporte de la suite BAT — sapi-oracle-core-tih

Ejecutada el 2026-10-20 contra la app en local.

## Resultado

**21/21 pruebas aprobadas.** Reportes en `reports/bat-report.json`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 9 |
| Robustness | 11 |
| Security | 1 |
| **Total** | **21** |

Procedencia: 21 nuevas (no había suite previa).

## Cobertura

| Endpoint | Prueba | Estado esperado |
| --- | --- | --- |
| POST /customers | post-customer-happy-path | 201 |
| POST /customers | post-customer-phone-only | 201 |
| POST /customers | post-customer-duplicate-email | 409 CUSTOMER_ALREADY_EXISTS |
| POST /customers | post-customer-invalid-email | 400 VALIDATION_ERROR |
| POST /customers | post-customer-missing-name | 400 VALIDATION_ERROR |
| GET /customers/{} | get-customer-by-id | 200 |
| GET /customers/{} | get-customer-not-found | 404 CUSTOMER_NOT_FOUND |
| GET /customers/{} | get-customer-invalid-uuid | 400 |
| GET /customers | search-customers-by-email | 200 |
| GET /customers | search-customers-no-match | 200 |
| GET /customers | search-customers-no-filter | 400 VALIDATION_ERROR |
| GET /inventory/items | get-inventory-items | 200 |
| GET /inventory/items | get-inventory-items-unknown-id | 200 |
| GET /inventory/items | get-inventory-items-invalid-ids | 400 |
| POST /orders | post-order-happy-path | 201 |
| POST /orders | post-order-duplicate | 409 ORDER_ALREADY_EXISTS |
| POST /orders | post-order-unknown-item | 400 VALIDATION_ERROR |
| POST /orders | post-order-empty-items | 400 |
| GET /orders/{} | get-order-by-id | 200 |
| GET /orders/{} | get-order-not-found | 404 ORDER_NOT_FOUND |
| GET /customers/{} | missing-client-headers | 400 |

## Notas para revisión humana

1. Los errores `DB:CONNECTIVITY`/`DB:CANNOT_GET_CONNECTION` (503) no tienen prueba BAT: exigirían apagar Oracle (cubiertos en MUnit).
2. Cada corrida deja clientes y pedidos con correo, teléfono e ids únicos en Oracle; BAT no tiene limpieza.
3. Las respuestas de error son 400 (APIkit) y no 401 sin la política de API Manager.

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
