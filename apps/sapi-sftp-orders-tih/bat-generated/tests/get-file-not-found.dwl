import * from bat::BDD
import * from bat::Assertions

var fileName = "bat-" ++ uuid() ++ ".csv"
var csv = [{ item: "c1a2b3c4-d5e6-4789-a012-3456789abc01", qty: 2 }]
---
describe("GET /files/{fileName} — unknown file") in [
  it must 'answer 404 FILE_NOT_FOUND' in [
    GET `$(config.url)/files/$(fileName)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.code mustEqual "FILE_NOT_FOUND"
    ]
  ]
]
