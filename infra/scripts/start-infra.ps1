# Levanta las dependencias locales de la PoC (proyecto poc-infra) y deja todo listo. Se puede ejecutar varias veces.
#   1. Revisa Docker, Node y las credenciales (si falta una, la crea desde su .example y pide llenarla).
#   2. Avisa si corren los contenedores de la base (tih-*). No toca oracle-store ni ngrok-oracle.
#   3. Genera las semillas (data/tools/build-seeds.mjs) y la llave del SFTP si falta.
#   4. Levanta el perfil pedido y crea los usuarios de RabbitMQ, esperando de verdad a que respondan.
#
# Uso:
#   .\infra\scripts\start-infra.ps1                  # perfil local: Oracle, RabbitMQ, SFTP, logística y WireMock
#   .\infra\scripts\start-infra.ps1 -Profile erp     # solo Oracle (erp | integracion | logistica | proveedores | local)
param([ValidateSet('erp', 'integracion', 'logistica', 'proveedores', 'local')][string]$Profile = 'local')

$ErrorActionPreference = 'Continue'
$infra = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $infra -Parent
$compose = @('compose', '-f', (Join-Path $infra 'docker-compose.yml'))

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }
function Read-EnvFile($path) {
    $values = @{}
    if (Test-Path $path) {
        foreach ($line in Get-Content $path) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $values[$matches[1]] = $matches[2].Trim() }
        }
    }
    return $values
}
function Wait-Healthy($container, $timeoutSeconds) {
    Write-Host "Esperando a $container (hasta $([int]($timeoutSeconds / 60)) min)..." -NoNewline
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $status = docker inspect -f '{{.State.Health.Status}}' $container 2>$null
        if ($status -eq 'healthy') { Write-Host ' listo.' -ForegroundColor Green; return }
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 5
    }
    Write-Host ''
    Fail "$container no quedó listo a tiempo. Revisa: docker logs $container"
}

$uses = @{
    oracle      = $Profile -in @('erp', 'integracion', 'local')
    rabbitmq    = $Profile -in @('integracion', 'local')
    sftp        = $Profile -in @('logistica', 'local')
    proveedores = $Profile -in @('proveedores', 'local')
}

# 1. Herramientas y credenciales
docker info *> $null
if ($LASTEXITCODE -ne 0) { Fail 'Docker no responde. Abre Docker Desktop y vuelve a intentar.' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail 'Falta Node.js (se usa para generar las semillas).' }

$required = @()
if ($uses.oracle) { $required += 'oracle' }
if ($uses.rabbitmq) { $required += 'rabbitmq' }
$missing = @()
foreach ($name in $required) {
    $file = Join-Path $infra "$name\credentials.local"
    if (-not (Test-Path $file)) { Copy-Item "$file.example" $file; $missing += $file }
}
if ($missing.Count -gt 0) {
    Write-Host 'Se crearon estos archivos desde sus plantillas. Cambia las claves y vuelve a ejecutar el script:' -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 1
}
if ($uses.oracle) {
    $ora = Read-EnvFile (Join-Path $infra 'oracle\credentials.local')
    foreach ($k in 'ORACLE_PWD', 'APP_USER', 'APP_USER_PASSWORD', 'INT_USER', 'INT_USER_PASSWORD') {
        if (-not $ora[$k]) { Fail "Falta $k en infra\oracle\credentials.local (ver credentials.local.example)." }
    }
}

# 2. Contenedores de la base
$running = docker ps --format '{{.Names}}'
foreach ($c in 'tih-oracle', 'tih-rabbitmq', 'tih-sftp') {
    if ($running -contains $c) { Write-Host "Aviso: $c (de la base) está corriendo. No se toca; consume memoria y puede ocupar puertos." -ForegroundColor Yellow }
}

# 3. Semillas y llave del SFTP (en Windows PowerShell 5.1 no se pasan comillas dobles a docker: se rompen)
Write-Host 'Generando semillas desde data/scenario.json...'
node (Join-Path $repo 'data\tools\build-seeds.mjs')
if ($LASTEXITCODE -ne 0) { Fail 'build-seeds.mjs falló.' }

if ($uses.sftp) {
    $keys = Join-Path $infra 'sftp\keys'
    if (-not (Test-Path (Join-Path $keys 'poc_sftp_rsa'))) {
        Write-Host 'Generando la llave del SFTP (RSA 4096, PEM)...'
        $mount = ($keys -replace '\\', '/')
        docker run --rm --entrypoint sh -v "${mount}:/k" atmoz/sftp:alpine -c 'ssh-keygen -q -t rsa -b 4096 -m PEM -N '''' -C poc-sftp -f /k/poc_sftp_rsa && chmod 644 /k/poc_sftp_rsa.pub'
        if ($LASTEXITCODE -ne 0) { Fail 'No se pudo generar la llave del SFTP.' }
    }
}

# 4. Contenedores
docker @compose --profile $Profile up -d
if ($LASTEXITCODE -ne 0) { Fail 'docker compose falló. Si un puerto está ocupado, cámbialo en infra\.env (ver .env.example).' }

if ($uses.rabbitmq) {
    Wait-Healthy 'poc-rabbitmq' 180
    # El healthcheck puede pasar antes de que la app rabbit acepte comandos: se reintenta list_users.
    $existing = $null
    for ($i = 0; $i -lt 30; $i++) {
        $existing = docker exec poc-rabbitmq rabbitmqctl list_users --quiet --no-table-headers 2>$null
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 2
    }
    if ($LASTEXITCODE -ne 0) { Fail 'RabbitMQ no acepta comandos. Revisa: docker logs poc-rabbitmq' }
    $rabbit = Read-EnvFile (Join-Path $infra 'rabbitmq\credentials.local')
    foreach ($u in @(
            @{ User = $rabbit['RABBITMQ_ADMIN_USER']; Password = $rabbit['RABBITMQ_ADMIN_PASSWORD']; Tag = 'administrator' },
            @{ User = $rabbit['RABBITMQ_APP_USER']; Password = $rabbit['RABBITMQ_APP_PASSWORD']; Tag = $null })) {
        if (-not $u.User -or -not $u.Password) { Fail 'Faltan usuarios o claves en infra\rabbitmq\credentials.local.' }
        if ($existing -match "(?m)^$([regex]::Escape($u.User))\s") {
            docker exec poc-rabbitmq rabbitmqctl change_password $u.User $u.Password *> $null
        } else {
            docker exec poc-rabbitmq rabbitmqctl add_user $u.User $u.Password *> $null
        }
        if ($LASTEXITCODE -ne 0) { Fail "No se pudo crear el usuario $($u.User) en RabbitMQ." }
        if ($u.Tag) { docker exec poc-rabbitmq rabbitmqctl set_user_tags $u.User $u.Tag *> $null }
        docker exec poc-rabbitmq rabbitmqctl set_permissions -p / $u.User '.*' '.*' '.*' *> $null
        Write-Host "RabbitMQ: usuario $($u.User) listo."
    }
}
if ($uses.oracle) { Wait-Healthy 'poc-oracle' 900 }

$envValues = Read-EnvFile (Join-Path $infra '.env')
function Port($key, $default) { if ($envValues[$key]) { $envValues[$key] } else { $default } }
Write-Host ''
Write-Host "Dependencias listas (perfil $Profile):" -ForegroundColor Green
if ($uses.oracle) { Write-Host "  Oracle     localhost:$(Port 'ORACLE_PORT' 1523)  servicio FREEPDB1, esquemas STORE_APP e INTEGRATION_APP" }
if ($uses.rabbitmq) { Write-Host "  RabbitMQ   localhost:$(Port 'RABBITMQ_PORT' 5673)  consola http://localhost:$(Port 'RABBITMQ_CONSOLE_PORT' 15673)" }
if ($uses.sftp) { Write-Host "  SFTP       localhost:$(Port 'SFTP_PORT' 2223)  usuario pocsftp con llave infra\sftp\keys\poc_sftp_rsa, carpeta /despachos" }
if ($uses.proveedores) { Write-Host "  WireMock   http://localhost:$(Port 'WIREMOCK_PORT' 8089)  /proveedor-a, /proveedor-b, /proveedor-c" }
Write-Host 'Para dejar los datos del guion: .\infra\scripts\reset-data.ps1'
