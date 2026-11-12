import * from bat::BDD
import * from bat::Assertions

var fileName = "bat-" ++ uuid() ++ ".csv"
var csv = [{ item: "c1a2b3c4-d5e6-4789-a012-3456789abc01", qty: 2 }]
---
describe("GET /files — pending list") in [
  it must 'list the file that was just deposited' in [
    PUT `$(config.url)/files/$(fileName)` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "text/csv" },
      body: csv
    } assert [
      $.response.status mustEqual 201
    ],

    GET `$(config.url)/files` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" }
    } assert [
      $.response.status mustEqual 200,
      (($.response.body.files map $.fileName) contains fileName) mustEqual true
    ],

    POST `$(config.url)/files/$(fileName)/move` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "Content-Type": "application/json" },
      body: { target: "processed" }
    } assert [
      $.response.status mustEqual 200
    ]
  ]
]
