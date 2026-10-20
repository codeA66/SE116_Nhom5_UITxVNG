import json
from pathlib import Path
from datetime import datetime,timezone

root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
concept=root/'output/wind_production/concepts/d02_concept_v1.png'
prompt=root/'output/wind_production/concepts/d02_prompt.txt'
assert concept.is_file() and prompt.is_file()
p=root/'output/wind_production/asset_state.json'; data=json.loads(p.read_text(encoding='utf-8'))
data['D02']={
 'state':'concept_ready',
 'spec':'Three distinct rubble layouts; small 1.2 x 1 x 0.5 m, medium 2 x 1.5 x 0.8 m, large 3 x 2 x 1.2 m. Each is one dominant stone plus 3-5 auxiliary blocks, with negative space, square surviving masonry faces and broad irregular fracture faces.',
 'concept':'output/wind_production/concepts/d02_concept_v1.png',
 'prompt':'output/wind_production/concepts/d02_prompt.txt',
 'generation':'built-in imagegen',
 'destination':'assets/generated/wind_ruins/d02/',
 'advisor':'sol_advisor',
 'advisory':'Pending review of the actual saved concept; no geometry started.',
 'outstanding':'One concise Sol advisory before direct Blender construction.'
}
data['next_asset']='D02'; data['current_task']='D02 actual concept sent to Sol for one 1-3 suggestion advisory; prepare three distinct rubble layouts, then direct MCP Blender build.'
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
stamp=datetime.fromtimestamp(concept.stat().st_mtime,tz=timezone.utc).isoformat()
with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
 f.write(f"\n\n## D02 — actual concept generated\n\nBuilt-in ImageGen concept saved as `output/wind_production/concepts/d02_concept_v1.png` ({concept.stat().st_size:,} bytes; last write {stamp} UTC); prompt saved to `output/wind_production/concepts/d02_prompt.txt`. The image depicts three visibly distinct layouts at the catalog small/medium/large scale and was sent for one concise Sol advisory before starting 3D.\n")
print({'concept_bytes':concept.stat().st_size,'mtime_utc':stamp})
