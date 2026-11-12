import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var email = "bat-" ++ uuid() ++ "@example.com"
---
describe("POST /customers — missing name") in [
  it must 'reject a customer without name with 400' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, email: email, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
