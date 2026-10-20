import json
from pathlib import Path
root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
p=root/'output/wind_production/asset_state.json'
d=json.loads(p.read_text(encoding='utf-8'))
d['D01'].update({
  'state':'completed','outstanding':'none',
  'generation':'built-in imagegen','advisor':'sol_advisor',
  'glb':'assets/generated/wind_ruins/d01/d01_ceremonial_ring_fragment.glb',
  'source':'assets/generated/wind_ruins/d01/source/d01_ceremonial_ring_fragment.blend',
  'preview':'assets/generated/wind_ruins/d01/preview.png','evidence':'output/wind_production/d01/',
  'dimensions_blender_xyz_m':[5.565970182418823,3.016867756843567,1.8110900223255157],
  'dimensions_godot_xyz_m':[5.565970182418823,1.8110900223255157,3.016867756843567],
  'triangles':424,'materials':1,'source_arc_meshes_reused':2,
  'self_check':'Reuses the exact L04_Intact_RingArc_02 and _03 mesh datablocks as the full 72-degree missing sector, preserving R5/R3.5, 1.5 m radial band, 0.9 m depth and channel profile. One rigid 70-degree rotation and translation only; no mesh edit or scale. Both modules closed manifold, total 424 triangles, one shared non-emissive vertex-color material, bottom-center pivot, valid Y-up GLB v2, exact selected meshes only, all checks passed. Beauty and fixed game-camera previews visually inspected with actual Idle fox; original default scene preserved.',
  'completed_utc':'2026-10-19T19:38:41Z'
})
q=d.get('remaining_catalog_order',[])
if 'D01' in q: q.remove('D01')
d['remaining_catalog_order']=q
d['completed_count']=sum(1 for k,v in d.items() if isinstance(v,dict) and v.get('state')=='completed')
d['pending_count']=39-d['completed_count']
d['next_asset']=q[0] if q else None
d['current_task']=f"{q[0]} actual 2D concept and one Sol advisory, then direct MCP Blender build, self-check/export/save" if q else 'All 39 specified assets complete'
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

with (root/'output/wind_production/reviews/workflow_order_audit.md').open('a',encoding='utf-8') as f:
  f.write("\n## D01 — direct 3D completion\n\nCompleted 2026-10-19 UTC after the saved concept and one Sol advisory. `assets/generated/wind_ruins/d01/d01_ceremonial_ring_fragment.glb` is 30,244 bytes; source blend, empty `.gdignore`, concept, preview, and metrics are in the required folders. The two adjacent 36° meshes are the exact source datablocks from L04's missing 72° sector, retaining R5/R3.5, 1.5 m radial band, 0.9 m depth, recessed channel, terminal fracture caps, and central seam; geometry was only rotated/translated. The final 424-triangle fragment measures 5.566 × 1.811 × 3.017 m in Godot X/Y/Z. Both mesh parts are manifold; one vertex-color material is shared. GLB v2 header/length, Y-up conversion, COLOR_0, fragment root, and exclusion of preview/locator objects were checked. Beauty and fixed game-camera renders with the actual Idle fox were visually inspected. The optional loose chunk was omitted to keep one dominant resting silhouette. Original default scene and L04 remain intact; no gameplay changes.\n")
print({'completed':d['completed_count'],'pending':d['pending_count'],'next_asset':d['next_asset'],'queue':q})
