%dw 2.0
output application/java
// Catálogo de errores -> estado HTTP, código y mensaje del ErrorResponse del contrato.
var unavailable = { status: 503, code: "SERVICE_UNAVAILABLE", message: "Servicio temporalmente no disponible, intenta de nuevo", retryable: true }
var providerError = { status: 502, code: "PROVIDER_ERROR", message: "El proveedor respondió con error", retryable: true }
var catalog = {
	"APIKIT:BAD_REQUEST":             { status: 400, code: "VALIDATION_ERROR",        message: "La solicitud no cumple el contrato de la API",         retryable: false },
	"APIKIT:NOT_FOUND":               { status: 404, code: "RESOURCE_NOT_FOUND",      message: "El recurso solicitado no existe",                      retryable: false },
	"APIKIT:METHOD_NOT_ALLOWED":      { status: 405, code: "METHOD_NOT_ALLOWED",      message: "Método HTTP no permitido para este recurso",           retryable: false },
	"APIKIT:NOT_ACCEPTABLE":          { status: 406, code: "NOT_ACCEPTABLE",          message: "El formato de respuesta solicitado no está soportado", retryable: false },
	"APIKIT:UNSUPPORTED_MEDIA_TYPE":  { status: 415, code: "UNSUPPORTED_MEDIA_TYPE",  message: "El tipo de contenido no está soportado",               retryable: false },
	"APIKIT:NOT_IMPLEMENTED":         { status: 501, code: "NOT_IMPLEMENTED",         message: "La operación no está implementada",                    retryable: false },
	"APP:PRODUCT_NOT_FOUND":          { status: 404, code: "PRODUCT_NOT_FOUND",       message: "El proveedor no conoce el artículo solicitado",        retryable: false },
	"APP:PROVIDER_NOT_SUPPORTED":     { status: 501, code: "PROVIDER_NOT_SUPPORTED",  message: "El proveedor no está soportado por ahora",             retryable: false },
	// Borland (SOAP, conector Web Service Consumer): sin conexión o sin respuesta = 503; el resto = 502
	"WSC:CANNOT_DISPATCH":            unavailable,
	"WSC:TIMEOUT":                    unavailable,
	"WSC:SOAP_FAULT":                 providerError,
	"WSC:BAD_RESPONSE":               providerError,
	"WSC:EMPTY_RESPONSE":             providerError,
	"WSC:BAD_REQUEST":                providerError,
	"WSC:ENCODING":                   providerError,
	"WSC:INVALID_WSDL":               providerError,
	"HTTP:CONNECTIVITY":              unavailable,
	"HTTP:TIMEOUT":                   unavailable,
	"HTTP:INTERNAL_SERVER_ERROR":     providerError,
	"HTTP:BAD_GATEWAY":               providerError,
	"HTTP:SERVICE_UNAVAILABLE":       providerError,
	"HTTP:GATEWAY_TIMEOUT":           providerError,
	"HTTP:PARSING":                   providerError,
	"HTTP:CLIENT_SECURITY":           providerError,
	"HTTP:SECURITY":                  providerError
}
var errorKey = (error.errorType.namespace default "MULE") ++ ":" ++ (error.errorType.identifier default "ANY")
var known = catalog[errorKey]
// Los errores de APIkit de validación traen una descripción pensada para el consumidor.
var showDescription = (errorKey == "APIKIT:BAD_REQUEST")
---
if (known != null)
	{
		status: known.status,
		code: known.code,
		message: if (showDescription and (error.description != null)) error.description else known.message,
		retryable: known.retryable
	}
else
	{ status: 500, code: "INTERNAL_ERROR", message: "Error inesperado", retryable: false }
