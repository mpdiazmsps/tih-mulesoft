import * from bat::BDD
import * from bat::Assertions

var missing = uuid()
---
describe("GET /customers/{customerId} — no client credentials") in [
  it must 'answer 400 when client_id and client_secret are absent' in [
    GET `$(config.url)/customers/$(missing)` with {
      headers: { "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
