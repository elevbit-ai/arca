<#
    make-video.ps1 - Instala dependencias e gera o MP4 do video explicativo
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>

    Uso:  ./make-video.ps1 [-Out ..\docs\arca.mp4]
#>
[CmdletBinding()]
param([string]$Out = (Join-Path $PSScriptRoot 'arca.mp4'))
$ErrorActionPreference = 'Stop'

if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python nao encontrado no PATH." }

Write-Host "Instalando Playwright..." -ForegroundColor Cyan
& python -m pip install --upgrade playwright | Out-Null
& python -m playwright install chromium | Out-Null

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Warning "ffmpeg nao encontrado. Instale: winget install Gyan.FFmpeg (senao sai .webm no lugar de .mp4)."
}

Write-Host "Gerando o video..." -ForegroundColor Cyan
& python (Join-Path $PSScriptRoot 'make-video.py') -o $Out
Write-Host "Concluido: $Out" -ForegroundColor Green
