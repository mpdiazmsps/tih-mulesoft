# mcp-online-store

Servidor MCP del canal de agentes (tarea 24): cinco herramientas en lenguaje de negocio sobre las mismas APIs de proceso
que usa la tienda. Contrato: `specs/mcp-online-store/tools.yaml` (no es RAML; se valida con
`npm --prefix specs/tools run validate-tools`). Mule 4.11.4, Java 17, MCP Connector 1.7.4 y HTTP 1.12.1.

Endpoint local: `http://localhost:8086/mcp` (streamable HTTP).

| Herramienta | Llama a | Qué hace |
|---|---|---|
| `get_order(orderId)` | papi-orders `GET /orders/{orderId}` | Pedido 360; dice si alguna fuente no respondió. Solo lee |
| `list_exceptions(limit?)` | papi-orders `GET /orders/exceptions` | La misma lista que la xapi. Solo lee |
| `propose_alternatives(orderId)` | papi-orders `GET /orders/{orderId}/alternatives` | Reponer con el más barato o reemitir. Solo lee |
| `request_correction(orderId, type, provider?, quantity?)` | papi-orders alternativas (solo RESTOCK) y papi-order-requests `POST /order-requests` | Pide; no ejecuta |
| `get_request(requestId)` | papi-order-requests `GET /order-requests/{requestId}` | Estado e historia. Solo lee |

- **Descripciones y esquemas** se copian de `tools.yaml` con un script (no se editan a mano en `tools.xml`).
- **`request_correction`:** para RESTOCK toma de las alternativas el artículo, la cantidad faltante (si el agente no da
  una) y el precio del proveedor elegido o del más barato. La llave es `{orderId}:{type}:{provider}` (`none` en REISSUE):
  pedir dos veces da la misma solicitud. Si el pedido no tiene faltante o el proveedor no cotizó, responde el motivo sin
  crear nada.
- **Ninguna herramienta aprueba ni aplica.** La solicitud queda `PENDING` hasta que una persona decide por la xapi.
- **Quién llama (D10):** el `client_id` de la petición MCP (`attributes.additionalProperties`) viaja a la capa de
  proceso como `x-client-app`; sin él, `agente-mcp` (`mcp.defaultClientApp`). papi-order-requests rechaza cualquier
  aprobación del agente.
- **Errores:** si la API de proceso responde 4xx o 5xx, la herramienta contesta con error y el `ErrorResponse` como
  texto, para que el agente lo lea.
- El conector 1.7.4 no tiene atributo para las anotaciones de MCP (`readOnlyHint`…): en `tools.yaml` quedan como
  documentación y la descripción ya dice si la herramienta solo lee.

## Ejecución local

- Requiere papi-orders (8083) y papi-order-requests (8085).
- En Studio, VM args: `-M-Denv=local`. No tiene propiedades seguras.
- Pruebas: `mvn -B clean package`: 16 MUnit, cobertura 100%. 13 de flujos (una por herramienta, la llave doble, los
  rechazos y el cuerpo de la solicitud) y 3 de protocolo con un cliente MCP real contra el servidor: `tools/list` da las
  cinco herramientas y ninguna aprueba, pedir una herramienta de aprobación falla, y `list_exceptions` por MCP da la
  lista de papi-orders. Las APIs de proceso se simulan; la suite de protocolo necesita libre el puerto 8086.
- Prueba manual: `npx --yes @modelcontextprotocol/inspector` (con la caché de npm en `tmp/`) contra
  `http://localhost:8086/mcp`, transporte "Streamable HTTP".
