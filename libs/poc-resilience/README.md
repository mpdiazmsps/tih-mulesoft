# poc-resilience: biblioteca de resiliencia

Que una fuente lenta o caída no tumbe la respuesta, con el mismo comportamiento en todas las piezas (sección 4 de la
final, "Biblioteca de resiliencia"). La usan las 4 System APIs y papi-orders.

Es un proyecto Mule empaquetado como **`mule-plugin`** (configuración compartida). Mule 4.11.4, Java 17,
Object Store 1.3.4, MUnit 3.7.1.

## Usarla desde una app

1. Dependencia en el `pom.xml` de la app (el `groupId` es el orgId, literal por D19):
   ```xml
   <dependency>
       <groupId>9885f017-0660-4c80-a27f-eb006d124bd8</groupId>
       <artifactId>poc-resilience</artifactId>
       <version>1.0.0</version>
       <classifier>mule-plugin</classifier>
   </dependency>
   ```
2. Importar su configuración en `global.xml`: `<import file="poc-resilience.xml"/>`.
3. Llamar a una fuente de lectura:
   ```xml
   <set-variable variableName="rsSource" value="sftp"/>
   <set-variable variableName="rsFlow" value="sftp-get-dispatch-note-subflow"/>
   <flow-ref name="resilience-call"/>
   <!-- vars.rsResult = { ok: true, source, payload }  o  { ok: false, source, reason, message } -->
   ```
4. Para una respuesta compuesta (Pedido 360), juntar los `rsResult` en `vars.rsResults` y llamar a
   `resilience-partial-marker`, que deja `vars.sources`, por ejemplo
   `{ erp: "OK", crm: "UNAVAILABLE", logistics: "OK", providers: "2 of 3" }`.
   Las fuentes cuyo nombre empieza con `provider` se cuentan juntas como `providers: "n of m"`.

## Comportamiento

| Pieza | Regla |
|---|---|
| Interruptor | Por fuente. Abre tras `rs.<fuente>.failureThreshold` fallas seguidas (3), queda abierto `rs.<fuente>.openMillis` (30000) y después deja pasar una llamada de prueba: si responde se cierra, si falla se vuelve a abrir. |
| Abierto | Responde de inmediato `ok: false`, `reason: CIRCUIT_OPEN`, sin llamar a la fuente. |
| Reintento | Una sola vez y solo si el error es de conectividad: identificador `CONNECTIVITY` en cualquier espacio de nombres (`HTTP:CONNECTIVITY`, `SFTP:CONNECTIVITY`…) o descripción con el mensaje de conexión de Mule ("Could not establish…", "Could not obtain…"; el SFTP rechazado llega como `UNKNOWN`). Esa falla se reporta con motivo `CONNECTIVITY`. Un tiempo agotado no se reintenta (D9). |
| Falla | No lanza error: deja `ok: false` con `reason` (el identificador del error, por ejemplo `TIMEOUT`) y `message`. |
| Tiempo límite | `rs.<fuente>.timeoutMillis` (2000 proveedores, 3000 sftp y crm). Lo aplica la app en su `http:request-config` o en su conector; la biblioteca no puede cortar un `flow-ref`. |
| Estado | Object Store en memoria `rs-circuit-store`; con 1 réplica por app basta (D16). |

Úsese solo para lecturas: una escritura nunca se reintenta a ciegas.

## Pruebas de las apps (importante)

MUnit inicializa de forma perezosa solo los componentes referenciados de forma estática. Como `resilience-call`
llama a la fuente con un `flow-ref` dinámico (`vars.rsFlow`), en las pruebas de la app ese flujo **no existe** a menos
que tenga una referencia estática. Agrega en la suite un bloque que nunca se ejecute:

```xml
<munit:before-suite name="referencias-estaticas">
    <choice>
        <when expression="#[false]">
            <flow-ref name="sftp-get-dispatch-note-subflow"/>
        </when>
    </choice>
</munit:before-suite>
```

Sin eso el resultado es `reason: ROUTING` ("No flow/sub-flow with name ... found"). En el runtime normal no pasa.

## Construir

```
mvn -B -f libs/poc-resilience/pom.xml clean install
```

5 pruebas MUnit y cobertura del 93.75 % (mínimo 80 %). `install` la deja en `~/.m2` con el `groupId` del perfil
`poc-org`. Publicarla en Exchange es opcional (`mvn deploy` contra la org).

Notas:
- El validador de la skill `build-mule-integration` marca `xmlns:os` como huérfano porque busca el prefijo `os`
  dentro del `artifactId` `mule-objectstore-connector`; es un falso positivo (el build compila).
- Bajo MUnit con cobertura cada procesador cuesta unos 10 ms y `os:retrieve` unos 50 ms; por eso las pruebas de
  tiempo usan márgenes amplios (menos de 500 ms con el interruptor abierto, frente a los 2 a 3 s del tiempo límite).
