%dw 2.0
output application/java
// Order registrada en Oracle -> OrderRegisteredEvent del contrato (exchange orders.events, routing key order.registered).
---
{
	eventType: "order.registered",
	orderId: payload.id,
	customerId: payload.customerId,
	items: payload.items,
	total: payload.total,
	createdAt: payload.creationDate
}
