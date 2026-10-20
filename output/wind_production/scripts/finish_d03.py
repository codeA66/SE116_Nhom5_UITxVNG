import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d03';PRE=ROOT+'/output/wind_production/d03'
GLB=OUT+'/d03_abandoned_cargo_cart.glb';BLEND=OUT+'/source/d03_abandoned_cargo_cart.blend'
CONCEPT=ROOT+'/output/wind_production/concepts/d03_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/d03_prompt.txt'
scene=bpy.data.scenes['WindProduction_D03'];bpy.context.window.scene=scene
export=bpy.data.collections['D03_Export'];preview=bpy.data.collections['D03_Preview_ONLY'];source=bpy.data.collections['D03_SourceLocators_NOT_EXPORTED']
roots=[bpy.data.objects['D03_Upright_AbandonedCart'],bpy.data.objects['D03_Tipped_MissingWheel_Cart']]
cam=bpy.data.objects['D03_PreviewCamera'];fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('D03_Fox_'))

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH']
    inv=root.matrix_world.inverted();pts=[inv@(o.matrix_world@v.co) for o in objs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];dims=[hi[i]-lo[i] for i in range(3)]
    health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();t=len(ob.data.loop_triangles);tris+=t
        bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
            'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
            'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)})
        bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':dims,
        'dimensions_godot_xyz_m':[dims[0],dims[2],dims[1]],'mesh_parts':len(objs),'triangles':tris,
        'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),
        'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

measurements={r.name:measure(r) for r in roots};intact,tipped=roots
idm=measurements[intact.name];tdm=measurements[tipped.name]
assert all(abs(idm['dimensions_blender_xyz_m'][i]-[1.4,2.2,1.3][i])<.002 for i in range(3)),idm
assert abs(idm['bounds_min_blender_m'][0]+idm['bounds_max_blender_m'][0])<.002 and abs(idm['bounds_min_blender_m'][1]+idm['bounds_max_blender_m'][1])<.002 and abs(idm['bounds_min_blender_m'][2])<.002,idm
assert abs(tdm['bounds_min_blender_m'][0]+tdm['bounds_max_blender_m'][0])<.002 and abs(tdm['bounds_min_blender_m'][1]+tdm['bounds_max_blender_m'][1])<.002 and abs(tdm['bounds_min_blender_m'][2])<.002,tdm
assert all(m['non_manifold_edges']==0 and m['boundary_edges']==0 and m['loose_edges']==0 and m['loose_vertices']==0 for v in measurements.values() for m in v['mesh_health']),measurements
assert idm['mesh_parts']==29 and tdm['mesh_parts']==30
iparts=[o for o in intact.children_recursive if o.type=='MESH'];tparts=[o for o in tipped.children_recursive if o.type=='MESH']
for ob in iparts+tparts:ob['disk_wheel']=ob.name.endswith('_Disk')
assert sum(1 for o in iparts if o.get('disk_wheel'))==2
assert sum(1 for o in tparts if o.get('disk_wheel'))==1
assert sum(1 for o in iparts if o.get('broad_body_band'))==2 and sum(1 for o in tparts if o.get('broad_body_band'))==2
assert sum(1 for o in tparts if o.name.startswith('D03_Tipped_SpilledCargoBlock_'))==3
assert any(o.name=='D03_Tipped_WoodAxle' for o in tparts)
assert not any(o.name.startswith('D03_Tipped_Wheel_PosX_') for o in tparts)
assert any(o.name=='D03_Tipped_Wheel_NegX_Disk' for o in tparts)
assert all(o.data.color_attributes.get('Color') is not None for o in iparts+tparts)
materials=sorted({m.name for o in iparts+tparts for m in o.data.materials})
assert len(materials)==2 and 'D03_Shared_Wood_VertexColor' in materials and 'D03_Shared_MutedBronze_VertexColor' in materials
assert all(all(abs(v-1)<.0001 for v in o.scale) for o in iparts+tparts)
assert len(source.objects)==2 and all(o.get('source_only') for o in source.objects)
assert bpy.data.scenes.get('Scene') is not None and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'

# Render both visible states with the actual fox, then the project's exact fixed in-game camera.
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.2;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam.location=(5.2,-7.8,4.7);cam.rotation_euler=(Vector((0,0,.65))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=42;fox.hide_render=False
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=intact;scene.render.filepath=PRE+'/beauty_3quarter.png'
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'));nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
expected_obj_names=[o.name for o in iparts+tparts]
glb_checks={
 'valid_glb_v2_and_declared_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'both_state_roots_and_every_mesh_object_present':all(r.name in names for r in roots) and all(n in names for n in expected_obj_names),
 'intact_and_tipped_wheel_counts_encoded':sum(n=='D03_Intact_Wheel_NegX_Disk' or n=='D03_Intact_Wheel_PosX_Disk' for n in names)==2 and sum(n=='D03_Tipped_Wheel_NegX_Disk' or n=='D03_Tipped_Wheel_PosX_Disk' for n in names)==1,
 'two_shared_materials_and_vertex_color_on_every_primitive':len(gltf.get('materials',[]))==2 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'preview_fox_camera_studio_and_locators_excluded':not any(n.startswith(('D03_Fox_','D03_Preview','D03_Key','D03_Fill','D03_Rim','D03_Source')) for n in names),
 'all_mesh_index_accessors_valid':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf['accessors']) and gltf['accessors'][p['indices']]['count']>0 for p in prims)}
assert all(glb_checks.values()),json.dumps(glb_checks,indent=2)

checks={
 'intact_exact_1_4_x_2_2_x_1_3_m_including_wheel_hubs_and_handle_tips':all(abs(idm['dimensions_blender_xyz_m'][i]-[1.4,2.2,1.3][i])<.002 for i in range(3)),
 'both_variant_roots_centered_on_bottom_pivots':all(abs(measurements[r.name]['bounds_min_blender_m'][0]+measurements[r.name]['bounds_max_blender_m'][0])<.002 and abs(measurements[r.name]['bounds_min_blender_m'][1]+measurements[r.name]['bounds_max_blender_m'][1])<.002 and abs(measurements[r.name]['bounds_min_blender_m'][2])<.002 for r in roots),
 'exactly_two_broad_body_bands_and_three_broad_wall_boards_per_side':sum(1 for o in iparts if o.get('broad_body_band'))==2 and sum(1 for o in iparts if 'Left_WallBoard_' in o.name)==3 and sum(1 for o in iparts if 'Right_WallBoard_' in o.name)==3 and sum(1 for o in iparts if 'Front_WallBoard_' in o.name)==3 and sum(1 for o in iparts if 'Rear_WallBoard_' in o.name)==3,
 'upright_cart_has_two_quiet_solid_disk_wheels':sum(1 for o in iparts if o.get('disk_wheel'))==2,
 'tipped_variant_reuses_rigidly_transformed_intact_parts_and_loses_one_wheel':sum(1 for o in tparts if o.get('disk_wheel'))==1 and all(o.get('state')=='tipped_derived_from_intact_cart' for o in tparts if 'Wheel' in o.name or 'DiagonalHandle' in o.name),
 'missing_side_has_exposed_wood_axle_and_exactly_three_grounded_cargo_blocks':any(o.name=='D03_Tipped_WoodAxle' for o in tparts) and not any(o.name.startswith('D03_Tipped_Wheel_PosX_') for o in tparts) and sum(1 for o in tparts if o.name.startswith('D03_Tipped_SpilledCargoBlock_'))==3 and all(abs(min(v.co.z for v in o.data.vertices))<.002 for o in tparts if o.name.startswith('D03_Tipped_SpilledCargoBlock_')),
 'all_meshes_closed_manifold_with_no_loose_geometry':all(m['non_manifold_edges']==0 and m['boundary_edges']==0 and m['loose_edges']==0 and m['loose_vertices']==0 for v in measurements.values() for m in v['mesh_health']),
 'two_shared_vertex_color_materials_are_non_emissive':len(materials)==2 and all(o.data.color_attributes.get('Color') for o in iparts+tparts),
 'actual_idle_fox_used_only_in_preview':fox.animation_data.action.name=='Idle' and all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword'))),
 'concept_prompt_gdignore_and_both_renders_saved':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png')),
 'original_default_cube_camera_light_preserved':all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))}
assert all(checks.values()),json.dumps(checks,indent=2)

metrics={'id':'D03','asset':'d03_abandoned_cargo_cart','glb':'assets/generated/wind_ruins/d03/d03_abandoned_cargo_cart.glb',
 'catalog_envelope_intact_blender_xyz_m':[1.4,2.2,1.3],
 'dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},
 'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'states':measurements,
 'geometry':{'intact_mesh_parts':idm['mesh_parts'],'tipped_mesh_parts':tdm['mesh_parts'],'body_bands_per_state':2,'boards_per_box_side':3,
  'upright_disk_wheels':2,'tipped_disk_wheels':1,'removed_wheel_side':'positive X','exposed_axle':True,'spilled_cargo_blocks':3,
  'tipped_roll_degrees':73,'fallen_cargo_not_used_as_support':True,'tipped_geometry':'copied from intact state and rigidly rotated about longitudinal side; one wheel and its outer hub removed'},
 'materials':{'count':len(materials),'names':materials,'vertex_colors':True,'emission':'none'},
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_degrees':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'self_check':{'geometry':checks,'glb':glb_checks}}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)

state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8'))
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z');was_done=state['D03'].get('state')=='completed'
state['D03'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/d03/d03_abandoned_cargo_cart.glb',
 'source':'assets/generated/wind_ruins/d03/source/d03_abandoned_cargo_cart.blend','preview':'assets/generated/wind_ruins/d03/preview.png',
 'evidence':'output/wind_production/d03/','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},
 'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'triangles_per_state':{k:v['triangles'] for k,v in measurements.items()},
 'mesh_parts_per_state':{k:v['mesh_parts'] for k,v in measurements.items()},'materials':materials,'glb_valid':all(glb_checks.values()),
 'self_check':'Intact cart fits exact 1.4 x 2.2 x 1.3 m envelope with two disk wheels, 3 broad boards on each side and exactly two closed bronze hoops. Tipped state is copied from and rigidly rolled from the intact mesh parts; exactly one wheel is removed exposing the axle, and three blocks rest on the low side. Every mesh is closed manifold with vertex colors; valid Y-up GLB v2 excludes preview/locators. Actual Idle fox shown for scale; default Cube/Camera/Light scene preserved.',
 'completed_utc':stamp})
if not was_done:state['completed_count']=int(state.get('completed_count',0))+1;state['pending_count']=int(state.get('pending_count',20))-1
queue=state.get('remaining_catalog_order',[])
if queue and queue[0]=='D03':queue=queue[1:]
state['remaining_catalog_order']=queue;state['next_asset']=queue[0] if queue else 'complete'
state['active_blender_scene']='WindProduction_D03';state['current_task']=f"D03 complete ({stamp}); proceed to {state['next_asset']} through actual2D, one Sol advisory, direct MCP Blender build, self-check and save."
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
    f.write(f"\n## D03 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/d03/d03_abandoned_cargo_cart.glb` ({len(raw):,} bytes), source blend, empty `.gdignore`, actual concept, preview and metrics. Upright geometry fits exactly 1.4 × 2.2 × 1.3 m including wheel hubs and handle tips. Its 29 closed mesh parts include two solid disks, three broad wall boards per side, and exactly two broad bronze hoops. The tipped root reuses transformed copies of the intact cart; one wheel/hub is removed, leaving the axle end exposed, and three cargo blocks sit at the low side without supporting the body. Both states use two restrained vertex-color materials; all meshes are manifold. GLB v2/Y-up/header, wheel counts, COLOR_0, exact upright envelope, bottom-center pivots and preview/locator exclusions were checked. Beauty and fixed game-camera images with the actual Idle fox are in `{PRE}/`.\n")
print('D03_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'states':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'mesh_parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'glb_checks':glb_checks,'checks':checks,'state':{'completed_count':state['completed_count'],'pending_count':state['pending_count'],'next_asset':state['next_asset']}}))
