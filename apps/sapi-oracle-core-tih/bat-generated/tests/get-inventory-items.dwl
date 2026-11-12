import * from bat::BDD
import * from bat::Assertions

---
describe("GET /inventory/items — known item") in [
  it must 'return the seeded keyboard' in [
    GET `$(config.url)/inventory/items?ids=c1a2b3c4-d5e6-4789-a012-3456789abc01` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      sizeOf($.response.body.items) mustEqual 1,
      $.response.body.items[0].id mustEqual "c1a2b3c4-d5e6-4789-a012-3456789abc01",
      $.response.body.items[0].name mustEqual "Teclado Mecanico",
      $.response.body.items[0].localPrice mustEqual 1250
    ]
  ]
]
