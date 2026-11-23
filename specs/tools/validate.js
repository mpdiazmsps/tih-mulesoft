// Valida los RAML de la PoC con el parser AMF de MuleSoft (webapi-parser).
// Sin argumentos valida el fragmento poc-common y cada specs/<api>/<api>.raml (los *-tih de la base se ignoran).
// Con argumentos valida solo esos archivos. Un RAML que use exchange_modules/... se resuelve
// contra la carpeta exchange_modules que tenga al lado (por ejemplo, un zip de Exchange descomprimido).
const wap = require('webapi-parser')
const fs = require('fs')
const path = require('path')

const SPECS = path.resolve(__dirname, '..')

function defaultSpecs () {
  const files = ['fragments/poc-common/poc-common.raml']
  for (const dir of fs.readdirSync(SPECS, { withFileTypes: true })) {
    if (!dir.isDirectory() || ['tools', 'fragments'].includes(dir.name) || dir.name.endsWith('-tih')) continue
    const main = path.join(dir.name, dir.name + '.raml')
    if (fs.existsSync(path.join(SPECS, main))) files.push(main)
  }
  return files.map(f => path.join(SPECS, f))
}

async function main () {
  const specs = process.argv.length > 2 ? process.argv.slice(2) : defaultSpecs()
  let failures = 0
  for (const file of specs) {
    // AMF resuelve mal la unidad (C:) en Windows; sin la letra de unidad usa la actual.
    const url = 'file://' + path.resolve(file).replace(/^[A-Za-z]:/, '').replace(/\\/g, '/')
    try {
      const model = await wap.WebApiParser.raml10.parse(url)
      const report = await wap.WebApiParser.raml10.validate(model)
      const results = (report.results || []).map(r => `${r.level}: ${r.message} @ ${r.position && r.position.start ? 'line ' + r.position.start.line : '?'}`)
      const violations = (report.results || []).filter(r => /violation/i.test(String(r.level)))
      const status = report.conforms ? 'OK' : 'FALLO'
      console.log(`${status}  ${path.relative(SPECS, path.resolve(file))}  (resultados: ${results.length}, violaciones: ${violations.length})`)
      results.forEach(r => console.log('      ' + r))
      if (!report.conforms) failures++
    } catch (e) {
      failures++
      console.log(`ERROR ${path.basename(file)}: ${e.message || e}`)
    }
  }
  console.log(`${failures} errores en ${specs.length} archivos`)
  process.exit(failures ? 1 : 0)
}

main()
