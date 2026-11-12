import * from bat::BDD
import * from bat::Assertions

---
describe("POST /orders/process — manual trigger") in [
  it must 'accept the processing request with 202 ACCEPTED' in [
    POST `$(config.url)/orders/process` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 202,
      $.response.body.status mustEqual "ACCEPTED"
    ]
  ]
]
