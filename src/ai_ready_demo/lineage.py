from __future__ import annotations

import json
import time
import uuid
from pathlib import Path
from typing import Any


class LineageStore:
    def __init__(self, path: str | Path = "data/runtime/lineage_events.jsonl") -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def emit(self, event_type: str, inputs: list[str], outputs: list[str], metadata: dict[str, Any] | None = None) -> str:
        event_id = f"lin-{uuid.uuid4().hex[:12]}"
        event = {
            "event_id": event_id,
            "event_type": event_type,
            "event_time": int(time.time()),
            "inputs": inputs,
            "outputs": outputs,
            "metadata": metadata or {},
        }
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")
        return event_id

    def read_all(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        return [json.loads(line) for line in self.path.read_text(encoding="utf-8").splitlines() if line.strip()]
