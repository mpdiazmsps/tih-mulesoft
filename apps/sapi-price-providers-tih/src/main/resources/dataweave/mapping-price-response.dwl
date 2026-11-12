%dw 2.0
output application/json
// Producto de Fakestore o Escuelajs (ambos traen title y price) -> Price canónico del contrato.
---
{
	externalId: vars.externalId as Number,
	providerAbv: vars.providerAbv,
	(name: payload.title) if payload.title != null,
	price: payload.price as Number,
	currency: "USD"
}
