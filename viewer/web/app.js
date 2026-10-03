/* Arca - Visualizador  |  Autor: Joaquim Pedro de Morais Filho <j360074@hotmail.com>
   Carrega messages.json (gerado por arca-export.py) e renderiza a timeline. */
(function () {
  "use strict";
  let DATA = { data: [] };
  let current = null;

  const $ = (id) => document.getElementById(id);

  function fmt(ts) {
    if (!ts) return "";
    // WhatsApp grava timestamp em milissegundos
    const d = new Date(ts > 1e12 ? ts : ts * 1000);
    if (isNaN(d)) return "";
    return d.toLocaleString("pt-BR");
  }

  function renderList(filter) {
    const ul = $("chatlist");
    ul.innerHTML = "";
    const f = (filter || "").toLowerCase();
    DATA.data
      .filter((c) => !f || (c.name || c.jid).toLowerCase().includes(f))
      .forEach((c, i) => {
        const li = document.createElement("li");
        if (c === current) li.className = "active";
        const last = c.messages[c.messages.length - 1];
        li.innerHTML =
          '<div class="name"></div><div class="meta"></div>';
        li.querySelector(".name").textContent = c.name || c.jid;
        li.querySelector(".meta").textContent =
          (last ? (last.from_me ? "Você: " : "") + (last.text || "[mídia]") : "") +
          " · " + c.messages.length + " msgs";
        li.onclick = () => selectChat(c);
        ul.appendChild(li);
      });
  }

  function selectChat(c) {
    current = c;
    $("convhead").textContent = (c.name || c.jid) + "  (" + c.messages.length + " mensagens)";
    const box = $("messages");
    box.innerHTML = "";
    c.messages.forEach((m) => {
      const div = document.createElement("div");
      div.className = "bubble " + (m.from_me ? "me" : "them");
      const txt = document.createElement("span");
      txt.textContent = m.text && m.text.length ? m.text : "[mídia / sem texto]";
      const time = document.createElement("span");
      time.className = "time";
      time.textContent = fmt(m.timestamp);
      div.appendChild(txt);
      div.appendChild(time);
      box.appendChild(div);
    });
    renderList($("filter").value);
    box.scrollTop = 0;
  }

  function boot() {
    fetch("messages.json")
      .then((r) => {
        if (!r.ok) throw new Error("messages.json nao encontrado");
        return r.json();
      })
      .then((j) => {
        DATA = j;
        $("stats").textContent =
          (j.chats || DATA.data.length) + " conversas · " + (j.messages || 0) + " mensagens";
        renderList("");
        if (!DATA.data.length) {
          $("messages").innerHTML = '<div class="empty">Nenhuma conversa no backup.</div>';
        }
      })
      .catch((e) => {
        $("stats").textContent = "erro";
        $("messages").innerHTML =
          '<div class="empty">Não foi possível carregar messages.json.<br>' +
          "Rode o visualizador via <code>arca-viewer.ps1</code> (servidor local) " +
          "e gere o JSON com <code>arca-export.py</code>.<br><small>" +
          e.message + "</small></div>";
      });
    $("filter").addEventListener("input", (e) => renderList(e.target.value));
  }

  document.addEventListener("DOMContentLoaded", boot);
})();
