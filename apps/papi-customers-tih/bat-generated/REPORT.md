# Reporte de la suite BAT — papi-customers-tih

Ejecutada el 2026-10-20 contra la app en local.

## Resultado

**9/9 pruebas aprobadas.** Reportes en `reports/bat-report.json` y `reports/bat-report.html`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 2 |
| Robustness | 6 |
| Security | 1 |
| **Total** | **9** |

Procedencia: 9 nuevas (no había suite previa).

## Cobertura

| Endpoint | Prueba | Estado esperado |
| --- | --- | --- |
| POST /customers | post-customer-happy-path | 201 |
| POST /customers | post-customer-duplicate-email | 409 CUSTOMER_ALREADY_EXISTS |
| POST /customers | post-customer-duplicate-phone | 409 CUSTOMER_ALREADY_EXISTS |
| POST /customers | post-customer-no-email-no-phone | 400 VALIDATION_ERROR |
| POST /customers | post-customer-invalid-email | 400 |
| GET /customers/{} | get-customer-by-id | 200 |
| GET /customers/{} | get-customer-not-found | 404 CUSTOMER_NOT_FOUND |
| GET /customers/{} | get-customer-invalid-uuid | 400 |
| POST /customers | missing-client-headers | 400 |

## Notas para revisión humana

1. Cada corrida registra clientes con correo y teléfono únicos en Oracle (vía sapi-oracle-core).
2. Sin API Manager, la ausencia de client_id/client_secret da 400 y no 401.
3. Depende de sapi-oracle-core-tih (8091) arriba.

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
