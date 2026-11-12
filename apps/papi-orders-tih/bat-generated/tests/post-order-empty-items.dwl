import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
---
describe("POST /orders — empty items") in [
  it must 'answer 400 when the order has no lines' in [
    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { customerId: cid, items: [] }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
