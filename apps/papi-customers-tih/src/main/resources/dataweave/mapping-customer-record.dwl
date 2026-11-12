%dw 2.0
output application/json
// Solicitud validada -> Customer con el UUID y la fecha de creación generados por esta API.
var request = vars.customerRequest
---
{
	id: uuid(),
	name: request.name,
	(lastName: request.lastName) if !isEmpty(request.lastName),
	(email: request.email) if !isEmpty(request.email),
	(phone: request.phone) if !isEmpty(request.phone),
	creationDate: now() >> "UTC"
}
