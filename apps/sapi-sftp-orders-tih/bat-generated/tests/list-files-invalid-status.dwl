import * from bat::BDD
import * from bat::Assertions

---
describe("GET /files — invalid status") in [
  it must 'answer 400 when status is not pending, processed or error' in [
    GET `$(config.url)/files?status=bogus` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
