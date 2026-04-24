/* ── HTML ESCAPE ── */
function esc(v) {
  return String(v)
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

/* ── MARKDOWN → HTML ── */
function md(raw) {
  if (!raw) return "";

  function inline(text) {
    // escape first, then apply inline formatting
    return esc(text)
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g,     "<em>$1</em>")
      .replace(/`(.+?)`/g,       "<code>$1</code>");
  }

  const lines = raw.split("\n");
  const out = [];
  let listTag = null;   // 'ul' | 'ol' | null
  let tableState = ""; // '' | 'head' | 'body'

  function closeList() {
    if (listTag) { out.push(`</${listTag}>`); listTag = null; }
  }
  function closeTable() {
    if (tableState === "body") out.push("</tbody>");
    if (tableState) { out.push("</table>"); tableState = ""; }
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const t = line.trim();

    // ── TABLE ──
    if (t.startsWith("|") && t.endsWith("|")) {
      closeList();
      const isSep = /^\|[\s\-:|]+\|$/.test(t);
      if (isSep) {
        // separator: close thead, open tbody
        if (tableState === "head") {
          out.push("</thead><tbody>");
          tableState = "body";
        }
        continue;
      }
      const cells = t.slice(1, -1).split("|").map(c => c.trim());
      if (!tableState) {
        out.push('<table class="md-table">');
        out.push("<thead><tr>" + cells.map(c => `<th>${inline(c)}</th>`).join("") + "</tr>");
        tableState = "head";
      } else {
        out.push("<tr>" + cells.map(c => `<td>${inline(c)}</td>`).join("") + "</tr>");
      }
      continue;
    }

    // non-table line → close table
    if (tableState) closeTable();

    // ── HR ──
    if (/^---+$/.test(t) || /^\*\*\*+$/.test(t)) {
      closeList();
      out.push("<hr>");
      continue;
    }

    // ── HEADERS ──
    if (t.startsWith("### ")) { closeList(); out.push(`<h3>${inline(t.slice(4))}</h3>`); continue; }
    if (t.startsWith("## "))  { closeList(); out.push(`<h2>${inline(t.slice(3))}</h2>`); continue; }
    if (t.startsWith("# "))   { closeList(); out.push(`<h1>${inline(t.slice(2))}</h1>`); continue; }

    // ── UNORDERED LIST ──
    if (/^[-*✓✅⚠❌] /.test(t)) {
      if (listTag !== "ul") { closeList(); out.push("<ul>"); listTag = "ul"; }
      out.push(`<li>${inline(t.replace(/^[-*✓✅⚠❌]\s/, ""))}</li>`);
      continue;
    }

    // ── ORDERED LIST ──
    if (/^\d+[.)]\s/.test(t)) {
      if (listTag !== "ol") { closeList(); out.push("<ol>"); listTag = "ol"; }
      out.push(`<li>${inline(t.replace(/^\d+[.)]\s/, ""))}</li>`);
      continue;
    }

    // ── BLANK LINE ── skip; CSS margins handle spacing
    if (t === "") { closeList(); continue; }

    // ── PARAGRAPH ──
    closeList();
    out.push(`<p>${inline(t)}</p>`);
  }

  closeList();
  closeTable();
  return out.join("\n");
}

/* ── BASIC RAG RENDERER ── */
function renderBasic(payload) {
  const sources = payload.sources || [];

  return `
    <div class="alert alert-bad">
      <strong>⚠ Sin contexto estructurado — respuesta desde PDFs genéricos</strong>
      <ul>
        <li>No verifica si la transacción o cliente existen en el sistema.</li>
        <li>Puede mezclar documentos obsoletos con los vigentes.</li>
        <li>Sin filtros de rol, confidencialidad ni vigencia de política.</li>
        <li>Chunking fijo puede fragmentar conceptos clave entre chunks.</li>
      </ul>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="icon">💬</span>
        <h2>Respuesta generada</h2>
      </div>
      <div class="answer-text md-body">${md(payload.answer)}</div>
    </div>

    ${renderSources(sources)}
  `;
}

/* ── AI-READY RAG RENDERER ── */
function renderAiReady(payload) {
  const data    = payload.structured_data || {};
  const sources = payload.sources || [];

  return `
    ${renderStructuredData(data)}

    <div class="card">
      <div class="card-header">
        <span class="icon">💬</span>
        <h2>Respuesta generada con contexto real</h2>
      </div>
      <div class="answer-text md-body">${md(payload.answer)}</div>
    </div>

    ${renderSources(sources)}
  `;
}

/* ── STRUCTURED DATA CARD ── */
function renderStructuredData(data) {
  const tx   = data.transaction;
  const prod = data.product;
  const cust = data.customer;

  if (!tx && !prod && !cust) {
    return `
      <div class="alert alert-warn">
        <strong>⚡ Sin enriquecimiento estructurado</strong>
        No se encontraron IDs de transacción (TX-NNN) o cliente (C-NNN) en la pregunta,
        o no existen en DynamoDB.
      </div>
    `;
  }

  function row(k, v) {
    if (v == null || v === "") return "";
    return `<div class="data-row"><span class="dk">${esc(k)}</span><span class="dv">${esc(String(v))}</span></div>`;
  }

  const txBlock = tx ? `
    <div class="data-group">
      <div class="data-group-title">Transacción</div>
      ${row("ID", tx.transaction_id)}
      ${row("Monto", tx.amount ? "USD " + tx.amount : null)}
      ${row("Comercio", tx.merchant)}
      ${row("Canal", tx.channel)}
      ${row("Estado", tx.status)}
      ${row("Fecha", tx.date)}
    </div>` : "";

  const prodBlock = prod ? `
    <div class="data-group">
      <div class="data-group-title">Producto</div>
      ${row("Nombre", prod.product_name)}
      ${row("Tipo", prod.product_type)}
      ${row("Estado", prod.status)}
    </div>` : "";

  const custBlock = cust ? `
    <div class="data-group">
      <div class="data-group-title">Cliente</div>
      ${row("ID", cust.customer_id)}
      ${row("Segmento", cust.segment)}
      ${row("Riesgo", cust.risk_level)}
      ${row("Consentimiento", cust.consent_status)}
    </div>` : "";

  return `
    <div class="alert alert-good">
      <strong>✓ Contexto validado desde DynamoDB</strong>
      El modelo recibió datos reales del cliente, transacción y producto —
      no solo fragmentos de texto de PDFs.
    </div>
    <div class="data-grid">
      ${txBlock}${prodBlock}${custBlock}
    </div>
  `;
}

/* ── SOURCES ── */
function renderSources(sources) {
  if (!sources || sources.length === 0) return "";
  const rows = sources.slice(0, 6).map((s) => {
    const score   = typeof s.score === "number" ? s.score.toFixed(3) : "—";
    const uri     = esc(s.source || "desconocida").split("/").pop();
    const excerpt = esc((s.excerpt || "").slice(0, 200));
    return `<tr><td>${score}</td><td><code>${uri}</code></td><td>${excerpt}</td></tr>`;
  }).join("");

  return `
    <details>
      <summary>Fragmentos recuperados (${sources.length})</summary>
      <table>
        <thead><tr><th>Score</th><th>Fuente</th><th>Fragmento</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </details>
  `;
}

/* ── API CALL ── */
async function askRag(mode, question) {
  const url = window.RAG_API_URL;
  if (!url) throw new Error("RAG_API_URL no configurado. Ejecuta terraform apply.");
  const res  = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mode, question }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error || `HTTP ${res.status}`);
  return json;
}

/* ── PRESET QUESTIONS ── */
const PRESETS = {
  "1": "El cliente C-1023 no reconoce el cargo TX-991 por USD 326.40 de ECOMMERCE_X en su tarjeta de crédito. ¿Qué pasos debe seguir el asesor y puede recomendar bloqueo preventivo?",
  "2": "La cliente C-2048 reporta que no realizó el retiro TX-445 por USD 850.00 en un ATM externo en Guayaquil. Ella vive en Quito. ¿Cómo se gestiona este caso y qué riesgo implica?",
  "3": "El cliente C-3050 fue cobrado dos veces por RESTAURANTE_A el mismo día: TX-782 y TX-783, ambos por USD 127.50. ¿Es un doble cobro y cómo procede el banco?"
};

/* ── WIRE ── */
function wireDemo() {
  const btn      = document.querySelector("[data-mode][data-target]");
  const textarea = document.querySelector("#question");
  if (!btn || !textarea) return;

  const mode      = btn.dataset.mode;
  const resultsEl = document.getElementById(btn.dataset.target);

  document.querySelectorAll(".preset-btn").forEach((pb) => {
    pb.addEventListener("click", () => {
      const q = PRESETS[pb.dataset.q];
      if (q) textarea.value = q;
      document.querySelectorAll(".preset-btn").forEach((x) => x.classList.remove("active"));
      pb.classList.add("active");
      resultsEl.classList.add("hidden");
      resultsEl.innerHTML = "";
    });
  });

  btn.addEventListener("click", async () => {
    const question = textarea.value.trim();
    if (!question) return;

    btn.disabled    = true;
    btn.textContent = "Consultando…";
    resultsEl.classList.remove("hidden");
    resultsEl.innerHTML = `
      <div class="loading">
        <div class="spinner"></div>
        Consultando Knowledge Base y generando respuesta…
      </div>
    `;

    try {
      const payload = await askRag(mode, question);
      resultsEl.innerHTML = mode === "basic"
        ? renderBasic(payload)
        : renderAiReady(payload);
    } catch (err) {
      resultsEl.innerHTML = `
        <div class="alert alert-bad">
          <strong>Error — </strong>${esc(err.message)}
        </div>
      `;
    } finally {
      btn.disabled    = false;
      btn.textContent = mode === "basic" ? "Consultar RAG Común" : "Consultar AI-Ready RAG";
    }
  });
}

wireDemo();
