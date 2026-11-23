%dw 2.0
// Rows of the INTEGRATION_APP store (ORDER_REQUESTS + ORDER_REQUEST_EVENTS) -> the common OrderRequest format.
// Dates arrive as UTC text 'YYYYMMDDHH24MISS' (Mule SQL does not accept ':' or quotes inside formats).

// Columns of ORDER_REQUESTS with the dates already as UTC text
var requestColumns = "ID, IDEMPOTENCY_KEY, ORDER_ID, CUSTOMER_ID, REQUEST_TYPE, ITEM_ID, PROVIDER_ABV, QTY, UNIT_PRICE, AMOUNT, CURRENCY, STATUS, REQUESTED_BY, DECIDED_BY, REASON, TO_CHAR(SYS_EXTRACT_UTC(EXPIRES_AT), 'YYYYMMDDHH24MISS') AS EXPIRES_AT, TO_CHAR(SYS_EXTRACT_UTC(DECIDED_AT), 'YYYYMMDDHH24MISS') AS DECIDED_AT, TO_CHAR(SYS_EXTRACT_UTC(CREATED_AT), 'YYYYMMDDHH24MISS') AS CREATED_AT"

var eventColumns = "REQUEST_ID, TO_STATUS, ACTOR, DETAIL, TO_CHAR(SYS_EXTRACT_UTC(EVENT_AT), 'YYYYMMDDHH24MISS') AS EVENT_AT, TO_CHAR(SYS_EXTRACT_UTC(EVENT_AT), 'YYYYMMDDHH24MISSFF6') AS EVENT_ORDER"

fun utc(s) =
	if (s == null) null
	else ((s as LocalDateTime {format: "yyyyMMddHHmmss"}) as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"})

fun num(v) = if (v == null) null else (v as Number)

fun opt(key: String, v) = if (v == null) {} else { (key): v }

// One ORDER_REQUESTS row and the events of the store -> OrderRequest with its history, oldest step first
fun toOrderRequest(r, events: Array) = {
	requestId: r.ID,
	orderId: r.ORDER_ID,
	"type": r.REQUEST_TYPE,
	status: r.STATUS,
	detail: {}
		++ opt("itemId", r.ITEM_ID)
		++ opt("quantity", num(r.QTY))
		++ opt("provider", r.PROVIDER_ABV)
		++ opt("price", num(r.UNIT_PRICE))
		++ opt("currency", r.CURRENCY),
	idempotencyKey: r.IDEMPOTENCY_KEY,
	requestedBy: r.REQUESTED_BY,
	requestedAt: utc(r.CREATED_AT),
	expiresAt: utc(r.EXPIRES_AT)
}
	++ opt("decidedBy", r.DECIDED_BY)
	++ opt("decidedAt", utc(r.DECIDED_AT))
	++ opt("reason", r.REASON)
	++ {
		history: ((events filter ((e) -> e.REQUEST_ID == r.ID)) orderBy ((e) -> e.EVENT_ORDER)) map ((e) ->
			{ status: e.TO_STATUS, actor: e.ACTOR, at: utc(e.EVENT_AT) } ++ opt("note", e.DETAIL))
	}

// D10: is the calling client application one of the configured approvers?
fun isApprover(clientApp, approvers: String) =
	(clientApp != null) and (((approvers splitBy ",") map trim($)) contains clientApp)

// "id1,id2" list for the INSTR batch query
fun idList(rows: Array) = rows.ID joinBy ","
