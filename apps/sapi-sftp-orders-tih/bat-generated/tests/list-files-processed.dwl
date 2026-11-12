import * from bat::BDD
import * from bat::Assertions

---
describe("GET /files?status=processed — processed list") in [
  it must 'answer 200 with a list of processed files' in [
    GET `$(config.url)/files?status=processed` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      (sizeOf($.response.body.files) >= 0) mustEqual true
    ]
  ]
]
