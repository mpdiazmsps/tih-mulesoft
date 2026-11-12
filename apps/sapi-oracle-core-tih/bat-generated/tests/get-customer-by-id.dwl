import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("GET /customers/{customerId} — existing customer") in [
  it must 'return the customer that was just registered' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", email: email, phone: phone, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 201
    ],

    GET `$(config.url)/customers/$(cid)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      $.response.body.id mustEqual cid,
      $.response.body.name mustEqual "Bat",
      $.response.body.email mustEqual email
    ]
  ]
]
