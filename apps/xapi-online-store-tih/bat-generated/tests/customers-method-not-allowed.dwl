import * from bat::BDD
import * from bat::Assertions

---
describe("GET /customers — method not allowed") in [
  it must 'answer 405 because /customers only accepts POST' in [
    GET `$(config.url)/customers` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 405,
      $.response.body.code mustEqual "METHOD_NOT_ALLOWED"
    ]
  ]
]
