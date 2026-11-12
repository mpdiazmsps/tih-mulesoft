import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/FAK/products/abc/price — externalId not an integer") in [
  it must 'reject a non numeric externalId with 400 VALIDATION_ERROR' in [
    GET `$(config.url)/providers/FAK/products/abc/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR",
      $.response.body.message mustMatch /.*externalId.*/
    ]
  ]
]
