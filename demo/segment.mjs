// Cambia el segmento de un cliente del guion en Salesforce (escena 2: "si el cliente cambia en Salesforce, el pedido
// lo refleja de inmediato"). Usa la sesión de la CLI sf (alias "poc"); la PoC nunca lee ni guarda el token.
//
//   node demo/segment.mjs <externalId> <ESTRATEGICO|REGULAR>
//   node demo/segment.mjs POC-CUMBRES REGULAR
//   node demo/segment.mjs restore            (todos los clientes vuelven al segmento de data/scenario.json)
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { session, api } from '../infra/salesforce/sf-session.mjs'

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const scenario = JSON.parse(fs.readFileSync(path.join(REPO, 'data', 'scenario.json'), 'utf8'))
const SEGMENTO = { ESTRATEGICO: 'Estratégico', REGULAR: 'Regular' }

const [target, value] = process.argv.slice(2)
const changes = target === 'restore'
  ? scenario.clientes.map(c => [c.externalId, c.segmento])
  : [[target, (value || '').toUpperCase()]]
if (!changes.length || changes.some(([id, seg]) => !id || !SEGMENTO[seg])) {
  console.error('Uso: node demo/segment.mjs <externalId> <ESTRATEGICO|REGULAR> | restore')
  process.exit(2)
}

const s = session()
for (const [externalId, seg] of changes) {
  const known = scenario.clientes.find(c => c.externalId === externalId)
  if (!known) { console.error(`${externalId} no es un cliente del guion`); process.exit(2) }
  await api(s, 'PATCH', `/sobjects/Contact/External_Id__c/${encodeURIComponent(externalId)}`, { Segmento__c: SEGMENTO[seg] })
  console.log(`${externalId.padEnd(16)} ${SEGMENTO[seg].padEnd(11)} ${known.nombre}`)
}
