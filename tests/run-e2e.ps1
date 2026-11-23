# Las cuatro escenas de punta a punta en local (tarea 25). Hace lo mismo que run-e2e.sh.
#   1. demo/control reset: datos del guion en todas las dependencias y segmentos de Salesforce.
#   2. Corre las carpetas de tests/postman/poc-e2e.postman_collection.json en orden con newman, intercalando los
#      comandos de demo/control de cada escena (cambio de segmento en Salesforce, proveedor C lento, SFTP apagado).
#   3. Al terminar (también si falla) deja el proveedor C normal, el SFTP encendido y Cumbres en Estratégico.
# Requiere: las 10 apps corriendo (Studio, poc-mule), Docker con los contenedores poc-*, Node.js y la sesión de la CLI
# sf (sf org login web --alias poc). newman se descarga con npx, con la caché de npm en tmp\.
# Uso: .\tests\run-e2e.ps1
$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo
$env:npm_config_cache = Join-Path $repo 'tmp\npm-cache'
$collection = 'tests\postman\poc-e2e.postman_collection.json'
$envIn = 'tests\postman\local.postman_environment.json'
$envRun = 'tmp\e2e-environment.json'
$xapi = 'http://localhost:8080/api/v1/online-store'
$ped1002 = '10000000-0000-4000-8000-000000001002'
$script:failed = $false

function Invoke-Control([string]$action) {
    & (Join-Path $repo 'demo\control.ps1') $action
    if ($LASTEXITCODE -ne 0) { throw "demo/control $action falló" }
}

function Invoke-Folder([string]$name) {
    Write-Host ''
    Write-Host "=== $name"
    npx --yes newman@6.2.1 run $collection -e $envRun --export-environment $envRun --folder $name --reporters cli
    if ($LASTEXITCODE -ne 0) { $script:failed = $true }
}

function Wait-Sources {
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $o = Invoke-RestMethod -Uri "$xapi/orders/$ped1002" -Headers @{ client_id = 'e2e'; client_secret = 'e2e' }
            if ($o.sources.logistics -eq 'OK' -and $o.sources.providers -eq '3 of 3') { return }
        } catch { }
        Start-Sleep -Seconds 2
    }
    Write-Warning 'Las fuentes no se recuperaron en 60 s'
    $script:failed = $true
}

New-Item -ItemType Directory -Force (Join-Path $repo 'tmp') | Out-Null
Copy-Item $envIn $envRun -Force
try {
    Invoke-Control 'normal-c'
    Invoke-Control 'sftp-up'
    Invoke-Control 'reset'

    Invoke-Folder '00 Calentamiento'
    Invoke-Folder 'E1 Qué requiere mi atención'
    Invoke-Folder 'E2a Qué hago con este pedido'
    Invoke-Control 'cumbres-regular'
    Invoke-Folder 'E2b Cambio en Salesforce'
    Invoke-Control 'cumbres-strategic'
    Invoke-Folder 'E2c Segmento restaurado'
    Invoke-Control 'slow-c'
    Invoke-Control 'sftp-down'
    Invoke-Folder 'E3 Y si un sistema falla'
    Invoke-Control 'normal-c'
    Invoke-Control 'sftp-up'
    Wait-Sources
    Invoke-Folder 'E4a El agente solicita'
    Invoke-Folder 'E4b La persona decide'
    Invoke-Folder 'E4c Stock repuesto y remisión emitida'
}
finally {
    & (Join-Path $repo 'demo\control.ps1') 'normal-c' | Out-Null
    & (Join-Path $repo 'demo\control.ps1') 'sftp-up' | Out-Null
    & (Join-Path $repo 'demo\control.ps1') 'cumbres-strategic' | Out-Null
}

Write-Host ''
if (-not $script:failed) {
    Write-Host 'Las cuatro escenas pasaron. Revisa en la bandeja de notifications.redirectTo los dos correos de la escena 4.'
    exit 0
}
Write-Warning 'Hubo aserciones fallidas: revisa la salida de newman.'
exit 1
