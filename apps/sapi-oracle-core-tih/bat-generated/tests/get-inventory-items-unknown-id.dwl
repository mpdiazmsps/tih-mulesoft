import * from bat::BDD
import * from bat::Assertions

var missing = uuid()
---
describe("GET /inventory/items — unknown id") in [
  it must 'answer 200 with an empty list' in [
    GET `$(config.url)/inventory/items?ids=$(missing)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      sizeOf($.response.body.items) mustEqual 0
    ]
  ]
]
