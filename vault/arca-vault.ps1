<#
    arca-vault.ps1 - CLI do cofre Arca
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
    Licenca: MIT

    Uso:
      # 1) Gerar a chave do operador ("quem clona") - guarde em local seguro (USB/offline)
      ./arca-vault.ps1 init -OperatorKey .\operator.key

      # 2) Selar um tar coletado do aparelho num cofre cifrado
      ./arca-vault.ps1 seal -In backup.tar -Out backup.arca `
          -OperatorKey .\operator.key -DeviceFingerprint "<impressao>"

      # 3) Abrir o cofre (recuperacao), opcionalmente exigindo o aparelho vivo
      ./arca-vault.ps1 open -In backup.arca -Out restored.tar `
          -OperatorKey .\operator.key [-ExpectedFingerprint "<impressao>"]

      # Inspecionar o cabecalho sem abrir
      ./arca-vault.ps1 info -In backup.arca
#>
[CmdletBinding()]
param(
    [Parameter(Position=0,Mandatory)][ValidateSet('init','seal','open','info')][string]$Command,
    [string]$In,
    [string]$Out,
    [string]$OperatorKey = '.\operator.key',
    [string]$DeviceFingerprint,
    [string]$ExpectedFingerprint
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Arca.Crypto.psm1') -Force

function Read-ArcaPassword {
    param([string]$Prompt = 'Senha do cofre')
    return (Read-Host -Prompt $Prompt -AsSecureString)
}

switch ($Command) {
    'init' {
        if (Test-Path $OperatorKey) { throw "Ja existe uma chave em $OperatorKey. Remova-a antes de gerar outra." }
        New-ArcaOperatorKey -Path $OperatorKey -Verbose | Out-Null
        Write-Host "Chave do operador criada: $OperatorKey" -ForegroundColor Green
        Write-Host "GUARDE ESTE ARQUIVO OFFLINE. Sem ele (e sem a senha) o cofre nao abre." -ForegroundColor Yellow
    }
    'seal' {
        if (-not $In)  { throw "Informe -In (tar coletado)." }
        if (-not $Out) { throw "Informe -Out (arquivo .arca de saida)." }
        if (-not $DeviceFingerprint) { throw "Informe -DeviceFingerprint (gerado pelo coletor no aparelho)." }
        if (-not (Test-Path $OperatorKey)) { throw "Chave do operador nao encontrada em $OperatorKey. Rode 'init' primeiro." }
        $pw1 = Read-ArcaPassword 'Defina a senha do cofre'
        $pw2 = Read-ArcaPassword 'Repita a senha'
        if ([System.Net.NetworkCredential]::new('',$pw1).Password -ne [System.Net.NetworkCredential]::new('',$pw2).Password) {
            throw "As senhas nao conferem."
        }
        Write-Host "Selando $In -> $Out ..." -ForegroundColor Cyan
        Protect-ArcaFile -InputPath $In -OutputPath $Out -Password $pw1 `
            -OperatorKeyPath $OperatorKey -DeviceFingerprint $DeviceFingerprint -Verbose | Out-Null
        $size = [math]::Round((Get-Item $Out).Length / 1MB, 1)
        Write-Host "Cofre selado: $Out ($size MB)" -ForegroundColor Green
    }
    'open' {
        if (-not $In)  { throw "Informe -In (arquivo .arca)." }
        if (-not $Out) { throw "Informe -Out (tar restaurado)." }
        if (-not (Test-Path $OperatorKey)) { throw "Chave do operador nao encontrada em $OperatorKey." }
        $pw = Read-ArcaPassword 'Senha do cofre'
        Write-Host "Abrindo $In -> $Out ..." -ForegroundColor Cyan
        Unprotect-ArcaFile -InputPath $In -OutputPath $Out -Password $pw `
            -OperatorKeyPath $OperatorKey -ExpectedFingerprint $ExpectedFingerprint -Verbose | Out-Null
        Write-Host "Cofre aberto: $Out" -ForegroundColor Green
    }
    'info' {
        if (-not $In) { throw "Informe -In (arquivo .arca)." }
        $h = Get-ArcaHeader -Path $In
        $h | ConvertTo-Json -Depth 6
    }
}
