%dw 2.0
output application/java
// Consulta por lote: un parámetro nombrado (:id0, :id1, ...) por cada id. Nunca se concatenan valores en el SQL.
var ids = ((attributes.queryParams.ids splitBy ",") map trim($)) distinctBy $
---
{
	sql: "SELECT ID, NAME, DESCRIPTION, STOCK_QTY, LOCAL_PRICE, EXTERNAL_ID, PROVIDER_ABV, TO_CHAR(CREATION_DATE, 'YYYYMMDDHH24MISSFF3') AS CREATION_DATE FROM INVENTORY WHERE ID IN ("
		++ ((ids map ((id, index) -> ":id" ++ (index as String))) joinBy ", ")
		++ ")",
	params: { (ids map ((id, index) -> { ("id" ++ (index as String)): id })) }
}
