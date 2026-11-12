import * from bat::BDD
import * from bat::Assertions
---
describe("POST /providers/FAK/products/1/price — method not allowed") in [
  it must 'reject POST with 405 METHOD_NOT_ALLOWED because the resource only supports GET' in [
    POST `$(config.url)/providers/FAK/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: {}
    } assert [
      $.response.status mustEqual 405,
      $.response.body.code mustEqual "METHOD_NOT_ALLOWED"
    ]
  ]
]
