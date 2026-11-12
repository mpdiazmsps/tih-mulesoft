import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/FAK/products/1/price — missing client headers") in [
  it must 'reject a request without client_id and client_secret with 400 VALIDATION_ERROR (locally APIkit answers, the 401 comes from the API Manager policy)' in [
    GET `$(config.url)/providers/FAK/products/1/price` with {
      headers: { Accept: "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR",
      $.response.body.message mustMatch /.*Required header.*/
    ]
  ]
]
