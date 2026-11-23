// Carga en Salesforce los 4 clientes del guion (data/scenario.json) con upsert por External_Id__c.
// Repetirlo no duplica: actualiza los mismos contactos. Escribe data/salesforce-ids.local.json
// ({ "POC-CUMBRES": "003...", ... }), que usa data/tools/build-seeds.mjs para la semilla del ERP.
//
//   node infra/salesforce/seed-contacts.mjs            (org con alias "poc"; otro alias: SF_ORG_ALIAS=...)
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { session, api } from './sf-session.mjs'

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..')
const scenario = JSON.parse(fs.readFileSync(path.join(REPO, 'data', 'scenario.json'), 'utf8'))
const SEGMENTO = { ESTRATEGICO: 'Estratégico', REGULAR: 'Regular' }

const s = session()
const ids = {}
for (const c of scenario.clientes) {
  // Solo calle, ciudad y código postal: si la org tiene listas de estados y países, un estado en texto libre fallaría.
  const record = {
    LastName: c.nombre,
    Email: c.correo,
    Email_Key__c: c.correo.toLowerCase(), // único: bloquea altas simultáneas con el mismo correo (D22)
    Phone: c.telefono,
    Segmento__c: SEGMENTO[c.segmento],
    MailingStreet: c.calle,
    MailingCity: c.ciudad,
    MailingPostalCode: c.codigoPostal
  }
  const r = await api(s, 'PATCH', `/sobjects/Contact/External_Id__c/${encodeURIComponent(c.externalId)}`, record)
  // 201: creado (trae el id); 204: ya existía y se actualizó (se consulta el id).
  let id = r.body && r.body.id
  if (!id) {
    const q = await api(s, 'GET', `/query?q=${encodeURIComponent(`SELECT Id FROM Contact WHERE External_Id__c = '${c.externalId}'`)}`)
    id = q.body.records[0].Id
  }
  ids[c.externalId] = id
  console.log(`${r.status === 201 ? 'creado    ' : 'actualizado'} ${c.externalId.padEnd(16)} ${id}  ${c.nombre}`)
}

const all = await api(s, 'GET', `/query?q=${encodeURIComponent("SELECT COUNT() FROM Contact WHERE External_Id__c LIKE 'POC-%'")}`)
console.log(`Contactos POC-* en Salesforce: ${all.body.totalSize}`)
const out = path.join(REPO, 'data', 'salesforce-ids.local.json')
fs.writeFileSync(out, JSON.stringify(ids, null, 2) + '\n')
console.log(`Ids escritos en ${path.relative(REPO, out)}. Siguiente: node data/tools/build-seeds.mjs y reset-data.`)
