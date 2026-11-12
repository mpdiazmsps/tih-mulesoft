import * from bat::BDD
import * from bat::Assertions
import * from bat::Mutable

var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
var context = HashMap()
---
describe("POST /orders — happy path") in [
  it must 'receive the order and deposit its CSV' in [
    POST `$(config.customersUrl)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", phone: phone }
    } assert [
      $.response.status mustEqual 201
    ] execute [
      context.set("customerId", $.response.body.customerId)
    ],

    POST `$(config.url)/orders` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { customerId: context.get("customerId"), items: [{ itemId: "c1a2b3c4-d5e6-4789-a012-3456789abc01", quantity: 1 }] }
    } assert [
      $.response.status mustEqual 201,
      $.response.body.status mustEqual "RECEIVED",
      $.response.body.customerId mustEqual context.get("customerId"),
      $.response.body.orderId mustMatch /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/,
      $.response.body.fileName mustMatch /.*\.csv/
    ]
  ]
]
