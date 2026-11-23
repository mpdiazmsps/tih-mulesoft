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
	"APP:ORDER_NOT_FOUND":            { status: 404, code: "ORDER_NOT_FOUND",        message: "The order does not exist",                                   retryable: false },
	"APP:ITEM_NOT_FOUND":             { status: 404, code: "ITEM_NOT_FOUND",         message: "The item does not exist",                                 retryable: false },
	"APP:ORDER_ALREADY_EXISTS":       { status: 409, code: "ORDER_ALREADY_EXISTS",   message: "An order with this id already exists",                        retryable: false },
	"APP:INVALID_TRANSITION":         { status: 409, code: "INVALID_TRANSITION",     message: "The order is not RECEIVED",                            retryable: false },
	"APP:INSUFFICIENT_STOCK":         { status: 409, code: "INSUFFICIENT_STOCK",     message: "The outbound movement would leave negative stock",                retryable: false },
	"DB:CONNECTIVITY":                unavailable,
	"DB:CANNOT_REACH":                unavailable,
	"DB:RETRY_EXHAUSTED":             unavailable,
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
