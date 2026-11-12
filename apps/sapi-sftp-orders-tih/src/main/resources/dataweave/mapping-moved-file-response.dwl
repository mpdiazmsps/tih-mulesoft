%dw 2.0
output application/json
// Primer (y único) resultado de sftp:list sobre la carpeta destino -> FileInfo del contrato.
var moved = payload[0].attributes
---
{
	fileName: moved.name,
	status: vars.targetFolder,
	size: moved.size,
	lastModified: (moved.timestamp as LocalDateTime) as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"}
}
