# Retiro programático del entorno de la PoC (D20; la final pide "levantamiento y retiro programáticos").
#   1. Apaga los túneles (ngrok, cloudflared).
#   2. Baja los contenedores poc-* y borra sus volúmenes (docker compose -p poc-infra down -v).
#      No toca oracle-store, ngrok-oracle ni los tih-* de la base.
#   3. Borra lo generado: semilla del ERP, remisiones semilla, reglas de logística, mappings de WireMock,
#      llaves del SFTP, Ids de Salesforce y tmp/.
#   4. Salesforce: borra los contactos POC-* y los metadatos de la PoC (infra/salesforce/teardown-salesforce.mjs).
#   5. Lista lo que no se puede borrar por script.
# Pide confirmación salvo con -Force. Cada paso se puede saltar.
#
# Uso:
#   .\infra\scripts\teardown.ps1                     # todo, con confirmación
#   .\infra\scripts\teardown.ps1 -Force -SkipSalesforce
#   .\infra\scripts\teardown.ps1 -OnlyTunnels        # solo apaga los túneles
param([switch]$Force, [switch]$SkipTunnels, [switch]$SkipDocker, [switch]$SkipFiles, [switch]$SkipSalesforce, [switch]$OnlyTunnels)

$ErrorActionPreference = 'Continue'
$infra = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $infra -Parent
if ($OnlyTunnels) { $SkipDocker = $true; $SkipFiles = $true; $SkipSalesforce = $true }

if (-not $Force) {
    Write-Host 'Esto va a retirar el entorno de la PoC:' -ForegroundColor Yellow
    if (-not $SkipTunnels) { Write-Host '  - apagar ngrok y cloudflared' }
    if (-not $SkipDocker) { Write-Host '  - borrar los contenedores poc-* y sus volúmenes (datos de Oracle, SFTP y RabbitMQ)' }
    if (-not $SkipFiles) { Write-Host '  - borrar los archivos generados, las llaves del SFTP, los Ids de Salesforce y tmp/' }
    if (-not $SkipSalesforce) { Write-Host '  - borrar en Salesforce los contactos POC-* y los metadatos de la PoC' }
    $answer = Read-Host '¿Continuar? (escribe si)'
    if ($answer -ne 'si') { Write-Host 'Cancelado.'; exit 1 }
}

# 1. Túneles
if (-not $SkipTunnels) {
    $procs = Get-Process -Name ngrok, cloudflared -ErrorAction SilentlyContinue
    if ($procs) { $procs | Stop-Process -Force; Write-Host "Túneles apagados: $(($procs | ForEach-Object Name | Sort-Object -Unique) -join ', ')." }
    else { Write-Host 'Túneles: no había ninguno corriendo.' }
}

# 2. Contenedores y volúmenes
if (-not $SkipDocker) {
    docker compose -f (Join-Path $infra 'docker-compose.yml') -p poc-infra --profile local down -v --remove-orphans
    if ($LASTEXITCODE -ne 0) { Write-Host 'docker compose down falló.' -ForegroundColor Red; exit 1 }
    Write-Host 'Contenedores poc-* y volúmenes de poc-infra borrados.'
}

# 3. Archivos generados
if (-not $SkipFiles) {
    $targets = @(
        'infra\oracle\sql\erp\20-seed.generated.sql',
        'infra\sftp\seed',
        'infra\sftp\keys\poc_sftp_rsa',
        'infra\sftp\keys\poc_sftp_rsa.pub',
        'infra\wiremock\mappings',
        'data\logistics-rules.json',
        'data\salesforce-ids.local.json',
        'tmp'
    )
    foreach ($t in $targets) {
        $p = Join-Path $repo $t
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force; Write-Host "borrado: $t" }
    }
}

# 4. Salesforce
if (-not $SkipSalesforce) {
    if (-not (Get-Command sf -ErrorAction SilentlyContinue)) { Write-Host 'Salesforce: falta la CLI sf; se omite.' -ForegroundColor Yellow }
    else {
        Push-Location $repo
        node infra\salesforce\teardown-salesforce.mjs
        $sfExit = $LASTEXITCODE
        Pop-Location
        if ($sfExit -ne 0) { Write-Host 'El retiro en Salesforce falló; revisa el mensaje anterior.' -ForegroundColor Red; exit 1 }
    }
}

# 5. Lo que queda a mano
Write-Host ''
Write-Host 'Retiro terminado. Queda a mano, si ya no se usa:' -ForegroundColor Green
Write-Host '  - Salesforce: la aplicación conectada de JWT (Setup > App Manager) y su certificado en infra\salesforce\certs\'
Write-Host '  - MagicBell: la cuenta o el proyecto de la PoC'
Write-Host '  - Anypoint Platform: las apps de CloudHub 2.0, las APIs de API Manager y los assets de Exchange'
Write-Host '  - Credenciales locales: infra\*\credentials.local'
