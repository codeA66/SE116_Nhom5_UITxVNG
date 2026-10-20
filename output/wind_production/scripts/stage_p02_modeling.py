import json
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
state_path=ROOT/"output/wind_production/asset_state.json";state=json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp=datetime.now(timezone.utc).isoformat().replace("+00:00","Z")
advice="Merge the busy grid into one broad retaining face, one wide cap and a subtly flared foot inside the straight 4 x 1 x 2.4 m envelope; preserve clean end connectors. Make the single drain a bounded outlet with visible jamb/lintel and a short channel floor; keep wall solid above and around it. Build the 90-degree corner from that same section with a continuous inner skin and cap. On the broken variant remove only the outer-corner face layer using 2-3 broad fracture planes, leaving the pond-facing wall and channel intact."
state.setdefault("P02",{}).update({"state":"modeling","advisor":"sol_advisor","advisory":advice,
 "advisory_received_utc":stamp,"outstanding":"Construct straight, corner and exterior-damaged states in live MCP Blender; inspect, self-check, render, export and save."})
state["current_task"]="P02: directly implementing Sol's single note in live MCP Blender; broad continuous wall, bounded drain and channel, continuous L-cap, and chipped exterior face only."
state["last_updated_utc"]=stamp;state_path.write_text(json.dumps(state,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
with (ROOT/"output/wind_production/reviews/workflow_order_audit.md").open("a",encoding="utf-8") as f:
    f.write("\n## P02 — one-time 3D advisory\n\n")
    f.write("Sol inspected the saved P02 concept and advised simplifying it to one broad wall face, one wide cap, subtly flared foot, and clean straight connectors within 4 × 1 × 2.4 m. The drain must be bounded by jamb/lintel and a short channel bottom; the wall remains solid above and around it. The 90-degree corner reuses the same section with continuous inner skin/cap; the damaged state removes only an outer-corner face layer across 2–3 broad fracture planes, preserving the pond-facing wall and channel. Proceeding directly to live Blender.\n")
print("P02 modeling stage",stamp)
