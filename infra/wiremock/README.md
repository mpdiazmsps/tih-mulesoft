# WireMock: proveedores simulados

Un solo WireMock (`poc-wiremock`, puerto 8089) atiende a los tres proveedores:

| Proveedor | Estilo | Ruta |
|---|---|---|
| A (`FAK`) | REST como Fakestore | `GET /proveedor-a/products/{id}` |
| B (`ESC`) | REST como Escuelajs | `GET /proveedor-b/api/v1/products/{id}` |
| C (`BOR`) | SOAP 1.1 `GetArticleById` | `POST /proveedor-c/OrderService` |

Los mappings (`mappings/`) se generan con `node data/tools/build-seeds.mjs` desde `data/scenario.json` y no se versionan.
Todos los precios vienen en MXN. SKU-300 en C (ArticleId 5) corta la conexión, como un proveedor que no responde.
