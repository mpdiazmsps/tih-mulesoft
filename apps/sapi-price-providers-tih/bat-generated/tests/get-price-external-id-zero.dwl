import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/FAK/products/0/price — externalId below the minimum") in [
  it must 'reject externalId 0 with 400 VALIDATION_ERROR because the minimum is 1' in [
    GET `$(config.url)/providers/FAK/products/0/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR",
      $.response.body.message mustMatch /.*externalId.*/
    ]
  ]
]
