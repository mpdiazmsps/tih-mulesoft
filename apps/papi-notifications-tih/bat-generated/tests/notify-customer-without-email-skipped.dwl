import * from bat::BDD
import * from bat::Assertions
import * from bat::Mutable

var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
var oid = uuid()
var context = HashMap()
---
describe("POST /orders-registered — customer without email") in [
  it must 'skip the email and answer 200 SKIPPED_NO_EMAIL' in [
    POST `$(config.customersUrl)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", phone: phone }
    } assert [
      $.response.status mustEqual 201
    ] execute [
      context.set("customerId", $.response.body.customerId)
    ],

    POST `$(config.url)/orders-registered` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { eventType: "order.registered", orderId: oid, customerId: context.get("customerId"), items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 2, price: 1250 }], total: 2500, createdAt: "2026-10-07T16:40:00Z" }
    } assert [
      $.response.status mustEqual 200,
      $.response.body.status mustEqual "SKIPPED_NO_EMAIL",
      $.response.body.orderId mustEqual oid
    ]
  ]
]
