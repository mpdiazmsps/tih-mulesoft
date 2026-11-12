%dw 2.0
output application/json
// Pedido cotizado -> OrderRecordRequest del contrato de sapi-oracle-core-tih.
---
{
	orderId: vars.orderId,
	customerId: vars.customerId,
	items: vars.orderLines.lines map (line) -> {
		itemId: line.itemId,
		quantity: line.quantity,
		price: vars.priceByItem[line.itemId]
	}
}
