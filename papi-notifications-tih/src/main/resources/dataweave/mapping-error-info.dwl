%dw 2.0
output application/java
// Catálogo de errores -> estado HTTP, código y mensaje del ErrorResponse del contrato.
var unavailable = { status: 503, code: "SERVICE_UNAVAILABLE", message: "Servicio temporalmente no disponible, intenta de nuevo", retryable: true }
var badGateway = { status: 502, code: "PROVIDER_ERROR", message: "El servicio de notificaciones respondió con error", retryable: true }
var providerRejected = { status: 502, code: "PROVIDER_REJECTED", message: "MagicBell rechazó la solicitud", retryable: false }
var catalog = {
	"APIKIT:BAD_REQUEST":             { status: 400, code: "VALIDATION_ERROR",          message: "La solicitud no cumple el contrato de la API",          retryable: false },
	"APIKIT:NOT_FOUND":               { status: 404, code: "RESOURCE_NOT_FOUND",        message: "El recurso solicitado no existe",                       retryable: false },
	"APIKIT:METHOD_NOT_ALLOWED":      { status: 405, code: "METHOD_NOT_ALLOWED",        message: "Método HTTP no permitido para este recurso",            retryable: false },
	"APIKIT:NOT_ACCEPTABLE":          { status: 406, code: "NOT_ACCEPTABLE",            message: "El formato de respuesta solicitado no está soportado",  retryable: false },
	"APIKIT:UNSUPPORTED_MEDIA_TYPE":  { status: 415, code: "UNSUPPORTED_MEDIA_TYPE",    message: "El tipo de contenido no está soportado",                retryable: false },
	"APIKIT:NOT_IMPLEMENTED":         { status: 501, code: "NOT_IMPLEMENTED",           message: "La operación no está implementada",                     retryable: false },
	"APP:CUSTOMER_NOT_FOUND":         { status: 404, code: "CUSTOMER_NOT_FOUND",        message: "El cliente no está registrado",                         retryable: false },
	"HTTP:CONNECTIVITY":              unavailable,
	"HTTP:TIMEOUT":                   unavailable,
	"HTTP:SERVICE_UNAVAILABLE":       unavailable,
	"HTTP:BAD_GATEWAY":               badGateway,
	"HTTP:INTERNAL_SERVER_ERROR":     badGateway,
	"HTTP:GATEWAY_TIMEOUT":           badGateway,
	"HTTP:TOO_MANY_REQUESTS":         unavailable,
	"HTTP:PARSING":                   badGateway,
	// Token vencido/inválido o body/destinatario que MagicBell no acepta: reintentar no ayuda hasta corregir la causa.
	"HTTP:UNAUTHORIZED":              providerRejected,
	"HTTP:FORBIDDEN":                 providerRejected,
	"HTTP:BAD_REQUEST":               providerRejected,
	"HTTP:NOT_FOUND":                 providerRejected,
	"APP:NOTIFICATION_REJECTED":      providerRejected,
	"HTTP:CLIENT_SECURITY":           providerRejected,
	"HTTP:SECURITY":                  providerRejected
}
var errorKey = (error.errorType.namespace default "MULE") ++ ":" ++ (error.errorType.identifier default "ANY")
var known = catalog[errorKey]
// Los errores de negocio (APP) y de APIkit traen una descripción pensada para el consumidor.
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
	{ status: 500, code: "INTERNAL_ERROR", message: "Error inesperado", retryable: false }
