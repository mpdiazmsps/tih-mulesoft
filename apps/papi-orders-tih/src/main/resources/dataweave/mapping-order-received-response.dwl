%dw 2.0
output application/json
// OrderReceived del contrato.
---
{
	orderId: vars.orderId,
	customerId: vars.customerId,
	status: "RECEIVED",
	fileName: vars.fileName,
	receivedAt: now() >> "UTC"
}
