# demo: controles de la demostración

`control.ps1` y `control.sh` hacen lo mismo:

| Comando | Escena | Qué hace |
|---|---|---|
| `reset` | Antes y después | Datos del guion en todas las dependencias y segmentos de Salesforce |
| `cumbres-regular` / `cumbres-strategic` | 2 | Cambia el segmento de Constructora Cumbres en Salesforce (`segment.mjs`, sesión de la CLI `sf`) |
| `slow-c` / `normal-c` | 3 | El proveedor C tarda 5 s / responde de inmediato (`wiremock-delay.mjs`) |
| `sftp-down` / `sftp-up` | 3 | Apaga / enciende el SFTP de logística |

`inspect.ps1` / `inspect.sh` muestran los registros sin credenciales (solo leen): `pedidos`, `inventario`, `movimientos`,
`solicitudes`, `historia`, `sftp` y `colas`.

El guion completo está en `docs/guion-demo.md`. `logistics-sim/` es el simulador del operador logístico.
