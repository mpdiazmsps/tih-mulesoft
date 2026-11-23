# Llave del SFTP de logística

`infra/scripts/start-infra` genera aquí, si no existe, el par de llaves que usa sapi-sftp-orders para entrar a `poc-sftp`:

- `poc_sftp_rsa`: llave privada (RSA 4096, formato PEM, sin frase). La lee sapi-sftp-orders.
- `poc_sftp_rsa.pub`: llave pública. `poc-sftp` la monta como llave autorizada del usuario `pocsftp`.

El SFTP solo acepta llave: el usuario no tiene contraseña (D21). Ninguno de los dos archivos se versiona.
Para cambiar la llave, borra los dos archivos y vuelve a correr `start-infra` (recrea `poc-sftp`).
