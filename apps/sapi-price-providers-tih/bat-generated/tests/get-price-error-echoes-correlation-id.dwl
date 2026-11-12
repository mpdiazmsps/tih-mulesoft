import * from bat::BDD
import * from bat::Assertions
---
describe("GET /providers/ESC/products/99999999/price — correlation id on errors") in [
  it must 'return in correlationId the x-correlation-id sent by the caller' in [
    GET `$(config.url)/providers/ESC/products/99999999/price` with {
      headers: { client_id: config.clientId, client_secret: config.clientSecret, "x-correlation-id": "bat-correlation-0001" }
    } assert [
      $.response.status mustEqual 404,
      $.response.body.correlationId mustEqual "bat-correlation-0001"
    ]
  ]
]
