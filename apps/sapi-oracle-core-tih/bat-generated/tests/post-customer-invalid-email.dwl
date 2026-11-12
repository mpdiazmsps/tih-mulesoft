import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
---
describe("POST /customers — invalid email") in [
  it must 'reject a malformed email with 400' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", email: "no-es-un-correo", creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
