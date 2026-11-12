import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/ESC/products/1/price — happy path") in [
  it must 'return the canonical Price for Escuelajs product 1 (structure only, the data is mutable)' in [
    GET `$(config.url)/providers/ESC/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 200,
      $.response.headers."Content-Type" mustMatch /application\/json.*/,
      $.response.body.externalId mustEqual 1,
      $.response.body.providerAbv mustEqual "ESC",
      $.response.body.name mustMatch /.+/,
      $.response.body.currency mustEqual "USD"
    ]
  ]
]
