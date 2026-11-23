%dw 2.0
// Order 360, exceptions and alternatives. Inputs are the ERP order, its inventory items and the resilient results
// (vars.rsResult: { ok, payload | reason }) of the CRM, logistics and providers.

fun itemOf(items: Array, itemId) = (items filter ((i) -> i.itemId == itemId))[0]

// Order lines with what was ordered and what the ERP has
fun lineViews(order, items: Array) =
	order.lines map ((l) -> do {
		var item = itemOf(items, l.itemId)
		---
		{ itemId: l.itemId, sku: l.sku default item.sku, ordered: l.quantity, available: item.stock default 0,
			(unitPrice: l.unitPrice) if (l.unitPrice != null) }
	})

fun shortLines(lines: Array) = lines filter ((l) -> l.ordered > l.available)

// Dispatch note from the logistics result: UNKNOWN when logistics did not answer, ON_HOLD when there is none
fun dispatchView(rs) =
	if (not (rs.ok default false)) { status: "UNKNOWN" }
	else if (not (rs.payload.found default false)) { status: "ON_HOLD" }
	else { dispatchNoteId: rs.payload.note.dispatchNoteId, status: rs.payload.note.status,
		(reason: rs.payload.note.reason) if (rs.payload.note.reason != null) }

// Exception rules:
// - UNCONFIRMED: the order is still RECEIVED;
// - STOCK_SHORTAGE: CONFIRMED, without a dispatch note (or logistics unknown) and a line asks for more than the stock;
// - DISPATCH_REJECTED: the latest dispatch note is REJECTED.
fun exceptionsOf(status: String, lines: Array, dispatch) =
	(if (status == "RECEIVED") ["UNCONFIRMED"] else [])
	++ (if (status == "CONFIRMED" and (["ON_HOLD", "UNKNOWN"] contains dispatch.status) and not isEmpty(shortLines(lines))) ["STOCK_SHORTAGE"] else [])
	++ (if (dispatch.status == "REJECTED") ["DISPATCH_REJECTED"] else [])

// POST /quotes body: every provider of every short item
fun quoteRequest(short: Array, items: Array) =
	flatten(short map ((l) -> (itemOf(items, l.itemId).providers default []) map ((p) -> { abv: p.abv, externalId: p.externalId })))

// Quotes of one short line (matched by provider and its external id), with the cheapest one flagged
fun lineQuotes(line, items: Array, quoteResult) = do {
	var providers = itemOf(items, line.itemId).providers default []
	var quotes = (quoteResult.quotes default []) filter ((q) -> not isEmpty(providers filter ((p) -> (p.abv == q.abv) and (p.externalId == q.externalId))))
	var minPrice = min(quotes.price default [])
	---
	quotes map ((q) -> { provider: q.abv, price: q.price, currency: q.currency, cheapest: q.price == minPrice })
}

// "n of m": how many of the queried providers returned a quote
fun providersLabel(requested: Number, quoteRs) =
	if (requested == 0) "0 of 0"
	else if (not (quoteRs.ok default false)) "0 of " ++ requested
	else sizeOf(quoteRs.payload.quotes default []) ++ " of " ++ requested

fun alternativesOf(exceptions: Array, short: Array, items: Array, quoteRs) =
	(if (exceptions contains "STOCK_SHORTAGE")
		flatten(short map ((l) -> lineQuotes(l, items, quoteRs.payload default {}) map ((q) -> {
			"type": "RESTOCK", itemId: l.itemId, sku: l.sku, quantity: l.ordered - l.available,
			provider: q.provider, price: q.price, currency: q.currency, cheapest: q.cheapest })))
	else [])
	++ (if (exceptions contains "DISPATCH_REJECTED") [ { "type": "REISSUE" } ] else [])

fun customerSummary(c) =
	if (c == null) null
	else { id: c.id, name: c.name, segment: c.segment default "REGULAR", (city: c.address.city) if (c.address.city != null) }

// The Order 360 response
fun order360(order, items: Array, crmRs, logisticsRs, quoteRs, requested: Number) = do {
	var lines = lineViews(order, items)
	var dispatch = dispatchView(logisticsRs)
	var exceptions = exceptionsOf(order.status, lines, dispatch)
	var customer = if (crmRs.ok default false) customerSummary(crmRs.payload) else null
	---
	{
		orderId: order.orderId,
		status: order.status,
		currency: order.currency,
		createdAt: order.createdAt,
		(customer: customer) if (customer != null),
		lines: lines,
		dispatchNote: dispatch,
		exceptions: exceptions,
		alternatives: alternativesOf(exceptions, shortLines(lines), items, quoteRs),
		sources: {
			erp: "OK",
			crm: if (crmRs.ok default false) "OK" else "UNAVAILABLE",
			logistics: if (logisticsRs.ok default false) "OK" else "UNAVAILABLE",
			providers: providersLabel(requested, quoteRs)
		}
	}
}

// GET /orders/{id}/alternatives from the Order 360 pieces (null when the order has no exception to resolve)
fun alternativesResponse(o360, items: Array, quoteRs) = do {
	var short = shortLines(o360.lines)
	---
	if (o360.exceptions contains "STOCK_SHORTAGE") do {
		var line = short[0]
		var quotes = lineQuotes(line, items, quoteRs.payload default {})
		var best = (o360.alternatives filter ((a) -> (a."type" == "RESTOCK") and (a.itemId == line.itemId) and (a.cheapest default false)))[0]
		---
		{
			orderId: o360.orderId, "type": "RESTOCK", itemId: line.itemId, sku: line.sku,
			shortage: line.ordered - line.available, currency: o360.currency,
			quotes: quotes map ((q) -> { provider: q.provider, price: q.price, (cheapest: true) if (q.cheapest) }),
			(cheapest: best) if (best != null),
			providers: o360.sources.providers
		}
	}
	else if (o360.exceptions contains "DISPATCH_REJECTED")
		{ orderId: o360.orderId, "type": "REISSUE", (reason: o360.dispatchNote.reason) if (o360.dispatchNote.reason != null),
			cheapest: { "type": "REISSUE" } }
	else null
}

// ---------------------------------------------------------------- Exceptions inbox
// Latest dispatch note of an order among the listings by status (each listing is a resilient result)
fun dispatchFromListings(orderId, listings: Array) = do {
	var allOk = isEmpty(listings filter ((r) -> not (r.ok default false)))
	var notes = flatten(listings map ((r) -> if (r.ok default false) r.payload else [])) filter ((n) -> n.orderId == orderId)
	var latest = (notes orderBy ((n) -> n.sequence))[-1]
	---
	if (latest != null) { dispatchNoteId: latest.dispatchNoteId, status: latest.status, (reason: latest.reason) if (latest.reason != null) }
	else if (allOk) { status: "ON_HOLD" }
	else { status: "UNKNOWN" }
}

fun detailOf(exceptionType: String, lines: Array, dispatch) =
	exceptionType match {
		case "STOCK_SHORTAGE" -> (shortLines(lines) map ((l) -> l.sku ++ " ordered " ++ l.ordered ++ ", available " ++ l.available)) joinBy "; "
		case "DISPATCH_REJECTED" -> dispatch.reason default "Dispatch note rejected"
		else -> "Waiting for confirmation: no price yet"
	}

// One entry per order exception; STRATEGIC customers first, then the oldest orders
fun exceptionsInbox(orders: Array, items: Array, crmRs, listings: Array, limit: Number) = do {
	var contacts = if (crmRs.ok default false) crmRs.payload else []
	var entries = flatten(orders map ((o) -> do {
		var lines = lineViews(o, items)
		var dispatch = dispatchFromListings(o.orderId, listings)
		var customer = customerSummary((contacts filter ((c) -> c.id == o.customerId))[0])
		---
		exceptionsOf(o.status, lines, dispatch) map ((e) -> {
			orderId: o.orderId, "type": e, status: o.status,
			(customer: customer) if (customer != null),
			createdAt: o.createdAt, detail: detailOf(e, lines, dispatch)
		})
	}))
	var sorted = entries orderBy ((e) -> (if ((e.customer.segment default "REGULAR") == "STRATEGIC") "0" else "1") ++ e.createdAt)
	---
	if (isEmpty(sorted)) [] else sorted[0 to (min([limit, sizeOf(sorted)]) - 1)]
}
