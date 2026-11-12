%dw 2.0
output application/csv header=true, lineSeparator="\n"
// Líneas del pedido -> CSV item,qty que lee después el procesamiento programado.
---
vars.orderRequest.items map (line) -> {
	item: lower(line.itemId),
	qty: line.quantity
}
