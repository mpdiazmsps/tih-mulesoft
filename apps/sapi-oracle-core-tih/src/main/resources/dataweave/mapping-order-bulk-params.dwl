%dw 2.0
output application/java
// Una fila de ORDERS por línea del pedido. Todas comparten la misma fecha (UTC). bulk-insert no conoce el tipo de la columna y exige texto "yyyy-MM-dd HH:mm:ss.SSS".
var created = (now() >> "UTC") as String {format: "yyyy-MM-dd HH:mm:ss.SSS"}
---
payload.items map (item) -> {
	id: payload.orderId,
	clientId: payload.customerId,
	itemId: item.itemId,
	itemQty: item.quantity,
	itemPrice: item.price,
	creationDate: created
}
