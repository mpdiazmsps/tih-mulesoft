%dw 2.0
output application/java
// customerId_orderId.csv -> { customerId, orderId }, o null si el nombre no cumple el formato.
var parts = vars.fileName scan /^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})_([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\.csv$/
---
if (isEmpty(parts)) null
else { customerId: lower(parts[0][1]), orderId: lower(parts[0][2]) }
