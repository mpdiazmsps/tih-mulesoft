%dw 2.0
output application/json
// Evento order.registered (vars.event) + cliente (vars.customer) -> body de POST /broadcasts de MagicBell.
// La API exige el objeto envuelto en "broadcast" (sin el envoltorio responde 422 "Param 'broadcast' is missing").
// category/topic fijos para poder filtrar en el dashboard; orderId viaja como atributo personalizado.
var name = vars.customer.name default ""
var total = vars.event.total default 0
var title = "Tu pedido fue registrado"
var content = "Hola " ++ name ++ ", tu pedido " ++ vars.event.orderId ++ " fue registrado por un total de " ++ (total as String {format: "0.00"}) ++ "."
---
{
	broadcast: {
		title: title,
		content: content,
		category: "order_registered",
		topic: "order_registered",
		custom_attributes: { orderId: vars.event.orderId },
		recipients: [ { email: vars.customer.email } ],
		overrides: {
			channels: {
				email: {
					title: title,
					content: content
				}
			}
		}
	}
}
