import json
from pathlib import Path
root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
state_path=root/'output/wind_production/asset_state.json';data=json.loads(state_path.read_text(encoding='utf-8'))
advisory=('Measure the closed hollow chest at exactly 0.9 × 0.7 × 0.65 m; reuse its body/lid for the open state with a rear-edge hinge and dark visible interior, keeping one broad band. '
          'Keep the rack exactly 1.8 × 0.7 × 1.6 m with slim posts and one broad shelf plane per tier; share simplified muted timber/metal colors. '
          'Break one leg using 2–3 matching broad fracture planes, lean the rack slightly toward that corner, and place only 2–3 detached-foot/crate pieces tightly on that side and outside the route.')
data['D04'].update({'state':'advised','advisory_received_from':'sol_advisor','advisory':advisory,'outstanding':'Direct MCP Blender construction, visual self-check, GLB export and source save.'})
data['current_task']='D04 direct MCP Blender build: closed/open one-band chests and two-tier racks (intact and one snapped leaning leg), plus compact 3-crate dock cluster.'
state_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
    f.write('\n## D04 — one-time 3D advisory\n\nSol inspected the actual saved `output/wind_production/concepts/d04_concept_v1.png` and advised: (1) measure the closed hollow chest exactly 0.9 × 0.7 × 0.65 m, reuse body/lid for the open state with rear-edge hinge and dark interior, and keep one broad band; (2) keep the rack exactly 1.8 × 0.7 × 1.6 m with slim posts and one broad shelf plane per tier, sharing simplified muted wood/metal colors; (3) break one leg across 2–3 matching broad planes, lean slightly toward the corner, and keep the detached foot plus only 2–3 chests tightly on that side outside the route. Sent directly for immediate implementation.\n')
print(advisory)
