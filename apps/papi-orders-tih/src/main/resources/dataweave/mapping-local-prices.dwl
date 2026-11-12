%dw 2.0
output application/java
// Mapa itemId -> precio para los artículos con precio de tienda (localPrice > 0).
---
((payload.items default []) filter ($.localPrice > 0)) reduce ((item, acc = {}) -> acc ++ { (lower(item.id)): item.localPrice })
