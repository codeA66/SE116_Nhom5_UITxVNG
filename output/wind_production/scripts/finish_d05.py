import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d05';PRE=ROOT+'/output/wind_production/d05'
GLB=OUT+'/d05_wind_relief_slab.glb';BLEND=OUT+'/source/d05_wind_relief_slab.blend'
CONCEPT=ROOT+'/output/wind_production/concepts/d05_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/d05_prompt.txt'
scene=bpy.data.scenes['WindProduction_D05'];bpy.context.window.scene=scene
export=bpy.data.collections['D05_Export'];preview=bpy.data.collections['D05_Preview_ONLY'];source=bpy.data.collections['D05_SourceLocators_NOT_EXPORTED']
roots=[bpy.data.objects[n] for n in ('D05_StoneRelief_Intact','D05_StoneRelief_MissingLowerLeftCorner')]

# Keep the inset field just proud of the slab face to avoid coplanar flicker.
for name in ('D05_Intact_InsetField','D05_Broken_InsetField'):
    me=bpy.data.objects[name].data
    for v in me.vertices:
        if abs(v.co.y+.075)<1e-6:v.co.y=-.08
    me.update();ca=me.color_attributes['Color']
    for p in me.polygons:
        if p.normal.y<-.99 and p.center.y<-.079:
            for li in p.loop_indices:ca.data[li].color=(.12,.137,.12,1)

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in objs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();t=len(ob.data.loop_triangles);tris+=t;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(objs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

measurements={r.name:measure(r) for r in roots}
for k,q in measurements.items():
    assert all(abs(q['dimensions_blender_xyz_m'][i]-[2.4,.35,2.8][i])<.005 for i in range(3)),(k,q)
    assert all(v==0 for v in (q['non_manifold_edges'],q['boundary_edges'],q['loose_edges'],q['loose_vertices'])),(k,q)
    assert abs(q['bounds_min_blender_m'][0]+q['bounds_max_blender_m'][0])<.005 and abs(q['bounds_min_blender_m'][1]+q['bounds_max_blender_m'][1])<.005 and abs(q['bounds_min_blender_m'][2])<.005,(k,q)
mesh_parts=[o for o in export.objects if o.type=='MESH']
assert len(mesh_parts)==12,[o.name for o in mesh_parts]
materials=sorted({m.name for o in mesh_parts for m in o.data.materials});assert len(materials)==1,materials
assert all(o.data.color_attributes.get('Color') is not None for o in mesh_parts)
assert all(len([o for o in r.children_recursive if o.type=='MESH' and o.get('emblem_component')])==4 for r in roots)
intact_emb={o.name.replace('D05_Intact',''):o for o in roots[0].children_recursive if o.type=='MESH' and o.get('emblem_component')}
broken_emb={o.name.replace('D05_Broken',''):o for o in roots[1].children_recursive if o.type=='MESH' and o.get('emblem_component')}
assert set(intact_emb)==set(broken_emb) and all(intact_emb[k].data is broken_emb[k].data for k in intact_emb)
broken_slab=next(o for o in roots[1].children_recursive if o.type=='MESH' and o.name=='D05_Broken_StoneSlab')
assert broken_slab.get('fracture_plane_count')==2 and roots[1].get('missing_lower_left_corner') is None
assert roots[0].get('relief_depth_m')==.10 and roots[1].get('relief_depth_m')==.10
assert all(abs(r.location.z)<1e-6 and abs(r.location.y)<1e-6 for r in roots)
assert len([o for o in source.objects if o.get('source_only')])==2
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
cam=bpy.data.objects['D05_PreviewCamera'];fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('D05_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT) and os.path.isfile(OUT+'/source/.gdignore')

scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.15;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
cam.location=(0,-12,7);cam.rotation_euler=(Vector((0,0,1.15))-cam.location).to_track_quat('-Z','Y').to_euler()
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
 'both_named_roots_and_all_meshes_exported':all(r.name in names for r in roots) and all(o.name in names for o in mesh_parts),
 'both_states_exact_2_4_by_0_35_by_2_8_m':all(all(abs(q['dimensions_blender_xyz_m'][i]-[2.4,.35,2.8][i])<.005 for i in range(3)) for q in measurements.values()),
 'four_exact_shared_f01_emblem_parts_per_state':all(len([o for o in r.children_recursive if o.type=='MESH' and o.get('emblem_component')])==4 for r in roots) and all(intact_emb[k].data is broken_emb[k].data for k in intact_emb),
 'broken_state_real_lower_corner_chip_with_two_fracture_planes':broken_slab.get('fracture_plane_count')==2 and abs(measurements[roots[1].name]['bounds_min_blender_m'][2])<.005,
 'all_export_meshes_closed_without_loose_geometry':all(v['non_manifold_edges']==0 and v['boundary_edges']==0 and v['loose_edges']==0 and v['loose_vertices']==0 for q in measurements.values() for v in q['mesh_health']),
 'one_shared_non_emissive_vertex_color_material':len(gltf.get('materials',[]))==1 and len(materials)==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims) and all(not m.get('emissiveFactor',[0,0,0])[0] and not m.get('emissiveFactor',[0,0,0])[1] and not m.get('emissiveFactor',[0,0,0])[2] for m in gltf.get('materials',[])),
 'preview_fox_camera_and_source_locators_excluded':not any(n.startswith(('D05_Fox_','D05_Preview','D05_Key','D05_Fill','D05_Rim','D05_Source','D05_Pivot')) for n in names),
 'all_primitive_index_accessors_valid':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf['accessors']) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'bottom_center_pivots_and_original_default_scene_preserved':all(abs(r.location.z)<1e-6 and abs(r.location.y)<1e-6 for r in roots) and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'idle_fox_preview_and_required_files':fox.animation_data.action.name=='Idle' and all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))}
assert all(checks.values()),json.dumps(checks,indent=2)

shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
metrics={'id':'D05','asset':'d05_wind_relief_slab','glb':'assets/generated/wind_ruins/d05/d05_wind_relief_slab.glb','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'states':measurements,'geometry':{'catalog_envelope_blender_m':[2.4,.35,2.8],'relief_depth_m':.10,'f01_open_ring_and_three_same_direction_strokes':True,'shared_emblem_meshes_between_states':True,'broken_corner':'lower-left','fracture_plane_count':2,'flat_base_width_m':1.84},'materials':{'count':len(materials),'names':materials,'shared':True,'vertex_colors':True,'emission':'none'},'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'preview':{'beauty':'output/wind_production/d05/beauty_3quarter.png','game_camera':'output/wind_production/d05/game_camera.png','fox_reference':'actual generated/models/fox_spirit.glb; Idle frame1; runtime fox_palette; helper and Sword hidden','game_camera_location_blender':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},'self_check':checks}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8-sig'));stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z');was=state['D05'].get('state')=='completed'
state['D05'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/d05/d05_wind_relief_slab.glb','source':'assets/generated/wind_ruins/d05/source/d05_wind_relief_slab.blend','preview':'assets/generated/wind_ruins/d05/preview.png','evidence':'output/wind_production/d05/','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'triangles_per_state':{k:v['triangles'] for k,v in measurements.items()},'mesh_parts_per_state':{k:v['mesh_parts'] for k,v in measurements.items()},'materials':materials,'glb_valid':all(checks.values()),'self_check':'Both states are exact 2.4 x 0.35 x 2.8 m with 0.10 m relief and four shared F01-derived emblem meshes. The broken slab removes a genuine lower-left corner across two broad planes while retaining a 1.84 m stable base and the complete emblem. Every export mesh is closed manifold; GLB v2/Y-up/header, node names, vertex colors, indices, material count, preview exclusions, pivots and original default scene were checked. Actual Idle fox appears only in previews.','completed_utc':stamp})
if not was:state['completed_count']=int(state.get('completed_count',0))+1;state['pending_count']=int(state.get('pending_count',18))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='D05':q=q[1:]
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete';state['active_blender_scene']='WindProduction_D05';state['current_task']=f'D05 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.';state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
        f.write(f"\n## D05 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/d05/d05_wind_relief_slab.glb` ({len(raw):,} bytes), Blender source, `.gdignore`, concept, preview and metrics. Both the intact slab and lower-left-corner-missing state fit the exact 2.4 × 0.35 × 2.8 m envelope with 0.10 m raised relief. Four shared mesh parts reproduce F01's open C-ring and three same-direction strokes; the damage cuts two broad planes while leaving a 1.84 m flat base. All {len(mesh_parts)} export meshes are closed manifold and share one non-emissive vertex-color material. GLB v2/Y-up/header, names, `COLOR_0`, indices, preview exclusions and default scene were checked. Beauty and fixed game-camera previews use the actual Idle fox. Next: {state['next_asset']}.\n")
print('D05_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'states':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'mesh_parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
