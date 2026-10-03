# Contribuindo com o Arca

Obrigado pelo interesse em contribuir. Este guia mantém o projeto consistente e seguro.

## Antes de começar

- Leia o [README](README.md), o [modelo de segurança](README.md#modelo-de-segurança--o-binding)
  e o [código de conduta](CODE_OF_CONDUCT.md).
- O Arca é para **backup do próprio aparelho**. Propostas que ajudem a contornar
  verificações de terceiros, attestation de outros donos ou extração sem consentimento
  **não serão aceitas**.

## Abrindo issues

- Use os templates de [bug](.github/ISSUE_TEMPLATE/bug_report.md) ou
  [sugestão](.github/ISSUE_TEMPLATE/feature_request.md).
- Para **falhas de segurança**, siga a [Política de Segurança](SECURITY.md) —
  não abra issue pública.

## Pull requests

1. Faça um fork e crie um branch descritivo (`fix/...`, `feat/...`, `docs/...`).
2. Mantenha o estilo existente:
   - **PowerShell**: verbos aprovados, `param()` tipado, `$ErrorActionPreference = 'Stop'`.
   - **Python**: PEP 8, 3.9+ compatível.
   - **Shell on-device**: POSIX `sh`, sem dependências além do que o Android traz.
3. **Nunca** inclua artefatos sensíveis (`operator.key`, `*.arca`, `*.tar`,
   `msgstore.db`, `wa.db`, chaves). Eles estão no `.gitignore` — confirme antes do commit.
4. Descreva **o quê** e **por quê** no PR; vincule a issue relacionada.
5. Atualize o [CHANGELOG.md](CHANGELOG.md) na seção *Unreleased*.

## Documentação e site

- O site (`docs/`) é publicado via GitHub Pages a partir da pasta `/docs`.
- Mantenha a autoria e a identidade visual existentes.

Toda contribuição é feita sob a [Licença MIT](LICENSE).
