# tests: pruebas de punta a punta de la PoC

| Archivo | Qué es |
|---|---|
| `postman/poc-e2e.postman_collection.json` | Las cuatro escenas del guion (tarea 25): una carpeta por paso, la tienda por la xapi, el agente por MCP (JSON-RPC sobre streamable HTTP) y la aprobación con la aplicación del aprobador |
| `postman/poc-demo-guiada.postman_collection.json` | La demo completa en orden: camino feliz, las cuatro escenas, reemisión, idempotencia, circuit breaker y las System APIs. Explicada en `docs/guia-demo-explicada.md` |
| `postman/poc-apps.postman_collection.json` | Verificación en vivo de cada app, una carpeta por app |
| `postman/local.postman_environment.json` | Ambiente local, sin secretos: las URLs y los `client_id` de ejemplo (`tienda-web`, `aprobador-tienda`, `agente-mcp`) |
| `run-e2e.ps1` / `run-e2e.sh` | Corre las cuatro escenas en orden con newman e intercala los comandos de `demo/control` |

`run-e2e` hace:

1. `demo/control reset`: datos del guion y segmentos de Salesforce.
2. Las carpetas en orden: `00 Calentamiento`, `E1`, `E2a`, *cumbres-regular*, `E2b`, *cumbres-strategic*, `E2c`,
   *slow-c y sftp-down*, `E3`, *normal-c y sftp-up* (espera a que vuelvan todas las fuentes), `E4a`, `E4b`, `E4c`.
3. Al terminar, también si falla: proveedor C normal, SFTP encendido y Cumbres en Estratégico.

newman se descarga con `npx --yes newman@6.2.1`, con la caché de npm en `tmp/`. El ambiente de la corrida (sesión MCP,
`requestId`) queda en `tmp/e2e-environment.json`. Requiere las 10 apps corriendo y la sesión de la CLI `sf`.

En Postman, las carpetas se pueden correr a mano en el mismo orden, con los comandos de `demo/control` entre ellas
(ver `docs/guion-demo.md`).
