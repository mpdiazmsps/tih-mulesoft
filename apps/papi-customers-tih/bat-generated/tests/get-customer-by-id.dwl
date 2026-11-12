import * from bat::BDD
import * from bat::Assertions
import * from bat::Mutable

var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
var context = HashMap()
---
describe("GET /customers/{customerId} — existing customer") in [
  it must 'return the customer that was just registered' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", lastName: "Test", email: email, phone: phone }
    } assert [
      $.response.status mustEqual 201
    ] execute [
      context.set("customerId", $.response.body.customerId)
    ],

    GET `$(config.url)/customers/$(context.get("customerId"))` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      $.response.body.id mustEqual context.get("customerId"),
      $.response.body.name mustEqual "Bat",
      $.response.body.email mustEqual email
    ]
  ]
]
