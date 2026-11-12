import * from bat::BDD
import * from bat::Assertions

var fileName = "bat-" ++ uuid() ++ ".csv"
var csv = [{ item: "c1a2b3c4-d5e6-4789-a012-3456789abc01", qty: 2 }]
---
describe("POST /files/{fileName}/move — to processed") in [
  it must 'move a pending file to processed' in [
    PUT `$(config.url)/files/$(fileName)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "text/csv" },
      body: csv
    } assert [
      $.response.status mustEqual 201
    ],

    POST `$(config.url)/files/$(fileName)/move` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { target: "processed" }
    } assert [
      $.response.status mustEqual 200,
      $.response.body.fileName mustEqual fileName,
      $.response.body.status mustEqual "processed"
    ],

    GET `$(config.url)/files/$(fileName)?status=processed` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      sizeOf($.response.body) mustEqual 1,
      $.response.body[0].item mustEqual "c1a2b3c4-d5e6-4789-a012-3456789abc01",
      ($.response.body[0].qty as String) mustEqual "2"
    ]
  ]
]
