import * from bat::BDD
import * from bat::Assertions

var csv = [{ item: "c1a2b3c4-d5e6-4789-a012-3456789abc01", qty: 2 }]
---
describe("PUT /files/{fileName} — invalid name") in [
  it must 'answer 400 for a name that is not a .csv' in [
    PUT `$(config.url)/files/bat-invalid.txt` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "text/csv" },
      body: csv
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ]
  ]
]
