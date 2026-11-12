import * from bat::BDD
import * from bat::Assertions

var missing = uuid()
---
describe("GET /orders/{orderId} — unknown order") in [
  it must 'answer 404 ORDER_NOT_FOUND' in [
    GET `$(config.url)/orders/$(missing)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.code mustEqual "ORDER_NOT_FOUND"
    ]
  ]
]
