%dw 2.0
output application/java
// Cliente normalizado: fecha en UTC y campos opcionales solo si vienen en la solicitud.
---
{
	id: payload.id,
	name: payload.name,
	(lastName: payload.lastName) if payload.lastName != null,
	(email: payload.email) if payload.email != null,
	(phone: payload.phone) if payload.phone != null,
	creationDate: (payload.creationDate as DateTime) >> "UTC"
}
