%dw 2.0
// Email templates for the three events and the MagicBell broadcast body. The email text is demo content (Spanish).

// Short order reference for the reader: the demo orders end in their number (…-000000001002 -> PED-1002).
fun orderRef(orderId) = "PED-" ++ ((orderId default "") as String)[-4 to -1]

fun money(amount, currency) = ((amount default 0) as String {format: "#,##0.00"}) ++ " " ++ (currency default "MXN")

// D11: in the demo every email goes to the redirectTo inbox; an empty redirectTo keeps the real recipient.
fun recipientFor(email, redirectTo) = if (isEmpty(redirectTo)) email else redirectTo

// POST /broadcasts body: MagicBell requires it wrapped in "broadcast" (422 "Param 'broadcast' is missing" otherwise).
fun broadcast(mail, recipient) = {
	broadcast: {
		title: mail.title,
		content: mail.content,
		category: mail.category,
		topic: mail.category,
		custom_attributes: mail.attributes default {},
		recipients: [ { email: recipient } ],
		overrides: { channels: { email: { title: mail.title, content: mail.content } } }
	}
}

fun orderRegisteredEmail(event, customer) = {
	to: customer.email,
	category: "order_registered",
	title: "Tu pedido " ++ orderRef(event.orderId) ++ " está confirmado",
	content: "Hola " ++ (customer.name default "") ++ ", confirmamos tu pedido " ++ orderRef(event.orderId)
		++ " por " ++ money(event.total, event.currency) ++ ". Ya va en camino.",
	attributes: { orderId: event.orderId }
}

fun approvalRequestedEmail(event, customerName, approverEmail) = {
	to: approverEmail,
	category: "approval_requested",
	title: "Solicitud por aprobar: " ++ ((event."type" default "") as String) ++ " del pedido " ++ orderRef(event.orderId),
	content: (event.requestedBy default "Un agente") ++ " pide " ++ ((event."type" default "") as String) ++ " en el pedido "
		++ orderRef(event.orderId) ++ " de " ++ (customerName default "") ++ " por " ++ money(event.amount, event.currency)
		++ ". Solicitud " ++ (event.requestId default "") ++ "; vence " ++ (event.expiresAt default "") ++ ".",
	attributes: { requestId: event.requestId, orderId: event.orderId }
}

fun correctionDetail(event) = do {
	var d = event.detail default {}
	---
	if (event."type" == "RESTOCK")
		"repusimos " ++ ((d.quantity default 0) as String) ++ " piezas"
			++ (if (d.provider != null) " con el proveedor " ++ d.provider else "")
			++ (if (d.dispatchNoteId != null) " y enviamos la remisión " ++ d.dispatchNoteId else "")
	else
		"reemitimos la remisión" ++ (if (d.dispatchNoteId != null) " " ++ d.dispatchNoteId else "")
}

fun correctionAppliedEmail(event, customer) = {
	to: customer.email,
	category: "correction_applied",
	title: "Corregimos tu pedido " ++ orderRef(event.orderId),
	content: "Hola " ++ (customer.name default "") ++ ", en tu pedido " ++ orderRef(event.orderId) ++ " "
		++ correctionDetail(event) ++ ".",
	attributes: { requestId: event.requestId, orderId: event.orderId }
}
