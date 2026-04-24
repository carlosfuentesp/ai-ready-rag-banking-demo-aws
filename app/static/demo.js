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
    return esc(text)
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g,     "<em>$1</em>")
      .replace(/`(.+?)`/g,       "<code>$1</code>");
  }

  const lines = raw.split("\n");
  const out = [];
  let listTag = null;
  let tableState = "";

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

    if (t.startsWith("|") && t.endsWith("|")) {
      closeList();
      const isSep = /^\|[\s\-:|]+\|$/.test(t);
      if (isSep) {
        if (tableState === "head") { out.push("</thead><tbody>"); tableState = "body"; }
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

    if (tableState) closeTable();

    if (/^---+$/.test(t) || /^\*\*\*+$/.test(t)) { closeList(); out.push("<hr>"); continue; }
    if (t.startsWith("### ")) { closeList(); out.push(`<h3>${inline(t.slice(4))}</h3>`); continue; }
    if (t.startsWith("## "))  { closeList(); out.push(`<h2>${inline(t.slice(3))}</h2>`); continue; }
    if (t.startsWith("# "))   { closeList(); out.push(`<h1>${inline(t.slice(2))}</h1>`); continue; }

    if (/^[-*✓✅⚠❌] /.test(t)) {
      if (listTag !== "ul") { closeList(); out.push("<ul>"); listTag = "ul"; }
      out.push(`<li>${inline(t.replace(/^[-*✓✅⚠❌]\s/, ""))}</li>`);
      continue;
    }
    if (/^\d+[.)]\s/.test(t)) {
      if (listTag !== "ol") { closeList(); out.push("<ol>"); listTag = "ol"; }
      out.push(`<li>${inline(t.replace(/^\d+[.)]\s/, ""))}</li>`);
      continue;
    }

    if (t === "") { closeList(); continue; }
    closeList();
    out.push(`<p>${inline(t)}</p>`);
  }

  closeList();
  closeTable();
  return out.join("\n");
}

/* ── RENDERERS ── */
function renderBasic(payload) {
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
      <div class="card-header"><span class="icon">💬</span><h2>Respuesta generada</h2></div>
      <div class="answer-text md-body">${md(payload.answer)}</div>
    </div>
    ${renderSources(payload.sources)}
  `;
}

function renderAiReady(payload) {
  return `
    ${renderStructuredData(payload.structured_data || {})}
    ${renderGraphContext(payload.graph_context || {})}
    <div class="card">
      <div class="card-header"><span class="icon">💬</span><h2>Respuesta generada con contexto real</h2></div>
      <div class="answer-text md-body">${md(payload.answer)}</div>
    </div>
    ${renderSources(payload.sources)}
  `;
}

function renderGraphContext(graph) {
  const edges = graph.edges || [];
  const lineage = graph.lineage_events || [];
  if (!edges.length && !lineage.length) return "";

  const edgeRows = edges.slice(0, 10).map((edge) => `
    <tr>
      <td><code>${esc(edge.source)}</code></td>
      <td>${esc(edge.relation)}</td>
      <td><code>${esc(edge.target)}</code></td>
    </tr>
  `).join("");
  const lineageRows = lineage.slice(0, 5).map((event) => `
    <tr>
      <td><code>${esc(event.event_id)}</code></td>
      <td>${esc(event.event_type)}</td>
      <td>${esc((event.outputs || []).slice(0, 4).join(", "))}</td>
    </tr>
  `).join("");

  return `
    <div class="card">
      <div class="card-header"><span class="icon">🕸</span><h2>GraphRAG y lineage</h2></div>
      <div class="split-tables">
        <div>
          <h3>Relaciones usadas</h3>
          <table><thead><tr><th>Origen</th><th>Relación</th><th>Destino</th></tr></thead><tbody>${edgeRows}</tbody></table>
        </div>
        <div>
          <h3>Eventos de lineage</h3>
          <table><thead><tr><th>Evento</th><th>Tipo</th><th>Salidas</th></tr></thead><tbody>${lineageRows}</tbody></table>
        </div>
      </div>
    </div>
  `;
}

function renderStructuredData(data) {
  const { transaction: tx, product: prod, customer: cust } = data;

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
    <div class="data-grid">${txBlock}${prodBlock}${custBlock}</div>
  `;
}

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

/* ── API ── */
async function askRag(mode, question, customerId = null) {
  const url = window.RAG_API_URL;
  if (!url) throw new Error("RAG_API_URL no configurado. Ejecuta terraform apply.");
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mode, question, ...(customerId ? { customer_id: customerId } : {}) }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error || `HTTP ${res.status}`);
  return json;
}

/* ── PRESETS ── */
const PRESETS = {
  "1": "No reconozco el cargo TX-991 por USD 326.40 de ECOMMERCE_X en mi tarjeta de crédito. ¿Qué pasos debo seguir y pueden bloquear mi tarjeta?",
  "2": "No realicé el retiro TX-445 por USD 850.00 en un ATM en Guayaquil. Yo vivo en Quito. ¿Cómo reporto esto y qué riesgo tiene mi cuenta?",
  "3": "Veo dos cargos de TX-782 del mismo restaurante el mismo día por USD 127.50 cada uno. ¿Es un doble cobro y cómo procede el banco?"
};

/* ── SESSION ── */
function getSession() {
  return JSON.parse(sessionStorage.getItem("demo_session") || "null");
}

function initSession() {
  const session = getSession();
  if (!session) { window.location.href = "login.html"; return null; }

  const badge = document.getElementById("session-badge");
  const logoutBtn = document.getElementById("logout-btn");
  if (badge) {
    badge.textContent = "👤 " + session.name + " · " + session.segment;
    badge.classList.remove("hidden");
  }
  if (logoutBtn) {
    logoutBtn.classList.remove("hidden");
    logoutBtn.addEventListener("click", () => {
      sessionStorage.removeItem("demo_session");
      window.location.href = "login.html";
    });
  }

  const ctx = document.getElementById("session-context");
  if (ctx) {
    ctx.innerHTML = `
      <div class="session-info">
        <span class="session-icon">🔐</span>
        <div>
          <strong>${esc(session.name)}</strong>
          <span class="session-meta">Sesión activa · ${esc(session.segment)} · Riesgo ${esc(session.risk)} · ID: <code>${esc(session.customer_id)}</code></span>
        </div>
        <span class="session-note">El sistema usará tu perfil automáticamente</span>
      </div>
    `;
    ctx.classList.remove("hidden");
  }

  return session;
}

/* ── PAGE SETUP (rag.html) ── */
function setupRagPage(mode) {
  const isAiReady = mode === "ai-ready";

  document.title = isAiReady ? "AI-Ready RAG" : "RAG Común";
  document.getElementById("page-title").textContent = document.title;

  const navBasic   = document.getElementById("nav-basic");
  const navAiReady = document.getElementById("nav-aiready");
  if (navBasic)   navBasic.setAttribute("aria-current",   isAiReady ? "false" : "page");
  if (navAiReady) navAiReady.setAttribute("aria-current", isAiReady ? "page"  : "false");

  const header = document.getElementById("page-header");
  if (header) {
    if (isAiReady) {
      header.innerHTML = `
        <span class="mode-badge mode-good">AI-Ready RAG</span>
        <h1>GraphRAG con datos AI-Ready</h1>
        <p class="subtitle">El sistema usa <strong>Bedrock GraphRAG sobre Neptune Analytics</strong>, DynamoDB, lineage y contexto de sesión antes de responder.</p>
      `;
    } else {
      header.innerHTML = `
        <span class="mode-badge mode-bad">RAG Común</span>
        <h1>Respuesta desde PDFs sin preparación</h1>
        <p class="subtitle">El sistema <strong>no sabe quién estás logueado</strong>. Solo busca en documentos con chunking fijo.</p>
      `;
    }
  }

  const warning = document.getElementById("mode-warning");
  if (warning && !isAiReady) {
    warning.innerHTML = `
      <div class="alert alert-warn" style="margin-bottom:0">
        <strong>⚠ Sin acceso a datos de sesión</strong>
        Este modo no puede consultar tu perfil, transacciones ni productos. Responde desde PDFs genéricos — sin saber quién eres ni si la transacción que mencionas existe realmente en el sistema.
      </div>
    `;
  }

  const btn = document.getElementById("query-btn");
  if (btn) {
    btn.dataset.mode   = mode;
    btn.dataset.target = "results";
    btn.textContent    = isAiReady ? "Consultar AI-Ready RAG" : "Consultar RAG Común";
    if (isAiReady) btn.classList.add("btn-query--good");
  }

  const ctx = document.getElementById("session-context");
  if (ctx && !isAiReady) ctx.remove();
}

/* ── WIRE ── */
function wireDemo() {
  const params = new URLSearchParams(window.location.search);
  const mode   = params.get("mode") === "ai-ready" ? "ai-ready" : "basic";

  if (document.getElementById("page-header")) setupRagPage(mode);

  const session    = initSession();
  const btn        = document.getElementById("query-btn");
  const textarea   = document.getElementById("question");
  const resultsEl  = document.getElementById("results");
  if (!btn || !textarea || !resultsEl) return;

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
    resultsEl.innerHTML = `<div class="loading"><div class="spinner"></div>Consultando Knowledge Base y generando respuesta…</div>`;

    try {
      const customerId = (mode === "ai-ready" && session) ? session.customer_id : null;
      const payload = await askRag(mode, question, customerId);
      resultsEl.innerHTML = mode === "basic" ? renderBasic(payload) : renderAiReady(payload);
    } catch (err) {
      resultsEl.innerHTML = `<div class="alert alert-bad"><strong>Error — </strong>${esc(err.message)}</div>`;
    } finally {
      btn.disabled    = false;
      btn.textContent = mode === "basic" ? "Consultar RAG Común" : "Consultar AI-Ready RAG";
    }
  });
}

wireDemo();
