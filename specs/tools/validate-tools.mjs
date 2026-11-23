// Validates specs/mcp-online-store/tools.yaml against tools.schema.json, plus the rules a schema cannot say:
// five distinct tools, only request_correction writes (and only through POST /order-requests, with a derived key),
// and no tool approves, rejects or applies anything.
//   npm --prefix specs/tools run validate-tools
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import YAML from 'yaml'
import Ajv from 'ajv'

const SPECS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const file = process.argv[2] || path.join(SPECS, 'mcp-online-store', 'tools.yaml')
const schema = JSON.parse(fs.readFileSync(path.join(SPECS, 'tools', 'tools.schema.json'), 'utf8'))
const doc = YAML.parse(fs.readFileSync(file, 'utf8'))

const errors = []
const ajv = new Ajv({ allErrors: true })
if (!ajv.validate(schema, doc)) for (const e of ajv.errors) errors.push(`schema: ${e.instancePath || '/'} ${e.message}`)

const tools = (doc && doc.tools) || []
const names = tools.map(t => t.name)
if (new Set(names).size !== names.length) errors.push('tools: names must be distinct')
for (const t of tools) {
  if (/approve|reject|apply|retry/i.test(t.name)) errors.push(`${t.name}: no tool approves, rejects or applies`)
  const writes = (t.calls || []).filter(c => c.startsWith('POST'))
  if (t.name === 'request_correction') {
    if (writes.length !== 1 || !/^POST papi-order-requests \/order-requests\s*$/.test(writes[0].split('#')[0])) {
      errors.push('request_correction: its only write is POST papi-order-requests /order-requests')
    }
    if (!t.idempotencyKey || !['{orderId}', '{type}', '{provider}'].every(p => t.idempotencyKey.includes(p))) {
      errors.push('request_correction: idempotencyKey derives from {orderId}, {type} and {provider}')
    }
    if (t.annotations && t.annotations.readOnlyHint !== false) errors.push('request_correction: readOnlyHint must be false')
  } else {
    if (writes.length) errors.push(`${t.name}: a read-only tool cannot POST`)
    if (t.annotations && t.annotations.readOnlyHint !== true) errors.push(`${t.name}: readOnlyHint must be true`)
  }
}

const rel = path.relative(process.cwd(), file)
if (errors.length) {
  console.log(`FAIL  ${rel}`)
  for (const e of errors) console.log('   ' + e)
  process.exit(1)
}
console.log(`OK  ${rel}  (${tools.length} tools: ${names.join(', ')})`)
