const KNOWN_PATTERNS = {
  mainCase: ["c-1023", "tx-991", "326.40", "consumo no reconocido"],
  policy: ["política", "vigente", "tarjeta", "2025"],
  confidentiality: ["matriz", "riesgo", "score", "umbral"],
};

function normalize(text) {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function hasAny(text, terms) {
  return terms.some((term) => text.includes(normalize(term)));
}

function classifyQuestion(question) {
  const text = normalize(question);
  if (hasAny(text, KNOWN_PATTERNS.mainCase)) return "mainCase";
  if (hasAny(text, KNOWN_PATTERNS.policy)) return "policy";
  if (hasAny(text, KNOWN_PATTERNS.confidentiality)) return "confidentiality";
  return "outOfContext";
}

function basicAnswer(kind) {
  if (kind === "outOfContext") {
    return `
      <p>No encuentro una fuente clara en los documentos recuperados para responder con precisión. La búsqueda trae fragmentos bancarios genéricos, pero no evidencia suficiente para esta pregunta.</p>
      <p class="bad"><strong>Riesgo del RAG común:</strong> sin filtros ni grounding fuerte, este enfoque podría intentar completar la respuesta con información no sustentada.</p>
    `;
  }
  if (kind === "policy") {
    return `
      <p>Los documentos recuperados mencionan políticas y tarifarios de reclamos. Podría aplicar la política de reclamos de tarjeta y usar el tarifario para plazos.</p>
      <p class="bad"><strong>Falla:</strong> la recuperación mezcla documentos vigentes y obsoletos, por lo que puede sugerir plazos reemplazados.</p>
    `;
  }
  if (kind === "confidentiality") {
    return `
      <p>La matriz interna de riesgo aparece entre las fuentes y contiene criterios de contracargo, score y umbrales operativos.</p>
      <p class="bad"><strong>Falla:</strong> esta respuesta expone contenido restringido que no debería compartirse con el cliente.</p>
    `;
  }
  return `
    <p>Con base en los documentos encontrados, el asesor debería abrir un reclamo, bloquear la tarjeta y explicar al cliente los criterios internos de contracargo. Puede usar el tarifario y política recuperados para definir plazos.</p>
    <p class="bad"><strong>Advertencia:</strong> esta respuesta mezcla fuentes y no aplica controles de vigencia, permisos ni validación transaccional.</p>
  `;
}

function aiReadyAnswer(kind) {
  if (kind === "outOfContext") {
    return `
      <p>No tengo información suficiente en las fuentes sintéticas disponibles para responder esa pregunta.</p>
      <p class="good"><strong>Control aplicado:</strong> la respuesta queda limitada al dominio de reclamos por consumo no reconocido en tarjeta de crédito.</p>
    `;
  }
  if (kind === "policy") {
    return `
      <p>Para un reclamo por consumo no reconocido en tarjeta de crédito en 2025, la política vigente aplicable es <code>POL-RECLAMOS-TC-V3</code>.</p>
      <p>Los plazos están complementados por <code>CIRCULAR-PLAZOS-2025</code>, que actualiza el plazo referencial a 15 días laborables.</p>
    `;
  }
  if (kind === "confidentiality") {
    return `
      <p>No. Un asesor no debe compartir la matriz interna de riesgo, score de contracargo, umbral de fraude ni reglas operativas restringidas con el cliente.</p>
      <p>Puede comunicar el procedimiento general, documentos requeridos, plazo referencial y canales de seguimiento.</p>
    `;
  }
  return `
    <p>El consumo <code>TX-991</code> corresponde a tarjeta de crédito, monto <code>USD 326.40</code>, comercio <code>ECOMMERCE_X</code>, canal online y estado <code>posted</code>. Aplica el flujo de consumo no reconocido.</p>
    <p>La política vigente es <code>POL-RECLAMOS-TC-V3</code>, complementada por <code>CIRCULAR-PLAZOS-2025</code>. El asesor puede solicitar formulario de reclamo, copia de identificación y declaración de desconocimiento, e informar un plazo referencial de 15 días laborables.</p>
    <p>El bloqueo preventivo es posible, pero crear el caso o solicitar bloqueo requiere confirmación humana y registro de auditoría.</p>
  `;
}

function wireDemo() {
  const button = document.querySelector("[data-mode][data-target]");
  const textarea = document.querySelector("#question");
  if (!button || !textarea) return;

  button.addEventListener("click", () => {
    const target = document.getElementById(button.dataset.target);
    const kind = classifyQuestion(textarea.value);
    target.innerHTML = button.dataset.mode === "ai-ready" ? aiReadyAnswer(kind) : basicAnswer(kind);
  });
}

wireDemo();
