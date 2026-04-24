from __future__ import annotations

import json
import sys
from pathlib import Path


def convert_event(e: dict) -> dict:
    return {
        "eventType": "COMPLETE",
        "eventTime": "2026-04-24T00:00:00Z",
        "producer": "ai-ready-rag-banking-demo",
        "job": {"namespace": "ai-ready-demo", "name": e["event_type"]},
        "run": {"runId": e["event_id"]},
        "inputs": [{"namespace": "ai-ready-demo", "name": i} for i in e.get("inputs", [])],
        "outputs": [{"namespace": "ai-ready-demo", "name": o} for o in e.get("outputs", [])],
        "facets": {"metadata": {"_producer": "ai-ready-rag-banking-demo", "_schemaURL": "", **e.get("metadata", {})}},
    }


def main() -> None:
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    with src.open(encoding="utf-8") as f, dst.open("w", encoding="utf-8") as out:
        for line in f:
            if line.strip():
                out.write(json.dumps(convert_event(json.loads(line)), ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
