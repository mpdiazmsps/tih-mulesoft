import * from bat::BDD
import * from bat::Assertions

var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
var phone2 = "+52156" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("POST /customers — duplicate email") in [
  it must 'answer 409 CUSTOMER_ALREADY_EXISTS for a repeated email' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", lastName: "Test", email: email, phone: phone }
    } assert [
      $.response.status mustEqual 201
    ],

    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", lastName: "Test", email: email, phone: phone2 }
    } assert [
      $.response.status mustEqual 409,
      $.response.body.code mustEqual "CUSTOMER_ALREADY_EXISTS"
    ]
  ]
]
