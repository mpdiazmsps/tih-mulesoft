// Genera las semillas de cada sistema a partir de data/scenario.json (única fuente de los datos del guion).
//
//   node data/tools/build-seeds.mjs
//
// Lee también data/salesforce-ids.local.json ({ "POC-CUMBRES": "003...", ... }, lo escribe la tarea 9).
// Si no existe, usa Ids marcadores de 18 caracteres y lo avisa.
//
// Genera (todo es derivado y no se versiona):
//   - infra/oracle/sql/erp/20-seed.generated.sql   semilla del ERP (borra y vuelve a insertar: se puede repetir)
//   - infra/sftp/seed/<carpeta>/remision_<pedidoId>_<n>.csv (+ .acuse.json)   remisiones iniciales de logística
//   - data/logistics-rules.json                    remisiones que el simulador rechaza, con su motivo
//   - infra/wiremock/mappings/proveedor-{a,b,c}.json   simuladores de los proveedores A (FAK), B (ESC) y C (BOR)
//
// Los valores de estado del guion (español) se traducen a los del ERP y los contratos (inglés).
// Ningún comentario va en la misma línea después de ';': Oracle 23ai lo rechaza con ORA-03405.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..')
const p = (...x) => path.join(REPO, ...x)
const scenario = JSON.parse(fs.readFileSync(p('data', 'scenario.json'), 'utf8'))

const ORDER_STATUS = { RECIBIDO: 'RECEIVED', CONFIRMADO: 'CONFIRMED', RECHAZADO: 'REJECTED' }
const PRICE_SOURCE = { LOCAL: 'LOCAL', ULTIMO_PRECIO: 'LAST_PRICE', COTIZACION: 'QUOTE' }
const DISPATCH_FOLDER = { PENDIENTE: 'pendientes', FIRMADA: 'firmadas', RECHAZADA: 'rechazadas' }

// ------------------------------------------------------------ Ids de Salesforce
const sfFile = p('data', 'salesforce-ids.local.json')
let sfIds = {}
let placeholders = false
if (fs.existsSync(sfFile)) {
  sfIds = JSON.parse(fs.readFileSync(sfFile, 'utf8'))
} else {
  placeholders = true
  scenario.clientes.forEach((c, i) => { sfIds[c.externalId] = `003${String(i + 1).padStart(12, '0')}AAA` })
}
for (const c of scenario.clientes) {
  const id = sfIds[c.externalId]
  if (!/^[a-zA-Z0-9]{18}$/.test(id || '')) throw new Error(`Falta un Id de Salesforce de 18 caracteres para ${c.externalId}`)
}

// ------------------------------------------------------------------ ayudas
const q = v => v === null || v === undefined ? 'NULL' : `'${String(v).replace(/'/g, "''")}'`
const n = v => v === null || v === undefined ? 'NULL' : String(v)
const ts = iso => iso ? `TO_TIMESTAMP_TZ('${iso}', 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')` : 'NULL'
const plusMinutes = (iso, m) => {
  const d = new Date(new Date(iso).getTime() + m * 60000)
  const off = iso.slice(-6)
  const sign = off[0] === '-' ? -1 : 1
  const offMin = sign * (Number(off.slice(1, 3)) * 60 + Number(off.slice(4, 6)))
  const local = new Date(d.getTime() + offMin * 60000).toISOString().slice(0, 19)
  return local + off
}
const product = key => {
  const prod = scenario.productos.find(x => x.clave === key)
  if (!prod) throw new Error(`Producto desconocido: ${key}`)
  return prod
}
const write = (rel, text) => {
  fs.mkdirSync(path.dirname(p(rel)), { recursive: true })
  fs.writeFileSync(p(rel), text.replace(/\r?\n/g, '\n'))
  console.log('generado:', rel)
}

// ---------------------------------------------------------------- semilla ERP
const sql = []
sql.push('-- GENERADO por data/tools/build-seeds.mjs desde data/scenario.json. No editar a mano.')
sql.push('-- Se ejecuta como STORE_APP. Borra los datos y los vuelve a insertar: se puede repetir.')
if (placeholders) sql.push('-- AVISO: Ids de Salesforce marcadores (falta data/salesforce-ids.local.json).')
sql.push('WHENEVER SQLERROR EXIT SQL.SQLCODE')
sql.push('SET DEFINE OFF')
sql.push('SET FEEDBACK OFF')
sql.push('DELETE FROM INVENTORY_MOVEMENTS;')
sql.push('DELETE FROM ORDER_ITEMS;')
sql.push('DELETE FROM ORDERS;')
sql.push('DELETE FROM INVENTORY_PROVIDERS;')
sql.push('DELETE FROM INVENTORY;')

for (const prod of scenario.productos) {
  sql.push(`INSERT INTO INVENTORY (ID, SKU, NAME, STOCK_QTY, LOCAL_PRICE, CURRENCY) VALUES (${q(prod.id)}, ${q(prod.clave)}, ${q(prod.nombre)}, ${n(prod.stock)}, ${n(prod.precioLocal)}, ${q(scenario.moneda)});`)
  for (const pr of prod.proveedores) {
    const lastAt = pr.ultimoPrecio !== null ? ts('2026-11-17T10:00:00-06:00') : 'NULL'
    sql.push(`INSERT INTO INVENTORY_PROVIDERS (ITEM_ID, PROVIDER_ABV, EXTERNAL_ID, IS_PREFERRED, LAST_PRICE, LAST_PRICE_AT) VALUES (${q(prod.id)}, ${q(pr.abv)}, ${n(pr.externalId)}, ${pr.preferente ? 1 : 0}, ${n(pr.ultimoPrecio)}, ${lastAt});`)
  }
}

// Las salidas de los pedidos con remisión ya ocurrieron: se reconstruye el stock hacia atrás
// para que RESULTING_STOCK termine en el stock del guion.
const movements = []
for (const ped of scenario.pedidos) {
  if (!ped.remision) continue
  for (const l of ped.lineas) movements.push({ ped, l, prod: product(l.producto), at: plusMinutes(ped.creado, 5) })
}
const running = Object.fromEntries(scenario.productos.map(x => [x.clave, x.stock]))
for (const m of [...movements].reverse()) { m.resulting = running[m.prod.clave]; running[m.prod.clave] += m.l.cantidad }

for (const ped of scenario.pedidos) {
  const status = ORDER_STATUS[ped.estado]
  if (!status) throw new Error(`Estado desconocido en ${ped.clave}: ${ped.estado}`)
  const confirmed = status === 'CONFIRMED'
  const total = confirmed ? ped.lineas.reduce((s, l) => s + l.cantidad * l.precio, 0).toFixed(2) : null
  const confirmedAt = confirmed ? plusMinutes(ped.creado, 2) : null
  sql.push(`-- ${ped.clave}`)
  sql.push(`INSERT INTO ORDERS (ID, CUSTOMER_ID, STATUS, CURRENCY, TOTAL, CREATED_AT, CONFIRMED_AT, UPDATED_AT) VALUES (${q(ped.id)}, ${q(sfIds[ped.cliente])}, ${q(status)}, ${q(scenario.moneda)}, ${n(total)}, ${ts(ped.creado)}, ${ts(confirmedAt)}, ${ts(confirmedAt)});`)
  for (const l of ped.lineas) {
    const prod = product(l.producto)
    sql.push(`INSERT INTO ORDER_ITEMS (ORDER_ID, ITEM_ID, QTY, UNIT_PRICE, PRICE_SOURCE, PRICE_PROVIDER) VALUES (${q(ped.id)}, ${q(prod.id)}, ${n(l.cantidad)}, ${confirmed ? n(l.precio) : 'NULL'}, ${confirmed ? q(PRICE_SOURCE[l.fuentePrecio]) : 'NULL'}, ${confirmed ? q(l.proveedor || null) : 'NULL'});`)
  }
}
movements.forEach((m, i) => {
  const id = `40000000-0000-4000-8000-${String(i + 1).padStart(12, '0')}`
  sql.push(`-- salida de ${m.ped.clave}`)
  sql.push(`INSERT INTO INVENTORY_MOVEMENTS (ID, ITEM_ID, MOVEMENT_TYPE, QTY, REFERENCE, ORDER_ID, RESULTING_STOCK, CREATED_AT) VALUES (${q(id)}, ${q(m.prod.id)}, 'OUTBOUND', ${n(m.l.cantidad)}, ${q(`${m.ped.id}-out-${m.prod.id}`)}, ${q(m.ped.id)}, ${n(m.resulting)}, ${ts(m.at)});`)
})
sql.push('COMMIT;')
sql.push('EXIT')
write('infra/oracle/sql/erp/20-seed.generated.sql', sql.join('\n') + '\n')

// -------------------------------------------------------- remisiones semilla
fs.rmSync(p('infra', 'sftp', 'seed'), { recursive: true, force: true })
for (const ped of scenario.pedidos) {
  if (!ped.remision) continue
  const c = scenario.clientes.find(x => x.externalId === ped.cliente)
  const folder = DISPATCH_FOLDER[ped.remision.estado]
  const file = `remision_${ped.id}_${ped.remision.n}.csv`
  const rows = ['pedido,remision,cliente,calle,ciudad,estado,codigo_postal,sku,cantidad']
  for (const l of ped.lineas) {
    rows.push([ped.id, `${ped.id}-${ped.remision.n}`, c.nombre, c.calle, c.ciudad, c.estado, c.codigoPostal, l.producto, l.cantidad]
      .map(v => /[",]/.test(String(v)) ? `"${String(v).replace(/"/g, '""')}"` : v).join(','))
  }
  write(`infra/sftp/seed/${folder}/${file}`, rows.join('\n') + '\n')
  const acuse = { remision: `${ped.id}-${ped.remision.n}`, archivo: file, estado: ped.remision.estado, depositada: ped.remision.depositada, ...ped.remision.acuse }
  write(`infra/sftp/seed/${folder}/${file}.acuse.json`, JSON.stringify(acuse, null, 2) + '\n')
}

// --------------------------------------------------------- reglas de logística
const rules = {
  _generado: 'data/tools/build-seeds.mjs desde data/scenario.json. No editar a mano.',
  rechazos: Object.fromEntries(scenario.logistica.rechazos.map(r => {
    const ped = scenario.pedidos.find(x => x.clave === r.pedido)
    return [`remision_${ped.id}_${r.n}.csv`, r.motivo]
  })),
  recibeFirma: scenario.logistica.recibeFirma
}
write('data/logistics-rules.json', JSON.stringify(rules, null, 2) + '\n')

// ------------------------------------------------------------ proveedores (WireMock)
// Cada simulador imita al proveedor real, también para un id desconocido:
//   A (estilo Fakestore): 200 con cuerpo vacío; B (estilo Escuelajs): 400; C (SOAP): respuesta sin GetArticleByIdResult.
// Un producto con "responde": false corta la conexión (fault CONNECTION_RESET_BY_PEER).
const quotesOf = abv => scenario.productos.flatMap(prod => prod.proveedores
  .filter(pr => pr.abv === abv).map(pr => ({ prod, pr })))
const price = v => Number(v.toFixed(2))
const reset = { fault: 'CONNECTION_RESET_BY_PEER' }

const mapA = { mappings: [] }
for (const { prod, pr } of quotesOf('FAK')) {
  mapA.mappings.push({
    name: `A · ${prod.clave} (externalId ${pr.externalId})`, priority: 1,
    request: { method: 'GET', urlPath: `/proveedor-a/products/${pr.externalId}` },
    response: pr.responde ? { status: 200, headers: { 'Content-Type': 'application/json' },
      jsonBody: { id: pr.externalId, title: prod.nombre, price: price(pr.precio), currency: scenario.moneda, description: `${prod.nombre} (proveedor A)`, category: 'general', image: `https://proveedor-a.example/img/${pr.externalId}.png` } } : reset
  })
}
mapA.mappings.push({ name: 'A · id desconocido: 200 sin cuerpo (como Fakestore)', priority: 10,
  request: { method: 'GET', urlPathPattern: '/proveedor-a/products/[^/]+' },
  response: { status: 200, headers: { 'Content-Type': 'application/json', 'Content-Length': '0' }, body: '' } })
write('infra/wiremock/mappings/proveedor-a.json', JSON.stringify(mapA, null, 2) + '\n')

const mapB = { mappings: [] }
for (const { prod, pr } of quotesOf('ESC')) {
  mapB.mappings.push({
    name: `B · ${prod.clave} (externalId ${pr.externalId})`, priority: 1,
    request: { method: 'GET', urlPath: `/proveedor-b/api/v1/products/${pr.externalId}` },
    response: pr.responde ? { status: 200, headers: { 'Content-Type': 'application/json' },
      jsonBody: { id: pr.externalId, title: prod.nombre, price: price(pr.precio), currency: scenario.moneda, description: `${prod.nombre} (proveedor B)`, category: { id: 1, name: 'General' }, images: [] } } : reset
  })
}
mapB.mappings.push({ name: 'B · id desconocido: 400 (como Escuelajs)', priority: 10,
  request: { method: 'GET', urlPathPattern: '/proveedor-b/api/v1/products/[^/]+' },
  response: { status: 400, headers: { 'Content-Type': 'application/json' },
    jsonBody: { message: 'Could not find any entity of type "Product" matching the criteria', error: 'EntityNotFound', statusCode: 400 } } })
write('infra/wiremock/mappings/proveedor-b.json', JSON.stringify(mapB, null, 2) + '\n')

const soap = inner => `<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body>${inner}</soap:Body></soap:Envelope>`
const xmlEsc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const mapC = { mappings: [] }
for (const { prod, pr } of quotesOf('BOR')) {
  mapC.mappings.push({
    name: `C · ${prod.clave} (ArticleId ${pr.externalId})`, priority: 1,
    request: { method: 'POST', urlPath: '/proveedor-c/OrderService',
      bodyPatterns: [{ matchesXPath: `//*[local-name()='GetArticleById']/*[local-name()='ArticleId' and normalize-space(text())='${pr.externalId}']` }] },
    response: pr.responde ? { status: 200, headers: { 'Content-Type': 'text/xml; charset=utf-8' },
      body: soap(`<GetArticleByIdResponse xmlns="http://tempuri.org/"><GetArticleByIdResult><ArticleId>${pr.externalId}</ArticleId><Name>${xmlEsc(prod.nombre)}</Name><Price>${price(pr.precio).toFixed(2)}</Price><Currency>${scenario.moneda}</Currency></GetArticleByIdResult></GetArticleByIdResponse>`) } : reset
  })
}
mapC.mappings.push({ name: 'C · ArticleId desconocido: respuesta sin GetArticleByIdResult', priority: 10,
  request: { method: 'POST', urlPath: '/proveedor-c/OrderService',
    bodyPatterns: [{ matchesXPath: "//*[local-name()='GetArticleById']" }] },
  response: { status: 200, headers: { 'Content-Type': 'text/xml; charset=utf-8' },
    body: soap('<GetArticleByIdResponse xmlns="http://tempuri.org/" />') } })
write('infra/wiremock/mappings/proveedor-c.json', JSON.stringify(mapC, null, 2) + '\n')

if (placeholders) console.log('AVISO: no existe data/salesforce-ids.local.json; se usaron Ids de Salesforce marcadores. Vuelve a correr este script después de la tarea 9.')
