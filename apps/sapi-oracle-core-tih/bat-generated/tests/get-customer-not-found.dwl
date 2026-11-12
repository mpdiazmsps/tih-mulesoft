import * from bat::BDD
import * from bat::Assertions

var missing = uuid()
---
describe("GET /customers/{customerId} — unknown customer") in [
  it must 'answer 404 CUSTOMER_NOT_FOUND' in [
    GET `$(config.url)/customers/$(missing)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.code mustEqual "CUSTOMER_NOT_FOUND",
      $.response.body.retryable mustEqual false
    ]
  ]
]
