// Llamadas a la API REST de Salesforce a través de la CLI `sf` (sesión abierta con `sf org login web --alias poc`).
// Se usa `sf api request rest`, que autentica por dentro: la PoC nunca lee ni guarda el token.
// (Las versiones recientes de la CLI ya no entregan el token de sesión en `sf org display`.)
// En Windows el instalador deja `sf` en C:\Program Files\sf\bin sin agregarlo siempre al PATH: si no está, se agrega
// para este proceso (los execSync de abajo lo heredan).
import fs from 'node:fs'
import path from 'node:path'
import { execSync } from 'node:child_process'

export const API = 'v62.0'

if (process.platform === 'win32') {
  const dir = path.join(process.env.ProgramFiles || 'C:\\Program Files', 'sf', 'bin')
  const key = Object.keys(process.env).find(k => k.toLowerCase() === 'path') || 'Path'
  const parts = (process.env[key] || '').split(path.delimiter)
  if (fs.existsSync(dir) && !parts.some(p => p.toLowerCase() === dir.toLowerCase())) process.env[key] = [...parts, dir].join(path.delimiter)
}

export function session (alias = process.env.SF_ORG_ALIAS || 'poc') {
  let out
  try {
    out = execSync(`sf org display --target-org ${alias} --json`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], shell: true })
  } catch (e) {
    const text = String(e.stdout || '') + String(e.stderr || '') + String(e.message || '')
    if (/not recognized|no se reconoce|not found|ENOENT/i.test(text) && !/"status"/.test(text)) {
      throw new Error('No se encontró la CLI sf. Instálala (https://developer.salesforce.com/tools/salesforcecli) o agrégala al PATH.')
    }
    out = String(e.stdout || '')   // sf responde JSON con status distinto de 0 cuando la org no está conectada
  }
  let connected = false
  try { connected = JSON.parse(out).result?.connectedStatus === 'Connected' } catch { }
  if (!connected) throw new Error(`La org "${alias}" no tiene una sesión activa en la CLI sf. Entra con: sf org login web --alias ${alias}`)
  return { alias }
}

export async function api (s, method, path, body) {
  // DELETE de un registro: `sf api request rest` falla sin cuerpo ("No 'mode' found in 'body' entry"),
  // así que se usa el comando propio de la CLI.
  const del = method === 'DELETE' && path.match(/^\/sobjects\/(\w+)\/(\w{15,18})$/)
  if (del) {
    try {
      execSync(`sf data delete record --sobject ${del[1]} --record-id ${del[2]} --target-org ${s.alias} --json`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], shell: true })
      return { status: 204, body: null }
    } catch (e) {
      const err = new Error(`DELETE ${path}: ${String(e.stdout || e.stderr || e.message).trim().slice(0, 300)}`)
      err.status = 400
      throw err
    }
  }
  const url = `/services/data/${API}${path}`
  const cmd = `sf api request rest "${url}" --target-org ${s.alias} --method ${method} --include` +
    (body !== undefined ? ' --header "Content-Type:application/json" --body -'
      : method === 'GET' ? '' : ' --body ""')   // DELETE y similares: la CLI exige un cuerpo explícito (vacío)
  let out
  try {
    out = execSync(cmd, { encoding: 'utf8', input: body === undefined ? '' : JSON.stringify(body), stdio: ['pipe', 'pipe', 'pipe'], shell: true })
  } catch (e) {
    out = String(e.stdout || '')
    if (!/^HTTP\/\S+ \d{3}/.test(out)) throw new Error(`${method} ${path}: la CLI sf falló: ${String(e.stderr || e.message).trim()}`)
  }
  const status = Number(out.match(/^HTTP\/\S+ (\d{3})/)[1])
  // Con --include la CLI imprime la línea de estado y los encabezados, y después el cuerpo (que empieza con { o [).
  const start = out.search(/^[[{]/m)
  const text = start >= 0 ? out.slice(start).trim() : ''
  let json = null
  try { json = text ? JSON.parse(text) : null } catch { json = text }
  if (status >= 400) {
    const err = new Error(`${method} ${path} → ${status}: ${JSON.stringify(json)}`)
    err.status = status; err.body = json
    throw err
  }
  return { status, body: json }
}
