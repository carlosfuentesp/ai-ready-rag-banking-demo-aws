from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: csv_to_dynamodb_puts.py <csv_path> <table_name>")
        raise SystemExit(2)

    csv_path = Path(sys.argv[1])
    table_name = sys.argv[2]

    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            item = {k: {"S": str(v)} for k, v in row.items()}
            subprocess.run(
                ["aws", "dynamodb", "put-item", "--table-name", table_name, "--item", json.dumps(item)],
                check=True,
            )


if __name__ == "__main__":
    main()
