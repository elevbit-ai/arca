# Guia de Root (caminho oficial — Magisk)

> **Importante:** o Arca **não** cria root por exploit. Root é obtido pelo caminho
> oficial: **destravar o bootloader + injetar o Magisk**. Isso **apaga o aparelho** e
> pode anular a garantia. Faça **antes** de precisar do backup, no **seu próprio** device.

Não existe "root para todas as versões num clique". Cada fabricante tem seu fluxo, e
muitos aparelhos **de operadora** têm o bootloader travado de fábrica — nesses, não há
caminho oficial.

---

## Moto G24 (Android 14, Helio G85) — passo a passo

A Motorola oferece desbloqueio **oficial** de bootloader (exceto variantes de operadora).

### 0. Preparação
- Bateria > 60%, backup do que puder, **ciente de que vai apagar tudo**.
- PC com `adb`/`fastboot` (platform-tools) e drivers Motorola.
- Confirme que é a versão **retail** (não travada por operadora).

### 1. Obter o unlock data
```
# Em Opções do desenvolvedor: "Desbloqueio de OEM" + "Depuração USB"
adb reboot bootloader
fastboot oem get_unlock_data
```
Junte as linhas da saída numa única string (sem espaços).

### 2. Portal oficial
- Acesse **motorola.com/unlockbootloader**, faça login, cole o unlock data.
- Se elegível, você recebe o **código de desbloqueio** por e-mail.

### 3. Destravar
```
fastboot oem unlock <CÓDIGO_RECEBIDO>
# o aparelho apaga e reinicia destravado
```

### 4. Obter a boot.img da build exata
- Use o **Rescue and Smart Assistant (LMSA)** da Motorola no PC para baixar o firmware
  oficial do seu modelo e extrair a `boot.img`.
- Deve ser **a mesma build** instalada (*Config → Sobre → número da versão*), senão dá bootloop.

### 5. Patch com Magisk
- Instale o APK do **Magisk** (≥ 27.x).
- Magisk → *Install* → *Select and Patch a File* → aponte para `boot.img` → gera
  `magisk_patched-xxxxx.img`.
- 📌 O G24 é MediaTek e normalmente usa a partição **`boot`** (não `init_boot`). Confirme
  olhando se o firmware traz `init_boot.img`; se trouxer, use-a.

### 6. Flashar
```
adb reboot bootloader
fastboot flash boot magisk_patched-xxxxx.img      # ou "init_boot", conforme o passo 5
fastboot reboot
```

### 7. Ocultar do Play Integrity
Magisk → **Zygisk ON** → reiniciar → **DenyList** → marcar WhatsApp, Google Play Services
e apps de banco (senão podem recusar rodar).

### Root temporário (opcional)
Em alguns aparelhos dá para bootar sem flashar, coletar o backup e reverter:
```
fastboot boot magisk_patched-xxxxx.img
# rode o collector/arca-pull.ps1 e depois reinicie limpo
```

---

## Outros fabricantes (resumo)

| Fabricante | Observações |
|---|---|
| **Pixel** | Mais simples: `fastboot flashing unlock`; ramdisk em `init_boot` (Android 13+). |
| **Xiaomi/Poco** | Destrava via Mi Unlock, com **período de carência** (dias) atrelado à conta Mi. |
| **Samsung** | Odin + flashar; **queima o Knox permanentemente** (perde Samsung Pay/Pasta Segura). |
| **Motorola/OnePlus** | Desbloqueio oficial via portal/`fastboot`. |
| **Operadora (carrier-locked)** | Bootloader frequentemente **travado de fábrica → sem caminho oficial.** |

> Depois de rootar, use `collector/arca-pull.ps1` para clonar o aparelho no cofre.
