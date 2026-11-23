%dw 2.0
// Business rules of papi-orders: line pricing, full stock check, catalog price and the order.registered event.

fun preferredOf(item) = (item.providers default []) filter ((p) -> p.preferred default false)

// Price of one order line, without quoting (P13, step 1):
// - LOCAL when the ERP local price is greater than 0;
// - LAST_PRICE with the last confirmed price of the preferred provider;
// - otherwise it needs a live quote from the preferred provider (quote: { abv, externalId });
// - without a preferred provider it cannot be priced.
fun priceLine(line, item) = do {
	var pref = preferredOf(item)[0]
	var base = { itemId: line.itemId, sku: item.sku default line.sku, quantity: line.quantity }
	---
	if (item == null) base ++ { unpriced: true }
	else if ((item.localPrice default 0) > 0) base ++ { unitPrice: item.localPrice, priceSource: "LOCAL" }
	else if (pref != null and pref.lastPrice != null) base ++ { unitPrice: pref.lastPrice, priceSource: "LAST_PRICE", provider: pref.abv }
	else if (pref != null) base ++ { quote: { abv: pref.abv, externalId: pref.externalId } }
	else base ++ { unpriced: true }
}

fun priceLines(lines: Array, items: Array) =
	lines map ((l) -> priceLine(l, (items filter ((i) -> i.itemId == l.itemId))[0]))

// Lines after the live quotes: quotes is { itemId: price } with the prices obtained (a failed quote is missing)
fun applyQuotes(lines: Array, quotes: Object) =
	lines map ((l) ->
		if (l.quote == null) l
		else if (quotes[l.itemId] == null) (l - "quote") ++ { unpriced: true }
		else (l - "quote") ++ { unitPrice: quotes[l.itemId], priceSource: "QUOTE", provider: l.quote.abv })

fun allPriced(lines: Array) = isEmpty(lines filter ((l) -> l.unitPrice == null))

// Lines for PATCH /orders/{id} (CONFIRMED)
fun confirmedLines(lines: Array) =
	lines map ((l) -> { itemId: l.itemId, quantity: l.quantity, unitPrice: l.unitPrice, priceSource: l.priceSource,
		(provider: l.provider) if (l.provider != null) })

// Every line has enough stock (D8: otherwise the order stays CONFIRMED and its dispatch note waits)
fun fullStock(lines: Array, items: Array) =
	isEmpty(lines filter ((l) -> l.quantity > (((items filter ((i) -> i.itemId == l.itemId))[0].stock) default 0)))

// Catalog product: local price, or the last price of the preferred provider. Never a live quote.
fun toProduct(item) = do {
	var pref = preferredOf(item)[0]
	var priced =
		if ((item.localPrice default 0) > 0) { price: item.localPrice, priceSource: "LOCAL" }
		else if (pref != null and pref.lastPrice != null) { price: pref.lastPrice, priceSource: "LAST_PRICE", provider: pref.abv }
		else {}
	---
	{ itemId: item.itemId, sku: item.sku, name: item.name, stock: item.stock } ++ priced ++ { currency: item.currency }
}

// order.registered event from the confirmed order returned by sapi-oracle-core (D8)
fun orderRegistered(order) = {
	eventType: "order.registered",
	orderId: order.orderId,
	customerId: order.customerId,
	currency: order.currency,
	lines: order.lines,
	total: order.total,
	occurredAt: (now() >> "UTC") as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}
