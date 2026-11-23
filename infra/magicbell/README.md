# MagicBell: avisos por correo

papi-notifications envía los avisos de la PoC por MagicBell (`POST /broadcasts`):

| Evento (RabbitMQ) | Destinatario | Aviso |
|---|---|---|
| `order.registered` | Cliente | Pedido confirmado y en camino |
| `approval.requested` | Aprobador | Hay una corrección por aprobar |
| `correction.applied` | Cliente | Su pedido se corrigió (un solo correo por corrección, D18) |

Los contactos del guion tienen correos ficticios (`*.ejemplo.mx`). En la demo todos los correos se redirigen a la
bandeja de quien presenta con la propiedad `notifications.redirectTo` de papi-notifications (D11).

## Estado actual (desviación D23)

**Mientras el equipo no tenga su infraestructura, la v1 usa la cuenta personal de MagicBell de Maite.**
La final pide el token de un proyecto del equipo ("el token: de la cuenta personal a la del proyecto"). Para cambiarlo
basta con crear el proyecto con los pasos de abajo, poner su token en `credentials.local` y volver a cifrarlo en
papi-notifications; no cambia ningún flujo.

## Crear el proyecto de la PoC y habilitar el correo

Los nombres de las pantallas pueden variar un poco según la versión del panel de MagicBell.

1. **Cuenta.** Entra a <https://app.magicbell.com> con la cuenta del equipo (o crea una con *Sign up*).
   Una misma cuenta puede tener varios proyectos, cada uno con sus propias claves.
2. **Proyecto.** En el selector de proyectos (arriba a la izquierda) elige *Create project* / *New project*.
   - Nombre sugerido: `poc-agentica`.
   - Trabaja siempre dentro de ese proyecto: las claves y los canales son por proyecto.
3. **Canal de correo.** En el menú del proyecto abre **Channels** (o *Integrations*) → **Email**.
   - Activa el canal.
   - Si pide un proveedor de envío, elige el que tenga el equipo (SendGrid, Mailgun, Amazon SES, Postmark o SMTP)
     y llena sus datos. Sin proveedor configurado MagicBell acepta el broadcast pero puede no entregar el correo.
   - Si tiene remitente configurable (*From*), pon una dirección del equipo verificada en el proveedor.
4. **Prueba desde el panel.** Si el panel tiene *Send test* / *Broadcasts → New*, envía un aviso de prueba a tu correo
   y confirma que llega (revisa spam).
5. **Token del proyecto.** Abre **Settings → Project Auth** (o *API Keys*) y copia el token del proyecto.
   No lo pegues en ningún chat ni archivo versionado.
6. **Credenciales locales.** Copia `infra/magicbell/credentials.local.example` como `credentials.local` y pon:
   ```
   ACCESS_TOKEN=<token del proyecto>
   ```
   En la tarea 21 se cifra en las propiedades seguras de papi-notifications (`magicbell.token`).
7. **Prueba por API (opcional).** Con el token en una variable de tu terminal (no en el historial compartido):
   ```powershell
   $t = '<token>'   # o léelo de credentials.local
   $body = '{"broadcast":{"title":"Prueba PoC","content":"Hola desde la PoC","recipients":[{"email":"tu.correo@dominio.com"}]}}'
   Invoke-RestMethod -Method Post -Uri https://api.magicbell.com/broadcasts -Headers @{ Authorization = "Bearer $t" } -ContentType 'application/json' -Body $body
   ```
   Verificado el 20-nov: `HTTP 201` con `status: enqueued` y el correo llegó. Es el mismo endpoint que usa papi-notifications.

## Lecciones de la base

- `POST /broadcasts` exige el cuerpo envuelto en `{ "broadcast": { ... } }`; si no, responde 422 (`Param 'broadcast' is missing`).
- En la base el broadcast quedó *enqueued* pero no se confirmó la entrega. En la PoC (20-nov) sí llegó: hacía falta
  el canal de correo con proveedor SMTP. `summary.total: 0` en la respuesta 201 es normal (MagicBell procesa la cola después).

## SMTP con Gmail (lo que usa la v1)

| Campo | Valor |
|---|---|
| Host | `smtp.gmail.com` |
| Port / Security | `587` / `STARTTLS` |
| Username | la dirección de Gmail |
| Password | una **contraseña de aplicación** de Google (16 letras; requiere verificación en dos pasos; se crea en <https://myaccount.google.com/apppasswords>) |
| From | la misma dirección de Gmail |
| Reply-To | vacío (nadie responde los correos de la demo) |

La contraseña de aplicación va solo en el panel de MagicBell; a la PoC solo llega el token de MagicBell.
Alternativas sin Gmail: Brevo (`smtp-relay.brevo.com`), SendGrid (`smtp.sendgrid.net`, usuario `apikey`).

## Retiro

`infra/scripts/teardown` no borra nada en MagicBell. Al terminar la PoC, elimina el proyecto `poc-agentica` desde el
panel (o, mientras se use la cuenta personal, revoca el token usado por la PoC).
