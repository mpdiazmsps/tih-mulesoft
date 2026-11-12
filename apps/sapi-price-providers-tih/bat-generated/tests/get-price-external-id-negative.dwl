import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/FAK/products/-5/price — negative externalId") in [
  it must 'reject a negative externalId with 400 VALIDATION_ERROR' in [
    GET `$(config.url)/providers/FAK/products/-5/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR",
      $.response.body.message mustMatch /.*externalId.*/
    ]
  ]
]
