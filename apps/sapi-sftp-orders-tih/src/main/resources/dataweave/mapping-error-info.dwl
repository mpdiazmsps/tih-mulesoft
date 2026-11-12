%dw 2.0
output application/java
// Catálogo de errores -> estado HTTP, código y mensaje del ErrorResponse del contrato.
var unavailable = { status: 503, code: "SERVICE_UNAVAILABLE", message: "Servicio temporalmente no disponible, intenta de nuevo", retryable: true }
var catalog = {
	"APIKIT:BAD_REQUEST":             { status: 400, code: "VALIDATION_ERROR",        message: "La solicitud no cumple el contrato de la API",         retryable: false },
	"APIKIT:NOT_FOUND":               { status: 404, code: "RESOURCE_NOT_FOUND",      message: "El recurso solicitado no existe",                      retryable: false },
	"APIKIT:METHOD_NOT_ALLOWED":      { status: 405, code: "METHOD_NOT_ALLOWED",      message: "Método HTTP no permitido para este recurso",           retryable: false },
	"APIKIT:NOT_ACCEPTABLE":          { status: 406, code: "NOT_ACCEPTABLE",          message: "El formato de respuesta solicitado no está soportado", retryable: false },
	"APIKIT:UNSUPPORTED_MEDIA_TYPE":  { status: 415, code: "UNSUPPORTED_MEDIA_TYPE",  message: "El tipo de contenido no está soportado",               retryable: false },
	"APIKIT:NOT_IMPLEMENTED":         { status: 501, code: "NOT_IMPLEMENTED",         message: "La operación no está implementada",                    retryable: false },
	"SFTP:FILE_DOESNT_EXIST":         { status: 404, code: "FILE_NOT_FOUND",          message: "El archivo no existe en la carpeta indicada",          retryable: false },
	"SFTP:FILE_ALREADY_EXISTS":       { status: 409, code: "FILE_ALREADY_EXISTS",     message: "Ya existe un archivo con ese nombre",                  retryable: false },
	"SFTP:ILLEGAL_PATH":              { status: 404, code: "FILE_NOT_FOUND",          message: "El archivo no existe en la carpeta indicada",          retryable: false },
	"SFTP:CONNECTIVITY":              unavailable,
	"SFTP:INVALID_CREDENTIALS":       unavailable,
	"SFTP:SERVICE_NOT_AVAILABLE":     unavailable,
	"SFTP:RETRY_EXHAUSTED":           unavailable
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
