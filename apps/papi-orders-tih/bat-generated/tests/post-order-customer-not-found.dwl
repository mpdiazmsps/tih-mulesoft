import * from bat::BDD
import * from bat::Assertions

var missing = uuid()
---
describe("POST /orders — unknown customer") in [
  it must 'answer 404 CUSTOMER_NOT_FOUND' in [
    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { customerId: missing, items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 1 }] }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.code mustEqual "CUSTOMER_NOT_FOUND"
    ]
  ]
]
