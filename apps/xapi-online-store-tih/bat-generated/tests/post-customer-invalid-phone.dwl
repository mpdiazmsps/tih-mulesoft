import * from bat::BDD
import * from bat::Assertions

---
describe("POST /customers — invalid phone") in [
  it must 'answer 400 for a malformed phone' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", phone: "abc" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
