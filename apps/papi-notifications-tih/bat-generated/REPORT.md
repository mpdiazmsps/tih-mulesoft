# Reporte de la suite BAT — papi-notifications-tih

Ejecutada el 2026-10-20 contra la app en local.

## Resultado

**6/6 pruebas aprobadas.** Reportes en `reports/bat-report.json` y `reports/bat-report.html`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 1 |
| Robustness | 4 |
| Security | 1 |
| **Total** | **6** |

Procedencia: 6 nuevas (no había suite previa).

## Cobertura

| Endpoint | Prueba | Estado esperado |
| --- | --- | --- |
| POST /orders-registered | notify-customer-without-email-skipped | 200 |
| POST /orders-registered | notify-customer-not-found | 404 CUSTOMER_NOT_FOUND |
| POST /orders-registered | notify-invalid-event-type | 400 |
| POST /orders-registered | notify-missing-items | 400 |
| GET /orders-registered | notify-method-not-allowed | 405 |
| POST /orders-registered | missing-client-headers | 400 |

## Notas para revisión humana

1. `NOTIFICATION_REJECTED` y el envío real (`SENT`) no tienen prueba BAT: llamarían a MagicBell. Solo se prueba `SKIPPED_NO_EMAIL`, con un cliente sin correo.
2. El listener AMQP (cola orders.registered.q) no es HTTP y queda fuera de BAT.
3. Usa `config.customersUrl` para sembrar el cliente en papi-customers (8082).

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
