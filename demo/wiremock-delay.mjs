// Cambia el retardo de un proveedor simulado en WireMock por su API de administración (sin reiniciar nada).
//
//   node demo/wiremock-delay.mjs <c|a|b> <milisegundos> [baseUrl]
//
// Ejemplos: node demo/wiremock-delay.mjs c 5000   (el proveedor C tarda 5 s: escena 3)
//           node demo/wiremock-delay.mjs c 0      (vuelve a la normalidad)
// baseUrl por defecto: http://localhost:$WIREMOCK_PORT (8089). Los cambios viven en memoria:
// reset-data los quita al recargar los mappings de los archivos.
const [, , provider = 'c', msArg = '0', base = `http://localhost:${process.env.WIREMOCK_PORT || 8089}`] = process.argv
const prefix = { a: '/proveedor-a/', b: '/proveedor-b/', c: '/proveedor-c/' }[provider.toLowerCase()]
const ms = Number(msArg)
if (!prefix || !Number.isInteger(ms) || ms < 0) {
  console.error('Uso: node demo/wiremock-delay.mjs <c|a|b> <milisegundos> [baseUrl]')
  process.exit(2)
}

const res = await fetch(`${base}/__admin/mappings`)
if (!res.ok) { console.error(`WireMock no responde en ${base} (${res.status})`); process.exit(1) }
const { mappings } = await res.json()
const target = mappings.filter(m => {
  const url = m.request.urlPath || m.request.urlPathPattern || m.request.url || ''
  return url.startsWith(prefix) && !m.response.fault
})
for (const m of target) {
  if (ms > 0) m.response.fixedDelayMilliseconds = ms
  else delete m.response.fixedDelayMilliseconds
  const put = await fetch(`${base}/__admin/mappings/${m.id}`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(m)
  })
  if (!put.ok) { console.error(`No se pudo actualizar ${m.name || m.id} (${put.status})`); process.exit(1) }
}
console.log(`Proveedor ${provider.toUpperCase()}: retardo ${ms} ms en ${target.length} respuestas.`)
