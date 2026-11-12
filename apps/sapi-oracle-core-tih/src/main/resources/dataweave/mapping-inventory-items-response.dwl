%dw 2.0
output application/json
// Filas de INVENTORY -> InventoryItemList del contrato. Los campos NULL se omiten.
---
{
	items: payload map (row) -> {
		id: row.ID,
		name: row.NAME,
		(description: row.DESCRIPTION) if row.DESCRIPTION != null,
		stockQty: row.STOCK_QTY as Number,
		localPrice: (row.LOCAL_PRICE default 0) as Number,
		(externalId: row.EXTERNAL_ID as Number) if row.EXTERNAL_ID != null,
		(providerAbv: row.PROVIDER_ABV) if row.PROVIDER_ABV != null,
		creationDate: ((row.CREATION_DATE as LocalDateTime {format: "yyyyMMddHHmmssSSS"}) as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"})
	}
}
