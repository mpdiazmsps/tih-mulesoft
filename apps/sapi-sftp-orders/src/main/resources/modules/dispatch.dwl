%dw 2.0
// Dispatch notes on the logistics SFTP. The status is the folder; the acknowledgment <file>.acuse.json sits next to
// the CSV in firmadas/ and rechazadas/ (fields in Spanish, written by logistics: recibio, motivo, fecha, depositada).

var csvName = /^remision_(.+)_(\d+)\.csv$/

fun utc(t) =
	if (t == null) null
	else if (t is String) t
	else (t as LocalDateTime) as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}

fun nameOf(m) = (m.attributes.fileName default m.attributes.name) as String

// Keeps the dispatch notes (CSV) and the acknowledgments of one folder (name, path, date); orderId null keeps every order
fun folderEntries(listing: Array, status: String, orderId) =
	listing
		filter ((m) -> do {
			var n = nameOf(m)
			---
			(n startsWith (if (orderId == null) "remision_" else "remision_" ++ orderId ++ "_"))
				and ((n matches csvName) or (n endsWith ".csv.acuse.json"))
		})
		map ((m) -> do {
			var n = nameOf(m)
			---
			{
				status: status,
				name: n,
				path: m.attributes.path,
				timestamp: utc(m.attributes.timestamp)
			}
		})

// Folder entries -> DispatchNote[] (one per CSV, joined with its acknowledgment), sorted by order and sequence.
// acks: acknowledgment content by file name (sftp:list only returns paths, so the flow reads each one).
fun toNotes(entries: Array, acks: Object) =
	(entries filter ((e) -> e.name matches csvName))
		map ((e) -> do {
			var parts = e.name scan csvName
			var ack = acks[e.name ++ ".acuse.json"]
			---
			{
				dispatchNoteId: parts[0][1] ++ "-" ++ parts[0][2],
				orderId: parts[0][1],
				sequence: parts[0][2] as Number,
				fileName: e.name,
				status: e.status,
				depositedAt: ack.depositada default e.timestamp,
				(receivedBy: ack.recibio) if (ack.recibio != null),
				(acknowledgedAt: ack.fecha) if (ack.fecha != null),
				(reason: ack.motivo) if (ack.motivo != null)
			}
		})
		orderBy ((n) -> n.orderId ++ "-" ++ (n.sequence as String {format: "000000"}))

// Next sequence number of an order: the highest one in any folder plus 1
fun nextSequence(notes: Array) = (max(notes.sequence default []) default 0) + 1
