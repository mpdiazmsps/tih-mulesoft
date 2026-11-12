import * from bat::BDD
import * from bat::Assertions

---
describe("GET /inventory/items — invalid ids") in [
  it must 'answer 400 when ids is not a list of UUIDs' in [
    GET `$(config.url)/inventory/items?ids=abc` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
