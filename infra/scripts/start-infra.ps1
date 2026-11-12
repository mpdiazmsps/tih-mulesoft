# Levanta la infraestructura local de TIH en Docker: Oracle, RabbitMQ y (opcional) SFTP.
# Crea los usuarios de RabbitMQ y espera a que todo esté listo. Se puede ejecutar varias veces.
#
# Uso:
#   .\infra\scripts\start-infra.ps1            # Oracle + RabbitMQ + SFTP en Docker
#   .\infra\scripts\start-infra.ps1 -NoSftp    # sin SFTP en Docker (por ejemplo, si usas Rebex en Windows)
param([switch]$NoSftp)

$infra = Split-Path $PSScriptRoot -Parent
Set-Location $infra

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

function Read-EnvFile($path) {
    $values = @{}
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $values[$matches[1]] = $matches[2].Trim() }
    }
    return $values
}

function Wait-Healthy($container, $timeoutSeconds) {
    Write-Host "Esperando a $container (hasta $([int]($timeoutSeconds / 60)) min)..." -NoNewline
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $status = docker inspect -f '{{.State.Health.Status}}' $container 2>$null
        if ($status -eq 'healthy') { Write-Host " listo." -ForegroundColor Green; return }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 10
    }
    Write-Host ""
    Fail "$container no quedó listo a tiempo. Revisa: docker logs $container"
}

# 1. Docker disponible
docker info *> $null
if ($LASTEXITCODE -ne 0) { Fail "Docker no responde. Abre Docker Desktop y vuelve a intentar." }

# 2. Archivos de credenciales: si falta alguno se crea desde su .example y se pide llenarlo
$required = @('oracle', 'rabbitmq')
if (-not $NoSftp) { $required += 'sftp' }
$missing = @()
foreach ($name in $required) {
    $file = Join-Path $infra "$name\credentials.local"
    if (-not (Test-Path $file)) {
        Copy-Item "$file.example" $file
        $missing += $file
    }
}
if ($missing.Count -gt 0) {
    Write-Host "Se crearon estos archivos desde sus plantillas. Cambia las claves y vuelve a ejecutar el script:" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# 3. Contenedores
$composeArgs = @('compose')
if (-not $NoSftp) { $composeArgs += @('--profile', 'sftp') }
$composeArgs += @('up', '-d')
docker @composeArgs
if ($LASTEXITCODE -ne 0) { Fail "docker compose falló. Si un puerto está ocupado, cámbialo en infra\.env (ver .env.example)." }

# 4. Usuarios de RabbitMQ
Wait-Healthy 'tih-rabbitmq' 180
$rabbit = Read-EnvFile (Join-Path $infra 'rabbitmq\credentials.local')
$existing = docker exec tih-rabbitmq rabbitmqctl list_users --quiet --no-table-headers 2>$null
foreach ($u in @(
        @{ User = $rabbit['RABBITMQ_ADMIN_USER']; Password = $rabbit['RABBITMQ_ADMIN_PASSWORD']; Tag = 'administrator' },
        @{ User = $rabbit['RABBITMQ_APP_USER']; Password = $rabbit['RABBITMQ_APP_PASSWORD']; Tag = $null })) {
    if (-not $u.User -or -not $u.Password) { Fail "Faltan usuarios o claves en rabbitmq\credentials.local." }
    if ($existing -match "^$([regex]::Escape($u.User))\s") {
        docker exec tih-rabbitmq rabbitmqctl change_password $u.User $u.Password *> $null
    } else {
        docker exec tih-rabbitmq rabbitmqctl add_user $u.User $u.Password *> $null
    }
    if ($LASTEXITCODE -ne 0) { Fail "No se pudo crear el usuario $($u.User) en RabbitMQ." }
    if ($u.Tag) { docker exec tih-rabbitmq rabbitmqctl set_user_tags $u.User $u.Tag *> $null }
    docker exec tih-rabbitmq rabbitmqctl set_permissions -p / $u.User '.*' '.*' '.*' *> $null
    Write-Host "RabbitMQ: usuario $($u.User) listo."
}

# 5. Oracle (el primer arranque crea la base, el esquema y el inventario de ejemplo)
Wait-Healthy 'tih-oracle' 900

$envValues = @{}
if (Test-Path (Join-Path $infra '.env')) { $envValues = Read-EnvFile (Join-Path $infra '.env') }
function Port($key, $default) { if ($envValues[$key]) { $envValues[$key] } else { $default } }

Write-Host ""
Write-Host "Infraestructura lista:" -ForegroundColor Green
Write-Host "  Oracle    localhost:$(Port 'ORACLE_PORT' 1521)  servicio FREEPDB1"
Write-Host "  RabbitMQ  localhost:$(Port 'RABBITMQ_PORT' 5672)  consola http://localhost:$(Port 'RABBITMQ_CONSOLE_PORT' 15672)"
if (-not $NoSftp) { Write-Host "  SFTP      localhost:$(Port 'SFTP_PORT' 2222)  usuario tihsftp, carpeta /orders" }
Write-Host "Siguiente paso: README.md, sección 'Configurar las apps'."
