%dw 2.0
output application/java
// Error catalog -> HTTP status, code and message of the contract ErrorResponse.
var unavailable = { status: 503, code: "SERVICE_UNAVAILABLE", message: "Service temporarily unavailable, please retry", retryable: true }
var catalog = {
	"APIKIT:BAD_REQUEST":             { status: 400, code: "VALIDATION_ERROR",       message: "The request does not match the API contract",          retryable: false },
	"APIKIT:NOT_FOUND":               { status: 404, code: "RESOURCE_NOT_FOUND",     message: "The requested resource does not exist",                       retryable: false },
	"APIKIT:METHOD_NOT_ALLOWED":      { status: 405, code: "METHOD_NOT_ALLOWED",     message: "HTTP method not allowed for this resource",            retryable: false },
	"APIKIT:NOT_ACCEPTABLE":          { status: 406, code: "NOT_ACCEPTABLE",         message: "The requested response format is not supported",  retryable: false },
	"APIKIT:UNSUPPORTED_MEDIA_TYPE":  { status: 415, code: "UNSUPPORTED_MEDIA_TYPE", message: "The content type is not supported",                retryable: false },
	"APIKIT:NOT_IMPLEMENTED":         { status: 501, code: "NOT_IMPLEMENTED",        message: "The operation is not implemented",                     retryable: false },
	"APP:VALIDATION_ERROR":           { status: 400, code: "VALIDATION_ERROR",       message: "The request is not valid",                             retryable: false },
	"APP:CUSTOMER_NOT_FOUND":         { status: 404, code: "CUSTOMER_NOT_FOUND",     message: "The customer does not exist",                          retryable: false },
	"APP:CUSTOMER_ALREADY_EXISTS":    { status: 409, code: "CUSTOMER_ALREADY_EXISTS", message: "A customer with this email already exists",           retryable: false },
	"HTTP:BAD_REQUEST":               { status: 502, code: "CRM_ERROR",              message: "The CRM rejected the request",                         retryable: false },
	"HTTP:BAD_GATEWAY":               { status: 502, code: "CRM_ERROR",              message: "The CRM returned an error",                            retryable: true },
	"HTTP:INTERNAL_SERVER_ERROR":     { status: 502, code: "CRM_ERROR",              message: "The CRM returned an error",                            retryable: true },
	"HTTP:SERVICE_UNAVAILABLE":       unavailable,
	"HTTP:CONNECTIVITY":              unavailable,
	"HTTP:TIMEOUT":                   unavailable,
	"MULE:RETRY_EXHAUSTED":           unavailable
}
var errorKey = (error.errorType.namespace default "MULE") ++ ":" ++ (error.errorType.identifier default "ANY")
var known = catalog[errorKey]
// Business (APP) and APIkit errors carry a description meant for the consumer.
var showDescription = (errorKey startsWith "APP:") or (errorKey == "APIKIT:BAD_REQUEST")
---
if (known != null)
	{
		status: known.status,
		code: known.code,
		message: if (showDescription and (error.description != null)) error.description else known.message,
		retryable: known.retryable
	}
else
	{ status: 500, code: "INTERNAL_ERROR", message: "Unexpected error", retryable: false }
