import json
from pathlib import Path
from datetime import datetime,timezone

root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
concept=root/'output/wind_production/concepts/d01_concept_v1.png'
prompt=root/'output/wind_production/concepts/d01_prompt.txt'
assert concept.is_file() and prompt.is_file()
data=json.loads((root/'output/wind_production/asset_state.json').read_text(encoding='utf-8'))
data['D01']={
    'state':'concept_ready',
    'spec':'One fallen ceremonial ring fragment from the exact missing L04 arc: 72 degrees from two adjacent 36-degree modules; outer R5 m, inner R3.5 m, radial band1.5 m, front-to-back depth0.9 m; one principal curved piece and at most two matching subsidiary pieces; 2-3 broad fracture planes.',
    'concept':'output/wind_production/concepts/d01_concept_v1.png',
    'prompt':'output/wind_production/concepts/d01_prompt.txt',
    'generation':'built-in imagegen',
    'destination':'assets/generated/wind_ruins/d01/',
    'advisor':'sol_advisor',
    'advisory':'Pending review of the actual saved concept; no geometry started.',
    'outstanding':'One concise Sol advisory before direct Blender construction.'
}
data['next_asset']='D01'
data['current_task']='D01 actual concept sent to Sol for one 1-3 suggestion advisory; prepare exact L04 arc reuse, then direct MCP Blender model.'
(root/'output/wind_production/asset_state.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
stamp=datetime.fromtimestamp(concept.stat().st_mtime,tz=timezone.utc).isoformat()
with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
    f.write(f"\n\n## D01 — actual concept generated\n\nBuilt-in ImageGen concept saved as `output/wind_production/concepts/d01_concept_v1.png` ({concept.stat().st_size:,} bytes; last write {stamp} UTC); prompt saved to `output/wind_production/concepts/d01_prompt.txt`. The isolated fragment sheet shows the 72-degree L04-matching arc with exact 5.0 m / 3.5 m radii, 1.5 m band and 0.9 m depth. Sent the actual image for one concise Sol advisory before starting 3D.\n")
print({'concept_bytes':concept.stat().st_size,'concept_mtime_utc':stamp,'next_asset':data['next_asset']})
