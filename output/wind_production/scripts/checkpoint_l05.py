import json
from pathlib import Path

root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
state_path=root/'output/wind_production/asset_state.json'
data=json.loads(state_path.read_text(encoding='utf-8'))
item=data['L05']
item.update({
    'state':'completed',
    'generation':'built-in imagegen',
    'advisor':'sol_advisor',
    'outstanding':'none',
    'glb':'assets/generated/wind_ruins/l05/l05_broken_observatory_tower.glb',
    'source':'assets/generated/wind_ruins/l05/source/l05_broken_observatory_tower.blend',
    'preview':'assets/generated/wind_ruins/l05/preview.png',
    'evidence':'output/wind_production/l05/',
    'triangles_per_state':{'intact':1684,'broken':1684},
    'materials':1,
    'dimensions_godot_xyz_m':{
        'intact':[3.0,9.0,3.0],
        'broken':[6.327821731567383,6.0,3.0]
    },
    'structure':{
        'base_width_depth_m':[3.0,3.0],
        'major_tier_masses':3,
        'fracture_height_m':6.0,
        'intact_tip_height_m':9.0,
        'detached_top_height_before_rotation_m':3.0,
        'detached_mesh_parts_reused':17,
        'fallen_top_scale':[1.0,1.0,1.0],
        'fallen_top_anchor_blender_m':[1.9,0.0,.9],
        'fallen_rotation_degrees':[0.0,76.0,0.0]
    },
    'self_check':'Both states have 1,684 triangles and every mesh is closed manifold. Intact measures exactly 3 x 3 x 9 m from its bottom-center pivot; broken retains a 6 m body and reuses all 17 identical crown mesh datablocks for the unscaled 3 m fallen section. Three broad tier masses, open bays, exact 9 m frame tip, one non-emissive vertex-color material, no preview/locator nodes in valid Y-up GLB v2, source locators excluded, original default scene preserved. Beauty and fixed game-camera renders were visually inspected with the actual Idle fox.',
    'completed_utc':'2026-10-19T19:31:18Z'
})
queue=data.get('remaining_catalog_order',[])
if 'L05' in queue: queue.remove('L05')
data['remaining_catalog_order']=queue
data['completed_count']=sum(1 for k,v in data.items() if isinstance(v,dict) and v.get('state')=='completed')
data['pending_count']=39-data['completed_count']
data['next_asset']=queue[0] if queue else None
data['current_task']=f"{queue[0]} actual 2D concept and one Sol advisory, then direct MCP Blender build, self-check/export/save" if queue else 'All 39 specified assets complete'
state_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

audit_path=root/'output/wind_production/reviews/workflow_order_audit.md'
with audit_path.open('a',encoding='utf-8') as f:
    f.write("\n\n## L05 — direct 3D completion\n\n")
    f.write("Completed 2026-10-19 UTC after the saved concept and one Sol advisory. The connected Blender export is `assets/generated/wind_ruins/l05/l05_broken_observatory_tower.glb` (241,056 bytes); source blend, empty `.gdignore`, concept, preview, metrics and prompt are saved in their requested locations. Intact is exactly 3 × 3 × 9 m with three broad tier masses and the frame tip at 9 m. Broken retains an exact 6 m body and reuses all 17 crown mesh datablocks, unscaled, for the exact 3 m top section rotated 76° beside it. Both variants have 1,684 triangles, zero non-manifold/boundary/loose edges and one shared non-emissive vertex-color material. GLB v2 header/length, Y-up export, both state roots, vertex colors on every primitive, and exclusion of studio/locator objects were checked. Beauty and exact 50°-down, 30°-FOV game-camera previews with the actual Idle fox were visually inspected; the broken model fits the frame. Original default Cube/Camera/Light scene remains preserved; no gameplay files changed.\n")
print({'completed':data['completed_count'],'pending':data['pending_count'],'next_asset':data['next_asset'],'queue':queue})
