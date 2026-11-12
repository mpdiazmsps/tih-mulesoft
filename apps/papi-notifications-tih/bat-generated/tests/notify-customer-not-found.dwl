import * from bat::BDD
import * from bat::Assertions

var oid = uuid()
var missing = uuid()
---
describe("POST /orders-registered — unknown customer") in [
  it must 'answer 404 CUSTOMER_NOT_FOUND' in [
    POST `$(config.url)/orders-registered` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { eventType: "order.registered", orderId: oid, customerId: missing, items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 2, price: 1250 }], total: 2500, createdAt: "2026-10-07T16:40:00Z" }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.code mustEqual "CUSTOMER_NOT_FOUND"
    ]
  ]
]
