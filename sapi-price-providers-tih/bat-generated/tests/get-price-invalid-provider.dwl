import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/XXX/products/1/price — invalid provider") in [
  it must 'reject a provider outside FAK, ESC and BOR with 400 VALIDATION_ERROR' in [
    GET `$(config.url)/providers/XXX/products/1/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR",
      $.response.body.message mustMatch /.*providerAbv.*/
    ]
  ]
]
