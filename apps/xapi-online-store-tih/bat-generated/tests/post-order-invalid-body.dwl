import * from bat::BDD
import * from bat::Assertions

---
describe("POST /orders — invalid body") in [
  it must 'answer 400 when the body does not match the contract' in [
    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { foo: "bar" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
