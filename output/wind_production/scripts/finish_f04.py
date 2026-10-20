import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/f04'
PRE=ROOT+'/output/wind_production/f04'
CONCEPT=ROOT+'/output/wind_production/concepts/f04_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/f04_prompt.txt'
GLB=OUT+'/f04_secondary_horizontal_banner.glb'
BLEND=OUT+'/source/f04_secondary_horizontal_banner.blend'

scene=bpy.data.scenes['WindProduction_F04']
bpy.context.window.scene=scene
export=next(c for c in scene.collection.children if c.name.startswith('F04_Export'))
preview=next(c for c in scene.collection.children if c.name.startswith('F04_Preview_ONLY'))
root=bpy.data.objects['F04_Secondary_Horizontal_Banner']
panel=bpy.data.objects['F04_Cloth_Panel_2p4x1p2']
emblem=bpy.data.objects['F04_Emblem_ExactF01_OpenRing_ThreeStrokes']
crossbar=bpy.data.objects['F04_Crossbar']
assert not os.path.exists(GLB),'Refusing to overwrite existing F04 GLB'

def bounds(ob):
    pts=[ob.matrix_local@v.co for v in ob.data.vertices]
    return [min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]

meshes=[o for o in export.objects if o.type=='MESH']
assert len(meshes)==9,[o.name for o in meshes]
allpts=[];health=[];triangles=0
for ob in meshes:
    lo,hi=bounds(ob)
    allpts.extend(Vector((x,y,z)) for x in (lo[0],hi[0]) for y in (lo[1],hi[1]) for z in (lo[2],hi[2]))
    ob.data.calc_loop_triangles();tris=len(ob.data.loop_triangles);triangles+=tris
    bm=bmesh.new();bm.from_mesh(ob.data)
    health.append({'mesh':ob.name,'triangles':tris,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                   'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),
                   'loose_vertices':sum(not v.link_edges for v in bm.verts)})
    bm.free()
lo=[min(p[i] for p in allpts) for i in range(3)]
hi=[max(p[i] for p in allpts) for i in range(3)]
dims=[hi[i]-lo[i] for i in range(3)]
godot_dims=[dims[0],dims[2],dims[1]]
panel_lo,panel_hi=bounds(panel);panel_dims=[panel_hi[i]-panel_lo[i] for i in range(3)]
emblem_lo,emblem_hi=bounds(emblem);emblem_dims=[emblem_hi[i]-emblem_lo[i] for i in range(3)]
uv=panel.data.uv_layers.get('WindUV_TopAnchorU0')
assert uv and len(uv.data)>0
uvals=[d.uv.x for d in uv.data]
f01=bpy.data.collections['F01_Export']
source_cloth=f01.objects['Cloth_Wind_Animated']
ngrid=17*25
source_logo_faces=[p for p in source_cloth.data.polygons if not all(i<ngrid for i in p.vertices)]
source_logo_vertices=sorted({i for p in source_logo_faces for i in p.vertices})
source_pts=[source_cloth.data.vertices[i].co for i in source_logo_vertices]
source_logo_dims=[max(v.x for v in source_pts)-min(v.x for v in source_pts),0,
                  max(v.z for v in source_pts)-min(v.z for v in source_pts)]
pole=bpy.data.objects['F04_Pole_Octagonal']
pole_lo,pole_hi=bounds(pole)
assert abs(panel_dims[0]-2.4)<.002 and abs(panel_dims[2]-1.2)<.002,panel_dims
assert abs(panel_lo[2]-2.5)<.002 and abs(panel_hi[2]-3.7)<.002,(panel_lo,panel_hi)
assert abs(emblem_dims[0]-source_logo_dims[0])<.002 and abs(emblem_dims[2]-source_logo_dims[2])<.002,(emblem_dims,source_logo_dims)
assert abs(crossbar.dimensions.x-2.64)<.002
assert abs(pole_hi[2]-4.2)<.002 and abs(lo[2])<.002,(pole_hi,lo)
assert min(uvals)<.001 and max(uvals)>.99,(min(uvals),max(uvals))
assert len(emblem.data.polygons)==224 and len(emblem.data.vertices)==464
assert all(len(ob.data.materials)==1 and ob.data.color_attributes.get('Color') for ob in meshes)
material_names={m.name for o in meshes for m in o.data.materials}
assert material_names=={'F01_Palette_VertexColor'},material_names
assert triangles<5000
assert all(x['non_manifold_edges']==0 and x['loose_edges']==0 and x['loose_vertices']==0
           for x in health if not x['mesh'].startswith(('F04_Cloth_','F04_Emblem_'))),health
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('F04_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
assert all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore'))

# Render one studio beauty and the actual fixed Godot camera view.
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam=bpy.data.objects['F04_PreviewCamera'];scene.camera=cam
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=42
cam.location=(5,-8,6);cam.rotation_euler=(Vector((0,0,2))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

# Export only the model collection; preview fox, lights, floor, camera and notes stay out.
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12])
chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'))
nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
expected=(root.name,panel.name,emblem.name,'F04_Pole_Octagonal','F04_Crossbar','F04_Foot_Stone')
checks={
 'glb_v2_header_and_json_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON' and chunk_len>0,
 'named_root_panel_emblem_pole_crossbar_and_base':all(n in names for n in expected),
 'panel_is_exactly_2p4_by_1p2_m_with_hem_at_2p5':abs(panel_dims[0]-2.4)<.002 and abs(panel_dims[2]-1.2)<.002 and abs(panel_lo[2]-2.5)<.002 and abs(panel_hi[2]-3.7)<.002,
 'pole_tip_at_4p2_and_ground_pivot_at_zero':abs(pole_hi[2]-4.2)<.002 and abs(lo[2])<.002,
 'crossbar_wider_than_panel_and_emblem_original_proportion':abs(crossbar.dimensions.x-2.64)<.002 and abs(emblem_dims[0]-source_logo_dims[0])<.002 and abs(emblem_dims[2]-source_logo_dims[2])<.002,
 'F01_top_anchored_UV_and_exact_emblem_topology':uv.name=='WindUV_TopAnchorU0' and min(uvals)<.001 and max(uvals)>.99 and len(emblem.data.vertices)==464 and len(emblem.data.polygons)==224,
 'single_shared_F01_vertex_color_material':len(gltf.get('materials',[]))==1 and material_names=={'F01_Palette_VertexColor'} and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'nine_named_export_meshes_and_under_5000_triangles':len(meshes)==9 and triangles<5000 and all(o.name in names for o in meshes),
 'preview_fox_and_staging_objects_excluded':not any(n.startswith(('F04_Fox_','F04_Preview','F04_Source')) for n in names),
 'primitive_indices_reference_nonempty_accessors':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf.get('accessors',[])) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'actual_idle_fox_and_default_scene_preserved':fox.animation_data.action.name=='Idle' and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'concept_prompt_previews_source_and_gdignore_present':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))
}
assert all(checks.values()),json.dumps(checks,indent=2)
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)

stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={
 'id':'F04','asset':'f04_secondary_horizontal_banner','glb':'assets/generated/wind_ruins/f04/f04_secondary_horizontal_banner.glb',
 'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':godot_dims,
 'dimensions_design_blender_xyz_m':[2.705,0.55,4.2],'cloth_dimensions_blender_xyz_m':panel_dims,
 'cloth_z_range_m':[panel_lo[2],panel_hi[2]],'crossbar_width_m':crossbar.dimensions.x,
 'emblem_dimensions_xz_m':[emblem_dims[0],emblem_dims[2]],'emblem_source_dimensions_xz_m':[source_logo_dims[0],source_logo_dims[2]],
 'emblem_geometry':'464 F01 emblem vertices and 224 faces; centered and translated only, original proportions preserved.',
 'uv':'WindUV_TopAnchorU0 copied from F01; u=0 at top attachment and u=1 at free hem.',
 'cloth_geometry':'One separate 2.4 x 1.2 m panel with two broad shallow billows and a clean hem; separate exact emblem mesh.',
 'materials':{'count':len(gltf.get('materials',[])),'names':sorted(material_names),'vertex_colors':True,'emission':'none'},
 'triangles':triangles,'mesh_parts':len(meshes),'mesh_health':health,
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'checks':checks,
 'preview':{'beauty':'output/wind_production/f04/beauty_3quarter.png','game_camera':'output/wind_production/f04/game_camera.png',
            'fox':'actual generated/models/fox_spirit.glb; Idle action and corrected palette; sword and helper hidden',
            'game_camera_location_blender':[0,-20.57,24.51],'pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},
 'completed_utc':stamp}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2);f.write('\n')

state_path=ROOT+'/output/wind_production/asset_state.json'
with open(state_path,encoding='utf-8-sig') as f:state=json.load(f)
was=state['F04'].get('state')=='completed'
state['F04'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/f04/f04_secondary_horizontal_banner.glb',
 'source':'assets/generated/wind_ruins/f04/source/f04_secondary_horizontal_banner.blend','preview':'assets/generated/wind_ruins/f04/preview.png',
 'evidence':'output/wind_production/f04/','dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':godot_dims,
 'cloth_dimensions_blender_xyz_m':panel_dims,'cloth_z_range_m':[panel_lo[2],panel_hi[2]],'triangles':triangles,'mesh_parts':len(meshes),
 'materials':sorted(material_names),'glb_valid':all(checks.values()),
 'self_check':'F04 derives its base, pole, collars, crossbar, cloth palette, UVs and exact emblem from F01. Its panel measures 2.4 x 1.2 m with hem at 2.5 m, pole tip at 4.2 m, and a 2.64 m crossbar. The emblem retains all 464 F01 vertices and 224 faces with original proportions. Separate cloth and emblem meshes use one F01 vertex-color material. GLB v2/Y-up/header, names, COLOR_0, indices, preview exclusions, idle fox, source, concept, previews, original default scene and required dimensions checked. Beauty and game-camera images saved.',
 'completed_utc':stamp})
state['builder']='luna_builder';state['advisor']='sol_advisor';state['protocol']='Actual2D -> one Sol advisory -> direct3D -> selfcheck/save; no3D approval gate'
if not was:
    state['completed_count']=int(state.get('completed_count',29))+1
    state['pending_count']=int(state.get('pending_count',10))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='F04':q=q[1:]
elif 'F04' in q:q.remove('F04')
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete'
state['active_blender_scene']='WindProduction_F04'
state['current_task']=f'F04 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.'
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    audit=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
    with open(audit,'a',encoding='utf-8') as f:
        f.write(f"\n## F04 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/f04/f04_secondary_horizontal_banner.glb` ({len(raw):,} bytes), editable Blender source, `.gdignore`, concept, preview and metrics. The 2.4 x 1.2 m panel has its hem at 2.5 m; the pole tip is 4.2 m and the crossbar is 2.64 m. The separate emblem retains F01's exact 464 vertices, 224 faces and proportions; cloth and emblem use one F01 vertex-color material. GLB, UVs, Y-up, node names, preview exclusions, fox, source artifacts and default scene were checked. Beauty and game-camera previews saved. Next: {state['next_asset']}.\n")
print('F04_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'triangles':triangles,'mesh_parts':len(meshes),
 'dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':godot_dims,'cloth_dimensions_blender_xyz_m':panel_dims,
 'cloth_z_range_m':[panel_lo[2],panel_hi[2]],'checks':checks,'next_asset':state['next_asset'],
 'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
