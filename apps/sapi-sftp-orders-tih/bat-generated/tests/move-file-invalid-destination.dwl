import * from bat::BDD
import * from bat::Assertions

var fileName = "bat-" ++ uuid() ++ ".csv"
var csv = [{ item: "c1a2b3c4-d5e6-4789-a012-3456789abc01", qty: 2 }]
---
describe("POST /files/{fileName}/move — invalid target") in [
  it must 'answer 400 when target is not processed or error' in [
    PUT `$(config.url)/files/$(fileName)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "text/csv" },
      body: csv
    } assert [
      $.response.status mustEqual 201
    ],

    POST `$(config.url)/files/$(fileName)/move` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { target: "nowhere" }
    } assert [
      $.response.status mustEqual 400,
      $.response.body.code mustEqual "VALIDATION_ERROR"
    ],

    POST `$(config.url)/files/$(fileName)/move` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { target: "processed" }
    } assert [
      $.response.status mustEqual 200
    ]
  ]
]
