<div align="center">

# ⛨ Arca — Cofre de Recuperação Android

**Clone o seu Android para um cofre cifrado e recupere apps, dados e o WhatsApp em caso de perda — com uma chave que só existe quando a senha, o operador e o aparelho se encontram.**

[![Licença: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-e6a94e.svg)](LICENSE)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-3776AB.svg?logo=python&logoColor=white)](https://www.python.org/)
[![Cripto: AES-256-GCM](https://img.shields.io/badge/Cripto-AES--256--GCM-2ea6ff.svg)](#modelo-de-segurança--o-binding)
[![Plataforma: Android · Windows](https://img.shields.io/badge/Plataforma-Android%20%C2%B7%20Windows-4ec98a.svg)](#requisitos)
[![Status: estável](https://img.shields.io/badge/Status-est%C3%A1vel-success.svg)](CHANGELOG.md)

[**Site**](https://elevbit-ai.github.io/arca/) · [**Vídeo explicativo**](https://elevbit-ai.github.io/arca/video.html) · [**Guia de root**](ROOT_GUIDE.md) · [**Política de segurança**](SECURITY.md)

<sub>Projeto de <b>Joaquim Pedro de Morais Filho</b> · <code>j360074@hotmail.com</code> · Licença MIT</sub>

</div>

---

## Índice

- [O que faz (e o que não faz)](#o-que-faz-e-o-que-não-faz)
- [Modelo de segurança — o binding](#modelo-de-segurança--o-binding)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Uso](#uso)
- [Arquitetura](#arquitetura)
- [Vídeo explicativo](#vídeo-explicativo)
- [Limites honestos](#limites-honestos)
- [Segurança e responsabilidade](#segurança-e-responsabilidade)
- [Contribuindo](#contribuindo)
- [Licença e autoria](#licença-e-autoria)

---

## O que faz (e o que não faz)

| Faz | Não faz |
|---|---|
| Empacota APKs, `/data/data` e mídia num cofre cifrado | **Não** cria root por exploit — usa o caminho oficial (Magisk) |
| Extrai e descriptografa o WhatsApp (`msgstore.db`) | **Não** contorna o número de telefone para "mover" o WhatsApp |
| Amarra o cofre a **senha + chave do operador + impressão do aparelho** | **Não** garante rodar todo app num emulador (attestation/Play Integrity bloqueiam) |
| Visualizador local das conversas, com nomes de contato | **Não** lê dados de aparelho de terceiros — uso no **seu próprio** device |

A recuperação é um **arquivo legível** e a reinstalação dos APKs; "simular o Android inteiro rodando no PC igual ao aparelho" é *best-effort* e não é prometido aqui.

---

## Modelo de segurança — o binding

A chave do cofre é derivada de **três fatores** e **não é armazenada em lugar nenhum** — ela só é recomposta quando os três se encontram:

```
Kp     = PBKDF2-SHA256(senha, salt, 600000)                 # algo que você SABE
B      = HMAC-SHA256(chave_operador, impressão_do_aparelho) # algo que você TEM + o aparelho
master = HMAC-SHA256(Kp, B)                                 # chave AES-256 final
cofre  = AES-256-GCM(payload, master)  # em blocos, autenticado
```

- **Senha** — segredo memorizado.
- **Chave do operador** (`operator.key`) — arquivo aleatório de 256 bits que representa *quem clona*; guarde offline (USB/cofre). Sem ele, o cofre não abre.
- **Impressão do aparelho** — `modelo | serial | android_id | build fingerprint`, lida direto do device na coleta. Fica no cabeçalho em claro (proveniência e recuperação após perda), mas está **fundida na chave**: um cofre não pode ser "reapontado" para outro aparelho.

> [!NOTE]
> **Verificado em teste:** senha errada, chave de operador errada **ou** aparelho errado (`-ExpectedFingerprint`) **não abrem** o cofre. A cifragem em blocos suporta backups grandes sem estourar a memória e autentica a ordem dos dados.

---

## Requisitos

| Componente | Versão | Onde |
|---|---|---|
| PowerShell | 7+ (AES-GCM nativo) | PC |
| Python | 3.9+ | PC |
| `adb` / platform-tools | recente | PC |
| `wa-crypt-tools` | via `pip` (instalado pelo `install.ps1`) | PC |
| Root (Magisk) | caminho oficial | Aparelho |

---

## Instalação

```powershell
# PowerShell 7+, Python 3.9+, adb
./install.ps1
```

Instala/verifica `wa-crypt-tools` (pip), checa `adb`/`platform-tools` e o runtime de cripto.

---

## Uso

```powershell
# 1) gerar a chave do operador (uma vez) — guarde offline
./vault/arca-vault.ps1 init -OperatorKey .\operator.key

# 2) clonar o aparelho rootado para um cofre
./collector/arca-pull.ps1 -Out backup.arca -OperatorKey .\operator.key    # -Media p/ incluir fotos/vídeos

# 3) recuperação (após perda): abrir o cofre
./vault/arca-vault.ps1 open -In backup.arca -Out restored.tar -OperatorKey .\operator.key

# 4) WhatsApp: descriptografar e visualizar
./collector/arca-wa-decrypt.ps1 -Key .\whatsapp\key -Crypt .\whatsapp\msgstore.db.crypt14 -Out .\msgstore.db
python ./viewer/arca-export.py .\msgstore.db -o ./viewer/web/messages.json --contacts .\wa.db
./viewer/arca-viewer.ps1        # abre http://localhost:8787

# vídeo explicativo (animado) em MP4
./viewer/make-video.ps1         # gera viewer/arca.mp4 (Playwright + ffmpeg)
```

> O explicador animado também roda direto no navegador em [`docs/video.html`](docs/video.html) e está embutido no [site](https://elevbit-ai.github.io/arca/).

> O coletor exige **root** (Magisk). Veja **[ROOT_GUIDE.md](ROOT_GUIDE.md)** — inclui o procedimento específico do **Moto G24**.

---

## Arquitetura

Três módulos com responsabilidade única, auditáveis isoladamente:

```
arca/
├─ vault/        Arca.Crypto.psm1  ·  arca-vault.ps1     (cofre: init/seal/open/info)
├─ collector/    arca-collect.sh (on-device)  ·  arca-pull.ps1  ·  arca-wa-decrypt.ps1
├─ viewer/       arca-export.py  ·  arca-viewer.ps1  ·  web/ (timeline do WhatsApp)
├─ docs/         site do GitHub Pages (explicativo + vídeo animado)
├─ install.ps1   ROOT_GUIDE.md   VIDEO_SCRIPT.md   SECURITY.md   LICENSE   AUTHORS
```

| Módulo | Papel |
|---|---|
| **`vault`** | Núcleo criptográfico: implementa o binding, a cifragem em blocos e os comandos `init`/`seal`/`open`/`info`. |
| **`collector`** | Coleta no device sob root (`arca-collect.sh`), orquestração pelo PC (`arca-pull.ps1`) e tratamento do WhatsApp (`arca-wa-decrypt.ps1`). |
| **`viewer`** | Exporta o banco em JSON com nomes de contato (`arca-export.py`) e serve a timeline local (`arca-viewer.ps1`). |

---

## Vídeo explicativo

Um explicador animado e narrado (com legendas) roda direto no navegador, sem plugin:

- **No ar:** <https://elevbit-ai.github.io/arca/video.html>
- **Local:** abra [`docs/video.html`](docs/video.html)
- **Screencast do app real:** siga o roteiro cena a cena em [`VIDEO_SCRIPT.md`](VIDEO_SCRIPT.md) e gere um MP4 com `./viewer/make-video.ps1`.

---

## Limites honestos

- Recuperação = **arquivo legível** + reinstalação de APKs. Rodar todo app num emulador é *best-effort* (Play Integrity/attestation bloqueiam).
- WhatsApp: lê o histórico; **não** contorna a verificação por número para "mudar de aparelho".
- Precisa de **root**. Aparelhos de operadora muitas vezes **não** destravam o bootloader.
- Ferramenta para o **seu próprio** aparelho, com consentimento.

---

## Segurança e responsabilidade

Ferramenta de **backup e recuperação do próprio aparelho**, com consentimento. Extrair dados de dispositivos de terceiros é ilegal na maioria das jurisdições. Rootear o aparelho pode anular a garantia e apagar os dados — leia o [`ROOT_GUIDE.md`](ROOT_GUIDE.md).

Para relatar uma vulnerabilidade, veja a [**Política de Segurança**](SECURITY.md).

---

## Contribuindo

Contribuições são bem-vindas. Leia o [guia de contribuição](CONTRIBUTING.md) e o [código de conduta](CODE_OF_CONDUCT.md) antes de abrir uma issue ou pull request. O histórico de versões está em [CHANGELOG.md](CHANGELOG.md).

---

## Licença e autoria

Distribuído sob a **Licença MIT** — veja [LICENSE](LICENSE).

Todo o projeto — arquitetura, criptografia, coletor, visualizador, documentação e site — é de autoria de **Joaquim Pedro de Morais Filho** (`j360074@hotmail.com`). Veja [AUTHORS](AUTHORS).

<div align="center"><sub>© 2026 Joaquim Pedro de Morais Filho — <code>j360074@hotmail.com</code> · MIT</sub></div>
