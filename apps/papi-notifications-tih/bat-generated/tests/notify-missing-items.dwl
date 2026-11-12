import * from bat::BDD
import * from bat::Assertions

var oid = uuid()
var cid = uuid()
---
describe("POST /orders-registered — no items") in [
  it must 'answer 400 when the event has no items' in [
    POST `$(config.url)/orders-registered` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { eventType: "order.registered", orderId: oid, customerId: cid, total: 0, createdAt: "2026-10-07T16:40:00Z" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
