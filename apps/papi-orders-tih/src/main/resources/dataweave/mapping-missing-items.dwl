%dw 2.0
output application/java
// Ids del pedido que Oracle no devolvió (INVENTORY no los tiene).
---
(vars.orderLines.lines map $.itemId) -- ((payload.items default []) map lower($.id))
