import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/FAK/products/1/price — happy path") in [
  it must 'return the canonical Price for Fakestore product 1' in [
    GET `$(config.url)/providers/FAK/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 200,
      $.response.headers."Content-Type" mustMatch /application\/json.*/,
      $.response.body.externalId mustEqual 1,
      $.response.body.providerAbv mustEqual "FAK",
      $.response.body.name mustMatch /.+/,
      $.response.body.price mustEqual 109.95,
      $.response.body.currency mustEqual "USD"
    ]
  ]
]
