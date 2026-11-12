import * from bat::BDD
import * from bat::Assertions

---
describe("GET /customers/{customerId} — invalid uuid") in [
  it must 'answer 400 for an id that is not a UUID' in [
    GET `$(config.url)/customers/not-a-uuid` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
