import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"C:/Code/UITxVNG/SE116_Nhom5_UITxVNG")
concept_rel = "output/wind_production/concepts/p01_concept_v1.png"
prompt_rel = "output/wind_production/concepts/p01_prompt.txt"
prompt = r"""Create an actual 2D concept-art sheet for a low-poly 3D game prop: a ceremonial lantern for an elegant ruined East Asian wind shrine. Show exactly three full-height views of the same design side by side, each on a plain dark charcoal studio background with a soft ground shadow: (1) intact and unlit, (2) damaged and unlit, (3) intact and glowing.

The lantern is 0.5 m wide, 0.5 m deep, 1.6 m tall, upright with a bottom-center ground pivot. Design a compact square stone foot, a slender dark weathered timber shaft, and a large square lantern chamber with one broad, clearly open front window. The chamber must be the dominant focal shape and occupy roughly the upper third of the silhouette. Above it use only two broad sloped roof planes meeting at a simple ridge; no extra roof tiers, finials, fringe or ornaments. Use large clean low-poly planes, sharp edges, graceful East Asian shrine proportions, restrained dark stone and muted timber values, and minimal details visible from a distant high game camera. The damaged state has one substantial missing corner of the roof/chamber, represented with 2–3 broad fracture faces; it remains standing and its window is still legible. The lit state reuses the intact geometry and adds one large pale wind-white luminous panel inside the opening, with a gentle contained glow, not colored orange and not overpowering. The light panel is a visibly separate simple insert so it can be its own glowing material. The unlit opening is dark and empty.

Illustration style: polished stylized game prop concept, broad faceted forms, flat shading, restrained Death's Door-like mood without copying existing artwork. No photorealism, no wood grain, no cracks except the single damaged break, no tiny lattice grid, no extra props, no people, no text, no labels, no borders, no logos. Front three-quarter views, camera slightly above; include the complete base and roof in every panel."""
state_path = ROOT / "output/wind_production/asset_state.json"
state = json.loads(state_path.read_text(encoding="utf-8-sig"))
stamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
(ROOT / prompt_rel).write_text(prompt + "\n", encoding="utf-8")
state.setdefault("P01", {}).update({
    "state": "concept_ready",
    "concept": concept_rel,
    "prompt": prompt_rel,
    "generation": "built-in imagegen",
    "spec": "Ceremonial lantern, 0.5 x 0.5 x 1.6 m; compact foot, slender shaft, large chamber opening, two-plane roof; unlit, damaged, and lit states; separate wind-white light insert.",
    "destination": "assets/generated/wind_ruins/p01/",
    "concept_generated_utc": stamp,
    "outstanding": "Send actual concept to sol_advisor for one concise 3D suggestion, then build in live MCP Blender."
})
state["current_task"] = "P01: actual 2D concept is saved; obtain one Sol advisory, then directly model the unlit, broken, and glowing ceremonial-lantern states in MCP Blender."
state["last_updated_utc"] = stamp
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
with (ROOT / "output/wind_production/reviews/workflow_order_audit.md").open("a", encoding="utf-8") as f:
    f.write("\n## P01 — actual 2D concept\n\n")
    f.write(f"Generated and saved `{concept_rel}` at {stamp} with the built-in image generator. It shows the compact 0.5 × 0.5 × 1.6 m ceremonial lantern in unlit, damaged, and wind-white lit states, with the separate light insert and two-plane roof called out in the prompt. Next: one Sol advisory, then direct live-Blender construction.\n")
print("P01 concept recorded", stamp)
