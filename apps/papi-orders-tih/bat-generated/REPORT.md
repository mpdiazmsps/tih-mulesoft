# Reporte de la suite BAT — papi-orders-tih

Ejecutada el 2026-10-20 contra la app en local.

## Resultado

**8/8 pruebas aprobadas.** Reportes en `reports/bat-report.json` y `reports/bat-report.html`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 2 |
| Robustness | 5 |
| Security | 1 |
| **Total** | **8** |

Procedencia: 8 nuevas (no había suite previa).

## Cobertura

| Endpoint | Prueba | Estado esperado |
| --- | --- | --- |
| POST /orders | post-order-happy-path | 201 |
| POST /orders | post-order-customer-not-found | 404 CUSTOMER_NOT_FOUND |
| POST /orders | post-order-empty-items | 400 VALIDATION_ERROR |
| POST /orders | post-order-quantity-zero | 400 |
| POST /orders | post-order-invalid-customer-uuid | 400 |
| POST /orders/process | post-process-accepted | 202 |
| GET /orders | orders-method-not-allowed | 405 |
| POST /orders | missing-client-headers | 400 |

## Notas para revisión humana

1. Los errores del procesamiento en segundo plano (`ITEM_NOT_FOUND`, `ORDER_INVALID`, `ORDER_ALREADY_REGISTERED`, `PRODUCT_NOT_FOUND`, `PROVIDER_NOT_SUPPORTED`, `PROCESS_ALREADY_RUNNING`) no son alcanzables por HTTP; siguen en MUnit.
2. `POST /orders` deja un CSV en el SFTP que el scheduler procesa y publica en RabbitMQ; los clientes de prueba no tienen correo para no disparar notificaciones.
3. `POST /orders/process` solo comprueba el 202; si hubiera un ciclo en curso respondería 409.

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
