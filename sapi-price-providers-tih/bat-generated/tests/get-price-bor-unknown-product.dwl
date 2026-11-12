import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/BOR/products/99/price — unknown product") in [
  it must 'return 404 PRODUCT_NOT_FOUND when Borland answers without GetArticleByIdResult' in [
    GET `$(config.url)/providers/BOR/products/99/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.code mustEqual "PRODUCT_NOT_FOUND",
      $.response.body.retryable mustEqual false
    ]
  ]
]
