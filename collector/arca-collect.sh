#!/system/bin/sh
# arca-collect.sh - Coletor on-device do Arca (roda no aparelho rootado, via su)
# Projeto: Arca - Cofre de Recuperacao Android
# Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
# Licenca: MIT
#
# Executado pelo orquestrador do PC com:
#   adb shell su -c 'sh /data/local/tmp/arca-collect.sh [--media]'
# Produz:
#   /data/local/tmp/arca/manifest.txt
#   /data/local/tmp/arca/fingerprint.txt
#   /data/local/tmp/arca-payload.tar   (empacotado, puxado pelo PC e selado no cofre)
#
# NAO cifra aqui: a cifragem com binding acontece no PC (arca-vault). Este tar
# fica em area protegida do device e deve ser apagado apos o pull (o orquestrador faz).

set -u
STAGE=/data/local/tmp/arca
OUT=/data/local/tmp/arca-payload.tar
INCLUDE_MEDIA=0
[ "${1:-}" = "--media" ] && INCLUDE_MEDIA=1

log() { echo "[arca] $*"; }

id | grep -q 'uid=0' || { echo "[arca] ERRO: precisa de root (uid=0). Rode via 'su -c'."; exit 1; }

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE/apks" "$STAGE/appdata" "$STAGE/whatsapp"

# --- 1. Impressao do aparelho (fator "o aparelho" do binding) -----------------
SERIAL=$(getprop ro.serialno 2>/dev/null)
MODEL=$(getprop ro.product.model 2>/dev/null)
BUILDFP=$(getprop ro.build.fingerprint 2>/dev/null)
ANDROID_ID=$(settings get secure android_id 2>/dev/null)
FP="model=$MODEL|serial=$SERIAL|android_id=$ANDROID_ID|build=$BUILDFP"
echo "$FP" > "$STAGE/fingerprint.txt"
log "Impressao do aparelho: $FP"

# --- 2. Inventario e copia dos APKs instalados --------------------------------
log "Copiando APKs instalados..."
pm list packages -f -3 2>/dev/null | sed 's/^package://' | while IFS= read -r line; do
    apk_path="${line%=*}"
    pkg="${line##*=}"
    [ -f "$apk_path" ] || continue
    cp -f "$apk_path" "$STAGE/apks/${pkg}.apk" 2>/dev/null \
        && echo "$pkg" >> "$STAGE/apks.list"
done
log "APKs copiados: $(wc -l < "$STAGE/apks.list" 2>/dev/null || echo 0)"

# --- 3. Dados privados dos apps (/data/data) ----------------------------------
log "Empacotando dados privados dos apps (/data/data)..."
# tar direto para preservar permissoes/symlinks; exclui caches volumosos
tar -cpf "$STAGE/appdata/data.tar" \
    --exclude='*/cache/*' --exclude='*/code_cache/*' \
    -C /data data 2>/dev/null
log "Tamanho data.tar: $(du -h "$STAGE/appdata/data.tar" 2>/dev/null | cut -f1)"

# --- 4. WhatsApp: chave + bancos + backups cifrados ---------------------------
WA=/data/data/com.whatsapp
if [ -d "$WA" ]; then
    log "Coletando WhatsApp..."
    [ -f "$WA/files/key" ] && cp -f "$WA/files/key" "$STAGE/whatsapp/key"
    # bancos ativos (nao cifrados dentro do sandbox)
    cp -f "$WA/databases/msgstore.db"  "$STAGE/whatsapp/" 2>/dev/null
    cp -f "$WA/databases/wa.db"        "$STAGE/whatsapp/" 2>/dev/null
    # backups cifrados no armazenamento compartilhado
    for d in /sdcard/WhatsApp/Databases /sdcard/Android/media/com.whatsapp/WhatsApp/Databases; do
        [ -d "$d" ] && cp -f "$d"/msgstore*.crypt* "$STAGE/whatsapp/" 2>/dev/null
    done
    log "WhatsApp coletado (key=$( [ -f "$STAGE/whatsapp/key" ] && echo sim || echo nao ))"
else
    log "WhatsApp nao instalado - pulando."
fi

# --- 5. Midia do usuario (opcional, pode ser grande) --------------------------
if [ "$INCLUDE_MEDIA" = "1" ]; then
    log "Empacotando midia de /sdcard (pode demorar)..."
    tar -cpf "$STAGE/sdcard-media.tar" \
        -C /sdcard DCIM Pictures Download Movies Music WhatsApp Android/media 2>/dev/null
fi

# --- 6. Manifesto -------------------------------------------------------------
{
    echo "arca-manifest v1"
    echo "coletado_em=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "fingerprint=$FP"
    echo "apks=$(wc -l < "$STAGE/apks.list" 2>/dev/null || echo 0)"
    echo "appdata_bytes=$(stat -c %s "$STAGE/appdata/data.tar" 2>/dev/null || echo 0)"
    echo "whatsapp_key=$( [ -f "$STAGE/whatsapp/key" ] && echo 1 || echo 0)"
    echo "media=$INCLUDE_MEDIA"
} > "$STAGE/manifest.txt"

# --- 7. Empacota tudo num tar unico para o PC puxar ---------------------------
log "Empacotando payload final..."
tar -cpf "$OUT" -C /data/local/tmp arca 2>/dev/null
chmod 0644 "$OUT" 2>/dev/null
log "Pronto: $OUT ($(du -h "$OUT" 2>/dev/null | cut -f1))"
echo "ARCA_DONE $OUT"
