<#
    publish.ps1 - Publica o Arca no GitHub (elevbit-ai) com Pages
    Projeto: Arca - Cofre de Recuperacao Android
    Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>

    Pre-requisitos: git, gh (logado como elevbit-ai).
    Uso (na raiz do projeto):  ./publish.ps1
    Observacao: o token nao tem escopo 'workflow' - este projeto nao usa GitHub Actions;
                o Pages e habilitado pela API apontando para /docs no branch main.
#>
[CmdletBinding()]
param(
    [string]$Owner = 'elevbit-ai',
    [string]$Repo  = 'arca',
    [string]$AuthorName  = 'Joaquim Pedro de Morais Filho',
    [string]$AuthorEmail = 'j360074@hotmail.com'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

foreach ($t in 'git','gh') {
    if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "$t nao encontrado no PATH." }
}

# autoria dos commits como Joaquim
& git init -b main 2>$null | Out-Null
& git config user.name  $AuthorName
& git config user.email $AuthorEmail

& git add -A
& git commit -m "Arca - Cofre de Recuperacao Android (release inicial)" 2>$null

# cria o repo publico e sobe
$exists = (& gh repo view "$Owner/$Repo" 2>$null)
if (-not $exists) {
    & gh repo create "$Owner/$Repo" --public --source=. --remote=origin --push `
        --description "Arca - clona o Android num cofre cifrado e recupera apps e WhatsApp; binding senha+operador+aparelho."
} else {
    & git remote add origin "https://github.com/$Owner/$Repo.git" 2>$null
    & git push -u origin main
}

# habilita GitHub Pages servindo a pasta /docs no branch main
Write-Host "Habilitando GitHub Pages (/docs)..." -ForegroundColor Cyan
try {
    & gh api -X POST "repos/$Owner/$Repo/pages" -f "source[branch]=main" -f "source[path]=/docs" | Out-Null
} catch {
    & gh api -X PUT "repos/$Owner/$Repo/pages" -f "source[branch]=main" -f "source[path]=/docs" | Out-Null
}

Write-Host "`nPublicado!" -ForegroundColor Green
Write-Host "Repo: https://github.com/$Owner/$Repo"
Write-Host "Site: https://$Owner.github.io/$Repo/  (leva 1-2 min para ficar no ar)"
