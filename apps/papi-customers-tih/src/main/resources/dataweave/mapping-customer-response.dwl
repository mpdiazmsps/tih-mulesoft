%dw 2.0
output application/json
// Customer de sapi-oracle-core-tih -> Customer del contrato. Los campos vacíos se omiten.
---
{
	id: payload.id,
	name: payload.name,
	(lastName: payload.lastName) if payload.lastName != null,
	(email: payload.email) if payload.email != null,
	(phone: payload.phone) if payload.phone != null,
	creationDate: payload.creationDate
}
