import * from bat::BDD
import * from bat::Assertions

var oid = uuid()
var cid = uuid()
---
describe("POST /orders-registered — no client credentials") in [
  it must 'answer 400 when client_id and client_secret are absent' in [
    POST `$(config.url)/orders-registered` with {
      headers: { "Content-Type": "application/json" },
      body: { eventType: "order.registered", orderId: oid, customerId: cid, items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 2, price: 1250 }], total: 2500, createdAt: "2026-10-07T16:40:00Z" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
