import json
from pathlib import Path

root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
state_path=root/'output/wind_production/asset_state.json'
data=json.loads(state_path.read_text(encoding='utf-8'))
data['D01'].update({
    'state':'advised',
    'advisory_received_from':'sol_advisor',
    'advisory':'Reuse the exact two adjacent L04 36-degree modules as the 72-degree fragment, preserving R5/R3.5, 0.9 m depth and channel; rotate/translate only, without fitting the concept drawing. Keep the original 2-3 broad terminal fracture planes and the existing center module seam as the only main cross-break; omit the optional extra chunk so one dominant resting silhouette remains clear of the route.',
    'outstanding':'Direct MCP Blender construction, visual self-check, export and source save.'
})
data['current_task']='D01 direct MCP Blender build reusing the two exact L04 missing-arc meshes; then self-check/export/save.'
state_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
    f.write("\n## D01 — one-time 3D advisory\n\nSol inspected the actual saved `output/wind_production/concepts/d01_concept_v1.png` and advised: (1) reuse the exact two adjacent L04 36° modules as the 72° fragment, preserving R5/R3.5, 0.9 m depth and channel; rotate/translate only, without fitting the concept's apparent arch height; (2) retain the broad terminal fracture planes and existing central module seam, with clean low-poly faces; (3) omit the optional extra chunk so one dominant resting silhouette stays outside the route. Sent directly for immediate implementation with no redraw or approval gate.\n")
print(data['D01']['advisory'])
