import * from bat::BDD
import * from bat::Assertions

---
describe("GET /files — no client credentials") in [
  it must 'answer 400 when client_id and client_secret are absent' in [
    GET `$(config.url)/files` with {
      headers: { "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
