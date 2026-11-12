import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
var phone2 = "+52156" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("POST /customers — duplicate email") in [
  it must 'reject a second customer with the same email with 409 CUSTOMER_ALREADY_EXISTS' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", email: email, phone: phone, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 201
    ],

    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: uuid(), name: "Bat", email: email, phone: phone2, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 409,
      $.response.body.code mustEqual "CUSTOMER_ALREADY_EXISTS"
    ]
  ]
]
