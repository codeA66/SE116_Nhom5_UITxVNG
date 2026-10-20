import json
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
concept_rel="output/wind_production/concepts/p02_concept_v1.png"
prompt_rel="output/wind_production/concepts/p02_prompt.txt"
prompt=r"""Create an actual 2D concept sheet for one low-poly game environment asset kit: a ruined East Asian stone pond-retaining wall in a wind-shrine world. Show exactly three separate full objects side by side, at matching scale and camera: an intact straight segment, a clean 90-degree corner segment, and an exterior-corner-damaged segment. Do not show water or a surrounding diorama.

Target straight envelope: 4 m long, 1 m front-to-back including cap, 2.4 m tall. The wall has one strong continuous broad stone face, a subtly flared continuous base, and one simple wide cap that can form a pond rim. Make one large, unmistakable rectangular drain opening low in the wall, with a deep dark void through the masonry; keep the wall structurally continuous around it and the bottom support intact. The 90-degree module uses the same wall and cap proportions, meeting cleanly at a true right-angle corner. The damaged variant has one exterior corner chipped or broken with 2–3 broad stone fracture planes, while the retaining wall remains continuous behind the break; no open breach through the full wall, no detached floating pieces.

Style: elegant, restrained low-poly, broad clean flat-shaded planes and sharp readable edges, dark weathered gray stone with subtle muted value shifts, solemn East Asian wind-ruin architecture, Death's Door-like minimalist mood without copying existing art. Shapes must read from a distant high camera. Avoid brick grids, tiny cracks, noisy rock texture, ornate trim, multiple buttresses, foliage, characters, any water, water effects, impossible suspended terrain, text, labels, borders, and logos. Use three-quarter views slightly above eye level so the drain tunnel and corner geometry are clearly visible. Include every full wall silhouette in the frame."""
state_path=ROOT/"output/wind_production/asset_state.json";state=json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp=datetime.now(timezone.utc).isoformat().replace("+00:00","Z")
(ROOT/prompt_rel).write_text(prompt+"\n",encoding="utf-8")
state.setdefault("P02",{}).update({"state":"concept_ready","concept":concept_rel,"prompt":prompt_rel,"generation":"built-in imagegen",
 "spec":"Pond-retaining wall, 4 x 1 x 2.4 m straight envelope; broad continuous face, flared base, wide pond-rim cap, one large empty drain opening; straight, right-angle corner, and exterior-damaged variants that retain the wall behind the break.",
 "destination":"assets/generated/wind_ruins/p02/","concept_generated_utc":stamp,
 "outstanding":"Send actual concept to sol_advisor for one concise build note, then model directly in live MCP Blender."})
state["current_task"]="P02: actual 2D concept is saved; obtain one Sol advisory, then build the straight, corner and exterior-damaged retaining-wall variants in live MCP Blender."
state["last_updated_utc"]=stamp;state_path.write_text(json.dumps(state,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
with (ROOT/"output/wind_production/reviews/workflow_order_audit.md").open("a",encoding="utf-8") as f:
    f.write("\n## P02 — actual 2D concept\n\n")
    f.write(f"Generated and saved `{concept_rel}` at {stamp} with built-in image generation. Concept covers the 4 × 1 × 2.4 m straight retaining wall, right-angle corner and broken outside corner; it calls for a broad continuous wall, subtly flared base, wide cap and one large open drain, without water. Next: one Sol advisory, then direct live-Blender construction.\n")
print("P02 concept recorded",stamp)
