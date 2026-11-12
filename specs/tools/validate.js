const wap = require('webapi-parser')
const path = require('path')
const { pathToFileURL } = require('url')

const specs = process.argv.slice(2)

async function main () {
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
      console.log(`${status}  ${path.basename(file)}  (resultados: ${results.length}, violaciones: ${violations.length})`)
      results.forEach(r => console.log('      ' + r))
      if (!report.conforms) failures++
    } catch (e) {
      failures++
      console.log(`ERROR ${path.basename(file)}: ${e.message || e}`)
    }
  }
  process.exit(failures ? 1 : 0)
}

main()
