# Reporte de la suite BAT — sapi-sftp-orders-tih

Ejecutada el 2026-10-20 contra la app en local.

## Resultado

**12/12 pruebas aprobadas.** Reportes en `reports/bat-report.json` y `reports/bat-report.html`.

## Inventario

| Dimensión | Pruebas |
| --- | --- |
| Accuracy | 5 |
| Robustness | 6 |
| Security | 1 |
| **Total** | **12** |

Procedencia: 12 nuevas (no había suite previa).

## Cobertura

| Endpoint | Prueba | Estado esperado |
| --- | --- | --- |
| PUT /files/{} | put-file-happy-path | 201 |
| PUT /files/{} | put-file-duplicate | 409 |
| PUT /files/{} | put-file-invalid-name | 400 |
| GET /files/{} | get-file-content | 200 |
| GET /files/{} | get-file-not-found | 404 |
| GET /files | list-files-pending | 200 |
| GET /files | list-files-processed | 200 |
| GET /files | list-files-invalid-status | 400 |
| POST /files/{}/move | move-file-to-processed | 200 |
| POST /files/{}/move | move-file-invalid-destination | 400 |
| POST /files/{}/move | move-file-not-found | 404 |
| GET /files | missing-client-headers | 400 |

## Notas para revisión humana

1. Las pruebas depositan archivos `bat-*.csv` en pending y los mueven a processed al final; quedan residuos en /orders/processed.
2. Si papi-orders-tih tiene el scheduler activo, podría tomar un archivo de pending antes de que la prueba lo mueva (carrera).
3. El cuerpo CSV se envía como lista de objetos porque BAT serializa por Content-Type; la respuesta text/csv llega parseada como lista.

Ninguna prueba falla; no se modificó la app para hacerlas pasar.
