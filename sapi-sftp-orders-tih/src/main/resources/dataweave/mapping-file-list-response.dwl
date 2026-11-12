%dw 2.0
output application/json
// Resultado de sftp:list -> FileList del contrato. status sale de la carpeta consultada.
---
{
	files: payload map (item) -> {
		fileName: item.attributes.name,
		status: vars.folderStatus,
		size: item.attributes.size,
		lastModified: (item.attributes.timestamp as LocalDateTime) as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"}
	}
}
