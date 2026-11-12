import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("GET /customers — search by email") in [
  it must 'find exactly the customer registered with that email' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", email: email, phone: phone, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 201
    ],

    GET `$(config.url)/customers?email=$(email)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      sizeOf($.response.body.customers) mustEqual 1,
      $.response.body.customers[0].id mustEqual cid
    ]
  ]
]
