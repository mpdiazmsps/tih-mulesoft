%dw 2.0
output application/json
// Customer creado por sapi-oracle-core-tih -> CustomerCreated del contrato.
---
{
	customerId: payload.id,
	creationDate: payload.creationDate
}
