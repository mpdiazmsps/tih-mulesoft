import * from bat::BDD
import * from bat::Assertions
import * from bat::Mutable
var context = HashMap()
---
describe("GET /providers/FAK/products/1/price — idempotent") in [
  it must 'return the same price when the same product is requested twice' in [
    GET `$(config.url)/providers/FAK/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 200
    ] execute [
      context.set("firstPrice", $.response.body.price)
    ],

    GET `$(config.url)/providers/FAK/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 200,
      $.response.body.price mustEqual context.get("firstPrice")
    ]
  ]
]
