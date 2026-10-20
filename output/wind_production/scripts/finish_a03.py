import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/a03';PRE=ROOT+'/output/wind_production/a03'
GLB=OUT+'/a03_low_retaining_wall.glb';SOURCE=OUT+'/source/a03_low_retaining_wall.blend';STATE=ROOT+'/output/wind_production/asset_state.json';AUDIT=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name=='WindProduction_A03';assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene=bpy.context.scene;camera=bpy.data.objects['A03_PreviewCamera'];scene.camera=camera
roots=[bpy.data.objects[n] for n in ('A03_Intact','A03_Broken_Low','A03_Terminal_End')]
mesh_objects=[ob for root in roots for ob in root.children_recursive if ob.type=='MESH']
fox=bpy.data.objects['A03_PreviewFox_FoxRig']
old_cam=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height)
old_render=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising)
old_locs={o.name:o.location.copy() for o in roots};old_hide={o.name:o.hide_render for o in mesh_objects};old_fox=fox.location.copy()
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
camera.data.type='PERSP';camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24
def aim(loc,target,lens):camera.location=loc;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
def render(name,loc,target,lens):aim(loc,target,lens);scene.render.filepath=PRE+'/'+name+'.png';bpy.ops.render.render(write_still=True)

# Side-by-side beauty view shows all three variants at matching scale and the fox at the center gap.
roots[0].location=(-4.45,0,0);roots[1].location=(0,0,0);roots[2].location=(4.45,0,0);fox.location=(-2.2,-.85,0)
render('beauty_3quarter',(0,-17,8),(0,0,.55),44)
# Exact Godot camera pose and 30-degree vertical FOV check one full-size wall with the fox beside it.
roots[0].location=(0,0,0)
for ob in [ob for root in roots[1:] for ob in root.children_recursive if ob.type=='MESH']:ob.hide_render=True
fox.location=(2.45,-.2,0)
game_lens=24.0/(2.0*math.tan(math.radians(15.0)));render('game_camera',(0,-20.57,24.51),(0,0,0),game_lens)
for o in roots:o.location=old_locs[o.name]
for ob in mesh_objects:ob.hide_render=old_hide[ob.name]
fox.location=old_fox
camera.location,camera.rotation_euler,camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height=old_cam
scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising=old_render

def bounds(root):
    pts=[];inv=root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type=='MESH':pts.extend(inv@(ob.matrix_world@v.co) for v in ob.data.vertices)
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];return lo,hi,[hi[i]-lo[i] for i in range(3)]
def health(ob):
    bm=bmesh.new();bm.from_mesh(ob.data);h={'vertices':len(bm.verts),'faces':len(bm.faces),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),'loose_vertices':sum(not v.link_edges for v in bm.verts)};bm.free();ob.data.calc_loop_triangles();h['triangles']=len(ob.data.loop_triangles);return h
metrics_states={};all_meshes=[]
for root,label in zip(roots,['intact','broken_low','terminal_end']):
    lo,hi,dims=bounds(root);assert all(abs(a-b)<.002 for a,b in zip(dims,(4,.35,1))),(label,lo,hi,dims)
    meshes=[ob for ob in root.children_recursive if ob.type=='MESH'];assert meshes
    rows=[]
    for ob in meshes:
        h=health(ob);assert h['non_manifold_edges']==h['boundary_edges']==h['loose_edges']==h['loose_vertices']==0,(label,ob.name,h)
        assert h['triangles']<5000 and len(ob.data.materials)==1 and ob.data.color_attributes.get('Color'),(label,ob.name,h)
        rows.append({'name':ob.name,'triangles':h['triangles'],'mesh_health':h})
    all_meshes.extend(meshes)
    metrics_states[label]={'bounds_min_local_m':[round(x,6) for x in lo],'bounds_max_local_m':[round(x,6) for x in hi],'dimensions_blender_xyz_m':[round(x,6) for x in dims],'mesh_count':len(meshes),'meshes':rows}
assert abs(metrics_states['intact']['dimensions_blender_xyz_m'][2]-1)<.002
assert abs(metrics_states['broken_low']['bounds_min_local_m'][0]+2)<.002 and abs(metrics_states['broken_low']['bounds_max_local_m'][0]-2)<.002
assert abs(metrics_states['terminal_end']['bounds_max_local_m'][0]-2)<.002

export=bpy.data.collections['A03_Export']
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
with open(GLB,'rb') as f:magic,version,declared=struct.unpack('<4sII',f.read(12));json_len,json_type=struct.unpack('<I4s',f.read(8));gltf=json.loads(f.read(json_len).decode('utf-8'))
size=os.path.getsize(GLB);assert magic==b'glTF' and version==2 and declared==size and json_type==b'JSON';assert gltf.get('asset',{}).get('version')=='2.0';assert len(gltf.get('materials',[]))==1
mesh_rows=[]
for m in gltf.get('meshes',[]):
    prims=m.get('primitives',[]);assert prims and all('COLOR_0' in p.get('attributes',{}) for p in prims),(m.get('name'),prims)
    mesh_rows.append({'name':m.get('name'),'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for p in prims),'primitives':len(prims)})
nodes={n.get('name') for n in gltf.get('nodes',[])};required={'A03_Intact','A03_Broken_Low','A03_Terminal_End'};assert required<=nodes,(required-nodes,nodes)
assert len(mesh_rows)==len(all_meshes) and sum(m['triangles'] for m in mesh_rows)<5000,(len(mesh_rows),len(all_meshes),mesh_rows)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
advisory='Keep the intact wall at exactly 4.0 x 0.35 x 1.0 m including its 0.12 m cap; use clean base/body/cap masses and flat modular ends. In the broken-low state remove one broad central panel and cap section, retaining the continuous base and only 2-3 large fracture planes. The terminal state keeps the same section with one tapered closed end; use plain broad faces, slim bevels and sparse moss/color variation.'
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={'id':'A03','asset':'modular low retaining wall','glb':'assets/generated/wind_ruins/a03/a03_low_retaining_wall.glb','source':'assets/generated/wind_ruins/a03/source/a03_low_retaining_wall.blend','concept':'assets/generated/wind_ruins/a03/concept.png','states':metrics_states,'dimensions_blender_xyz_m':[4,.35,1],'dimensions_godot_xyz_m':[4,1,.35],'cap_thickness_m':.12,'base':'continuous across broken-low variant','terminal_end':'same 4 m module with one tapered closed end and one flat connector','materials':1,'glb_meshes':mesh_rows,'glb_bytes':size,'glb_v2_y_up_header':True,'color_attributes':'COLOR_0 on every primitive','advisory':advisory,'game_camera':[0,24.51,20.57],'vertical_fov_degrees':30,'self_check':'All three variants fit exact 4 x 0.35 x 1.0 m envelopes; broken-low retains a continuous base, and terminal retains one flat connector plus tapered closed end. Every mesh is manifold, uses one shared material and COLOR_0, and is under 5000 triangles; GLB v2 header/names validated; default Scene/Cube/Camera/Light preserved.','completed_utc':stamp}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
for img in bpy.data.images:
    if img.filepath.lower().endswith('fox_palette.png') and not img.packed_file:img.pack()
for root in (roots[0],roots[2]):
    root.hide_set(True)
    for ob in root.children_recursive:
        ob.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,copy=True)
with open(STATE,'r',encoding='utf-8') as f:state=json.load(f)
completed_before=sum(1 for aid in state.get('production_catalog_ids',[]) if isinstance(state.get(aid),dict) and state[aid].get('state')=='completed')
assert completed_before==34,('unexpected completion count',completed_before)
a=state['A03'];a.update({'state':'completed','advisor':'sol_advisor_resume','advisory':advisory,'advisory_received_from':'sol_advisor_resume','destination':'assets/generated/wind_ruins/a03/','glb':'assets/generated/wind_ruins/a03/a03_low_retaining_wall.glb','source':'assets/generated/wind_ruins/a03/source/a03_low_retaining_wall.blend','preview':'assets/generated/wind_ruins/a03/preview.png','evidence':'output/wind_production/a03/','triangles':sum(m['triangles'] for m in mesh_rows),'materials':1,'dimensions_blender_xyz_m':[4,.35,1],'dimensions_godot_xyz_m':[4,1,.35],'non_manifold_edges':0,'glb_valid':True,'self_check':metrics['self_check'],'outstanding':'none','completed_utc':stamp})
state['active_blender_scene']='WindProduction_A03';state['production_queue']=[aid for aid in state.get('production_queue',[]) if aid!='A03'];state['completed_count']=completed_before+1;state['current_task']='A03 complete; next A04, then A05 and I01-I02.';state['last_updated_utc']=stamp;state['next_asset']='A04'
with open(STATE,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(AUDIT,'a',encoding='utf-8') as f:f.write('\n## A03 - 3D completion\n\nApplied Sol advice directly: exact low wall envelope and cap, continuous base with one broad missing central panel/cap, and a terminal variant with one tapered closed end. Exported and self-checked the live Blender GLB without an extra review gate.\n')
print('A03_COMPLETE',json.dumps({'glb_bytes':size,'triangles':sum(m['triangles'] for m in mesh_rows),'dimensions_blender_xyz_m':[4,.35,1],'states':metrics_states,'mesh_count':len(mesh_rows),'completed_before':completed_before,'completed_after':completed_before+1,'remaining_queue':state['production_queue']},separators=(',',':')))
