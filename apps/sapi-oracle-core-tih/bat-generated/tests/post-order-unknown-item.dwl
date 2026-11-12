import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var oid = uuid()
var missing = uuid()
var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("POST /orders — unknown inventory item") in [
  it must 'answer 400 VALIDATION_ERROR when an item is not in INVENTORY' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", email: email, phone: phone, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 201
    ],

    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { orderId: oid, customerId: cid, items: [{ itemId: missing, quantity: 1, price: 10 }] }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
