%dw 2.0
output application/json
// Order del contrato a partir de la solicitud guardada (vars.orderRequest) y de la fecha usada al insertar.
---
{
	id: vars.orderRequest.orderId,
	customerId: vars.orderRequest.customerId,
	items: vars.orderRequest.items map (item) -> {
		itemId: item.itemId,
		quantity: item.quantity,
		price: item.price
	},
	total: sum(vars.orderRequest.items map ((item) -> item.quantity * item.price)),
	creationDate: ((vars.orderBulkParams[0].creationDate as LocalDateTime {format: "yyyy-MM-dd HH:mm:ss.SSS"}) as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"})
}
