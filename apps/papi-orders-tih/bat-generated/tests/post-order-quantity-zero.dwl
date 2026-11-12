import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
---
describe("POST /orders — quantity zero") in [
  it must 'answer 400 when a line has quantity 0' in [
    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { customerId: cid, items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 0 }] }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
