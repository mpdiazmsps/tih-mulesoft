import * from bat::BDD
import * from bat::Assertions

var fileName = "bat-" ++ uuid() ++ ".csv"
var csv = [{ item: "c1a2b3c4-d5e6-4789-a012-3456789abc01", qty: 2 }]
---
describe("GET /files/{fileName} — pending file") in [
  it must 'return the CSV exactly as it was deposited' in [
    PUT `$(config.url)/files/$(fileName)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "text/csv" },
      body: csv
    } assert [
      $.response.status mustEqual 201
    ],

    GET `$(config.url)/files/$(fileName)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      $.response.headers."Content-Type" mustMatch /text\/csv.*/,
      sizeOf($.response.body) mustEqual 1,
      $.response.body[0].item mustEqual "c1a2b3c4-d5e6-4789-a012-3456789abc01",
      ($.response.body[0].qty as String) mustEqual "2"
    ],

    POST `$(config.url)/files/$(fileName)/move` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { target: "processed" }
    } assert [
      $.response.status mustEqual 200
    ]
  ]
]
