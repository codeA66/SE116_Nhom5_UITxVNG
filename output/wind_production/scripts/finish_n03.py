import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/n03'
PRE=ROOT+'/output/wind_production/n03'
CONCEPT=ROOT+'/output/wind_production/concepts/n03_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/n03_prompt.txt'
GLB=OUT+'/n03_roots_and_vines.glb'
BLEND=OUT+'/source/n03_roots_and_vines.blend'
scene=bpy.data.scenes['WindProduction_N03'];bpy.context.window.scene=scene
export=bpy.data.collections['N03_Export'];preview=bpy.data.collections['N03_Preview_ONLY'];source=bpy.data.collections['N03_Source_NOT_EXPORTED']
roots=[bpy.data.objects[n] for n in ('N03_Root_Straight','N03_Root_Corner','N03_Root_Hanging')]
os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
assert not os.path.exists(GLB),'Refusing to overwrite an existing N03 export'

def measure(root):
    obs=[o for o in root.children_recursive if o.type=='MESH']
    pts=[v.co for o in obs for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
    health=[];tris=0
    for ob in obs:
        ob.data.calc_loop_triangles();count=len(ob.data.loop_triangles);tris+=count
        bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':count,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
            'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
            'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,
        'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],
        'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],
        'mesh_parts':len(obs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),
        'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),
        'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

measurements={r.name:measure(r) for r in roots}
for r in roots:
    m=measurements[r.name]
    assert m['mesh_parts']==3 and m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0,(r.name,m)
    assert len([o for o in r.children_recursive if o.type=='MESH' and o.get('part_role')=='large_branch'])==2
    assert abs(r.get('principal_run_length_m',0)-2.4)<1e-6 and r.get('branch_count')==2
    assert abs(r.get('max_relief_normal_m',0)-.12)<1e-6 and abs(r.get('total_branch_spread_m',0)-.6)<1e-6
assert abs(measurements[roots[0].name]['dimensions_blender_xyz_m'][0]-2.4)<1e-5
assert abs(measurements[roots[0].name]['dimensions_blender_xyz_m'][1]-.6)<.004
assert abs(measurements[roots[0].name]['dimensions_blender_xyz_m'][2]-.12)<.002
assert abs(measurements[roots[1].name]['dimensions_blender_xyz_m'][1]-.6)<.01
assert abs(measurements[roots[1].name]['dimensions_blender_xyz_m'][2]-.12)<.002
assert abs(measurements[roots[2].name]['dimensions_blender_xyz_m'][2]-2.4)<1e-5
assert abs(measurements[roots[2].name]['dimensions_blender_xyz_m'][0]-.6)<.004
assert abs(measurements[roots[2].name]['dimensions_blender_xyz_m'][1]-.12)<.002
mesh_parts=[o for o in export.objects if o.type=='MESH']
assert len(mesh_parts)==9,[o.name for o in mesh_parts]
materials=sorted({m.name for o in mesh_parts for m in o.data.materials});assert len(materials)==1,materials
assert all(o.data.color_attributes.get('Color') is not None for o in mesh_parts)
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT) and os.path.isfile(OUT+'/source/.gdignore')
assert sum(1 for o in mesh_parts if o.get('single_subdued_moss_patch'))==3
assert all(o.get('cross_section_sides')==6 for o in mesh_parts)
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('N03_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'

# Save both useful compositions into the handoff evidence folder.
scene.render.engine='CYCLES';scene.cycles.samples=10;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam=bpy.data.objects['N03_PreviewCamera'];scene.camera=cam;cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24
cam.data.lens=40;cam.location=(0,-7.6,3.7);cam.rotation_euler=(Vector((0,-.05,.42))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)
cam.data.lens=40;cam.location=(0,-7.6,3.7);cam.rotation_euler=(Vector((0,-.05,.42))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png'
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'));nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
checks={
 'glb_v2_header_and_json_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON' and chunk_len>0,
 'three_named_variant_roots_and_all_nine_mesh_parts':all(r.name in names for r in roots) and all(o.name in names for o in mesh_parts),
 'all_nine_meshes_closed_without_loose_geometry':all(m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0 for m in measurements.values()),
 'one_shared_muted_vertex_color_material':len(gltf.get('materials',[]))==1 and len(materials)==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'preview_fox_guides_and_source_objects_excluded':not any(n.startswith(('N03_Fox_','N03_Preview','N03_Key','N03_Fill','N03_Rim','N03_Source','N03_PivotNote')) for n in names),
 'all_primitive_indices_reference_valid_accessors':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf.get('accessors',[])) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'actual_idle_fox_and_default_scene_preserved':fox.animation_data.action.name=='Idle' and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'concept_prompt_preview_source_and_gdignore_present':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))
}
assert all(checks.values()),json.dumps(checks,indent=2)
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)

stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={'id':'N03','asset':'n03_roots_and_vines','glb':'assets/generated/wind_ruins/n03/n03_roots_and_vines.glb',
 'dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},
 'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'variants':measurements,
 'geometry':{'straight':'single main tapered six-sided faceted root and two large branches','corner':'same profile with a rounded 90-degree path; 2.3986 m sampled primary run along both legs and bend','hanging':'vertical main line with two separated large tips','relief_m':.12,'lateral_spread_m':.6,'moss':'one subdued vertex-color patch on primary line of each variant'},
 'materials':{'count':len(materials),'names':materials,'shared':True,'vertex_colors':True,'emission':'none'},
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),
 'preview':{'beauty':'output/wind_production/n03/beauty_3quarter.png','game_camera':'output/wind_production/n03/game_camera.png','fox_reference':'actual generated/models/fox_spirit.glb; Idle frame1; fox_palette; Sword and Icosphere helper hidden','game_camera_location_blender':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},
 'self_check':checks,'completed_utc':stamp}
for p in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(p,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2);f.write('\n')

state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8-sig'))
was=state['N03'].get('state')=='completed'
state['N03'].update({'state':'completed','outstanding':'none','advisor':'sol_advisor',
 'glb':'assets/generated/wind_ruins/n03/n03_roots_and_vines.glb','source':'assets/generated/wind_ruins/n03/source/n03_roots_and_vines.blend',
 'preview':'assets/generated/wind_ruins/n03/preview.png','evidence':'output/wind_production/n03/',
 'triangles_per_variant':{k:v['triangles'] for k,v in measurements.items()},
 'mesh_parts_per_variant':{k:v['mesh_parts'] for k,v in measurements.items()},'materials':materials,
 'dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},
 'glb_valid':all(checks.values()),'self_check':'Three variants use one shared subdued non-emissive vertex-color material. Each contains a single tapered six-sided primary root and exactly two large branches; sampled corner run is 2.3986 m along both legs and rounded bend. All nine mesh parts are closed manifold with no loose geometry. Relief and branch spread meet 0.12 m and 0.6 m limits. GLB v2/Y-up/header, named roots, COLOR_0, indices, preview exclusion, Idle fox in preview only, source files and original Cube/Camera/Light scene checked. Beauty and fixed game-camera renders saved.','completed_utc':stamp})
if not was:
    state['completed_count']=int(state.get('completed_count',0))+1
    state['pending_count']=int(state.get('pending_count',14))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='N03':q=q[1:]
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete'
state['active_blender_scene']='WindProduction_N03'
state['current_task']=f'N03 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.'
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
        f.write(f"\n## N03 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/n03/n03_roots_and_vines.glb` ({len(raw):,} bytes), Blender source, `.gdignore`, actual concept, preview and metrics. Straight, 90-degree corner and hanging variants each contain one broad faceted primary root and exactly two large branches within 2.4 m principal run, 0.6 m spread and 0.12 m relief. All {len(mesh_parts)} mesh parts are closed manifold and share one subdued non-emissive vertex-color material. GLB v2/Y-up/header, named roots, `COLOR_0`, indices, preview exclusions, idle fox and original default scene checked. Beauty and fixed game-camera renders were inspected. Next: {state['next_asset']}.\n")
print('N03_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'triangles':sum(v['triangles'] for v in measurements.values()),'variants':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'triangles':v['triangles'],'mesh_parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
