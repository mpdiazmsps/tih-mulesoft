%dw 2.0
output application/json
// Líneas de ORDERS (mismo id) -> Order del contrato, con el total calculado.
var first = payload[0]
---
{
	id: first.ID,
	customerId: first.CLIENT_ID,
	items: payload map (row) -> {
		itemId: row.ITEM_ID,
		quantity: row.ITEM_QTY as Number,
		price: row.ITEM_PRICE as Number
	},
	total: sum(payload map ((row) -> (row.ITEM_QTY as Number) * (row.ITEM_PRICE as Number))),
	creationDate: ((first.CREATION_DATE as LocalDateTime {format: "yyyyMMddHHmmssSSS"}) as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"})
}
