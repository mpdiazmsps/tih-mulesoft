# Guion de la demo: cuatro escenas de un lunes, en diez minutos

La PoC no vende un agente: vende la capa que permite a cualquier canal trabajar con los sistemas reales de una empresa
sin unificarlos y sin riesgo. El agente es un consumidor más.

Cada escena responde una pregunta del cliente y toca uno de sus dolores. El agente es cualquier cliente MCP conectado a
`mcp-online-store`; la tienda y el aprobador usan la xapi (Postman, colección `tests/postman/poc-e2e.postman_collection.json`).

## Antes de empezar (5 minutos antes)

1. Las 10 apps corriendo en Studio (configuración `poc-mule`) y los contenedores `poc-*` arriba (`docker ps`).
2. Datos del guion, segmentos de Salesforce incluidos:
   ```powershell
   .\demo\control.ps1 reset
   ```
3. Calentar las conexiones (la primera consulta tras arrancar tarda unos 5 s): en Postman, carpeta
   **00 Calentamiento** de la colección `poc-e2e`, o una pregunta cualquiera al agente.
4. El cliente MCP conectado a `http://localhost:8086/mcp` (transporte *Streamable HTTP*) con el encabezado
   `client_id: agente-mcp` (ver "Preparar el agente" abajo).
5. Abiertos: la bandeja de `notifications.redirectTo` (los correos de la demo llegan ahí) y Postman con el ambiente
   **PoC local**.

### Preparar Postman (una vez)

1. Import → `tests/postman/poc-e2e.postman_collection.json` y `tests/postman/local.postman_environment.json`.
2. Arriba a la derecha, elige el ambiente **PoC local**.
3. Las carpetas van en el orden de las escenas (00, E1, E2a…). Cada petición ya trae su `client_id`: la tienda
   (`tienda-web`), el aprobador (`aprobador-tienda`) o el agente (`agente-mcp`). La pestaña *Test Results* muestra qué
   se verificó.
4. Las peticiones "Agente: …" hablan MCP directamente. Si el agente de la demo es un cliente MCP real, sáltalas; la
   única que hace falta antes de las otras peticiones MCP es "Agente: abre sesión MCP" (guarda la sesión).

### Preparar el agente (elige uno)

- **Claude Code** (el agente responde en lenguaje natural): una vez,
  `claude mcp add --transport http poc-online-store http://localhost:8086/mcp --header "client_id: agente-mcp"`.
  En una sesión nueva de `claude`, `/mcp` debe mostrar `poc-online-store` conectado con 5 herramientas.
- **MCP Inspector** (se ve cada herramienta y su respuesta): `npx --yes @modelcontextprotocol/inspector`, abre la
  página que indica, *Transport Type* = Streamable HTTP, *URL* = `http://localhost:8086/mcp`, agrega el encabezado
  `client_id: agente-mcp` y *Connect* → *Tools* → *List Tools*.

Si algo no responde, `.\tests\run-e2e.ps1` recorre las cuatro escenas solo y dice qué falla.

## Escena 1 · ¿Qué requiere mi atención hoy? (2 min)

**Dolor:** no tengo visibilidad de lo que está en riesgo.

- **Pregunta al agente:** "¿Qué pedidos requieren mi atención hoy?"
- **El agente usa:** `list_exceptions`.
- **Qué se ve:** cuatro pedidos, primero los clientes estratégicos de Salesforce:

  | Pedido | Cliente | Segmento | Problema |
  |---|---|---|---|
  | PED-1002 | Constructora Cumbres | Estratégico | Faltante de inventario (SKU-100: pide 5, hay 2) |
  | PED-1004 | Grupo Hotelero Tapatío | Estratégico | Remisión rechazada: "Dirección incorrecta" |
  | PED-1001 | Ferretería Angelópolis | Regular | Sin confirmar: su proveedor no responde |
  | PED-1005 | Papelería Coyoacán | Regular | Faltante de inventario |

  PED-1003 no aparece: está confirmado y su remisión firmada.
- **Mensaje:** una pregunta reemplaza cuatro pantallas. La lista se arma al consultar, desde el ERP, el CRM y logística.

## Escena 2 · ¿Qué hago con este pedido? (3 min)

**Dolor:** mis sistemas no se hablan.

- **Pregunta al agente:** "Abre el PED-1002. ¿Qué opciones tengo?"
- **El agente usa:** `get_order` y `propose_alternatives`.
- **Qué se ve:** el Pedido 360. Confirmado, de Constructora Cumbres (Estratégico), SKU-100 con 2 de 5 disponibles,
  la remisión en espera y la reposición de 3 piezas cotizada por los tres proveedores: A (REST) 189.00, B (REST)
  194.00 y C (SOAP) 175.00, la más barata.
- **Cambio en Salesforce:** cambia el segmento del cliente en Salesforce (en la org, o con el comando) y repite la
  pregunta:
  ```powershell
  .\demo\control.ps1 cumbres-regular      # Cumbres pasa a Regular
  ```
  - **Pregunta al agente:** "Repite la consulta del PED-1002, por favor."
  - **Qué se ve:** el cliente ahora es Regular, sin copiar ni sincronizar nada.
  ```powershell
  .\demo\control.ps1 cumbres-strategic    # de vuelta a Estratégico
  ```
- **Mensaje:** cada sistema conserva su dato; la integración lo compone al consultar y oculta que uno es REST, otro
  SOAP y otro archivos por SFTP.

## Escena 3 · ¿Y si un sistema falla justo hoy? (2 min)

**Dolor:** un sistema caído detiene la operación.

- **Fallas controladas:**
  ```powershell
  .\demo\control.ps1 slow-c       # el proveedor C tarda 5 s
  .\demo\control.ps1 sftp-down    # logística apagada
  ```
- **Pregunta al agente:** "Vuelve a revisar el PED-1002."
- **Qué se ve:** la respuesta llega en menos de 3 s, completa salvo lo que falta: la remisión aparece como
  desconocida (logística no disponible) y hay 2 de 3 cotizaciones (falta C).
- **Haz una sola consulta.** Tres fallas seguidas de una fuente abren su circuito durante 30 s (es parte del patrón).
- **Al terminar:**
  ```powershell
  .\demo\control.ps1 normal-c
  .\demo\control.ps1 sftp-up
  ```
  Antes de la escena 4, verifica que el agente vuelve a ver logística y "3 of 3" (si no, espera unos segundos).
- **Mensaje:** la respuesta dice qué le falta: un agente no se equivoca con seguridad.

## Escena 4 · Lo resuelvo y aviso al cliente (3 min)

**Dolor:** las correcciones se hacen por correo y WhatsApp, sin rastro.

1. **Pregunta al agente:** "Repón el faltante del PED-1002 con el proveedor más barato."
   - **El agente usa:** `request_correction` (RESTOCK, sin proveedor: toma el más barato, C).
   - **Qué se ve:** una solicitud `PENDING` de 3 piezas de SKU-100 con C a 175.00. No se aplica nada.
2. **"Por error", repite la petición:** "Pide de nuevo la reposición del PED-1002."
   - **Qué se ve:** la misma solicitud, no una segunda. La llave se deriva del pedido, el tipo y el proveedor.
3. **Llega a la tienda y por correo:** en la bandeja aparece "Solicitud por aprobar: RESTOCK del pedido PED-1002".
   En Postman, carpeta **E4a**: la vista del aprobador lista una sola solicitud `PENDING`.
4. **El agente no puede aprobar:** carpeta **E4b**, "El agente intenta aprobar" → 403. Ninguna herramienta del
   agente aprueba.
5. **Una persona aprueba el gasto:** "El aprobador aprueba" (aplicación `aprobador-tienda`) → `COMPLETED`, con la
   historia de cada paso: quién y cuándo. Aprobar otra vez → 409: no se aplica dos veces.
6. **Resultado:** carpeta **E4c**. El stock de SKU-100 se repuso y se despachó (queda en 0), la remisión se emitió y
   llega el correo "Corregimos tu pedido PED-1002" que saluda a Constructora Cumbres. Es el único correo al cliente por
   la corrección.
   - **Pregunta al agente:** "¿Cómo va la solicitud?" (`get_request`) → aplicada, con su historia.
- **Mensaje:** autonomía con control. El agente propone, una persona decide el gasto y cada paso queda registrado.

## Cierre (30 s)

"¿Y con mis sistemas?" Cada sistema se conecta por una sola puerta, así que cambiar uno no toca al resto. Se explica,
no se demuestra: la invitación es a mapear sus sistemas contra este elenco.

## Después de la demo

```powershell
.\demo\control.ps1 reset
```

## Si algo sale mal

| Síntoma | Qué hacer |
|---|---|
| La primera respuesta tarda unos 5 s y marca "0 of 3" | Fue el arranque en frío: repite la pregunta. Para la próxima, calienta antes |
| Después de la escena 3 sigue faltando logística o C | Un circuito quedó abierto: espera 30 s y repite |
| `cumbres-regular` dice que la org no tiene sesión | `sf org login web --alias poc` y repite el comando |
| La solicitud de la escena 4 sale con otro proveedor | Algún circuito de proveedores estaba abierto: `.\demo\control.ps1 reset`, espera 30 s y empieza la escena |
| No llega un correo | Revisa spam y que papi-notifications esté DEPLOYED; las colas `*.dlq` dicen si falló el envío |
