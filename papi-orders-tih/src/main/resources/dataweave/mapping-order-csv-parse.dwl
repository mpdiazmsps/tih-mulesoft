%dw 2.0
output application/java
// CSV item,qty -> { valid, reason, lines: [{ itemId, quantity }] }. No lanza: el flujo decide qué hacer con valid=false.
var uuidRe = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
var qtyRe = /^([1-9][0-9]{0,2}|1000)$/
var rows = read(payload, "application/csv", { header: true }) default []
var lines = rows map (r) -> { itemId: lower(trim(r.item default "")), qty: trim(r.qty default "") }
var badLines = lines filter ((l) -> !(l.itemId matches uuidRe) or !(l.qty matches qtyRe))
var ids = lines map $.itemId
var reason =
	if (isEmpty(lines)) "El archivo no contiene artículos"
	else if (!isEmpty(badLines)) "Líneas inválidas: se requiere item (UUID) y qty entero entre 1 y 1000"
	else if (sizeOf(ids distinctBy $) != sizeOf(ids)) "El archivo repite un artículo en más de una línea"
	else null
---
{
	valid: reason == null,
	reason: reason,
	lines: if (reason == null) (lines map (l) -> { itemId: l.itemId, quantity: l.qty as Number }) else []
}
