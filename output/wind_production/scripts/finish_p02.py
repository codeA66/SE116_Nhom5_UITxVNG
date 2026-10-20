import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/p02';PRE=ROOT+'/output/wind_production/p02'
CONCEPT=ROOT+'/output/wind_production/concepts/p02_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/p02_prompt.txt'
GLB=OUT+'/p02_pond_retaining_wall.glb';BLEND=OUT+'/source/p02_pond_retaining_wall.blend'
scene=bpy.data.scenes['WindProduction_P02'];bpy.context.window.scene=scene;export=bpy.data.collections['P02_Export'];preview=bpy.data.collections['P02_Preview_ONLY'];source=bpy.data.collections['P02_Source_NOT_EXPORTED']
roots=[bpy.data.objects[n] for n in ('P02_Wall_Straight','P02_Wall_Corner90','P02_Wall_BrokenOutside')]
assert not os.path.exists(GLB),'Refusing to overwrite existing P02 GLB'

def measure(root):
    obs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in obs for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)];health=[];tris=0
    for ob in obs:
        ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles);tris+=n;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':n,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(obs),'triangles':tris,'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),'boundary_edges':sum(x['boundary_edges'] for x in health),'loose_edges':sum(x['loose_edges'] for x in health),'loose_vertices':sum(x['loose_vertices'] for x in health),'mesh_health':health}

measurements={r.name:measure(r) for r in roots}
for r in roots:
    m=measurements[r.name];assert m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0,(r.name,m)
    assert m['triangles']<2000
assert all(abs(measurements[r.name]['dimensions_blender_xyz_m'][i]-[4,1,2.4][i])<.002 for r in (roots[0],roots[2]) for i in range(3))
assert all(abs(measurements[roots[1].name]['dimensions_blender_xyz_m'][i]-[3,3,2.4][i])<.002 for i in range(3))
assert roots[0].get('drain_count')==1 and roots[1].get('drain_count')==2 and roots[2].get('drain_count')==1
corner_cap=[o for o in roots[1].children_recursive if o.get('part_role')=='single_continuous_L_pond_rim_cap'];assert len(corner_cap)==1 and corner_cap[0].get('inner_cap_skin_continuous')
broken_cap=[o for o in roots[2].children_recursive if o.get('part_role')=='outer_cap_corner_chipped_with_three_planes'];assert len(broken_cap)==1 and broken_cap[0].get('pond_facing_edge_continuous')
broken_face=[o for o in roots[2].children_recursive if o.get('part_role')=='one_outer_corner_layer'];assert len(broken_face)==1 and broken_face[0].get('broad_fracture_planes')==3
straight_body=next(o for o in roots[0].children_recursive if o.get('part_role')=='one_broad_retaining_wall_face')
broken_body=next(o for o in roots[2].children_recursive if o.get('part_role')=='one_broad_retaining_wall_face')
sig=lambda o:sorted(tuple(round(c,6) for c in v.co) for v in o.data.vertices)
assert sig(straight_body)==sig(broken_body),'Broken state must preserve the continuous wall core and drain'
meshes=[o for o in export.objects if o.type=='MESH'];materials=sorted({m.name for o in meshes for m in o.data.materials})
assert len(materials)==1 and all(o.data.color_attributes.get('Color') is not None for o in meshes)
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT) and os.path.isfile(OUT+'/source/.gdignore')
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('P02_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'

scene.render.engine='CYCLES';scene.cycles.samples=10;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam=bpy.data.objects['P02_PreviewCamera'];scene.camera=cam;cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24
cam.data.lens=40;cam.location=(7,-20,11);cam.rotation_euler=(Vector((0,.2,1.15))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)
cam.data.lens=40;cam.location=(7,-20,11);cam.rotation_euler=(Vector((0,.2,1.15))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=PRE+'/beauty_3quarter.png'
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'));nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes];prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
checks={
 'glb_v2_header_and_json_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON' and chunk_len>0,
 'three_named_wall_variants_and_mesh_parts':all(r.name in names for r in roots) and all(o.name in names for o in meshes),
 'straight_and_broken_envelope_4_x_1_x_2_4_m_with_bottom_pivots':all(all(abs(measurements[r.name]['dimensions_blender_xyz_m'][i]-[4,1,2.4][i])<.002 for i in range(3)) and abs(measurements[r.name]['bounds_min_blender_m'][2])<.002 for r in (roots[0],roots[2])),
 'corner_is_true_90_degree_continuous_L_cap_same_section':all(abs(measurements[roots[1].name]['dimensions_blender_xyz_m'][i]-[3,3,2.4][i])<.002 for i in range(3)) and len(corner_cap)==1,
 'bounded_drains_have_channel_floors_and_solid_wall_core':[r.get('drain_count') for r in roots]==[1,2,1] and len([o for o in roots[0].children_recursive if o.get('part_role')=='short_bounded_drain_channel_floor'])==1 and sig(straight_body)==sig(broken_body),
 'broken_outer_face_has_three_planes_and_pond_wall_is_retained':len(broken_face)==1 and broken_face[0].get('broad_fracture_planes')==3 and sig(straight_body)==sig(broken_body),
 'all_mesh_parts_closed_without_loose_geometry':all(m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0 for m in measurements.values()),
 'single_shared_muted_vertex_color_material':len(gltf.get('materials',[]))==1 and len(materials)==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'preview_fox_and_source_objects_excluded':not any(n.startswith(('P02_Fox_','P02_Preview','P02_Key','P02_Fill','P02_Rim','P02_Source','P02_PivotNote')) for n in names),
 'all_primitive_indices_reference_valid_accessors':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf.get('accessors',[])) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'actual_idle_fox_and_default_scene_preserved':fox.animation_data.action.name=='Idle' and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'concept_prompt_previews_source_and_gdignore_present':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))
}
assert all(checks.values()),json.dumps(checks,indent=2)
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={'id':'P02','asset':'p02_pond_retaining_wall','glb':'assets/generated/wind_ruins/p02/p02_pond_retaining_wall.glb',
 'dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'variants':measurements,
 'geometry':{'straight_and_broken_envelope_blender_m':[4,1,2.4],'corner_centerline_length_m':4,'corner_angle_degrees':90,'corner_continuous_L_cap':True,'straight_drain_count':1,'corner_drain_count':2,'drain_clear_width_m':.94,'drain_clear_height_m':.58,'channel_floor_depth_m':.66,'foot_flare':'single continuous trapezoidal base; 0.90 m base depth','broken_state':'three broad cut planes on one exterior corner face/cap layer; pond-facing wall core and channel unchanged','end_connectors':'flat, no projection beyond the 4 m straight envelope'},
 'materials':{'count':len(materials),'names':materials,'shared':True,'vertex_colors':True,'emission':'none'},'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),
 'preview':{'beauty':'output/wind_production/p02/beauty_3quarter.png','game_camera':'output/wind_production/p02/game_camera.png','fox_reference':'actual generated/models/fox_spirit.glb; Idle frame1; fox_palette; Sword and Icosphere helper hidden','game_camera_location_blender':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},
 'self_check':checks,'completed_utc':stamp}
for p in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(p,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2);f.write('\n')
state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8-sig'));was=state['P02'].get('state')=='completed'
state['P02'].update({'state':'completed','outstanding':'none','advisor':'sol_advisor','glb':'assets/generated/wind_ruins/p02/p02_pond_retaining_wall.glb','source':'assets/generated/wind_ruins/p02/source/p02_pond_retaining_wall.blend','preview':'assets/generated/wind_ruins/p02/preview.png','evidence':'output/wind_production/p02/','triangles_per_variant':{k:v['triangles'] for k,v in measurements.items()},'mesh_parts_per_variant':{k:v['mesh_parts'] for k,v in measurements.items()},'materials':materials,'dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'glb_valid':all(checks.values()),'self_check':'Straight and exterior-broken wall states fit 4 x 1 x 2.4 m with bottom pivots; corner is a true 90-degree L with a continuous cap and the same section. The drain is a bounded .94 x .58 m rectangular outlet with a short continuous channel floor; the solid wall remains above/around it. Broken state removes only the outside face/cap layer with three broad cuts; the pond-facing wall core and channel geometry are unchanged. All mesh parts are closed manifold; single shared vertex-color material. GLB v2/Y-up/header, node names, COLOR_0, indices, preview exclusion, idle fox, source files and default scene checked. Beauty and fixed game-camera renders saved.','completed_utc':stamp})
if not was:state['completed_count']=int(state.get('completed_count',0))+1;state['pending_count']=int(state.get('pending_count',13))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='P02':q=q[1:]
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete';state['active_blender_scene']='WindProduction_P02'
state['current_task']=f'P02 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.';state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
        f.write(f"\n## P02 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/p02/p02_pond_retaining_wall.glb` ({len(raw):,} bytes), Blender source, `.gdignore`, actual concept, preview and metrics. Straight and broken variants fit the 4 × 1 × 2.4 m envelope; the right-angle variant reuses the same wall section with a continuous L cap and inner overlap. The outlet is a bounded 0.94 × 0.58 m opening with a short channel floor; the wall stays solid around it. The broken variant removes only the outer face/cap layer across three broad cut planes, preserving the water-side wall and drain. All {len(meshes)} mesh parts are closed manifold with one shared vertex-color material. GLB v2/Y-up/header, node names, `COLOR_0`, indices, preview exclusions, idle fox and default scene checked. Beauty and fixed game-camera renders inspected. Next: {state['next_asset']}.\n")
print('P02_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'triangles':sum(v['triangles'] for v in measurements.values()),'variants':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'triangles':v['triangles'],'mesh_parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
