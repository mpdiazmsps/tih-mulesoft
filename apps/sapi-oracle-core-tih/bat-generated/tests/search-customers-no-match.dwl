import * from bat::BDD
import * from bat::Assertions

var email = "bat-" ++ uuid() ++ "@example.com"
---
describe("GET /customers — no match") in [
  it must 'answer 200 with an empty list' in [
    GET `$(config.url)/customers?email=$(email)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      sizeOf($.response.body.customers) mustEqual 0
    ]
  ]
]
