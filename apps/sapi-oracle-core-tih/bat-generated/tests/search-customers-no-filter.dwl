import * from bat::BDD
import * from bat::Assertions

---
describe("GET /customers — no filter") in [
  it must 'answer 400 when neither email nor phone is sent' in [
    GET `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
