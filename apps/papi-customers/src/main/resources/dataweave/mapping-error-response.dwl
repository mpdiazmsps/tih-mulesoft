%dw 2.0
output application/json
// Contract ErrorResponse (poc-common fragment, ErrorResponse type).
---
{
	code: vars.errorInfo.code,
	message: vars.errorInfo.message,
	correlationId: correlationId,
	timestamp: now() >> "UTC",
	retryable: vars.errorInfo.retryable
}
