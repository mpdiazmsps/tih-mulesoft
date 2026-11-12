import * from bat::BDD
import * from bat::Assertions

var cid = uuid()
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("POST /customers — phone only") in [
  it must 'register a customer that has a phone but no email' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { id: cid, name: "Bat", lastName: "Test", phone: phone, creationDate: "2026-10-07T16:30:00Z" }
    } assert [
      $.response.status mustEqual 201,
      $.response.body.id mustEqual cid
    ]
  ]
]
