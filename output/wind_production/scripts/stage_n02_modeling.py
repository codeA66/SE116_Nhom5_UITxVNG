import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
state_path = ROOT / "output/wind_production/asset_state.json"
state = json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
state["N02"].update({
    "state": "modeling",
    "advisor": "sol_advisor",
    "advisory": "Three broad swept masses per asset, with 1–2 long tapered ends each and gaps in plan/side; distinguish low-horizontal and rising-asymmetric shrubs within 1.2 × 1 × 0.65 m; grass is three slender bent blades within 0.7 × 0.5 × 0.4 m; muted greens, compact bases, tips swept the same way.",
    "advisory_received_utc": stamp,
    "outstanding": "Build in live MCP Blender, inspect beauty/game-camera render, validate and export GLB/source."
})
state["current_task"] = "N02: applying Sol advisory in live MCP Blender; two 1.2 × 1 × 0.65 m three-mass shrubs and a 0.7 × 0.5 × 0.4 m three-blade grass tuft; inspect, validate, export and save."
state["last_updated_utc"] = stamp
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

audit_path = ROOT / "output/wind_production/reviews/workflow_order_audit.md"
with audit_path.open("a", encoding="utf-8") as f:
    f.write("\n## N02 — one-time 3D advisory\n\n")
    f.write("Sol inspected the saved N02 concept and advised: (1) three broad swept masses per shrub, with long tapered ends and gaps in plan and side; (2) distinct low-horizontal and rising-asymmetric shrub silhouettes within the shared 1.2 × 1 × 0.65 m envelope, plus exactly three slender bent grass blades within 0.7 × 0.5 × 0.4 m; (3) muted greens, consistent wind direction and compact bases. Proceeding directly to live Blender construction.\n")
print("N02 modeling stage", stamp)
