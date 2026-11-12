import * from bat::BDD
import * from bat::Assertions

var email = "bat-" ++ uuid() ++ "@example.com"
var phone = "+52155" ++ ((floor(random() * 9000000) + 1000000) as String)
---
describe("POST /customers — happy path") in [
  it must 'register a customer through the experience API' in [
    POST `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { name: "Bat", email: email, phone: phone }
    } assert [
      $.response.status mustEqual 201,
      $.response.body.customerId mustMatch /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/,
      $.response.body.creationDate mustMatch /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.*/
    ]
  ]
]
