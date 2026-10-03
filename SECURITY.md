# Política de Segurança

O Arca é uma ferramenta de **backup e recuperação do próprio aparelho**. Levamos a
segurança a sério, tanto no código quanto no uso responsável.

## Versões suportadas

| Versão | Suportada |
|--------|-----------|
| 1.x    | ✅        |

## Como relatar uma vulnerabilidade

Se você encontrar uma falha de segurança, **não abra uma issue pública**. Em vez disso:

1. Envie um e-mail para **Joaquim Pedro de Morais Filho** — `j360074@hotmail.com`
   com o assunto `[SECURITY] Arca`.
2. Descreva o problema, o impacto e, se possível, um passo a passo para reproduzir.
3. Você receberá uma confirmação em até **5 dias úteis** e atualizações sobre a correção.

Pedimos uma janela de divulgação coordenada: dê um prazo razoável para a correção
antes de tornar a falha pública.

## Modelo de ameaças (resumo)

- A chave do cofre **não é armazenada**. Ela é recomposta de três fatores:
  senha (PBKDF2-SHA256, 600 000 iterações), chave do operador e impressão do aparelho.
- O payload é cifrado com **AES-256-GCM em blocos autenticados** — confidencialidade,
  integridade e ordem dos dados.
- A impressão do aparelho fica em claro no cabeçalho (proveniência), mas **fundida na
  chave**: um cofre não pode ser reapontado para outro device.
- Artefatos sensíveis (`operator.key`, `*.arca`, `*.tar`, `msgstore.db`, `wa.db`, chaves)
  estão no [`.gitignore`](.gitignore) e **nunca** devem ser versionados.

## Uso responsável

Use o Arca **apenas no seu próprio aparelho**, com consentimento. Extrair dados de
dispositivos de terceiros é ilegal na maioria das jurisdições.
