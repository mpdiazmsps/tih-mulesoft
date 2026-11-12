import * from bat::BDD
import * from bat::Assertions

---
describe("POST /customers — no contact data") in [
  it must 'answer 400 when email and phone are both missing' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
