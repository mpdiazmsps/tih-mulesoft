%dw 2.0
// Maps Oracle rows (STORE_APP) to the common contract format (camelCase).
// Dates arrive as UTC text 'YYYYMMDDHH24MISS' (Mule SQL does not accept ':' or quotes inside formats).

fun utc(s) =
	if (s == null) null
	else ((s as LocalDateTime {format: "yyyyMMddHHmmss"}) as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"})

fun opt(key: String, v) = if (v == null) {} else { (key): v }

fun num(v) = if (v == null) null else (v as Number)

// ORDERS JOIN ORDER_ITEMS JOIN INVENTORY rows (one per line) -> Order[] in arrival order
fun toOrders(rows: Array) =
	(rows distinctBy ((r) -> r.ID)) map (h) -> do {
		var lines = rows filter ((r) -> r.ID == h.ID)
		---
		{
			orderId: h.ID,
			customerId: h.CUSTOMER_ID,
			status: h.STATUS,
			currency: h.CURRENCY,
			lines: lines map (l) -> (
				{ itemId: l.ITEM_ID, sku: l.SKU, quantity: num(l.QTY) }
				++ opt('unitPrice', num(l.UNIT_PRICE))
				++ opt('priceSource', l.PRICE_SOURCE)
				++ opt('provider', l.PRICE_PROVIDER)
			)
		}
		++ opt('total', num(h.TOTAL))
		++ { createdAt: utc(h.CREATED_AT) }
		++ opt('updatedAt', utc(h.UPDATED_AT))
	}

// INVENTORY rows (+ INVENTORY_PROVIDERS rows when requested) -> InventoryItem[]
fun toInventoryItems(items: Array, providers: Array | Null) =
	items map (i) -> (
		{
			itemId: i.ID,
			sku: i.SKU,
			name: i.NAME,
			stock: num(i.STOCK_QTY),
			localPrice: num(i.LOCAL_PRICE),
			currency: i.CURRENCY
		}
		++ (if (providers == null) {} else {
			providers: (providers filter ((p) -> p.ITEM_ID == i.ID)) map (p) -> (
				{ abv: p.PROVIDER_ABV, externalId: num(p.EXTERNAL_ID), preferred: (num(p.IS_PREFERRED) default 0) == 1 }
				++ opt('lastPrice', num(p.LAST_PRICE))
				++ opt('lastPriceAt', utc(p.LAST_PRICE_AT))
			)
		})
	)

// INVENTORY_MOVEMENTS row -> InventoryMovement
fun toMovement(m) =
	{
		movementId: m.ID,
		itemId: m.ITEM_ID,
		"type": m.MOVEMENT_TYPE,
		quantity: num(m.QTY),
		reference: m.REFERENCE
	}
	++ opt('orderId', m.ORDER_ID)
	++ { resultingStock: num(m.RESULTING_STOCK), createdAt: utc(m.CREATED_AT) }
