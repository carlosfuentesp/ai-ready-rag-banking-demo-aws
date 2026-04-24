function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function renderSources(sources) {
  if (!sources || sources.length === 0) {
    return "<p>No se devolvieron fuentes recuperadas.</p>";
  }
  const rows = sources
    .slice(0, 6)
    .map((source) => {
      const score = typeof source.score === "number" ? source.score.toFixed(4) : "";
      const uri = escapeHtml(source.source || "unknown");
      const excerpt = escapeHtml(source.excerpt || "");
      return `<tr><td>${score}</td><td><code>${uri}</code></td><td>${excerpt}</td></tr>`;
    })
    .join("");
  return `
    <h3>Fuentes recuperadas</h3>
    <table>
      <thead><tr><th>Score</th><th>Fuente</th><th>Extracto</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function renderStructuredData(data) {
  if (!data || (!data.transaction && !data.product && !data.customer)) {
    return "";
  }
  return `
    <h3>Datos estructurados validados</h3>
    <pre>${escapeHtml(JSON.stringify(data, null, 2))}</pre>
  `;
}

async function askRag(mode, question) {
  const apiUrl = window.RAG_API_URL;
  if (!apiUrl) {
    throw new Error("No se encontró config.js con window.RAG_API_URL. Vuelve a ejecutar terraform apply para publicar la configuración runtime.");
  }
  const response = await fetch(apiUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mode, question }),
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.error || `HTTP ${response.status}`);
  }
  return payload;
}

function wireDemo() {
  const button = document.querySelector("[data-mode][data-target]");
  const textarea = document.querySelector("#question");
  if (!button || !textarea) return;

  button.addEventListener("click", async () => {
    const target = document.getElementById(button.dataset.target);
    const originalText = button.textContent;
    button.disabled = true;
    button.textContent = "Consultando...";
    target.innerHTML = "<p>Consultando Knowledge Base y modelo Bedrock...</p>";

    try {
      const payload = await askRag(button.dataset.mode, textarea.value);
      target.innerHTML = `
        <div class="answer-text">${escapeHtml(payload.answer).replaceAll("\n", "<br />")}</div>
        ${renderStructuredData(payload.structured_data)}
        ${renderSources(payload.sources)}
      `;
    } catch (error) {
      target.innerHTML = `<p class="bad"><strong>Error:</strong> ${escapeHtml(error.message)}</p>`;
    } finally {
      button.disabled = false;
      button.textContent = originalText;
    }
  });
}

wireDemo();
