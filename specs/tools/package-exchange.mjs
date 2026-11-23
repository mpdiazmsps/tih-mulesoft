// Empaqueta los contratos de specs/ como zips listos para publicar en Exchange.
//
//   node specs/tools/package-exchange.mjs [--group <orgId>] --version 1.0.0 [--only <asset>] [--common-version <v>] [--bundle]
//
// Por cada asset deja tmp/exchange/<asset>-<version>.zip con:
//   - poc-common: poc-common.raml, types/, traits/ y exchange.json (classifier raml-fragment, main poc-common.raml).
//   - cada API (specs/<api>/): sus archivos, con los `uses` relativos reescritos a
//     exchange_modules/<orgId>/poc-common/<v>/..., y exchange.json (classifier raml) con poc-common como dependencia.
// --bundle (plan B): mete el fragmento dentro del zip de cada API y no declara la dependencia.
// Sin dependencias de npm: el zip se arma con zlib.
import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'
import { fileURLToPath } from 'node:url'

const SPECS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const REPO = path.resolve(SPECS, '..')
const COMMON_DIR = path.join(SPECS, 'fragments', 'poc-common')
const COMMON = 'poc-common'

function args () {
  const a = process.argv.slice(2)
  const o = { bundle: false }
  for (let i = 0; i < a.length; i++) {
    const k = a[i]
    if (k === '--bundle') o.bundle = true
    else if (['--group', '--version', '--only', '--common-version', '--out'].includes(k)) o[k.slice(2)] = a[++i]
    else throw new Error(`Argumento desconocido: ${k}`)
  }
  if (!o.group) {
    // Sin --group, el orgId sale de data/org.local.json (no se versiona; D19).
    const orgFile = path.join(REPO, 'data', 'org.local.json')
    if (fs.existsSync(orgFile)) o.group = JSON.parse(fs.readFileSync(orgFile, 'utf8')).orgId
  }
  if (!o.group || !o.version) throw new Error('Uso: [--group <orgId>] --version <x.y.z> [--only <asset>] [--common-version <v>] [--bundle]. Sin --group se lee data/org.local.json')
  if (!/^\d+\.\d+\.\d+$/.test(o.version)) throw new Error('--version debe ser x.y.z')
  o['common-version'] = o['common-version'] || o.version
  o.out = path.resolve(REPO, o.out || 'tmp/exchange')
  return o
}

// ------------------------------------------------------------------- zip mínimo
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  return c >>> 0
})
function crc32 (buf) {
  let c = 0xffffffff
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}
function zip (entries) { // entries: [{ name, data: Buffer }]
  const locals = []
  const centrals = []
  let offset = 0
  for (const { name, data } of entries) {
    const nameBuf = Buffer.from(name.replace(/\\/g, '/'), 'utf8')
    const comp = zlib.deflateRawSync(data)
    const crc = crc32(data)
    const local = Buffer.alloc(30)
    local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x0800, 6)
    local.writeUInt16LE(8, 8); local.writeUInt32LE(0, 10); local.writeUInt32LE(crc, 14)
    local.writeUInt32LE(comp.length, 18); local.writeUInt32LE(data.length, 22)
    local.writeUInt16LE(nameBuf.length, 26); local.writeUInt16LE(0, 28)
    locals.push(local, nameBuf, comp)
    const central = Buffer.alloc(46)
    central.writeUInt32LE(0x02014b50, 0); central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6)
    central.writeUInt16LE(0x0800, 8); central.writeUInt16LE(8, 10); central.writeUInt32LE(0, 12)
    central.writeUInt32LE(crc, 16); central.writeUInt32LE(comp.length, 20); central.writeUInt32LE(data.length, 24)
    central.writeUInt16LE(nameBuf.length, 28); central.writeUInt32LE(offset, 42)
    centrals.push(central, nameBuf)
    offset += 30 + nameBuf.length + comp.length
  }
  const cd = Buffer.concat(centrals)
  const end = Buffer.alloc(22)
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(entries.length, 8); end.writeUInt16LE(entries.length, 10)
  end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16)
  return Buffer.concat([...locals, cd, end])
}

// ------------------------------------------------------------------- assets
function listFiles (dir, base = dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(d => {
    const p = path.join(dir, d.name)
    return d.isDirectory() ? listFiles(p, base) : [path.relative(base, p)]
  })
}

function apiAssets () {
  return fs.readdirSync(SPECS, { withFileTypes: true })
    .filter(d => d.isDirectory() && !['tools', 'fragments'].includes(d.name) && !d.name.endsWith('-tih'))
    .filter(d => fs.existsSync(path.join(SPECS, d.name, d.name + '.raml')))
    .map(d => d.name)
}

function exchangeJson ({ assetId, group, version, classifier, main, dependencies }) {
  return Buffer.from(JSON.stringify({
    main,
    name: assetId,
    classifier,
    tags: [],
    groupId: group,
    assetId,
    version,
    ...(classifier === 'raml' ? { apiVersion: 'v1' } : {}),
    dependencies,
    originalFormatVersion: '1.0'
  }, null, 2) + '\n')
}

// Reescribe `../fragments/poc-common/<archivo>.raml` (con cualquier cantidad de ../) al destino indicado.
function rewriteUses (text, target) {
  return text.replace(/((?:\.\.\/)+)fragments\/poc-common\/([\w.-]+\.raml)/g, (_, _up, file) => `${target}/${file}`)
}

function packCommon (o) {
  const files = listFiles(COMMON_DIR).filter(f => f.endsWith('.raml'))
  const entries = files.map(f => ({ name: f, data: fs.readFileSync(path.join(COMMON_DIR, f)) }))
  entries.push({ name: 'exchange.json', data: exchangeJson({ assetId: COMMON, group: o.group, version: o['common-version'], classifier: 'raml-fragment', main: 'poc-common.raml', dependencies: [] }) })
  return write(o, COMMON, o['common-version'], entries)
}

function packApi (o, api) {
  const dir = path.join(SPECS, api)
  const target = o.bundle ? COMMON : `exchange_modules/${o.group}/${COMMON}/${o['common-version']}`
  const entries = listFiles(dir).map(f => {
    let data = fs.readFileSync(path.join(dir, f))
    if (f.endsWith('.raml')) {
      const depth = f.split(path.sep).length - 1 // archivos en subcarpetas necesitan ../ hasta la raíz del zip
      data = Buffer.from(rewriteUses(data.toString('utf8'), '../'.repeat(depth) + target))
    }
    return { name: f, data }
  })
  const leftovers = entries.filter(e => e.name.endsWith('.raml') && /fragments\//.test(e.data.toString('utf8')))
  if (leftovers.length) throw new Error(`${api}: quedaron rutas a fragments/ sin reescribir en ${leftovers.map(e => e.name).join(', ')}`)
  if (o.bundle) {
    for (const f of listFiles(COMMON_DIR).filter(x => x.endsWith('.raml'))) {
      entries.push({ name: `${COMMON}/${f}`, data: fs.readFileSync(path.join(COMMON_DIR, f)) })
    }
  }
  const dependencies = o.bundle ? [] : [{ groupId: o.group, assetId: COMMON, version: o['common-version'] }]
  entries.push({ name: 'exchange.json', data: exchangeJson({ assetId: api, group: o.group, version: o.version, classifier: 'raml', main: `${api}.raml`, dependencies }) })
  return write(o, api, o.version, entries)
}

function write (o, asset, version, entries) {
  fs.mkdirSync(o.out, { recursive: true })
  const file = path.join(o.out, `${asset}-${version}.zip`)
  fs.writeFileSync(file, zip(entries))
  console.log(`${path.relative(REPO, file)}  (${entries.map(e => e.name).join(', ')})`)
  return file
}

function main () {
  const o = args()
  const all = [COMMON, ...apiAssets()]
  const selected = o.only ? all.filter(a => a === o.only) : all
  if (!selected.length) throw new Error(`No existe el asset ${o.only}. Disponibles: ${all.join(', ')}`)
  for (const asset of selected) asset === COMMON ? packCommon(o) : packApi(o, asset)
}

try { main() } catch (e) { console.error(`ERROR: ${e.message}`); process.exit(1) }
