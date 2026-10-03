#!/usr/bin/env python3
"""
arca-export.py - Exporta o msgstore.db do WhatsApp para JSON (timeline do visualizador)
Projeto: Arca - Cofre de Recuperacao Android
Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
Licenca: MIT

Detecta os dois esquemas comuns do WhatsApp:
  - novo:   tabelas message / chat / jid
  - antigo: tabela messages (key_remote_jid, data, ...)
Gera um JSON uniforme consumido por viewer/web/index.html.

Uso:
  python arca-export.py msgstore.db -o web/messages.json [--contacts wa.db]
"""
import argparse, json, sqlite3, sys, os


def table_exists(cur, name):
    cur.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,))
    return cur.fetchone() is not None


def load_contacts(path):
    names = {}
    if not path or not os.path.exists(path):
        return names
    try:
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        cur = con.cursor()
        if table_exists(cur, "wa_contacts"):
            cur.execute("SELECT jid, COALESCE(display_name, wa_name, number) FROM wa_contacts")
            for jid, name in cur.fetchall():
                if jid and name:
                    names[jid] = name
        con.close()
    except Exception as e:
        print(f"[arca] aviso: nao consegui ler contatos: {e}", file=sys.stderr)
    return names


def export_modern(cur, contacts):
    chats = {}
    cur.execute("""
        SELECT j.user || '@' || j.server AS jid,
               m.from_me, m.timestamp, m.text_data, m.message_type
        FROM message m
        JOIN chat c ON m.chat_row_id = c._id
        JOIN jid  j ON c.jid_row_id  = j._id
        ORDER BY m.timestamp ASC
    """)
    for jid, from_me, ts, text, mtype in cur.fetchall():
        name = contacts.get(jid, jid)
        chats.setdefault(jid, {"jid": jid, "name": name, "messages": []})
        chats[jid]["messages"].append({
            "from_me": bool(from_me),
            "timestamp": ts,
            "text": text or "",
            "type": mtype,
        })
    return list(chats.values())


def export_legacy(cur, contacts):
    chats = {}
    cur.execute("""
        SELECT key_remote_jid, key_from_me, timestamp, data, media_wa_type, media_caption
        FROM messages
        ORDER BY timestamp ASC
    """)
    for jid, from_me, ts, data, mtype, caption in cur.fetchall():
        if not jid:
            continue
        name = contacts.get(jid, jid)
        chats.setdefault(jid, {"jid": jid, "name": name, "messages": []})
        chats[jid]["messages"].append({
            "from_me": bool(from_me),
            "timestamp": ts,
            "text": data if data else (caption or ""),
            "type": mtype,
        })
    return list(chats.values())


def main():
    ap = argparse.ArgumentParser(description="Exporta msgstore.db para JSON")
    ap.add_argument("db", help="msgstore.db descriptografado")
    ap.add_argument("-o", "--out", default="web/messages.json")
    ap.add_argument("--contacts", help="wa.db para nomes de contato")
    args = ap.parse_args()

    if not os.path.exists(args.db):
        sys.exit(f"[arca] erro: banco nao encontrado: {args.db}")

    contacts = load_contacts(args.contacts)
    con = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    cur = con.cursor()

    if table_exists(cur, "message") and table_exists(cur, "chat") and table_exists(cur, "jid"):
        print("[arca] esquema novo (message/chat/jid)")
        chats = export_modern(cur, contacts)
    elif table_exists(cur, "messages"):
        print("[arca] esquema antigo (messages)")
        chats = export_legacy(cur, contacts)
    else:
        con.close()
        sys.exit("[arca] erro: esquema do msgstore.db nao reconhecido.")
    con.close()

    chats.sort(key=lambda c: c["messages"][-1]["timestamp"] if c["messages"] else 0, reverse=True)
    total = sum(len(c["messages"]) for c in chats)
    payload = {
        "generator": "Arca - Cofre de Recuperacao Android",
        "author": "Joaquim Pedro de Morais Filho <j360074@hotmail.com>",
        "chats": len(chats),
        "messages": total,
        "data": chats,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)
    print(f"[arca] exportado: {args.out}  ({len(chats)} conversas, {total} mensagens)")


if __name__ == "__main__":
    main()
