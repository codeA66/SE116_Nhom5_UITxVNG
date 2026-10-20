import json
from pathlib import Path

root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
state_path=root/'output/wind_production/asset_state.json'
data=json.loads(state_path.read_text(encoding='utf-8'))
advisory=('Differentiate the supplied envelopes as a small low wedge, medium sideways spread, and large upright-leaning slab; each uses one dominant stone plus 3-5 smaller blocks. '
          'Keep broad squared masonry faces with 2-3 irregular fracture planes per stone, omitting dense crack webs and rounded chips. '
          'Preserve 1-2 visible shadow gaps; tuck every auxiliary inside the footprint and keep the path clear.')
data['D02'].update({'state':'advised','advisory_received_from':'sol_advisor','advisory':advisory,
                    'outstanding':'Direct MCP Blender construction, visual self-check, GLB export and source save.'})
data['current_task']='D02 direct MCP Blender build of three distinct rubble clusters; then inspect, self-check, export and save.'
state_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
    f.write('\n## D02 — one-time 3D advisory\n\nSol inspected the actual saved `output/wind_production/concepts/d02_concept_v1.png` and advised: (1) distinguish the exact small/medium/large envelopes as a low wedge, sideways spread, and upright-leaning slab, each with one dominant and 3–5 smaller stones; (2) use broad squared masonry faces and 2–3 irregular fracture planes per stone, without crack webs or rounded chips; (3) retain 1–2 visible shadow gaps and keep all auxiliary stones within the cluster footprint. Sent directly for immediate implementation.\n')
print(advisory)
