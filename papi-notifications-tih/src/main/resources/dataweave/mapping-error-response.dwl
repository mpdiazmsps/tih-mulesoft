%dw 2.0
output application/json
// ErrorResponse del contrato (fragment tih-common-types.raml).
---
{
	code: vars.errorInfo.code,
	message: vars.errorInfo.message,
	correlationId: correlationId,
	timestamp: now() >> "UTC",
	retryable: vars.errorInfo.retryable
}
