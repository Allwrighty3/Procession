from pathlib import Path
import json

repo_root = Path(__file__).resolve().parents[1]

source_path = repo_root / "priv" / "training" / "exports" / "npc_interaction_training_export.jsonl"
output_path = repo_root / "priv" / "training" / "exports" / "npc_interaction_sft.jsonl"

rows = []

with source_path.open("r", encoding="utf-8") as f:
    for line_number, line in enumerate(f, start=1):
        if not line.strip():
            continue

        row = json.loads(line)

        if row.get("task") != "npc_interaction":
            raise SystemExit(f"line {line_number}: bad task")

        if row.get("metadata", {}).get("non_authoritative") is not True:
            raise SystemExit(
                f"line {line_number}: missing metadata.non_authoritative true"
            )

        context_value = row.get("input", {}).get("context", "")

        if isinstance(context_value, str):
            context = context_value.strip()
        else:
            context = json.dumps(context_value, ensure_ascii=False, indent=2)

        expected = row.get("output", {}).get("expected_response", "").strip()

        if not context or not expected:
            raise SystemExit(f"line {line_number}: missing context or expected response")

        text = (
            "### Task\n"
            "Respond as the NPC using only the provided grounded context.\n\n"
            "### Context\n"
            f"{context}\n\n"
            "### Response\n"
            f"{expected}"
        )

        rows.append(
            {
                "id": row["id"],
                "text": text,
                "metadata": row["metadata"],
            }
        )

with output_path.open("w", encoding="utf-8") as f:
    for row in rows:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

print("wrote:", output_path)
print("rows:", len(rows))
print("first id:", rows[0]["id"])
print("last id:", rows[-1]["id"])


