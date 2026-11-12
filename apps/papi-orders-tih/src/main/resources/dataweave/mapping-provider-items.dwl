%dw 2.0
output application/java
// Artículos con precio 0: se cotizan con su proveedor (providerAbv y externalId).
---
((payload.items default []) filter ($.localPrice == 0)) map (item) -> {
	id: lower(item.id),
	providerAbv: item.providerAbv,
	externalId: item.externalId
}
