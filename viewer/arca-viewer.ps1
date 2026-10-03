<#
    arca-viewer.ps1 - Sobe um servidor local e abre o visualizador
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
    Licenca: MIT

    O visualizador precisa de http:// (nao file://) para carregar messages.json.
    Este script sobe um servidor estatico simples via Python e abre o navegador.

    Uso:
      ./arca-viewer.ps1 [-Port 8787]
    Antes, gere o JSON:
      python arca-export.py msgstore.db -o web/messages.json --contacts wa.db
#>
[CmdletBinding()]
param([int]$Port = 8787)
$ErrorActionPreference = 'Stop'
$webDir = Join-Path $PSScriptRoot 'web'
if (-not (Test-Path (Join-Path $webDir 'messages.json'))) {
    Write-Warning "web\messages.json ainda nao existe. Gere com arca-export.py antes (o visualizador abrira vazio)."
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python nao encontrado no PATH. Necessario para o servidor local."
}
Write-Host "Servindo $webDir em http://localhost:$Port ..." -ForegroundColor Cyan
Start-Process "http://localhost:$Port/index.html"
Push-Location $webDir
try { & python -m http.server $Port } finally { Pop-Location }
