# Roteiro do vídeo demonstrativo — Arca

> O vídeo precisa ser **gravado por você**, com o **seu** aparelho (Moto G24) — eu não
> tenho acesso ao device. Este é o roteiro cena a cena; o site (`docs/`) já tem o espaço
> para embutir o vídeo (basta colar o ID/arquivo). Duração alvo: **4–6 min**.

## Preparação da gravação
- Capturador de tela do PC (OBS Studio) + captura do celular (scrcpy, se quiser mostrar o aparelho).
- Tenha pronto: aparelho **já rootado** (Magisk), `operator.key` ainda **não** gerado, projeto aberto.
- **Oculte dados reais**: use um aparelho de teste / conta de WhatsApp secundária, ou borre nomes e números na edição. Nunca exponha dados de terceiros.

---

## Cena 1 — Abertura (0:00–0:25)
- Título "Arca — Cofre de Recuperação Android" e a frase: *"Clonar o Android num cofre
  cifrado e recuperar WhatsApp e apps em caso de perda."*
- Fale a ideia central: **senha que converge quem clona e o aparelho**.

## Cena 2 — O problema (0:25–0:55)
- "Perdi o celular. Como recupero meus apps e o histórico do WhatsApp com segurança?"
- Mostre no diagrama (slide do site) os três fatores do binding.

## Cena 3 — Instalação (0:55–1:30)
- Terminal: `./install.ps1` — mostre PowerShell 7, Python, `wa-crypt-tools`, `adb`.

## Cena 4 — Chave do operador (1:30–2:00)
- `./vault/arca-vault.ps1 init -OperatorKey .\operator.key`
- Enfatize: **guardar offline**; é o "quem clona".

## Cena 5 — Root (referência, 2:00–2:40)
- Mostre rapidamente o `ROOT_GUIDE.md` e a seção do Moto G24 (bootloader + Magisk).
- Deixe claro: **caminho oficial, não exploit**; apaga o aparelho.

## Cena 6 — Clonagem (2:40–3:40)
- Conecte o aparelho rootado. `./collector/arca-pull.ps1 -Out backup.arca -OperatorKey .\operator.key`
- Mostre: teste de `su`, coleta, impressão do aparelho na tela, senha, cofre `.arca` criado.

## Cena 7 — Recuperação + WhatsApp (3:40–5:00)
- `arca-vault.ps1 open ...` restaura o tar.
- `arca-wa-decrypt.ps1` descriptografa o `msgstore.db`.
- `arca-export.py` gera o JSON; `arca-viewer.ps1` abre a timeline no navegador.
- Role as conversas recuperadas (com dados borrados).

## Cena 8 — Segurança (5:00–5:40)
- Demonstre: senha errada **não abre**; `-ExpectedFingerprint` de outro aparelho **não abre**.
- Reforce AES-256-GCM em blocos + PBKDF2 600k.

## Cena 9 — Encerramento (5:40–6:00)
- Autoria: **Joaquim Pedro de Morais Filho**. Link do repositório e do site (Pages).
- "Uso no próprio aparelho, com consentimento."

---

### Legenda sugerida (descrição do vídeo)
> Arca — ferramenta de backup e recuperação do Android: clona apps, dados e WhatsApp
> num cofre cifrado amarrado à senha, à chave do operador e à impressão do aparelho.
> Autor: Joaquim Pedro de Morais Filho. Código aberto (MIT).
