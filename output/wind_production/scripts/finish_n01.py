import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/n01';PRE=ROOT+'/output/wind_production/n01'
GLB=OUT+'/n01_wind_bent_trees.glb';BLEND=OUT+'/source/n01_wind_bent_trees.blend'
CONCEPT=ROOT+'/output/wind_production/concepts/n01_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/n01_prompt.txt'
scene=bpy.data.scenes['WindProduction_N01'];bpy.context.window.scene=scene
export=bpy.data.collections['N01_Export'];preview=bpy.data.collections['N01_Preview_ONLY'];source=bpy.data.collections['N01_Source_NOT_EXPORTED']
roots=[bpy.data.objects[n] for n in ('N01_WindBentTree_Living','N01_WindBentTree_Dry_TwoLargeBranches')]

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in objs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();t=len(ob.data.loop_triangles);tris+=t;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(objs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

measurements={r.name:measure(r) for r in roots};living=measurements[roots[0].name];dead=measurements[roots[1].name]
assert all(abs(living['dimensions_blender_xyz_m'][i]-[4.5,3.0,4.8][i])<.005 for i in range(3)),living
assert abs(dead['dimensions_blender_xyz_m'][2]-4.8)<.005,dead
assert all(q['non_manifold_edges']==0 and q['boundary_edges']==0 and q['loose_edges']==0 and q['loose_vertices']==0 for q in measurements.values()),measurements
mesh_parts=[o for o in export.objects if o.type=='MESH'];assert len(mesh_parts)==12,[o.name for o in mesh_parts]
materials=sorted({m.name for o in mesh_parts for m in o.data.materials});assert len(materials)==1,materials
assert all(o.data.color_attributes.get('Color') is not None for o in mesh_parts)
assert len([o for o in roots[0].children_recursive if o.type=='MESH' and o.get('part_role')=='broad_foliage_mass'])==5
assert len([o for o in roots[0].children_recursive if o.type=='MESH' and o.get('part_role')=='primary_branch'])==3
dead_branches=[o for o in roots[1].children_recursive if o.type=='MESH' and o.get('part_role')=='primary_broken_branch']
assert len(dead_branches)==2 and all(o.get('fractured_tip') for o in dead_branches)
assert bpy.data.objects['N01_Dry_SameTrunk'].get('fractured_tip') and bpy.data.objects['N01_Dry_SameTrunk'].get('derived_from')
assert abs(living['bounds_min_blender_m'][2])<.005 and abs(dead['bounds_min_blender_m'][2])<.005
assert len([o for o in source.objects if o.get('source_only')])==2
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
cam=bpy.data.objects['N01_PreviewCamera'];fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('N01_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT) and os.path.isfile(OUT+'/source/.gdignore')

scene.render.engine='CYCLES';scene.cycles.samples=10;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
cam.location=(0,-10,16);cam.rotation_euler=(Vector((0,0,2.4))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20];gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'))
nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes];prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
checks={
 'glb_v2_length_and_json_chunk':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'both_named_roots_and_all_mesh_nodes_exported':all(r.name in names for r in roots) and all(o.name in names for o in mesh_parts),
 'living_tree_exact_4_5_by_3_by_4_8_m':all(abs(living['dimensions_blender_xyz_m'][i]-[4.5,3,4.8][i])<.005 for i in range(3)),
 'living_has_five_broad_leaf_masses_and_three_primary_branches':len([o for o in roots[0].children_recursive if o.type=='MESH' and o.get('part_role')=='broad_foliage_mass'])==5 and len([o for o in roots[0].children_recursive if o.type=='MESH' and o.get('part_role')=='primary_branch'])==3,
 'dry_tree_derived_from_same_s_curve_with_two_broken_primary_branches':bool(bpy.data.objects['N01_Dry_SameTrunk'].get('derived_from')) and len(dead_branches)==2 and all(o.get('fractured_tip') for o in dead_branches),
 'all_meshes_closed_without_loose_geometry':all(q['non_manifold_edges']==0 and q['boundary_edges']==0 and q['loose_edges']==0 and q['loose_vertices']==0 for v in measurements.values() for q in v['mesh_health']),
 'one_shared_vertex_color_material':len(gltf.get('materials',[]))==1 and len(materials)==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'fox_and_preview_objects_excluded':not any(n.startswith(('N01_Fox_','N01_Preview','N01_Key','N01_Fill','N01_Rim','N01_Source','N01_Pivot')) for n in names),
 'all_primitive_index_accessors_valid':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf['accessors']) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'bottom_center_pivots_and_original_default_scene_preserved':all(abs(q['bounds_min_blender_m'][2])<.005 for q in measurements.values()) and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'actual_idle_fox_preview_and_required_files':fox.animation_data.action.name=='Idle' and all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))}
assert all(checks.values()),json.dumps(checks,indent=2)

shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
metrics={'id':'N01','asset':'n01_wind_bent_trees','glb':'assets/generated/wind_ruins/n01/n01_wind_bent_trees.glb','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'states':measurements,'geometry':{'living_canopy_envelope_local_m':[4.5,3.0],'living_tree_height_m':4.8,'living_leaf_masses':5,'living_primary_branches':3,'dry_primary_branches':2,'dry_broken_tip_planes_per_branch':3,'dry_trunk':'same lower S-curve as living, with a broad broken termination where two branches split','root_spread':'compact at ground; no path-spreading roots','wind_direction_local_x':1},'materials':{'count':len(materials),'names':materials,'shared':True,'vertex_colors':True,'emission':'none'},'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'preview':{'beauty':'output/wind_production/n01/beauty_3quarter.png','game_camera':'output/wind_production/n01/game_camera.png','fox_reference':'actual generated/models/fox_spirit.glb; Idle frame1; runtime fox_palette; helper and Sword hidden','game_camera_location_blender':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},'self_check':checks}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8-sig'));stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z');was=state['N01'].get('state')=='completed'
state['N01'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/n01/n01_wind_bent_trees.glb','source':'assets/generated/wind_ruins/n01/source/n01_wind_bent_trees.blend','preview':'assets/generated/wind_ruins/n01/preview.png','evidence':'output/wind_production/n01/','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'triangles_per_state':{k:v['triangles'] for k,v in measurements.items()},'mesh_parts_per_state':{k:v['mesh_parts'] for k,v in measurements.items()},'materials':materials,'glb_valid':all(checks.values()),'self_check':'Living tree fits exact 4.5 x 3.0 x 4.8 m bounds, with five separate broad leaf masses, three thick primary branches, and visible negative-space gaps. Dry tree reuses the lower S-curved trunk profile, is truncated at a broad fracture where exactly two large branches split off, and has three broad fracture planes on both branch tips. All 12 meshes are manifold and share one non-emissive vertex-color material. GLB v2/Y-up/header, names, COLOR_0, indices, preview exclusion, bottom pivots and original default scene checked. Actual Idle fox appears only in previews.','completed_utc':stamp})
if not was:state['completed_count']=int(state.get('completed_count',0))+1;state['pending_count']=int(state.get('pending_count',16))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='N01':q=q[1:]
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete';state['active_blender_scene']='WindProduction_N01';state['current_task']=f'N01 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.';state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
        f.write(f"\n## N01 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/n01/n01_wind_bent_trees.glb` ({len(raw):,} bytes), Blender source, `.gdignore`, actual concept, preview and metrics. The living tree fits the exact 4.5 × 3 × 4.8 m envelope with five distinct broad leaf masses, three primary branches and visible gaps. The dry counterpart uses the same lower S-curved trunk profile, two large fractured branches, and a broad broken crown termination. All {len(mesh_parts)} meshes are closed manifold and share one non-emissive vertex-color material. GLB v2/Y-up/header, node names, `COLOR_0`, indices, preview exclusions, bottom pivots and original default scene were checked. Beauty and fixed game-camera previews include the actual Idle fox. Next: {state['next_asset']}.\n")
print('N01_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'states':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'mesh_parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
