# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Adicionado
- Site profissional em `docs/` com identidade visual própria, SEO/Open Graph,
  seções de arquitetura e FAQ.
- Vídeo explicativo animado e narrado (com legendas) em `docs/video.html`,
  agora com cenas de arquitetura e instalação.
- Governança do repositório: `SECURITY.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `CHANGELOG.md` e templates em `.github/`.

## [1.0.0] — 2026-10-02

### Adicionado
- Núcleo criptográfico `vault` com binding de três fatores
  (senha + chave do operador + impressão do aparelho) e AES-256-GCM em blocos.
- Coletor (`collector`) para APKs, `/data/data`, mídia e WhatsApp sob root (Magisk).
- Descriptografia do WhatsApp (`arca-wa-decrypt.ps1`) e visualizador de timeline (`viewer`).
- Guia de root (`ROOT_GUIDE.md`) com procedimento do Moto G24.
- Site inicial e roteiro de vídeo.

[Unreleased]: https://github.com/elevbit-ai/arca/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/elevbit-ai/arca/releases/tag/v1.0.0
