import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
state_path = ROOT / "output/wind_production/asset_state.json"
state = json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
advice = "Keep the roof eaves and compact base inside 0.5 x 0.5 m and total height 1.6 m, simplify stacked foot/collars and roof ridge to two broad slopes. Reuse the same separate inset panel geometry in unlit/lit states, changing only its material; use restrained warm-white emission, quieter than P04. Derive the damaged state from the same hood with one broad missing upper corner and 2-3 large fracture planes; preserve the main post/base silhouette and keep its light off."
state.setdefault("P01", {}).update({
    "state": "modeling",
    "advisor": "sol_advisor",
    "advisory": advice,
    "advisory_received_utc": stamp,
    "outstanding": "Build the three measured states in live MCP Blender; inspect, self-check, export and save source/previews."
})
state["current_task"] = "P01: implementing Sol's single advisory directly in live MCP Blender; preserve 0.5 x 0.5 x 1.6 m envelope, shared inset panel geometry, and three named light/broken states."
state["last_updated_utc"] = stamp
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
with (ROOT / "output/wind_production/reviews/workflow_order_audit.md").open("a", encoding="utf-8") as f:
    f.write("\n## P01 — one-time 3D advisory\n\n")
    f.write("Sol inspected the actual saved P01 concept. The build will hold the base and eaves inside the 0.5 × 0.5 m footprint and 1.6 m height with a two-slope roof; keep identical inset light-panel geometry in unlit and lit variants and change only its material to restrained warm-white emission; and make the damaged hood from the same design with one broad missing upper corner and 2–3 broad fracture planes while preserving the post/base. Proceeding directly to live Blender.")
    f.write("\n")
print("P01 modeling stage", stamp)
