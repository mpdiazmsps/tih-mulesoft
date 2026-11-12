import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var oid = uuid()
var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("POST /orders — happy path") in [
  it must 'register a two-unit order with total 2500' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", email: email, phone: phone, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 201
    ],

    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { orderId: oid, customerId: cid, items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 2, price: 1250 }] }
    } assert [
      $.response.status mustEqual 201,
      $.response.body.id mustEqual oid,
      $.response.body.customerId mustEqual cid,
      $.response.body.total mustEqual 2500,
      $.response.body.creationDate mustMatch /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.*/
    ]
  ]
]
