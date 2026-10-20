import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
state_path = ROOT / "output/wind_production/asset_state.json"
state = json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
state["N03"] = {
    "state": "concept_ready_advisory_pending",
    "concept": "output/wind_production/concepts/n03_concept_v1.png",
    "prompt": "output/wind_production/concepts/n03_prompt.txt",
    "generation": "built-in imagegen",
    "spec": "Three modular root/vine silhouettes: straight, 90-degree corner, and hanging. Each uses one main line and two large branches, within 2.4 m length, 0.6 m width and 0.12 m relief; sparse edge-only placement.",
    "destination": "assets/generated/wind_ruins/n03/",
    "concept_generated_utc": stamp,
    "outstanding": "One concise Sol advisory, then direct MCP Blender build, self-check and export."
}
state["current_task"] = "N03 concept saved; requesting one concise Sol advisory, then direct live MCP Blender build, self-check, export and save."
state["last_updated_utc"] = stamp
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

audit_path = ROOT / "output/wind_production/reviews/workflow_order_audit.md"
with audit_path.open("a", encoding="utf-8") as f:
    f.write("\n## N03 — actual concept generated\n\n")
    f.write("Built-in ImageGen output saved at `output/wind_production/concepts/n03_concept_v1.png`; exact prompt persisted at `output/wind_production/concepts/n03_prompt.txt`. The sheet presents straight, corner and hanging edge-hugging root/vine silhouettes, each with one main line and two large branches. Requesting one concise Sol advisory before direct Blender construction.\n")
print("N03 concept stage", stamp)
