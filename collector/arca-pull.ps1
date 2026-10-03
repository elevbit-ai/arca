<#
    arca-pull.ps1 - Orquestrador de coleta (lado PC)
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
    Licenca: MIT

    Dirige o adb: envia o coletor ao aparelho rootado, executa via su, puxa o
    payload, le a impressao do aparelho e sela tudo no cofre .arca.

    Pre-requisitos: adb no PATH; aparelho rootado (Magisk) com depuracao USB.
    Uso:
      ./arca-pull.ps1 -Out backup.arca -OperatorKey .\operator.key [-Media]
#>
[CmdletBinding()]
param(
    [string]$Out = "arca-backup-$(Get-Date -Format yyyyMMdd-HHmmss).arca",
    [string]$OperatorKey = '.\operator.key',
    [switch]$Media,
    [string]$WorkDir = (Join-Path $env:TEMP "arca-pull-$(Get-Random)")
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\vault\Arca.Crypto.psm1') -Force

function Invoke-Adb { param([Parameter(ValueFromRemainingArguments)]$Args) & adb @Args }

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb nao encontrado no PATH. Instale o Android platform-tools (veja install.ps1)."
}
if (-not (Test-Path $OperatorKey)) {
    throw "Chave do operador nao encontrada: $OperatorKey. Rode: ..\vault\arca-vault.ps1 init -OperatorKey $OperatorKey"
}

Write-Host "Verificando aparelho..." -ForegroundColor Cyan
$devices = (& adb devices) | Select-String -Pattern "\tdevice$"
if (-not $devices) { throw "Nenhum aparelho autorizado via adb. Conecte e aceite a depuracao USB." }

Write-Host "Testando root (su)..." -ForegroundColor Cyan
$uid = (& adb shell su -c id) 2>&1
if ($uid -notmatch 'uid=0') { throw "Root (su) indisponivel. O aparelho precisa estar rootado (Magisk). Retorno: $uid" }

New-Item -ItemType Directory -Force $WorkDir | Out-Null
$remoteSh = '/data/local/tmp/arca-collect.sh'
$localSh  = Join-Path $PSScriptRoot 'arca-collect.sh'

Write-Host "Enviando coletor ao aparelho..." -ForegroundColor Cyan
& adb push $localSh $remoteSh | Out-Null
& adb shell "chmod 0755 $remoteSh" | Out-Null

Write-Host "Executando coleta no aparelho (pode demorar)..." -ForegroundColor Cyan
$mediaArg = if ($Media) { '--media' } else { '' }
$run = (& adb shell su -c "sh $remoteSh $mediaArg") 2>&1
$run | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
if ($run -notmatch 'ARCA_DONE') { throw "Coleta falhou no aparelho. Veja o log acima." }

$remotePayload = '/data/local/tmp/arca-payload.tar'
$localPayload  = Join-Path $WorkDir 'payload.tar'
Write-Host "Puxando payload..." -ForegroundColor Cyan
& adb pull $remotePayload $localPayload | Out-Null
if (-not (Test-Path $localPayload)) { throw "Nao consegui puxar o payload." }

# impressao do aparelho (fator de binding) - direto do getprop/settings, sem confiar no tar
$serial  = (& adb shell getprop ro.serialno).Trim()
$model   = (& adb shell getprop ro.product.model).Trim()
$buildfp = (& adb shell getprop ro.build.fingerprint).Trim()
$aid     = (& adb shell settings get secure android_id).Trim()
$fingerprint = "model=$model|serial=$serial|android_id=$aid|build=$buildfp"
Write-Host "Impressao do aparelho: $fingerprint" -ForegroundColor Yellow

Write-Host "Selando no cofre..." -ForegroundColor Cyan
$pw1 = Read-Host -Prompt 'Defina a senha do cofre' -AsSecureString
$pw2 = Read-Host -Prompt 'Repita a senha' -AsSecureString
if ([System.Net.NetworkCredential]::new('',$pw1).Password -ne [System.Net.NetworkCredential]::new('',$pw2).Password) {
    throw "As senhas nao conferem."
}
Protect-ArcaFile -InputPath $localPayload -OutputPath $Out -Password $pw1 `
    -OperatorKeyPath $OperatorKey -DeviceFingerprint $fingerprint | Out-Null

Write-Host "Limpando vestigios no aparelho..." -ForegroundColor Cyan
& adb shell su -c "rm -rf /data/local/tmp/arca /data/local/tmp/arca-payload.tar $remoteSh" | Out-Null
Remove-Item -Recurse -Force $WorkDir

$size = [math]::Round((Get-Item $Out).Length / 1MB, 1)
Write-Host "`nCofre criado: $Out ($size MB)" -ForegroundColor Green
Write-Host "Impressao selada: $fingerprint" -ForegroundColor Green
Write-Host "Para abrir: ..\vault\arca-vault.ps1 open -In $Out -Out restored.tar -OperatorKey $OperatorKey" -ForegroundColor Green
