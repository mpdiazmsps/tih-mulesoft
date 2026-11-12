import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
---
describe("POST /orders — no client credentials") in [
  it must 'answer 400 when client_id and client_secret are absent' in [
    POST `$(config.url)/orders` with {
      headers: { "Content-Type": "application/json" },
      body: { customerId: cid, items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 1 }] }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
