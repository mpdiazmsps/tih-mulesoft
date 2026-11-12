import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/BOR/products/1/price — happy path") in [
  it must 'return the canonical Price for Borland article 1 (SOAP service, SoapUI mock locally)' in [
    GET `$(config.url)/providers/BOR/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 200,
      $.response.headers."Content-Type" mustMatch /application\/json.*/,
      $.response.body.externalId mustEqual 1,
      $.response.body.providerAbv mustEqual "BOR",
      $.response.body.name mustEqual "Lord of the Rings - Fellowship of the Ring",
      $.response.body.price mustEqual 34.99,
      $.response.body.currency mustEqual "USD"
    ]
  ]
]
