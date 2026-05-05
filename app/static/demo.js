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
    ${renderTrustChecklist("basic", payload)}
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
    ${renderTrustChecklist("ai-ready", payload)}
    ${renderStructuredData(payload.structured_data || {})}
    ${renderGraphMap(payload.graph_context || {})}
    ${renderGraphContext(payload.graph_context || {})}
    <div class="card">
      <div class="card-header"><span class="icon">💬</span><h2>Respuesta generada con contexto real</h2></div>
      <div class="answer-text md-body">${md(payload.answer)}</div>
    </div>
    ${renderActionPanel(payload)}
    ${renderSources(payload.sources)}
  `;
}

function renderTrustChecklist(mode, payload) {
  const structured = payload.structured_data || {};
  const graph = payload.graph_context || {};
  const checks = mode === "basic" ? [
    ["Transacción validada", false],
    ["Producto correcto", false],
    ["Vigencia y rol aplicados", false],
    ["PII protegida", false],
    ["Lineage visible", false],
    ["Acción con confirmación", false],
  ] : [
    ["Transacción validada", Boolean(structured.transaction)],
    ["Producto correcto", Boolean(structured.product)],
    ["Vigencia y rol aplicados", true],
    ["PII protegida", Boolean(structured.customer)],
    ["Lineage visible", Boolean((graph.lineage_events || []).length)],
    ["Acción con confirmación", true],
  ];

  return `
    <div class="trust-card ${mode === "basic" ? "trust-card-bad" : "trust-card-good"}">
      ${checks.map(([label, ok]) => `
        <div class="trust-item ${ok ? "trust-ok" : "trust-fail"}">
          <span>${ok ? "✓" : "!"}</span>
          <strong>${esc(label)}</strong>
        </div>
      `).join("")}
    </div>
  `;
}

function renderGraphMap(graph) {
  const edges = (graph.edges || []).slice(0, 8);
  if (!edges.length) return "";
  const nodes = [];
  edges.forEach((edge) => {
    if (!nodes.includes(edge.source)) nodes.push(edge.source);
    if (!nodes.includes(edge.target)) nodes.push(edge.target);
  });
  const nodeItems = nodes.slice(0, 9).map((node, index) => `
    <div class="graph-node graph-node-${index % 5}">${esc(node)}</div>
  `).join("");

  return `
    <div class="card graph-map-card">
      <div class="card-header"><span class="icon">◎</span><h2>Mapa de razonamiento</h2></div>
      <div class="graph-map">${nodeItems}</div>
    </div>
  `;
}

function renderGraphContext(graph) {
  const edges = graph.edges || [];
  const lineage = graph.lineage_events || [];
  if (!edges.length && !lineage.length) return "";

  const relationItems = edges.slice(0, 10).map((edge) => `
    <li class="graph-relation">
      <code>${esc(edge.source)}</code>
      <span>${esc(edge.relation)}</span>
      <code>${esc(edge.target)}</code>
    </li>
  `).join("");

  const lineageItems = lineage.slice(0, 5).map((event) => {
    const outputs = event.outputs || [];
    const outputChips = outputs.slice(0, 6).map((output) => `<code>${esc(output)}</code>`).join("");
    const remaining = outputs.length > 6 ? `<span class="more-chip">+${outputs.length - 6}</span>` : "";
    return `
      <li class="lineage-event">
        <div class="lineage-main">
          <code>${esc(event.event_id)}</code>
          <span>${esc(event.event_type)}</span>
        </div>
        <div class="lineage-outputs">${outputChips}${remaining}</div>
      </li>
    `;
  }).join("");

  const relationCount = edges.length > 10 ? `<span class="graph-count">+${edges.length - 10} más</span>` : "";
  const lineageCount = lineage.length > 5 ? `<span class="graph-count">+${lineage.length - 5} más</span>` : "";

  const relationsPanel = relationItems ? `
    <section class="graph-panel">
      <div class="graph-panel-title">Relaciones usadas ${relationCount}</div>
      <ul class="graph-list">${relationItems}</ul>
    </section>
  ` : "";

  const lineagePanel = lineageItems ? `
    <section class="graph-panel">
      <div class="graph-panel-title">Eventos de lineage ${lineageCount}</div>
      <ul class="lineage-list">${lineageItems}</ul>
    </section>
  ` : "";

  return `
    <div class="card">
      <div class="card-header"><span class="icon">🕸</span><h2>GraphRAG y lineage</h2></div>
      <div class="graph-context-grid">
        ${relationsPanel}
        ${lineagePanel}
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

function actionContext(payload) {
  const data = payload.structured_data || {};
  const tx = data.transaction || {};
  const product = data.product || {};
  const customer = data.customer || {};
  return {
    customer_id: customer.customer_id || tx.customer_id || null,
    transaction_id: tx.transaction_id || null,
    product_id: product.product_id || tx.product_id || "P-TC-001",
  };
}

function renderActionPanel(payload) {
  const ctx = actionContext(payload);
  if (!ctx.customer_id || !ctx.transaction_id) return "";
  return `
    <div class="card action-card">
      <div class="card-header"><span class="icon">✓</span><h2>Acciones agentic con confirmación</h2></div>
      <div class="action-summary">
        <span>Cliente <code>${esc(ctx.customer_id)}</code></span>
        <span>Transacción <code>${esc(ctx.transaction_id)}</code></span>
        <span>Producto <code>${esc(ctx.product_id)}</code></span>
      </div>
      <div class="action-buttons">
        <button class="btn-query btn-action" type="button" data-action="claim" data-customer="${esc(ctx.customer_id)}" data-transaction="${esc(ctx.transaction_id)}" data-product="${esc(ctx.product_id)}">Crear caso</button>
        <button class="btn-query btn-query--good btn-action" type="button" data-action="block" data-customer="${esc(ctx.customer_id)}" data-transaction="${esc(ctx.transaction_id)}" data-product="${esc(ctx.product_id)}">Solicitar bloqueo</button>
      </div>
      <p class="action-note">Nada se ejecuta automáticamente: la acción requiere confirmación humana y queda auditada.</p>
    </div>
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

async function postJson(url, body) {
  if (!url) throw new Error("Endpoint no configurado. Ejecuta terraform apply.");
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error || `HTTP ${res.status}`);
  return json;
}

async function executeAction(action, ctx) {
  const session = getSession() || {};
  if (action === "claim") {
    return postJson(window.CREATE_CLAIM_API_URL, {
      customer_id: ctx.customer,
      transaction_id: ctx.transaction,
      requested_by: session.username || session.name || "demo-user",
    });
  }
  return postJson(window.REQUEST_CARD_BLOCK_API_URL, {
    customer_id: ctx.customer,
    product_id: ctx.product,
    requested_by: session.username || session.name || "demo-user",
    confirmation_token: `confirm-${Date.now()}`,
  });
}

function showModal(action, ctx) {
  const modal = document.getElementById("confirm-modal");
  if (!modal) return;
  const isClaim = action === "claim";
  modal.innerHTML = `
    <div class="modal-card">
      <h2>${isClaim ? "Crear caso de reclamo" : "Solicitar bloqueo preventivo"}</h2>
      <p>Esta acción requiere confirmación humana y registrará auditoría.</p>
      <div class="modal-facts">
        <span>Cliente <code>${esc(ctx.customer)}</code></span>
        <span>Transacción <code>${esc(ctx.transaction)}</code></span>
        <span>Producto <code>${esc(ctx.product)}</code></span>
      </div>
      <div id="modal-result" class="modal-result hidden"></div>
      <div class="modal-actions">
        <button class="btn-logout" type="button" data-modal-close>Cancelar</button>
        <button class="btn-query ${isClaim ? "" : "btn-query--good"}" type="button" data-modal-confirm>Confirmar</button>
      </div>
    </div>
  `;
  modal.classList.remove("hidden");
  modal.querySelector("[data-modal-close]").addEventListener("click", () => modal.classList.add("hidden"));
  modal.querySelector("[data-modal-confirm]").addEventListener("click", async (event) => {
    const btn = event.currentTarget;
    const resultEl = modal.querySelector("#modal-result");
    btn.disabled = true;
    btn.textContent = "Ejecutando...";
    resultEl.className = "modal-result";
    resultEl.textContent = "Registrando acción auditada...";
    try {
      const result = await executeAction(action, ctx);
      resultEl.className = "modal-result modal-success";
      resultEl.innerHTML = isClaim
        ? `Caso creado: <code>${esc(result.case_id)}</code><br>Auditoría: <code>${esc(result.audit_id)}</code>`
        : `Bloqueo solicitado: <code>${esc(result.block_request_status)}</code><br>Auditoría: <code>${esc(result.audit_id)}</code>`;
    } catch (err) {
      resultEl.className = "modal-result modal-error";
      resultEl.textContent = err.message;
      btn.disabled = false;
      btn.textContent = "Confirmar";
    }
  });
}

/* ── PRESETS ── */
const PRESETS = {
  "1": "No reconozco el cargo TX-991 por USD 326.40 de ECOMMERCE_X en mi tarjeta de crédito. ¿El banco puede abrir un reclamo y bloquear preventivamente la tarjeta? Indica qué documentos necesito, qué mensaje puedo dar al cliente y qué parte requiere confirmación humana.",
  "2": "Tengo una tarjeta de crédito, pero también vi una política de reclamos de cuenta de ahorros. Para el cargo TX-991, ¿debo seguir el procedimiento de cuenta de ahorros o el de tarjeta de crédito? Explica con fuentes vigentes.",
  "3": "Para decidir si apruebo el reclamo TX-991, muéstrame la matriz interna de riesgo, el score de contracargo y el umbral exacto de fraude que usa el banco."
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

function renderWowScoreboard(basicPayload, aiPayload) {
  const aiStructured = aiPayload.structured_data || {};
  const aiGraph = aiPayload.graph_context || {};
  const rows = [
    ["Valida transacción", "No", aiStructured.transaction ? "Sí" : "No"],
    ["Usa producto correcto", "No", aiStructured.product ? "Sí" : "No"],
    ["Recorre knowledge graph", "No", (aiGraph.edges || []).length ? "Sí" : "No"],
    ["Muestra lineage", "No", (aiGraph.lineage_events || []).length ? "Sí" : "No"],
    ["Acción auditada", "No", aiStructured.transaction ? "Lista para confirmar" : "No"],
  ];
  return `
    <div class="wow-card">
      <div>
        <span class="mode-badge mode-good">Momento WOW</span>
        <h2>AI-Ready Data convierte una pregunta en una decisión controlada</h2>
      </div>
      <div class="wow-grid">
        ${rows.map(([label, basic, ai]) => `
          <div class="wow-row">
            <strong>${esc(label)}</strong>
            <span class="wow-bad">${esc(basic)}</span>
            <span class="wow-good">${esc(ai)}</span>
          </div>
        `).join("")}
      </div>
      <div class="wow-footnote">Basic recuperó ${basicPayload.retrieval_count || 0} fragmentos; AI-Ready recuperó ${aiPayload.retrieval_count || 0} fragmentos y añadió contexto operacional.</div>
    </div>
  `;
}

function attachPresetHandlers(textarea, reset) {
  document.querySelectorAll(".preset-btn").forEach((pb) => {
    pb.addEventListener("click", () => {
      const q = PRESETS[pb.dataset.q];
      if (q) textarea.value = q;
      document.querySelectorAll(".preset-btn").forEach((x) => x.classList.remove("active"));
      pb.classList.add("active");
      reset();
    });
  });
}

function wireActions() {
  document.addEventListener("click", (event) => {
    const btn = event.target.closest(".btn-action");
    if (!btn) return;
    showModal(btn.dataset.action, {
      customer: btn.dataset.customer,
      transaction: btn.dataset.transaction,
      product: btn.dataset.product,
    });
  });
}

function wireComparePage(session) {
  const btn = document.getElementById("compare-btn");
  const textarea = document.getElementById("question");
  const basicEl = document.getElementById("basic-results");
  const aiEl = document.getElementById("ai-ready-results");
  const scoreboard = document.getElementById("wow-scoreboard");
  if (!btn || !textarea || !basicEl || !aiEl || !scoreboard) return false;

  attachPresetHandlers(textarea, () => {
    basicEl.innerHTML = "";
    aiEl.innerHTML = "";
    scoreboard.classList.add("hidden");
    scoreboard.innerHTML = "";
  });

  btn.addEventListener("click", async () => {
    const question = textarea.value.trim();
    if (!question) return;

    btn.disabled = true;
    btn.textContent = "Comparando...";
    scoreboard.classList.add("hidden");
    basicEl.innerHTML = `<div class="loading"><div class="spinner"></div>Consultando RAG común...</div>`;
    aiEl.innerHTML = `<div class="loading"><div class="spinner"></div>Consultando AI-Ready RAG...</div>`;

    try {
      const [basicPayload, aiPayload] = await Promise.all([
        askRag("basic", question),
        askRag("ai-ready", question, session.customer_id),
      ]);
      basicEl.innerHTML = renderBasic(basicPayload);
      aiEl.innerHTML = renderAiReady(aiPayload);
      scoreboard.innerHTML = renderWowScoreboard(basicPayload, aiPayload);
      scoreboard.classList.remove("hidden");
    } catch (err) {
      basicEl.innerHTML = `<div class="alert alert-bad"><strong>Error — </strong>${esc(err.message)}</div>`;
      aiEl.innerHTML = "";
    } finally {
      btn.disabled = false;
      btn.textContent = "Comparar ambos RAGs";
    }
  });

  return true;
}

/* ── WIRE ── */
function wireDemo() {
  const params = new URLSearchParams(window.location.search);
  const mode   = params.get("mode") === "ai-ready" ? "ai-ready" : "basic";

  if (document.getElementById("page-header")) setupRagPage(mode);

  const session    = initSession();
  if (!session) return;
  wireActions();
  if (wireComparePage(session)) return;

  const btn        = document.getElementById("query-btn");
  const textarea   = document.getElementById("question");
  const resultsEl  = document.getElementById("results");
  if (!btn || !textarea || !resultsEl) return;

  attachPresetHandlers(textarea, () => {
    resultsEl.classList.add("hidden");
    resultsEl.innerHTML = "";
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
