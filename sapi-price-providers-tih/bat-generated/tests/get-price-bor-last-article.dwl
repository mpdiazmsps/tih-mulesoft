import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/BOR/products/5/price — last catalog article") in [
  it must 'return Borland article 5 (Toy Story 4), proving the id reaches the SOAP service' in [
    GET `$(config.url)/providers/BOR/products/5/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 200,
      $.response.body.externalId mustEqual 5,
      $.response.body.providerAbv mustEqual "BOR",
      $.response.body.name mustEqual "Toy Story 4",
      $.response.body.price mustEqual 24.9,
      $.response.body.currency mustEqual "USD"
    ]
  ]
]
