%dw 2.0
output application/json
// Resultado del procesamiento (NotificationResult del contrato). vars.notificationStatus: SENT o SKIPPED_NO_EMAIL.
---
{
	orderId: vars.event.orderId,
	status: vars.notificationStatus
}
