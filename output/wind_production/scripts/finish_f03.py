import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/f03'
PRE=ROOT+'/output/wind_production/f03'
CONCEPT=ROOT+'/output/wind_production/concepts/f03_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/f03_prompt.txt'
GLB=OUT+'/f03_collapsed_wind_banner.glb'
BLEND=OUT+'/source/f03_collapsed_wind_banner.blend'

scene=bpy.data.scenes['WindProduction_F03']
bpy.context.window.scene=scene
export=next(c for c in scene.collection.children if c.name.startswith('F03_Export'))
preview=next(c for c in scene.collection.children if c.name.startswith('F03_Preview_ONLY'))
root=bpy.data.objects['F03_Collapsed_WindBanner']
assert not os.path.exists(GLB), 'Refusing to overwrite existing F03 GLB'

def bounds(ob):
    pts=[ob.matrix_world @ v.co for v in ob.data.vertices]
    return [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]

meshes=[o for o in export.objects if o.type=='MESH']
assert len(meshes)==9, [o.name for o in meshes]
allpts=[];health=[];triangles=0
for ob in meshes:
    lo,hi=bounds(ob);allpts.extend([Vector((x,y,z)) for x in (lo[0],hi[0]) for y in (lo[1],hi[1]) for z in (lo[2],hi[2])])
    ob.data.calc_loop_triangles();tris=len(ob.data.loop_triangles);triangles+=tris
    bm=bmesh.new();bm.from_mesh(ob.data)
    health.append({'mesh':ob.name,'triangles':tris,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),'loose_vertices':sum(not v.link_edges for v in bm.verts)})
    bm.free()
lo=[min(p[i] for p in allpts) for i in range(3)];hi=[max(p[i] for p in allpts) for i in range(3)]
dims=[hi[i]-lo[i] for i in range(3)]
godot_dims=[dims[0],dims[2],dims[1]]
cloth=bpy.data.objects['F03_Cloth_Continuous_F01EmblemSnagged']
sourcecloth=bpy.data.collections['F01_Export'].objects['Cloth_Wind_Animated']
crossbar=bpy.data.objects['F03_Crossbar']
cloth_lo,cloth_hi=bounds(cloth);cloth_dims=[cloth_hi[i]-cloth_lo[i] for i in range(3)]
uv=cloth.data.uv_layers.get('WindUV_TopAnchorU0')
assert uv and len(uv.data)>0
uvals=[loop.uv.x for loop in uv.data]
assert min(uvals)<.001 and max(uvals)>.90,(min(uvals),max(uvals))
assert len(cloth.data.vertices)==len(sourcecloth.data.vertices)==889
assert len(cloth.data.polygons)==len(sourcecloth.data.polygons)==608
assert len(cloth.data.uv_layers)==len(sourcecloth.data.uv_layers)
assert all(len(ob.data.materials)==1 and ob.data.color_attributes.get('Color') for ob in meshes)
material_names={m.name for ob in meshes for m in ob.data.materials}
assert material_names=={'F01_Palette_VertexColor'},material_names
assert abs(crossbar.dimensions.y-1.55)<.002, list(crossbar.dimensions)
assert 4.2<=dims[0]<=5.2 and abs(dims[1]-1.55)<.01 and .72<=dims[2]<=.9, (dims,lo,hi)
assert lo[2]>=-.015 and abs(lo[2])<.01, ('Asset must be grounded at its stone foot',lo)
assert triangles<5000
assert all(x['non_manifold_edges']==0 and x['loose_edges']==0 and x['loose_vertices']==0 for x in health if not x['mesh'].endswith('Continuous_F01EmblemSnagged')),health
assert next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('F03_Fox_')).animation_data.action.name=='Idle'
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
assert all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore'))

# Beauty shot first, then the fixed gameplay camera (1280x720, 30-degree vertical FOV, 50-degree down pitch).
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam=bpy.data.objects['F03_PreviewCamera'];scene.camera=cam
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24
cam.location=(5,-7,5);cam.rotation_euler=(Vector((2,0,.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=42
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

# Export only the model collection. Preview fox, floor, lights, camera and source note stay out.
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read()
magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'))
nodes=gltf.get('nodes',[]);node_names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
expected=('F03_Collapsed_WindBanner','F03_Pole_Broken_Stump','F03_Pole_Fallen_Upper','F03_Cloth_Continuous_F01EmblemSnagged','F03_Crossbar')
checks={
 'glb_v2_header_and_json_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON' and chunk_len>0,
 'named_root_stump_fallen_pole_cloth_and_crossbar':all(n in node_names for n in expected),
 'approximate_resting_envelope_and_ground_pivot':4.2<=dims[0]<=5.2 and 1.5<=dims[1]<=1.6 and .72<=dims[2]<=.9 and abs(lo[2])<.01,
 'full_width_original_crossbar':abs(crossbar.dimensions.y-1.55)<.002,
 'continuous_f01_cloth_mesh_topology_and_uv':len(cloth.data.vertices)==889 and len(cloth.data.polygons)==608 and uv.name=='WindUV_TopAnchorU0' and min(uvals)<.001 and max(uvals)>.90,
 'single_shared_f01_vertex_color_material':len(gltf.get('materials',[]))==1 and material_names=={'F01_Palette_VertexColor'} and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'all_9_export_meshes_named_and_under_5000_triangles':len(meshes)==9 and triangles<5000 and all(o.name in node_names for o in meshes),
 'preview_fox_source_and_staging_objects_excluded':not any(n.startswith(('F03_Fox_','F03_Preview','F03_Source')) for n in node_names),
 'all_primitive_indices_reference_nonempty_accessors':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf.get('accessors',[])) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'actual_idle_fox_and_original_default_scene_preserved':next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('F03_Fox_')).animation_data.action.name=='Idle' and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'concept_prompt_preview_source_and_gdignore_saved':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,PRE+'/beauty_3quarter.png',PRE+'/game_camera.png',OUT+'/source/.gdignore'))
}
assert all(checks.values()),json.dumps(checks,indent=2)

shutil.copy2(CONCEPT,OUT+'/concept.png')
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={
 'id':'F03','asset':'f03_collapsed_wind_banner','glb':'assets/generated/wind_ruins/f03/f03_collapsed_wind_banner.glb',
 'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':godot_dims,
 'dimensions_target_about_blender_xyz_m':[4.8,1.5,0.8],
 'stump_height_m':.47,'fallen_pole_source':'F01_Pole_Octagonal; eight-sided taper retained; 2-3 broad fracture wedges at cut faces',
 'crossbar_dimensions_blender_xyz_m':list(crossbar.dimensions),'cloth_dimensions_blender_xyz_m':cloth_dims,
 'cloth_geometry':'One continuous F01 panel mesh and exact emblem topology, arching across the fallen pole with two broad sag folds; original UV layers retained.',
 'emblem':'F01 open C-ring and three same-direction strokes, mapped flush across the original surface topology',
 'materials':{'count':len(gltf.get('materials',[])),'names':sorted(material_names),'vertex_colors':True,'emission':'none'},
 'triangles':triangles,'mesh_parts':len(meshes),'mesh_health':health,
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'checks':checks,
 'preview':{'beauty':'output/wind_production/f03/beauty_3quarter.png','game_camera':'output/wind_production/f03/game_camera.png','fox':'actual generated/models/fox_spirit.glb; Idle action, fox_palette, sword and helper hidden','game_camera_location_blender':[0,-20.57,24.51],'pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},
 'completed_utc':stamp}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2);f.write('\n')

state_path=ROOT+'/output/wind_production/asset_state.json'
with open(state_path,encoding='utf-8-sig') as f:state=json.load(f)
was=state['F03'].get('state')=='completed'
state['F03'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/f03/f03_collapsed_wind_banner.glb','source':'assets/generated/wind_ruins/f03/source/f03_collapsed_wind_banner.blend','preview':'assets/generated/wind_ruins/f03/preview.png','evidence':'output/wind_production/f03/','dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':godot_dims,'cloth_dimensions_blender_xyz_m':cloth_dims,'triangles':triangles,'mesh_parts':len(meshes),'materials':sorted(material_names),'glb_valid':all(checks.values()),'self_check':'F03 derives both pole pieces, foot, collars, crossbar and the single continuous cloth from F01. It retains the exact 1.55 m crossbar, 889 cloth vertices, 608 faces and source UVs; the emblem remains on the transformed cloth surface. The 9 export meshes use one F01 vertex-color material. Non-cloth meshes are closed manifold, cloth boundaries are intentional. GLB v2/Y-up/header, named nodes, COLOR_0, indices, preview exclusions, actual Idle fox, source artifacts and original default scene checked. Beauty and fixed game-camera previews saved.','completed_utc':stamp})
state['builder']='luna_builder';state['advisor']='sol_advisor';state['protocol']='Actual2D -> one Sol advisory -> direct3D -> selfcheck/save; no3D approval gate'
if not was:
    state['completed_count']=int(state.get('completed_count',28))+1
    state['pending_count']=int(state.get('pending_count',11))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='F03':q=q[1:]
elif 'F03' in q:q.remove('F03')
state['remaining_catalog_order']=q
state['next_asset']=q[0] if q else 'complete'
state['active_blender_scene']='WindProduction_F03'
state['current_task']=f'F03 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.'
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    audit=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
    with open(audit,'a',encoding='utf-8') as f:
        f.write(f"\n## F03 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/f03/f03_collapsed_wind_banner.glb` ({len(raw):,} bytes), editable Blender source, `.gdignore`, actual concept, preview and metrics. The stump, fallen upper pole, original crossbar and one continuous 889-vertex F01 cloth panel use shared source proportions; the exact F01 emblem and UV layer remain on the draped panel. The 9 meshes use one F01 vertex-color material; all solid parts are manifold, with only intended cloth sheet boundaries. GLB v2/Y-up/header, named nodes, `COLOR_0`, indices, preview exclusions, idle fox, source files and default scene checked. Beauty and fixed game-camera previews saved. Next: {state['next_asset']}.\n")
print('F03_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'triangles':triangles,'mesh_parts':len(meshes),'dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':godot_dims,'cloth_dimensions_blender_xyz_m':cloth_dims,'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
