from __future__ import annotations

import csv
from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
import re
from typing import Any

from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib import colors
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW_DOCS = ROOT / "data/raw/documents"
RAW_TABLES = ROOT / "data/raw/tables"
CURATED = ROOT / "data/curated"

for p in [RAW_DOCS, RAW_TABLES, CURATED]:
    p.mkdir(parents=True, exist_ok=True)


@dataclass
class Chunk:
    chunk_id: str
    document_id: str
    parent_section_id: str
    title: str
    text: str
    source_page: int
    metadata: dict[str, Any]
    entities: list[str] = field(default_factory=list)


SECTION_RE = re.compile(r"^(#+|\d+\.|Artículo|Sección|Cláusula|Tabla)\s+", re.IGNORECASE)


def stable_id(prefix: str, text: str) -> str:
    return f"{prefix}-{hashlib.sha1(text.encode('utf-8')).hexdigest()[:10]}"


def split_sections(text: str) -> list[tuple[str, str]]:
    sections: list[tuple[str, str]] = []
    current_title = "Introducción"
    current_lines: list[str] = []
    for line in text.splitlines():
        clean = line.strip()
        if not clean:
            continue
        if SECTION_RE.match(clean) and current_lines:
            sections.append((current_title, "\n".join(current_lines)))
            current_title = clean
            current_lines = []
        elif SECTION_RE.match(clean):
            current_title = clean
        else:
            current_lines.append(clean)
    if current_lines:
        sections.append((current_title, "\n".join(current_lines)))
    return sections


def semantic_split(section_text: str, max_chars: int = 900) -> list[str]:
    sentences = re.split(r"(?<=[.!?])\s+", section_text)
    chunks, buf = [], ""
    for sentence in sentences:
        if len(buf) + len(sentence) > max_chars and buf:
            chunks.append(buf.strip())
            buf = sentence
        else:
            buf = f"{buf} {sentence}".strip()
    if buf:
        chunks.append(buf.strip())
    return chunks


ENTITY_PATTERNS = {
    "tarjeta_credito": r"tarjeta de crédito|tarjeta credito|visa gold",
    "cuenta_ahorros": r"cuenta de ahorros|cuenta ahorro",
    "consumo_no_reconocido": r"consumo no reconocido|transacción no autorizada|cargo desconocido|contracargo",
    "bloqueo_preventivo": r"bloqueo preventivo|bloquear tarjeta",
    "formulario_reclamo": r"formulario de reclamo",
    "circular_plazos_2025": r"circular.*2025|plazos.*2025",
    "matriz_riesgo": r"matriz.*riesgo|score de contracargo|umbral de fraude",
}


def extract_entities(text: str) -> list[str]:
    found = []
    for entity, pattern in ENTITY_PATTERNS.items():
        if re.search(pattern, text, flags=re.IGNORECASE):
            found.append(entity)
    return found


def build_chunks(document_id: str, raw_text: str, metadata: dict[str, Any], source_page: int = 1) -> list[Chunk]:
    chunks: list[Chunk] = []
    for section_title, body in split_sections(raw_text):
        section_id = stable_id("SEC", f"{document_id}:{section_title}")
        for i, text in enumerate(semantic_split(body)):
            chunk_id = stable_id("CHK", f"{document_id}:{section_id}:{i}:{text}")
            entities = extract_entities(f"{section_title}\n{text}")
            chunk_metadata = dict(metadata)
            chunk_metadata["section_title"] = section_title
            chunk_metadata["entities"] = entities
            chunks.append(
                Chunk(
                    chunk_id=chunk_id,
                    document_id=document_id,
                    parent_section_id=section_id,
                    title=section_title,
                    text=text,
                    source_page=source_page,
                    metadata=chunk_metadata,
                    entities=entities,
                )
            )
    return chunks


DOCUMENTS = [
    {
        "document_id": "CONTRATO-TC-2024",
        "filename": "Contrato_Tarjeta_Credito_2024.pdf",
        "title": "Contrato de Tarjeta de Crédito 2024",
        "doc_type": "contract",
        "product": "tarjeta_credito",
        "confidentiality": "public",
        "allowed_roles": ["cliente", "asesor", "supervisor"],
        "customer_visible": True,
        "effective_from": "2024-01-01",
        "effective_to": "2026-12-31",
        "version": "v2024",
        "supersedes": None,
        "sections": [
            ("1. Objeto del contrato", "Este contrato regula el uso de la tarjeta de crédito emitida por Banco Sintético Ecuador. El cliente debe revisar sus consumos y reportar de forma oportuna cualquier consumo no reconocido."),
            ("2. Consumos no reconocidos", "Si el cliente identifica una transacción no autorizada o cargo desconocido, puede presentar un reclamo por consumo no reconocido. El banco podrá solicitar formulario de reclamo, copia de identificación y detalles del comercio."),
            ("3. Bloqueo preventivo", "A solicitud del cliente o del asesor autorizado, el banco puede iniciar bloqueo preventivo de la tarjeta mientras se analiza el caso. El bloqueo no implica aceptación automática del reclamo."),
            ("4. Protección de datos", "El banco no solicitará claves completas, CVV, tokens ni contraseñas por canales no autorizados. Los datos personales deben tratarse con confidencialidad."),
        ],
    },
    {
        "document_id": "TARIFARIO-2025",
        "filename": "Tarifario_Servicios_Bancarios_2025.pdf",
        "title": "Tarifario de Servicios Bancarios 2025",
        "doc_type": "tariff",
        "product": "multiproducto",
        "confidentiality": "public",
        "allowed_roles": ["cliente", "asesor", "supervisor"],
        "customer_visible": True,
        "effective_from": "2025-01-01",
        "effective_to": "2025-12-31",
        "version": "v2025",
        "supersedes": "TARIFARIO-2023",
        "sections": [
            ("1. Servicios de tarjeta de crédito", "La reposición de tarjeta por bloqueo preventivo puede tener costo cero cuando el bloqueo se origina por consumo no reconocido y se confirma riesgo operativo."),
            ("2. Reclamos", "La recepción de reclamos por consumos no reconocidos no tiene costo para el cliente. Los valores sujetos a devolución dependen del análisis del reclamo y de las reglas aplicables."),
            ("Tabla 1. Plazos operativos", "Producto: tarjeta de crédito | Evento: consumo no reconocido | Canal: agencia o digital | Plazo referencial de respuesta: 15 días laborables | Requiere formulario: sí."),
        ],
    },
    {
        "document_id": "TARIFARIO-2023",
        "filename": "Tarifario_2023_obsoleto.pdf",
        "title": "Tarifario de Servicios Bancarios 2023 - Obsoleto",
        "doc_type": "tariff",
        "product": "multiproducto",
        "confidentiality": "public",
        "allowed_roles": ["cliente", "asesor", "supervisor"],
        "customer_visible": True,
        "effective_from": "2023-01-01",
        "effective_to": "2023-12-31",
        "version": "v2023",
        "supersedes": None,
        "sections": [
            ("1. Reclamos obsoletos", "Documento obsoleto. Este tarifario no debe usarse para reclamos iniciados en 2025 o posterior."),
            ("Tabla 1. Plazos obsoletos", "Producto: tarjeta de crédito | Evento: consumo no reconocido | Plazo referencial: 30 días laborables. Este plazo fue reemplazado por la circular 2025."),
        ],
    },
    {
        "document_id": "POL-RECLAMOS-TC-V3",
        "filename": "Politica_Reclamos_Tarjeta_Credito_v3_2025.pdf",
        "title": "Política Interna de Reclamos de Tarjeta de Crédito v3",
        "doc_type": "policy",
        "product": "tarjeta_credito",
        "confidentiality": "internal",
        "allowed_roles": ["asesor", "supervisor"],
        "customer_visible": False,
        "effective_from": "2025-01-01",
        "effective_to": "2026-12-31",
        "version": "v3",
        "supersedes": "POL-RECLAMOS-TC-V1",
        "sections": [
            ("1. Alcance", "Esta política aplica a consumo no reconocido, transacción no autorizada y cargo desconocido en tarjeta de crédito. No aplica a cuenta de ahorros ni débito directo."),
            ("2. Validación inicial", "El asesor debe verificar transacción, producto, estado de tarjeta, fecha, canal, comercio y coincidencia con datos del cliente. Si el estado es posted, se puede abrir reclamo."),
            ("3. Documentos requeridos", "Para consumo no reconocido se solicita formulario de reclamo, copia de identificación y declaración de desconocimiento. El asesor no debe pedir claves ni CVV."),
            ("4. Bloqueo preventivo", "El bloqueo preventivo está permitido cuando el cliente desconoce el consumo o se identifica riesgo de repetición. La acción requiere confirmación humana del asesor y registro de auditoría."),
            ("5. Comunicación al cliente", "El asesor puede explicar plazos, documentos y estado del proceso. No puede compartir matriz interna de riesgo, score de contracargo, umbral de fraude ni reglas operativas restringidas."),
        ],
    },
    {
        "document_id": "POL-RECLAMOS-TC-V1",
        "filename": "Politica_Reclamos_v1_obsoleta.pdf",
        "title": "Política Interna de Reclamos v1 - Obsoleta",
        "doc_type": "policy",
        "product": "tarjeta_credito",
        "confidentiality": "internal",
        "allowed_roles": ["asesor", "supervisor"],
        "customer_visible": False,
        "effective_from": "2023-01-01",
        "effective_to": "2023-12-31",
        "version": "v1",
        "supersedes": None,
        "sections": [
            ("1. Alcance obsoleto", "Documento reemplazado por POL-RECLAMOS-TC-V3. No debe usarse para casos actuales."),
            ("2. Plazo obsoleto", "Indicaba plazo de 30 días laborables. Fue actualizado por Circular de Plazos 2025."),
        ],
    },
    {
        "document_id": "CIRCULAR-PLAZOS-2025",
        "filename": "Circular_Actualizacion_Plazos_2025.pdf",
        "title": "Circular de Actualización de Plazos 2025",
        "doc_type": "circular",
        "product": "tarjeta_credito",
        "confidentiality": "internal",
        "allowed_roles": ["asesor", "supervisor"],
        "customer_visible": False,
        "effective_from": "2025-02-01",
        "effective_to": "2026-12-31",
        "version": "v2025-02",
        "supersedes": "POL-RECLAMOS-TC-V1",
        "sections": [
            ("1. Actualización", "Se actualiza el plazo referencial de respuesta para consumo no reconocido en tarjeta de crédito a 15 días laborables."),
            ("2. Relación normativa", "Esta circular complementa la Política Interna de Reclamos de Tarjeta de Crédito v3 y reemplaza plazos obsoletos de documentos anteriores."),
        ],
    },
    {
        "document_id": "PROC-ATENCION-CNR",
        "filename": "Procedimiento_Atencion_Consumo_No_Reconocido.pdf",
        "title": "Procedimiento de Atención de Consumo No Reconocido",
        "doc_type": "procedure",
        "product": "tarjeta_credito",
        "confidentiality": "internal",
        "allowed_roles": ["asesor", "supervisor"],
        "customer_visible": False,
        "effective_from": "2025-01-01",
        "effective_to": "2026-12-31",
        "version": "v2",
        "supersedes": None,
        "sections": [
            ("1. Paso 1 - Identificación", "Validar identidad con mecanismos permitidos y verificar que el cliente no comparta claves, CVV ni token."),
            ("2. Paso 2 - Transacción", "Consultar la transacción en el core bancario. Para TX-991 se observa monto 326.40, comercio ECOMMERCE_X, ciudad Quito, canal online y estado posted."),
            ("3. Paso 3 - Registro", "Crear caso de reclamo cuando el cliente confirme desconocimiento. Asociar documentos y transacción al caso."),
            ("4. Paso 4 - Bloqueo", "Si el cliente solicita protección o existe riesgo operativo, registrar solicitud de bloqueo preventivo. Esta acción debe ser idempotente y auditable."),
        ],
    },
    {
        "document_id": "MATRIZ-RIESGO-CB",
        "filename": "Matriz_Riesgo_Contracargos_Interna.pdf",
        "title": "Matriz Interna de Riesgo de Contracargos",
        "doc_type": "risk_matrix",
        "product": "tarjeta_credito",
        "confidentiality": "restricted",
        "allowed_roles": ["supervisor"],
        "customer_visible": False,
        "effective_from": "2025-01-01",
        "effective_to": "2026-12-31",
        "version": "v1",
        "supersedes": None,
        "sections": [
            ("1. Uso restringido", "La matriz interna de riesgo no debe compartirse con clientes. Incluye score de contracargo, umbral de fraude y señales operativas."),
            ("Tabla 1. Señales", "Canal online | Comercio nuevo | Monto atípico | Coincidencia de dispositivo | Score de contracargo | Umbral de fraude."),
        ],
    },
    {
        "document_id": "GUIA-CLIENTE-RECLAMOS",
        "filename": "Guia_Cliente_Reclamos_Canales_Digitales.pdf",
        "title": "Guía para Cliente - Reclamos por Canales Digitales",
        "doc_type": "customer_guide",
        "product": "multiproducto",
        "confidentiality": "public",
        "allowed_roles": ["cliente", "asesor", "supervisor"],
        "customer_visible": True,
        "effective_from": "2025-01-01",
        "effective_to": "2026-12-31",
        "version": "v2025",
        "supersedes": None,
        "sections": [
            ("1. Cómo presentar un reclamo", "El cliente puede presentar reclamo por canales digitales, agencia o contact center. Debe indicar fecha, monto, comercio y motivo del reclamo."),
            ("2. Documentos", "Se puede solicitar formulario de reclamo y copia de identificación. Nunca comparta claves, CVV ni códigos de seguridad."),
            ("3. Seguimiento", "El banco informará el número de caso y el estado del proceso por canales autorizados."),
        ],
    },
]


def pdf_document(path: Path, title: str, sections: list[tuple[str, str]], metadata: dict) -> None:
    styles = getSampleStyleSheet()
    doc = SimpleDocTemplate(str(path), pagesize=LETTER, rightMargin=54, leftMargin=54, topMargin=54, bottomMargin=54)
    story = []
    story.append(Paragraph(title, styles["Title"]))
    story.append(Spacer(1, 0.18 * inch))
    meta_rows = [
        ["ID", metadata["document_id"]],
        ["Tipo", metadata["doc_type"]],
        ["Producto", metadata["product"]],
        ["Confidencialidad", metadata["confidentiality"]],
        ["Vigencia", f'{metadata["effective_from"]} a {metadata["effective_to"]}'],
        ["Versión", metadata["version"]],
    ]
    table = Table(meta_rows, colWidths=[1.4 * inch, 4.6 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#E9EEF4")),
        ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#B8C2CC")),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
    ]))
    story.append(table)
    story.append(Spacer(1, 0.22 * inch))
    for heading, body in sections:
        story.append(Paragraph(heading, styles["Heading2"]))
        if "|" in body and heading.lower().startswith("tabla"):
            rows = [r.strip().split("|") for r in body.splitlines()]
            rows = [[c.strip() for c in row] for row in rows]
            t = Table(rows)
            t.setStyle(TableStyle([
                ("GRID", (0, 0), (-1, -1), 0.3, colors.grey),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F5F7FA")),
                ("FONTSIZE", (0, 0), (-1, -1), 7),
            ]))
            story.append(t)
        else:
            story.append(Paragraph(body, styles["BodyText"]))
        story.append(Spacer(1, 0.16 * inch))
    doc.build(story)


def scanned_form_pdf(path: Path) -> None:
    img_path = path.with_suffix(".png")
    img = Image.new("RGB", (1700, 2200), "white")
    d = ImageDraw.Draw(img)
    try:
        font_title = ImageFont.truetype("DejaVuSans-Bold.ttf", 56)
        font = ImageFont.truetype("DejaVuSans.ttf", 36)
        font_small = ImageFont.truetype("DejaVuSans.ttf", 28)
    except Exception:
        font_title = font = font_small = None
    y = 120
    d.text((120, y), "FORMULARIO DE RECLAMO - CONSUMO NO RECONOCIDO", fill="black", font=font_title)
    y += 110
    fields = [
        ("Cliente", "Carlos Andrade Sintético"),
        ("Identificación", "1712345678"),
        ("Producto", "Tarjeta de crédito Visa Gold"),
        ("Transacción", "TX-991"),
        ("Monto", "USD 326.40"),
        ("Comercio", "ECOMMERCE_X"),
        ("Fecha", "2025-11-03"),
        ("Motivo", "Cliente indica que no reconoce el consumo y solicita investigación."),
    ]
    for label, value in fields:
        d.rectangle((120, y, 1580, y + 90), outline="black", width=3)
        d.text((140, y + 20), f"{label}: {value}", fill="black", font=font)
        y += 115
    d.text((120, y + 60), "Firma del cliente: ______________________________", fill="black", font=font)
    d.text((120, y + 140), "Uso interno: no solicitar claves, CVV ni token.", fill="black", font=font_small)
    img.save(img_path)

    styles = getSampleStyleSheet()
    doc = SimpleDocTemplate(str(path), pagesize=LETTER, rightMargin=36, leftMargin=36, topMargin=36, bottomMargin=36)
    story = [Paragraph("Formulario escaneado sintético", styles["Title"])]
    from reportlab.platypus import Image as RLImage
    story.append(RLImage(str(img_path), width=7.0 * inch, height=9.1 * inch))
    doc.build(story)


def write_tables() -> None:
    customers = [
        {"customer_id": "C-1023", "name": "Carlos Andrade Sintético", "segment": "preferente", "risk_level": "medio", "consent_status": "active", "email": "carlos.synthetic@example.com", "national_id": "1712345678"},
        {"customer_id": "C-2048", "name": "Ana Pérez Sintética", "segment": "masivo", "risk_level": "bajo", "consent_status": "active", "email": "ana.synthetic@example.com", "national_id": "1722222222"},
    ]
    products = [
        {"product_id": "P-TC-001", "customer_id": "C-1023", "product_type": "tarjeta_credito", "product_name": "Visa Gold", "status": "active"},
        {"product_id": "P-CA-001", "customer_id": "C-1023", "product_type": "cuenta_ahorros", "product_name": "Cuenta Ahorros Plus", "status": "active"},
    ]
    transactions = [
        {"transaction_id": "TX-991", "customer_id": "C-1023", "product_id": "P-TC-001", "product": "tarjeta_credito", "amount": "326.40", "merchant": "ECOMMERCE_X", "city": "Quito", "date": "2025-11-03", "channel": "online", "status": "posted"},
        {"transaction_id": "TX-117", "customer_id": "C-1023", "product_id": "P-CA-001", "product": "cuenta_ahorros", "amount": "15.00", "merchant": "ATM_INTERNO", "city": "Ambato", "date": "2025-11-01", "channel": "atm", "status": "posted"},
    ]
    roles = [
        {"role": "cliente", "can_access_public": "true", "can_access_internal": "false", "can_access_restricted": "false", "can_execute_action": "false"},
        {"role": "asesor", "can_access_public": "true", "can_access_internal": "true", "can_access_restricted": "false", "can_execute_action": "true"},
        {"role": "supervisor", "can_access_public": "true", "can_access_internal": "true", "can_access_restricted": "true", "can_execute_action": "true"},
    ]
    tables = {"customers.csv": customers, "products.csv": products, "transactions.csv": transactions, "roles.csv": roles}
    for filename, rows in tables.items():
        with (RAW_TABLES / filename).open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)


def write_jsonl(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def main() -> None:
    for doc in DOCUMENTS:
        pdf_document(RAW_DOCS / doc["filename"], doc["title"], doc["sections"], doc)

    scanned_form_pdf(RAW_DOCS / "Formulario_Reclamo_Escaneado.pdf")
    write_tables()

    chunks_basic = []
    chunks_ai = []
    metadata_rows = []
    for doc in DOCUMENTS:
        source_path = f"data/raw/documents/{doc['filename']}"
        md = {
            "document_id": doc["document_id"],
            "title": doc["title"],
            "doc_type": doc["doc_type"],
            "product": doc["product"],
            "country": "EC",
            "business_domain": "reclamos",
            "owner": "operaciones_tarjetas",
            "data_steward": "steward_reclamos",
            "effective_from": doc["effective_from"],
            "effective_to": doc["effective_to"],
            "version": doc["version"],
            "supersedes": doc["supersedes"],
            "confidentiality": doc["confidentiality"],
            "allowed_roles": doc["allowed_roles"],
            "customer_visible": doc["customer_visible"],
            "source_path": source_path,
        }
        metadata_rows.append(md)
        raw_text = "\n".join([f"{h}\n{b}" for h, b in doc["sections"]])
        # Basic chunks deliberately lose most metadata.
        for c in build_chunks(doc["document_id"], raw_text, {"source_path": source_path, "title": doc["title"]}):
            chunks_basic.append({
                "chunk_id": c.chunk_id,
                "document_id": c.document_id,
                "parent_section_id": c.parent_section_id,
                "title": c.title,
                "text": c.text,
                "source_page": c.source_page,
                "metadata": c.metadata,
                "entities": c.entities,
            })
        for c in build_chunks(doc["document_id"], raw_text, md):
            chunks_ai.append({
                "chunk_id": c.chunk_id,
                "document_id": c.document_id,
                "parent_section_id": c.parent_section_id,
                "title": c.title,
                "text": c.text,
                "source_page": c.source_page,
                "metadata": c.metadata,
                "entities": c.entities,
            })

    write_jsonl(CURATED / "metadata_documents.jsonl", metadata_rows)
    write_jsonl(CURATED / "chunks_basic.jsonl", chunks_basic)
    write_jsonl(CURATED / "chunks_ai_ready.jsonl", chunks_ai)

    nodes = [
        {"id": "C-1023", "type": "Customer", "label": "Cliente sintético C-1023"},
        {"id": "P-TC-001", "type": "Product", "label": "Tarjeta Crédito Visa Gold"},
        {"id": "TX-991", "type": "Transaction", "label": "USD 326.40 ECOMMERCE_X"},
        {"id": "CLAIM-CNR", "type": "ClaimType", "label": "Consumo no reconocido"},
        {"id": "POL-RECLAMOS-TC-V3", "type": "Policy", "label": "Política vigente reclamos TC v3"},
        {"id": "CIRCULAR-PLAZOS-2025", "type": "Circular", "label": "Actualización de plazos 2025"},
        {"id": "PROC-ATENCION-CNR", "type": "Procedure", "label": "Procedimiento consumo no reconocido"},
        {"id": "CONTRATO-TC-2024", "type": "Contract", "label": "Contrato tarjeta crédito 2024"},
        {"id": "FORM-RECLAMO", "type": "Document", "label": "Formulario de reclamo"},
        {"id": "ACTION-BLOQUEO", "type": "Action", "label": "Bloqueo preventivo"},
        {"id": "ACTION-CREAR-CASO", "type": "Action", "label": "Crear caso reclamo"},
        {"id": "ROLE-ASESOR", "type": "Role", "label": "Asesor bancario"},
        {"id": "ROLE-SUPERVISOR", "type": "Role", "label": "Supervisor"},
    ]
    edges = [
        {"source": "C-1023", "target": "P-TC-001", "relation": "HAS_PRODUCT"},
        {"source": "P-TC-001", "target": "TX-991", "relation": "HAS_TRANSACTION"},
        {"source": "TX-991", "target": "CLAIM-CNR", "relation": "INITIATES"},
        {"source": "CLAIM-CNR", "target": "POL-RECLAMOS-TC-V3", "relation": "GOVERNED_BY"},
        {"source": "POL-RECLAMOS-TC-V3", "target": "CIRCULAR-PLAZOS-2025", "relation": "UPDATED_BY"},
        {"source": "CLAIM-CNR", "target": "PROC-ATENCION-CNR", "relation": "USES_PROCEDURE"},
        {"source": "P-TC-001", "target": "CONTRATO-TC-2024", "relation": "GOVERNED_BY"},
        {"source": "CLAIM-CNR", "target": "FORM-RECLAMO", "relation": "REQUIRES_DOCUMENT"},
        {"source": "CLAIM-CNR", "target": "ACTION-BLOQUEO", "relation": "ALLOWS_ACTION"},
        {"source": "CLAIM-CNR", "target": "ACTION-CREAR-CASO", "relation": "ALLOWS_ACTION"},
        {"source": "ACTION-BLOQUEO", "target": "ROLE-ASESOR", "relation": "REQUIRES_CONFIRMATION_BY"},
        {"source": "ACTION-CREAR-CASO", "target": "ROLE-ASESOR", "relation": "REQUIRES_CONFIRMATION_BY"},
        {"source": "ROLE-SUPERVISOR", "target": "MATRIZ-RIESGO-CB", "relation": "CAN_ACCESS"},
        {"source": "ROLE-ASESOR", "target": "POL-RECLAMOS-TC-V3", "relation": "CAN_ACCESS"},
    ]
    write_jsonl(CURATED / "graph_nodes.jsonl", nodes)
    write_jsonl(CURATED / "graph_edges.jsonl", edges)

    lineage_events = [
        {"event_id": "lin-source-docs", "event_type": "SOURCE_REGISTERED", "inputs": [], "outputs": [m["document_id"] for m in metadata_rows], "metadata": {"zone": "raw"}},
        {"event_id": "lin-chunking", "event_type": "STRUCTURE_SEMANTIC_ENTITY_CHUNKING", "inputs": [m["document_id"] for m in metadata_rows], "outputs": [c["chunk_id"] for c in chunks_ai[:10]], "metadata": {"method": "structure-aware + semantic + entity-aware"}},
        {"event_id": "lin-graph-build", "event_type": "KNOWLEDGE_GRAPH_BUILD", "inputs": [c["chunk_id"] for c in chunks_ai[:10]], "outputs": [n["id"] for n in nodes], "metadata": {"graph": "synthetic-neptune-graph"}},
    ]
    write_jsonl(CURATED / "lineage_events.jsonl", lineage_events)

    permissions = {
        "cliente": {"public": True, "internal": False, "restricted": False, "can_execute_actions": False},
        "asesor": {"public": True, "internal": True, "restricted": False, "can_execute_actions": True},
        "supervisor": {"public": True, "internal": True, "restricted": True, "can_execute_actions": True},
    }
    (CURATED / "role_permissions.json").write_text(json.dumps(permissions, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"Synthetic data generated in {ROOT / 'data'}")


if __name__ == "__main__":
    main()
