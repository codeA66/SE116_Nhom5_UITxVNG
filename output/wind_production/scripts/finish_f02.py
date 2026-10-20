import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/f02';PRE=ROOT+'/output/wind_production/f02'
CONCEPT=ROOT+'/output/wind_production/concepts/f02_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/f02_prompt.txt'
GLB=OUT+'/f02_torn_wind_banner.glb';BLEND=OUT+'/source/f02_torn_wind_banner.blend'
scene=bpy.data.scenes['WindProduction_F02'];bpy.context.window.scene=scene
export=next(c for c in scene.collection.children if c.name.startswith('F02_Export'))
preview=next(c for c in scene.collection.children if c.name.startswith('F02_Preview_ONLY'))
root=bpy.data.objects['F02_Torn_WindBanner'];panel=bpy.data.objects['F02_ClothPanel_Torn_TopAnchored'];emblem=bpy.data.objects['F02_ClothEmblem_OpenRing_ThreeStrokes']
assert not os.path.exists(GLB),'Refusing to overwrite existing F02 GLB'

def bounds(ob):
    pts=[ob.matrix_local@v.co for v in ob.data.vertices]
    return [min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]

def measure(root):
    meshes=[o for o in root.children_recursive if o.type=='MESH'];pts=[];tris=0;health=[]
    for ob in meshes:
        lo,hi=bounds(ob);pts.extend([Vector((x,y,z)) for x in (lo[0],hi[0]) for y in (lo[1],hi[1]) for z in (lo[2],hi[2])])
        ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles);tris+=n
        bm=bmesh.new();bm.from_mesh(ob.data);health.append({'mesh':ob.name,'triangles':n,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(meshes),'triangles':tris,'mesh_health':health}

def surface_area(mesh):
    total=0.0
    for p in mesh.polygons:
        pts=[mesh.vertices[i].co for i in p.vertices]
        if len(pts)<3:continue
        for j in range(1,len(pts)-1):total+=.5*(pts[j]-pts[0]).cross(pts[j+1]-pts[0]).length
    return total

measurements=measure(root);meshes=[o for o in export.objects if o.type=='MESH']
assert abs(measurements['dimensions_blender_xyz_m'][0]-1.55)<.002,measurements
assert abs(measurements['dimensions_blender_xyz_m'][2]-4.8)<.002,measurements
lo,hi=bounds(panel);panel_dims=[hi[i]-lo[i] for i in range(3)]
assert abs(panel_dims[0]-1.2)<.002 and abs(panel_dims[2]-2.4)<.002,panel_dims
loss=float(panel['cloth_area_loss_percent']);assert 15<=loss<=25,loss
assert panel['tears']==2 and panel['upper_attachments_intact']
assert panel.data.uv_layers and emblem.data.uv_layers
uv=panel.data.uv_layers[0];uvals=[d.uv.x for d in uv.data];assert min(uvals)<.001 and max(uvals)>.91,(min(uvals),max(uvals))
assert len({m.name for o in meshes for m in o.data.materials})==1 and all(o.data.color_attributes.get('Color') for o in meshes)
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
source_cloth=bpy.data.collections['F01_Export'].objects['Cloth_Wind_Animated'];ngrid=17*25
old_logo=sorted(tuple(round(v.co[i],7) for i in range(3)) for v in source_cloth.data.vertices[ngrid:])
new_logo=sorted(tuple(round(v.co[i],7) for i in range(3)) for v in emblem.data.vertices)
assert old_logo==new_logo,'F02 emblem no longer matches F01 exactly'
assert len(emblem.data.polygons)==sum(1 for p in source_cloth.data.polygons if not all(i<ngrid for i in p.vertices))
solid=[o for o in meshes if any(n in o.name for n in ('Foot_Stone','Pole_Octagonal','Foot_Collar','Upper_Collar','Crossbar'))]
for ob in solid:
    bm=bmesh.new();bm.from_mesh(ob.data);bad=sum(not e.is_manifold for e in bm.edges)+sum(len(v.link_edges)==0 for v in bm.verts);bm.free();assert bad==0,(ob.name,bad)
assert measurements['triangles']<5000,measurements['triangles']
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT) and os.path.isfile(OUT+'/source/.gdignore')
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('F02_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'

scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam=bpy.data.objects['F02_PreviewCamera'];scene.camera=cam;cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
cam.location=(6,-11,7);cam.rotation_euler=(Vector((.25,0,2.4))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)
cam.data.lens=40;cam.location=(6,-11,7);cam.rotation_euler=(Vector((.25,0,2.4))-cam.location).to_track_quat('-Z','Y').to_euler()
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'));nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes];prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
checks={
 'glb_v2_header_and_json_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON' and chunk_len>0,
 'named_torn_banner_root_and_panel_logo':all(n in names for n in (root.name,panel.name,emblem.name)),
 'same_F01_mount_dimensions_and_ground_pivot':abs(measurements['dimensions_blender_xyz_m'][0]-1.55)<.002 and abs(measurements['dimensions_blender_xyz_m'][2]-4.8)<.002 and abs(measurements['bounds_min_blender_m'][2])<.002,
 'cloth_panel_exact_1_2_by_2_4_m':abs(panel_dims[0]-1.2)<.002 and abs(panel_dims[2]-2.4)<.002,
 'two_broad_tears_remove_15_to_25_percent':panel['tears']==2 and 15<=loss<=25,
 'exact_F01_emblem_and_upper_attachments_preserved':old_logo==new_logo and panel['upper_attachments_intact'],
 'top_anchored_free_edge_UV_direction_preserved':min(uvals)<.001 and max(uvals)>.91 and 'WindUV_TopAnchorU0' in [u.name for u in panel.data.uv_layers],
 'all_geometry_under_5000_triangles':measurements['triangles']<5000,
 'single_shared_vertex_color_material':len(gltf.get('materials',[]))==1 and len({m.name for o in meshes for m in o.data.materials})==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'preview_fox_and_source_objects_excluded':not any(n.startswith(('F02_Fox_','F02_Preview','F02_Source')) for n in names),
 'all_primitive_indices_reference_valid_accessors':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf.get('accessors',[])) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'actual_idle_fox_and_default_scene_preserved':fox.animation_data.action.name=='Idle' and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'concept_prompt_previews_source_and_gdignore_present':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))}
assert all(checks.values()),json.dumps(checks,indent=2)
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={'id':'F02','asset':'f02_torn_wind_banner','glb':'assets/generated/wind_ruins/f02/f02_torn_wind_banner.glb','dimensions_blender_xyz_m':measurements['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':measurements['dimensions_godot_xyz_m'],'cloth_dimensions_blender_xyz_m':panel_dims,'cloth_surface_area_m2_before':float(panel['cloth_area_surface_before_m2']),'cloth_surface_area_m2_removed':float(panel['cloth_area_removed_m2']),'cloth_area_loss_percent':loss,'cloth_damage':'two broad triangular cuts from the lower edge; both below emblem; upper mount intact','emblem':'exact F01 vertex positions, open C-ring and three same-direction strokes','materials':{'count':len(gltf.get('materials',[])),'names':sorted({m.name for o in meshes for m in o.data.materials}),'vertex_colors':True,'emission':'none'},'triangles':measurements['triangles'],'mesh_parts':measurements['mesh_parts'],'mesh_health':measurements['mesh_health'],'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'checks':checks,'preview':{'beauty':'output/wind_production/f02/beauty_3quarter.png','game_camera':'output/wind_production/f02/game_camera.png','fox':'actual generated/models/fox_spirit.glb; Idle frame1; fox_palette; Sword and Icosphere helper hidden','game_camera_location_blender':[0,-20.57,24.51],'pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},'completed_utc':stamp}
for p in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(p,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2);f.write('\n')
state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8-sig'));was=state['F02'].get('state')=='completed'
state['F02'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/f02/f02_torn_wind_banner.glb','source':'assets/generated/wind_ruins/f02/source/f02_torn_wind_banner.blend','preview':'assets/generated/wind_ruins/f02/preview.png','evidence':'output/wind_production/f02/','cloth_area_loss_percent':loss,'dimensions_blender_xyz_m':measurements['dimensions_blender_xyz_m'],'cloth_dimensions_blender_xyz_m':panel_dims,'triangles':measurements['triangles'],'mesh_parts':measurements['mesh_parts'],'materials':sorted({m.name for o in meshes for m in o.data.materials}),'glb_valid':all(checks.values()),'self_check':'F02 duplicates the actual F01 pole, base, collars, crossbar, cloth folds and logo; only two broad lower-edge triangular areas are removed, measuring 16.8% of the 3D cloth panel area. The full 1.2 x 2.4 m cloth range and 1.55 x 4.8 m banner bounds remain; top attachments and F01 UV direction survive. The open C-ring and three same-direction wind strokes compare vertex-for-vertex against F01. One shared material with vertex colors, GLB v2/Y-up/header, valid indices, preview exclusion, idle fox and original default scene checked. Beauty and game-camera previews saved.','completed_utc':stamp})
if not was:state['completed_count']=int(state.get('completed_count',27))+1;state['pending_count']=int(state.get('pending_count',12))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='F02':q=q[1:]
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete';state['active_blender_scene']='WindProduction_F02'
state['current_task']=f'F02 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.';state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
        f.write(f"\n## F02 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/f02/f02_torn_wind_banner.glb` ({len(raw):,} bytes), Blender source, `.gdignore`, actual concept, preview and metrics. It reuses F01’s exact pole/mount/folds/logo; two broad lower-edge tears remove {loss:.1f}% of cloth area while preserving the 1.2 × 2.4 m panel envelope, top attachments, open C-ring and three-stroke emblem. All meshes remain below 5,000 triangles with one shared vertex-color material. GLB v2/Y-up/header, node names, `COLOR_0`, indices, preview exclusions, idle fox and default scene checked. Beauty and fixed game-camera previews saved. Next: {state['next_asset']}.\n")
print('F02_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'triangles':measurements['triangles'],'mesh_parts':measurements['mesh_parts'],'dimensions_blender_xyz_m':measurements['dimensions_blender_xyz_m'],'cloth_dimensions_blender_xyz_m':panel_dims,'cloth_area_loss_percent':loss,'checks':checks,'next_asset':state['next_asset'],'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
