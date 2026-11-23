// Retira de Salesforce lo que creó la PoC (D20). Lo llama infra/scripts/teardown; también se puede correr solo.
//   1. Borra los contactos con External_Id__c LIKE 'POC-%' (y los contactos de prueba con correo *.ejemplo.mx).
//   2. Desactiva la regla de duplicados y después la de coincidencia (destructive/deactivate-1-duplicate y -2-matching).
//   3. Borra la duplicate rule, la matching rule, los dos campos de Contact y el permission set (destructiveChangesPost.xml).
// La aplicación conectada no se borra por script: se quita a mano en Setup.
//
//   node infra/salesforce/teardown-salesforce.mjs      (org con alias "poc"; otro alias: SF_ORG_ALIAS=...)
import { execSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { session, api } from './sf-session.mjs'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const s = session()

// 1. Contactos
const q = await api(s, 'GET', `/query?q=${encodeURIComponent("SELECT Id, External_Id__c FROM Contact WHERE External_Id__c LIKE 'POC-%' OR Email LIKE '%.ejemplo.mx'")}`)
for (const r of q.body.records) {
  await api(s, 'DELETE', `/sobjects/Contact/${r.Id}`)
  console.log(`contacto borrado: ${r.External_Id__c || '(prueba)'} ${r.Id}`)
}
console.log(`Contactos borrados: ${q.body.records.length}`)

// 2 y 3. Metadatos (con la CLI sf, desde el proyecto infra/salesforce)
const sf = cmd => execSync(cmd, { cwd: HERE, stdio: 'inherit', shell: true })
// Salesforce no deja desactivar la matching rule mientras la duplicate rule que la usa siga activa,
// ni siquiera en el mismo despliegue: se desactivan en dos pasos.
sf(`sf project deploy start --source-dir destructive/deactivate-1-duplicate --target-org ${s.alias} --wait 10`)
sf(`sf project deploy start --source-dir destructive/deactivate-2-matching --target-org ${s.alias} --wait 10`)
// Un permission set asignado no se puede borrar: primero se quitan sus asignaciones.
const psa = await api(s, 'GET', `/query?q=${encodeURIComponent("SELECT Id FROM PermissionSetAssignment WHERE PermissionSet.Name = 'POC_Integracion'")}`)
for (const r of psa.body.records) await api(s, 'DELETE', `/sobjects/PermissionSetAssignment/${r.Id}`)
console.log(`Asignaciones de POC_Integracion quitadas: ${psa.body.records.length}`)
sf(`sf project deploy start --manifest destructive/package.xml --post-destructive-changes destructive/destructiveChangesPost.xml --target-org ${s.alias} --wait 10`)
console.log('Metadatos de la PoC retirados de Salesforce.')
