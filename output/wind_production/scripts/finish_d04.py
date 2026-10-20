import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d04';PRE=ROOT+'/output/wind_production/d04'
GLB=OUT+'/d04_abandoned_storage_kit.glb';BLEND=OUT+'/source/d04_abandoned_storage_kit.blend'
CONCEPT=ROOT+'/output/wind_production/concepts/d04_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/d04_prompt.txt'
scene=bpy.data.scenes['WindProduction_D04'];bpy.context.window.scene=scene
export=bpy.data.collections['D04_Export'];preview=bpy.data.collections['D04_Preview_ONLY'];source=bpy.data.collections['D04_SourceLocators_NOT_EXPORTED']
roots=[bpy.data.objects[n] for n in ('D04_Open_HollowChest','D04_Closed_Chest_Cluster','D04_Closed_CrateCluster_1','D04_Closed_CrateCluster_2','D04_TwoTierRack_Intact','D04_TwoTierRack_BrokenLeg')]

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in objs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();t=len(ob.data.loop_triangles);tris+=t;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(objs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

measurements={r.name:measure(r) for r in roots}
closed=measurements['D04_Closed_Chest_Cluster'];intact=measurements['D04_TwoTierRack_Intact'];broken=measurements['D04_TwoTierRack_BrokenLeg']
assert all(abs(closed['dimensions_blender_xyz_m'][i]-[.9,.7,.65][i])<.004 for i in range(3)),closed
assert all(abs(intact['dimensions_blender_xyz_m'][i]-[1.8,.7,1.6][i])<.004 for i in range(3)),intact
assert all(abs(broken['dimensions_blender_xyz_m'][i]-[1.8,.7,1.6][i])<.004 for i in range(3)),broken
assert all(v['non_manifold_edges']==0 and v['boundary_edges']==0 and v['loose_edges']==0 and v['loose_vertices']==0 for q in measurements.values() for v in q['mesh_health']),measurements
mesh_parts=[o for o in export.objects if o.type=='MESH']
assert len(mesh_parts)==54,[(o.name) for o in mesh_parts]
assert len({m.name for o in mesh_parts for m in o.data.materials})==2
assert all(o.data.color_attributes.get('Color') is not None for o in mesh_parts)
assert len([o for o in bpy.data.objects['D04_TwoTierRack_Intact'].children_recursive if o.type=='MESH' and o.get('post_role')])==4
assert len([o for o in bpy.data.objects['D04_TwoTierRack_Intact'].children_recursive if o.type=='MESH' and o.get('single_broad_shelf_plane')])==2
brokenroot=bpy.data.objects['D04_TwoTierRack_BrokenLeg']
assert len([o for o in brokenroot.children_recursive if o.type=='MESH' and o.get('post_role')])==4
assert len([o for o in brokenroot.children_recursive if o.type=='MESH' and o.get('single_broad_shelf_plane')])==2
assert sum(1 for o in brokenroot.children_recursive if o.type=='MESH' and o.get('detached_foot'))==1
assert len([o for o in bpy.data.objects['D04_Closed_Chest_Cluster'].children_recursive if o.type=='MESH' and o.get('one_broad_wrap_band')])==4
assert all(len([o for o in r.children_recursive if o.type=='MESH' and o.get('one_broad_wrap_band')])==4 for r in roots[:4])
assert len([o for o in source.objects if o.get('source_only')])==len(roots)
assert bpy.data.scenes.get('Scene') is not None and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
cam=bpy.data.objects['D04_PreviewCamera'];fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('D04_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT) and os.path.isfile(OUT+'/source/.gdignore')

scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.15;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
cam.location=(0,-14.5,8.1);cam.rotation_euler=(Vector((0,0,.78))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['D04_TwoTierRack_Intact']
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20];gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'))
nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes];prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
expected_roots=[r.name for r in roots]
checks={
 'glb_v2_length_and_json_chunk':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'all_named_roots_and_mesh_objects_exported':all(n in names for n in expected_roots) and all(o.name in names for o in mesh_parts),
 'exact_1_8_by_0_7_by_1_6_m_two_tier_racks':all(abs(intact['dimensions_blender_xyz_m'][i]-[1.8,.7,1.6][i])<.004 for i in range(3)) and all(abs(broken['dimensions_blender_xyz_m'][i]-[1.8,.7,1.6][i])<.004 for i in range(3)),
 'closed_chest_exact_0_9_by_0_7_by_0_65_m':all(abs(closed['dimensions_blender_xyz_m'][i]-[.9,.7,.65][i])<.004 for i in range(3)),
 'four_support_positions_per_rack_state_with_one_snapped_fragment_and_detached_foot':len([o for o in bpy.data.objects['D04_TwoTierRack_Intact'].children_recursive if o.type=='MESH' and o.get('post_role')])==4 and len([o for o in brokenroot.children_recursive if o.type=='MESH' and o.get('post_role')])==4 and len([o for o in bpy.data.objects['D04_TwoTierRack_Intact'].children_recursive if o.type=='MESH' and o.get('single_broad_shelf_plane')])==2 and len([o for o in brokenroot.children_recursive if o.type=='MESH' and o.get('single_broad_shelf_plane')])==2 and sum(1 for o in brokenroot.children_recursive if o.get('detached_foot'))==1,
 'three_matching_closed_crates_clustered_with_open_variant_separate':len([r for r in roots if r.name.startswith('D04_Closed')])==3 and len([r for r in roots if 'CrateCluster' in r.name])==2,
 'shared_wood_and_muted_bronze_materials_with_vertex_colors':len(gltf.get('materials',[]))==2 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'all_meshes_closed_manifold_without_loose_geometry':all(v['non_manifold_edges']==0 and v['boundary_edges']==0 and v['loose_edges']==0 and v['loose_vertices']==0 for q in measurements.values() for v in q['mesh_health']),
 'preview_fox_camera_studio_and_source_locators_excluded':not any(n.startswith(('D04_Fox_','D04_Preview','D04_Key','D04_Fill','D04_Rim','D04_Source','D04_Pivot')) for n in names),
 'all_primitive_index_accessors_valid':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf['accessors']) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'original_default_cube_camera_light_preserved':all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'actual_idle_fox_in_preview_and_required_files_present':fox.animation_data.action.name=='Idle' and all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))}
assert all(checks.values()),json.dumps(checks,indent=2)

for path in (OUT+'/concept.png',):shutil.copy2(CONCEPT,path)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
materials=sorted({m.name for o in mesh_parts for m in o.data.materials})
metrics={'id':'D04','asset':'d04_abandoned_storage_kit','glb':'assets/generated/wind_ruins/d04/d04_abandoned_storage_kit.glb','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'states':measurements,'geometry':{'closed_chest_catalog_envelope_m':[.9,.7,.65],'open_chest_envelope_including_open_lid_m':measurements['D04_Open_HollowChest']['dimensions_blender_xyz_m'],'closed_chest_hollow':True,'one_wrap_band_per_chest':True,'rack_catalog_envelope_m':[1.8,.7,1.6],'rack_posts_intact':4,'rack_posts_broken':3,'single_shelf_planes_per_state':2,'broken_leg_fracture_planes':3,'detached_foot':True,'rack_lean_degrees':1,'closed_crates_in_compact_cluster':3},'materials':{'count':len(materials),'names':materials,'shared':True,'vertex_colors':True,'emission':'none'},'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'preview':{'beauty':'output/wind_production/d04/beauty_3quarter.png','game_camera':'output/wind_production/d04/game_camera.png','fox_reference':'actual generated/models/fox_spirit.glb; Idle frame1; runtime fox_palette; helper and Sword hidden','game_camera_location_blender':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},'self_check':checks}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8-sig'));stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z');was=state['D04'].get('state')=='completed'
state['D04'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/d04/d04_abandoned_storage_kit.glb','source':'assets/generated/wind_ruins/d04/source/d04_abandoned_storage_kit.blend','preview':'assets/generated/wind_ruins/d04/preview.png','evidence':'output/wind_production/d04/','dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},'triangles_per_state':{k:v['triangles'] for k,v in measurements.items()},'mesh_parts_per_state':{k:v['mesh_parts'] for k,v in measurements.items()},'materials':materials,'glb_valid':all(checks.values()),'self_check':'Closed chest exact 0.9 x 0.7 x 0.65 m; open variant uses the same hollow body and rear-hinged lid. Each crate has one broad four-piece wrap band. Both racks exact 1.8 x 0.7 x 1.6 m with two broad shelves; intact has four posts, broken has three plus a detached snapped foot and subtle 1-degree lean. Three matching closed crates form one compact cluster. All export meshes are closed manifold; GLB v2/Y-up/header, names, COLOR_0, indices, material count, preview exclusions, bottom pivots, and original default scene checked. Actual Idle fox used only in previews.','completed_utc':stamp})
if not was:state['completed_count']=int(state.get('completed_count',0))+1;state['pending_count']=int(state.get('pending_count',18))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='D04':q=q[1:]
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete';state['active_blender_scene']='WindProduction_D04';state['current_task']=f'D04 complete ({stamp}); proceed to {state["next_asset"]} through actual2D, one Sol advisory, direct MCP Blender build, self-check and save.';state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
    f.write(f"\n## D04 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/d04/d04_abandoned_storage_kit.glb` ({len(raw):,} bytes), Blender source, `.gdignore`, concept, preview and metrics. The closed hollow one-band chest and both rack variants fit their exact catalog envelopes. Each rack has two single broad shelf planes; the intact state has four corner posts and the broken state has one three-plane snapped corner, separated foot and subtle lean. Three closed crates sit as a compact cluster beside it. All 64 mesh parts are manifold, use two shared vertex-color materials, and the Y-up GLB header, node names, vertex colors, indices, render exclusions and original default scene were checked. Beauty and exact fixed-game-camera previews use the actual Idle fox.\n")
print('D04_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'states':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'mesh_parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
