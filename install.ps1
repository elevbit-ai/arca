<#
    install.ps1 - Instalador de dependencias do Arca (Windows)
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
    Licenca: MIT

    Verifica/instala:
      - PowerShell 7+        (AES-GCM nativo)
      - Python 3.9+          (exportador e wa-crypt-tools)
      - wa-crypt-tools       (decriptacao do WhatsApp)
      - Android platform-tools (adb/fastboot) - orienta a instalacao
#>
[CmdletBinding()]
param([switch]$SkipAdb)
$ErrorActionPreference = 'Stop'
Write-Host "== Arca :: instalador ==" -ForegroundColor Cyan

# PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Este projeto exige PowerShell 7+. Instale: winget install Microsoft.PowerShell"
} else { Write-Host "[ok] PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green }

# AES-GCM nativo
try { $g=[System.Security.Cryptography.AesGcm]::new([byte[]]::new(32),16); $g.Dispose(); Write-Host "[ok] AES-256-GCM disponivel" -ForegroundColor Green }
catch { Write-Warning "AES-GCM indisponivel neste runtime: $($_.Exception.Message)" }

# Python
if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "[ok] $(python --version)" -ForegroundColor Green
} else {
    Write-Warning "Python nao encontrado. Instale: winget install Python.Python.3.12"
}

# wa-crypt-tools
Write-Host "Instalando wa-crypt-tools (pip)..." -ForegroundColor Cyan
try {
    & python -m pip install --upgrade wa-crypt-tools 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "[ok] wa-crypt-tools instalado" -ForegroundColor Green
} catch { Write-Warning "Falha ao instalar wa-crypt-tools: $($_.Exception.Message)" }

# adb / platform-tools
if (-not $SkipAdb) {
    if (Get-Command adb -ErrorAction SilentlyContinue) {
        Write-Host "[ok] adb presente: $((Get-Command adb).Source)" -ForegroundColor Green
    } else {
        Write-Warning "adb (platform-tools) nao encontrado."
        Write-Host "  Instale com: winget install Google.PlatformTools" -ForegroundColor Yellow
        Write-Host "  ou baixe: https://developer.android.com/tools/releases/platform-tools" -ForegroundColor Yellow
    }
}

Write-Host "`nProximos passos:" -ForegroundColor Cyan
Write-Host "  1) vault\arca-vault.ps1 init -OperatorKey .\operator.key"
Write-Host "  2) (aparelho rootado) collector\arca-pull.ps1 -Out backup.arca -OperatorKey .\operator.key"
Write-Host "  3) Recuperacao: vault\arca-vault.ps1 open -In backup.arca -Out restored.tar -OperatorKey .\operator.key"
Write-Host "  Veja README.md e ROOT_GUIDE.md." -ForegroundColor Cyan
