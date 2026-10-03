<#
    Arca.Crypto.psm1 - Nucleo criptografico do cofre Arca
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
    Licenca: MIT

    Modelo de seguranca (binding "quem clona" + "o aparelho"):
      Kp      = PBKDF2-SHA256(senha, salt, 600000)              -> fator "segredo memorizado"
      B       = HMAC-SHA256(chave_operador, impressao_aparelho) -> funde operador + aparelho
      master  = HMAC-SHA256(Kp, B)                              -> chave final AES-256
    O arquivo so abre com (senha) E (chave_operador) E (impressao do aparelho).
    A impressao fica no cabecalho em claro (proveniencia + permite recuperacao
    apos perda do aparelho); os fatores SECRETOS sao a senha e a chave_operador.

    Cifragem em blocos (framing) para suportar arquivos grandes sem estourar RAM:
      cada bloco = AES-256-GCM com nonce = noncePrefix(4) || contador(8, big-endian)
      e AAD = contador(8), o que autentica a ordem e impede reordenacao/truncamento.
#>

Set-StrictMode -Version Latest
$script:Magic       = [System.Text.Encoding]::ASCII.GetBytes('ARCA1')
$script:Iterations  = 600000
$script:TagSize     = 16
$script:NonceSize   = 12
$script:DefaultChunk = 4MB

function New-ArcaOperatorKey {
    <#
      .SYNOPSIS  Gera a chave do operador ("quem clona") - 32 bytes aleatorios em base64.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    [System.IO.File]::WriteAllText($Path, [Convert]::ToBase64String($bytes))
    Write-Verbose "Chave do operador gravada em $Path"
    return $Path
}

function ConvertTo-ArcaBytes {
    param([object]$Password)
    if ($Password -is [securestring]) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        try   { $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    } else { $plain = [string]$Password }
    return [System.Text.Encoding]::UTF8.GetBytes($plain)
}

function Get-ArcaMasterKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Password,
        [Parameter(Mandatory)][byte[]]$Salt,
        [Parameter(Mandatory)][int]$Iterations,
        [Parameter(Mandatory)][byte[]]$OperatorKey,
        [Parameter(Mandatory)][string]$DeviceFingerprint
    )
    $pwBytes = ConvertTo-ArcaBytes $Password
    try {
        $Kp = [System.Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2(
            $pwBytes, $Salt, $Iterations,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256, 32)
    } finally { [Array]::Clear($pwBytes, 0, $pwBytes.Length) }

    $fpBytes = [System.Text.Encoding]::UTF8.GetBytes($DeviceFingerprint)
    $hB = [System.Security.Cryptography.HMACSHA256]::new($OperatorKey)
    try   { $B = $hB.ComputeHash($fpBytes) } finally { $hB.Dispose() }

    $hM = [System.Security.Cryptography.HMACSHA256]::new($Kp)
    try   { $master = $hM.ComputeHash($B) } finally { $hM.Dispose(); [Array]::Clear($Kp,0,$Kp.Length) }
    return $master
}

function Write-UInt32LE { param($Writer,[uint32]$Value); $Writer.Write([BitConverter]::GetBytes($Value)) }
function Read-UInt32LE  { param($Reader); return [BitConverter]::ToUInt32($Reader.ReadBytes(4),0) }

function Get-ArcaNonce {
    param([byte[]]$Prefix,[uint64]$Counter)
    $ctr = [BitConverter]::GetBytes($Counter)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($ctr) }   # big-endian
    return ($Prefix + $ctr)
}

function Protect-ArcaFile {
    <#
      .SYNOPSIS  Sela um arquivo (tar do coletor) no cofre .arca.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][object]$Password,
        [Parameter(Mandatory)][string]$OperatorKeyPath,
        [Parameter(Mandatory)][string]$DeviceFingerprint,
        [int]$ChunkSize = $script:DefaultChunk
    )
    $operatorKey = [Convert]::FromBase64String((Get-Content -Raw $OperatorKeyPath).Trim())
    $salt = [byte[]]::new(16); [System.Security.Cryptography.RandomNumberGenerator]::Fill($salt)
    $noncePrefix = [byte[]]::new(4); [System.Security.Cryptography.RandomNumberGenerator]::Fill($noncePrefix)

    $master = Get-ArcaMasterKey -Password $Password -Salt $salt -Iterations $script:Iterations `
                                -OperatorKey $operatorKey -DeviceFingerprint $DeviceFingerprint

    $header = [ordered]@{
        format  = 'arca-vault'
        version = 1
        author  = 'Joaquim Pedro de Morais Filho <j360074@hotmail.com>'
        createdUtc = (Get-Date).ToUniversalTime().ToString('o')
        kdf     = [ordered]@{ algo='PBKDF2-SHA256'; salt=[Convert]::ToBase64String($salt); iterations=$script:Iterations }
        binding = [ordered]@{ algo='HMAC-SHA256'; deviceFingerprint=$DeviceFingerprint; requiresOperatorKey=$true }
        cipher  = [ordered]@{ algo='AES-256-GCM'; chunkSize=$ChunkSize; noncePrefix=[Convert]::ToBase64String($noncePrefix); tagSize=$script:TagSize }
    }
    $headerJson  = ($header | ConvertTo-Json -Depth 6 -Compress)
    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerJson)

    $aes = [System.Security.Cryptography.AesGcm]::new($master, $script:TagSize)
    $in  = [System.IO.File]::OpenRead($InputPath)
    $out = [System.IO.File]::Create($OutputPath)
    $bw  = [System.IO.BinaryWriter]::new($out)
    try {
        $bw.Write($script:Magic)
        Write-UInt32LE $bw ([uint32]$headerBytes.Length)
        $bw.Write($headerBytes)

        $buffer  = [byte[]]::new($ChunkSize)
        $counter = [uint64]0
        while (($read = $in.Read($buffer,0,$ChunkSize)) -gt 0) {
            $plain  = if ($read -eq $ChunkSize) { $buffer } else { $buffer[0..($read-1)] }
            $cipher = [byte[]]::new($read)
            $tag    = [byte[]]::new($script:TagSize)
            $nonce  = Get-ArcaNonce $noncePrefix $counter
            $aad    = [byte[]]($nonce[4..11])
            $aes.Encrypt($nonce, $plain, $cipher, $tag, $aad)
            Write-UInt32LE $bw ([uint32]$read)
            $bw.Write($tag)
            $bw.Write($cipher)
            $counter++
        }
        Write-UInt32LE $bw ([uint32]0)   # bloco final de tamanho zero = fim
    } finally {
        $bw.Dispose(); $out.Dispose(); $in.Dispose(); $aes.Dispose()
        [Array]::Clear($master,0,$master.Length)
    }
    Write-Verbose "Cofre selado: $OutputPath"
    return $OutputPath
}

function Get-ArcaHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $in = [System.IO.File]::OpenRead($Path)
    $br = [System.IO.BinaryReader]::new($in)
    try {
        $magic = $br.ReadBytes($script:Magic.Length)
        if ([Convert]::ToBase64String($magic) -ne [Convert]::ToBase64String($script:Magic)) {
            throw "Arquivo invalido: assinatura ARCA ausente."
        }
        $len = Read-UInt32LE $br
        $json = [System.Text.Encoding]::UTF8.GetString($br.ReadBytes([int]$len))
        return ($json | ConvertFrom-Json)
    } finally { $br.Dispose(); $in.Dispose() }
}

function Unprotect-ArcaFile {
    <#
      .SYNOPSIS  Abre um cofre .arca e restaura o tar original.
      .PARAMETER ExpectedFingerprint  Se informado, exige que a impressao bata (binding ao vivo).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][object]$Password,
        [Parameter(Mandatory)][string]$OperatorKeyPath,
        [string]$ExpectedFingerprint
    )
    $operatorKey = [Convert]::FromBase64String((Get-Content -Raw $OperatorKeyPath).Trim())
    $in = [System.IO.File]::OpenRead($InputPath)
    $br = [System.IO.BinaryReader]::new($in)
    try {
        $magic = $br.ReadBytes($script:Magic.Length)
        if ([Convert]::ToBase64String($magic) -ne [Convert]::ToBase64String($script:Magic)) {
            throw "Arquivo invalido: assinatura ARCA ausente."
        }
        $len  = Read-UInt32LE $br
        $json = [System.Text.Encoding]::UTF8.GetString($br.ReadBytes([int]$len))
        $header = $json | ConvertFrom-Json

        $fp = $header.binding.deviceFingerprint
        if ($ExpectedFingerprint -and ($ExpectedFingerprint -ne $fp)) {
            throw "Binding falhou: aparelho presente nao corresponde ao cofre."
        }
        $salt        = [Convert]::FromBase64String($header.kdf.salt)
        $noncePrefix = [Convert]::FromBase64String($header.cipher.noncePrefix)
        $master = Get-ArcaMasterKey -Password $Password -Salt $salt -Iterations ([int]$header.kdf.iterations) `
                                    -OperatorKey $operatorKey -DeviceFingerprint $fp

        $aes = [System.Security.Cryptography.AesGcm]::new($master, [int]$header.cipher.tagSize)
        $out = [System.IO.File]::Create($OutputPath)
        try {
            $counter = [uint64]0
            while ($true) {
                $n = Read-UInt32LE $br
                if ($n -eq 0) { break }
                $tag    = $br.ReadBytes($script:TagSize)
                $cipher = $br.ReadBytes([int]$n)
                $plain  = [byte[]]::new([int]$n)
                $nonce  = Get-ArcaNonce $noncePrefix $counter
                $aad    = [byte[]]($nonce[4..11])
                try {
                    $aes.Decrypt($nonce, $cipher, $tag, $plain, $aad)
                } catch {
                    throw "Falha de autenticacao no bloco $counter (senha/chave/aparelho errados ou arquivo corrompido)."
                }
                $out.Write($plain,0,$plain.Length)
                $counter++
            }
        } finally { $out.Dispose(); $aes.Dispose(); [Array]::Clear($master,0,$master.Length) }
    } finally { $br.Dispose(); $in.Dispose() }
    Write-Verbose "Cofre aberto em: $OutputPath"
    return $OutputPath
}

Export-ModuleMember -Function New-ArcaOperatorKey, Get-ArcaMasterKey, Protect-ArcaFile, Unprotect-ArcaFile, Get-ArcaHeader
