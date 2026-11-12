import * from bat::BDD
import * from bat::Assertions

---
describe("POST /orders — invalid customer id") in [
  it must 'answer 400 when customerId is not a UUID' in [
    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { customerId: "no-es-uuid", items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 1 }] }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
