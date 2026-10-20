import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
state_path = ROOT / "output/wind_production/asset_state.json"
state = json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
state["N03"].update({
    "state": "modeling",
    "advisor": "sol_advisor",
    "advisory": "Export the root geometry alone; one dominant tapered line plus two large branches; max 0.12 m relief from mount surface and 0.6 m total spread. Use the same broad faceted profile for straight, 90-degree corner and hanging variants; principal run is 2.4 m, both corner legs combined, with no stretched profile at the bend. One subdued moss patch, clean long bark planes and separated hanging tips; no extra tendrils.",
    "advisory_received_utc": stamp,
    "outstanding": "Build in live MCP Blender, inspect beauty/game-camera renders, validate and export GLB/source."
})
state["current_task"] = "N03: applying Sol advisory in live MCP Blender; straight, corner and hanging root/vine modules with a 2.4 m principal run, 0.6 m spread and 0.12 m relief; inspect, validate, export and save."
state["last_updated_utc"] = stamp
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

audit_path = ROOT / "output/wind_production/reviews/workflow_order_audit.md"
with audit_path.open("a", encoding="utf-8") as f:
    f.write("\n## N03 — one-time 3D advisory\n\n")
    f.write("Sol inspected the actual saved N03 concept and advised: (1) export the roots alone, keeping one dominant tapered line and two large branches with maximum 0.12 m mounting-surface relief and 0.6 m total spread; (2) reuse one broad faceted profile for straight, 90-degree bend and hanging variants, measuring the corner's 2.4 m principal run along both legs without stretching cross-sections; (3) use clean bark planes, one subdued moss patch and clearly separated hanging tips, with no extra tendrils. Proceeding directly to live Blender construction.\n")
print("N03 modeling stage", stamp)
