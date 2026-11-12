# Mock de Borland OrderService (SoapUI)

**Archivo para importar:** `OrderService-Borland-Mock-soapui-project.xml`

1. SoapUI → **File → Import Project** → elige ese archivo. (No sirve importar los XML de `responses/` sueltos: SoapUI espera un proyecto completo.)
2. En el proyecto `OrderService-Borland-Mock-2`, abre el MockService **OrderServiceSoap MockService** y pulsa **Start**.
3. Queda en `http://localhost:8088/mockOrderServiceSoap` (WSDL en `...?WSDL`).

Operaciones simuladas (SOAP 1.1):
- `GetArticleById`: ids 1 al 5 devuelven su artículo; cualquier otro id devuelve `<GetArticleByIdResponse/>` vacío (respuesta `desconocido`). Dispatch XPATH sobre `ArticleId` (sin scripts; el despacho por Groovy daba NullPointerException en el SoapUI de escritorio).
- `SearchArticles`: devuelve los 5 artículos sin filtrar.

Catálogo (el del propio mock original): 1 Lord of the Rings - Fellowship of the Ring 34.99 · 2 Jurassic Park 14.99 · 3 The Breakfast Club 5.97 · 4 Gladiator II 11.95 · 5 Toy Story 4 24.90.

Cambios respecto al proyecto original (`Downloads\OrderService-soapui-project_For-Mocking.xml`, que no se tocó):
- Se agregó `GetArticleById` al mock SOAP 1.1.
- El host del mock pasó de `jhernandez8fs3` a `localhost`, y la ruta del WSDL, de la carpeta de otro equipo a `src/main/resources/wsdl/borland-orderservice.wsdl`.
- En `SearchArticles`, el quinto artículo (Toy Story 4) tenía el id 4 repetido; ahora es 5.

`responses/` contiene las mismas respuestas en archivos sueltos, por si prefieres copiarlas a mano. `dispatch-GetArticleById.groovy` es el script anterior y ya no se usa.
