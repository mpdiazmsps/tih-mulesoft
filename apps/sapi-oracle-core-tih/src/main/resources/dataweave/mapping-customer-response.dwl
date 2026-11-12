%dw 2.0
output application/json
// Primera fila de CUSTOMERS -> Customer del contrato. Los campos NULL se omiten.
var row = payload[0]
---
{
	id: row.ID,
	name: row.CLIENT_NAME,
	(lastName: row.CLIENT_LAST_NAME) if row.CLIENT_LAST_NAME != null,
	(email: row.CLIENT_EMAIL) if row.CLIENT_EMAIL != null,
	(phone: row.CLIENT_PHONE) if row.CLIENT_PHONE != null,
	creationDate: ((row.CREATION_DATE as LocalDateTime {format: "yyyyMMddHHmmssSSS"}) as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"})
}
