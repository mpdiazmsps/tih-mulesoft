import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/FAK/products/1/price — missing client_secret") in [
  it must 'reject a request with client_id but without client_secret with 400 VALIDATION_ERROR' in [
    GET `$(config.url)/providers/FAK/products/1/price` with {
      headers: { client_id: config.clientId }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR",
      $.response.body.message mustMatch /.*client_secret.*/
    ]
  ]
]
