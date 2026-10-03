<#
    arca-wa-decrypt.ps1 - Decriptador de backup do WhatsApp
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
    Licenca: MIT

    Usa a ferramenta real wa-crypt-tools (pip) para descriptografar
    msgstore.crypt14/15 a partir do arquivo 'key' (crypt14) ou da
    chave hex de 64 digitos do backup com criptografia de ponta a ponta (crypt15).

    Pre-requisito: pip install wa-crypt-tools  (install.ps1 instala)
    Uso:
      # crypt14 (chave extraida do aparelho em /data/data/com.whatsapp/files/key)
      ./arca-wa-decrypt.ps1 -Key .\whatsapp\key -Crypt .\whatsapp\msgstore.db.crypt14 -Out .\msgstore.db

      # crypt15 E2E (chave de 64 digitos hex, mostrada no app ao ativar o backup cifrado)
      ./arca-wa-decrypt.ps1 -HexKey "<64 hex>" -Crypt .\msgstore.db.crypt15 -Out .\msgstore.db
#>
[CmdletBinding(DefaultParameterSetName='KeyFile')]
param(
    [Parameter(ParameterSetName='KeyFile',Mandatory)][string]$Key,
    [Parameter(ParameterSetName='HexKey',Mandatory)][string]$HexKey,
    [Parameter(Mandatory)][string]$Crypt,
    [Parameter(Mandatory)][string]$Out
)
$ErrorActionPreference = 'Stop'

$wadecrypt = (Get-Command wadecrypt -ErrorAction SilentlyContinue)
if (-not $wadecrypt) {
    # fallback: modulo python
    $hasMod = (& python -c "import wa_crypt_tools" 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "wa-crypt-tools nao instalado. Rode: pip install wa-crypt-tools (ou use install.ps1)."
    }
}

if (-not (Test-Path $Crypt)) { throw "Arquivo cifrado nao encontrado: $Crypt" }

if ($PSCmdlet.ParameterSetName -eq 'HexKey') {
    Write-Host "Descriptografando (crypt15 / chave hex)..." -ForegroundColor Cyan
    if ($wadecrypt) { & wadecrypt $HexKey $Crypt $Out }
    else { & python -m wa_crypt_tools.decrypt14_15 $HexKey $Crypt $Out }
} else {
    if (-not (Test-Path $Key)) { throw "Arquivo de chave nao encontrado: $Key" }
    Write-Host "Descriptografando (chave de arquivo)..." -ForegroundColor Cyan
    if ($wadecrypt) { & wadecrypt $Key $Crypt $Out }
    else { & python -m wa_crypt_tools.decrypt14_15 $Key $Crypt $Out }
}

if (Test-Path $Out) {
    Write-Host "Banco descriptografado: $Out" -ForegroundColor Green
    Write-Host "Agora gere a timeline: python ..\viewer\arca-export.py $Out -o ..\viewer\web\messages.json" -ForegroundColor Green
} else {
    throw "Falha: o banco nao foi gerado. Verifique se a chave corresponde ao backup."
}
