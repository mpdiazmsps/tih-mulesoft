import * from bat::BDD
import * from bat::Assertions

var email = "bat-" ++ uuid() ++ "@example.com"
---
describe("POST /customers — no client credentials") in [
  it must 'answer 400 when client_id and client_secret are absent' in [
    POST `$(config.url)/customers` with {
      headers: { "Content-Type": "application/json" },
      body: { name: "Bat", lastName: "Test", email: email }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
