import json
from pathlib import Path
root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
state_path=root/'output/wind_production/asset_state.json'
data=json.loads(state_path.read_text(encoding='utf-8'))
advisory=('Preserve the narrow box, disk wheels and long diagonal handle while fitting wheel hubs and handle tips within exactly 1.4 × 2.2 × 1.3 m; keep only two broad body bands. '
          'Use 3–4 broad timber boards per side and quiet solid wheel faces, merging fine seams, grain and small splinters into broad planes. '
          'Derive the tipped state from the same cart, remove exactly one wheel with the axle exposed, and spill 2–3 compact cargo blocks toward its low side without using them to prop the cart.')
data['D03'].update({'state':'advised','advisory_received_from':'sol_advisor','advisory':advisory,
                    'outstanding':'Direct MCP Blender construction, visual self-check, GLB export and source save.'})
data['current_task']='D03 direct MCP Blender build: exact-size intact cart and derived tipped missing-wheel state; inspect, self-check, export and save.'
state_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
    f.write('\n## D03 — one-time 3D advisory\n\nSol inspected the actual saved `output/wind_production/concepts/d03_concept_v1.png` and advised: (1) preserve the narrow box, disk wheels and long diagonal handle within exactly 1.4 × 2.2 × 1.3 m including hubs and tips, using only two broad body bands; (2) use 3–4 broad timber boards per side and quiet solid wheel faces, merging fine seams/grain/splinters into broad planes; (3) derive the tipped state from the same cart, remove exactly one wheel with exposed axle, and spill 2–3 compact cargo blocks toward the low side without propping the cart. Sent directly for immediate implementation.\n')
print(advisory)
