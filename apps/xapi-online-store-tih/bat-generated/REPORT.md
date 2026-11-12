# Reporte de la suite BAT — xapi-online-store-tih

Ejecutada el 2026-10-20 contra la app en local.

## Resultado

**10/10 pruebas aprobadas.** Reportes en `reports/bat-report.json` y `reports/bat-report.html`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 2 |
| Robustness | 7 |
| Security | 1 |
| **Total** | **10** |

Procedencia: 10 nuevas (no había suite previa).

## Cobertura

| Endpoint | Prueba | Estado esperado |
| --- | --- | --- |
| POST /customers | post-customer-happy-path | 201 |
| POST /customers | post-customer-duplicate-email | 409 |
| POST /customers | post-customer-no-email-no-phone | 400 |
| POST /customers | post-customer-invalid-phone | 400 |
| POST /orders | post-order-happy-path | 201 |
| POST /orders | post-order-customer-not-found | 404 |
| POST /orders | post-order-empty-items | 400 |
| POST /orders | post-order-invalid-body | 400 |
| GET /customers | customers-method-not-allowed | 405 |
| POST /customers | missing-client-headers | 400 |

## Notas para revisión humana

1. Hace pasar los dos recursos por papi-customers, papi-orders, sapi-sftp-orders y oracle-core, así que requiere toda la cadena arriba.
2. Los pedidos de prueba son de clientes sin correo para evitar notificaciones.
3. Sin API Manager no hay Client ID Enforcement: la ausencia de credenciales da 400 y no 401.

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
