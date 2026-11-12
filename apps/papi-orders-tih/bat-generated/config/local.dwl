%dw 2.0
---
{
  url: 'http://localhost:8083/api/v1/orders-management',
  env: 'local',
  token: 'Bearer not-used',
  clientId: 'bat-client-id',
  clientSecret: 'bat-client-secret',
  customersUrl: 'http://localhost:8082/api/v1/customers-management'
}
