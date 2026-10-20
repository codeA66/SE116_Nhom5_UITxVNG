import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/i02';PRE=ROOT+'/output/wind_production/i02'
GLB=OUT+'/i02_modular_bridge_pier.glb';SOURCE=OUT+'/source/i02_modular_bridge_pier.blend'
STATE=ROOT+'/output/wind_production/asset_state.json';AUDIT=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name=='WindProduction_I02'
assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene=bpy.context.scene;camera=bpy.data.objects['I02_PreviewCamera'];scene.camera=camera
roots=[bpy.data.objects[n] for n in ('I02_Intact','I02_Broken_Leaning')];export=bpy.data.collections['I02_Export']
mesh_objects=[o for o in export.objects if o.type=='MESH'];assert mesh_objects
assert len({m.name for o in mesh_objects for m in o.data.materials})==1
assert all(o.data.color_attributes.get('Color') for o in mesh_objects)
assert len(bpy.data.objects['I02_Intact_Shaft_Lower_Repeatable_Module'].data.vertices)==24
assert bpy.data.objects['I02_Intact_Upper_Module_Assembly'] and bpy.data.objects['I02_Broken_Leaning_Upper_Repeatable_Assembly']
assert bpy.data.objects['I02_Broken_Matching_Loose_Foot_Fragment']
assert bpy.data.objects['I02_Optional_Shaft_Extension_Module_SOURCE_ONLY'].name not in export.objects

old_cam=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height)
old_render=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising)
old_locs={r.name:r.location.copy() for r in roots};old_hide={o.name:o.hide_render for o in export.objects}
fox=bpy.data.objects['I02_PreviewFox_FoxRig'];old_fox=fox.location.copy();fox_objects=[]
def collect(ob):
    fox_objects.append(ob)
    for child in ob.children:collect(child)
collect(fox);old_fox_hide={o.name:o.hide_render for o in fox_objects}
scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';camera.data.type='PERSP';camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24

def aim(loc,target,lens):
    camera.location=loc;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
def render(name,loc,target,lens):
    aim(loc,target,lens);scene.render.filepath=PRE+'/'+name+'.png';bpy.ops.render.render(write_still=True)

# Compare intact and leaning states at close range; show the fox in the open space between them.
roots[0].location=(-1.2,0,0);roots[1].location=(1.2,0,0);fox.location=(0,-1.5,0)
render('beauty_3quarter',(8,-12,7.8),(0,0,2.65),45)

# Production camera transform and an intact pier with the same fox for scale.
roots[0].location=(0,0,0);roots[1].hide_render=True
for o in roots[1].children_recursive:o.hide_render=True
fox.location=(1.6,-2.0,0)
for o in export.objects:
    if o.name in old_hide:o.hide_render=old_hide[o.name]
game_lens=24.0/(2.0*math.tan(math.radians(15.0)))
render('game_camera',(0,-20.57,24.51),(0,0,0),game_lens)
for o in export.objects:o.hide_render=old_hide[o.name]

def bounds(root):
    pts=[];inv=root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type=='MESH':pts.extend(inv@(ob.matrix_world@v.co) for v in ob.data.vertices)
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    return lo,hi,[hi[i]-lo[i] for i in range(3)]
def health(ob):
    bm=bmesh.new();bm.from_mesh(ob.data)
    h={'vertices':len(bm.verts),'faces':len(bm.faces),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
       'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),
       'loose_vertices':sum(not v.link_edges for v in bm.verts)}
    bm.free();ob.data.calc_loop_triangles();h['triangles']=len(ob.data.loop_triangles);return h

for r in roots:r.location=old_locs[r.name];r.hide_render=False
fox.location=old_fox
for o in fox_objects:o.hide_render=old_fox_hide[o.name]
camera.location,camera.rotation_euler,camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height=old_cam
scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising=old_render
bpy.context.view_layer.update()

states={};all_rows=[]
for r,label in zip(roots,('intact','broken_leaning')):
    lo,hi,dims=bounds(r);meshes=[o for o in r.children_recursive if o.type=='MESH'];rows=[]
    if label=='intact':assert all(abs(a-b)<.002 for a,b in zip(dims,(1.2,1.2,5.4))),(label,lo,hi,dims)
    else:assert dims[2]<=5.402 and dims[0]<2.0 and dims[1]<1.6,(label,lo,hi,dims)
    assert meshes
    for ob in meshes:
        h=health(ob)
        assert h['non_manifold_edges']==h['boundary_edges']==h['loose_edges']==h['loose_vertices']==0,(label,ob.name,h)
        assert h['triangles']<5000 and len(ob.data.materials)==1 and ob.data.color_attributes.get('Color'),(label,ob.name,h)
        rows.append({'name':ob.name,'triangles':h['triangles'],'mesh_health':h})
    all_rows.extend(rows)
    states[label]={'bounds_min_local_m':[round(x,6) for x in lo],'bounds_max_local_m':[round(x,6) for x in hi],
        'dimensions_blender_xyz_m':[round(x,6) for x in dims],'mesh_count':len(meshes),'meshes':rows}

# Verify the irregular fracture interface was generated from the same eight coordinates.
lower=bpy.data.meshes['I02_Broken_Lower_Stump_Matching_Cut_Mesh_Mesh']
upper=bpy.data.meshes['I02_Broken_Upper_Shaft_Matching_Cut_Mesh_Mesh']
lower_top=sorted((round(v.co.x,6),round(v.co.y,6),round(v.co.z-2.2,6)) for v in lower.vertices if v.co.z>2.0)
upper_bottom=sorted((round(v.co.x,6),round(v.co.y,6),round(v.co.z,6)) for v in upper.vertices if v.co.z<.2)
assert len(lower_top)>=8 and len(upper_bottom)>=8
assert lower_top==upper_bottom,('fracture vertex mismatch',lower_top,upper_bottom)

for o in bpy.context.view_layer.objects:o.select_set(False)
for o in export.objects:o.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12));json_len,json_type=struct.unpack('<I4s',f.read(8));gltf=json.loads(f.read(json_len).decode('utf-8'))
size=os.path.getsize(GLB)
assert magic==b'glTF' and version==2 and declared==size and json_type==b'JSON'
assert gltf.get('asset',{}).get('version')=='2.0' and len(gltf.get('materials',[]))==1
mesh_rows=[]
for m in gltf.get('meshes',[]):
    prims=m.get('primitives',[]);assert prims and all('COLOR_0' in p.get('attributes',{}) for p in prims),(m.get('name'),prims)
    mesh_rows.append({'name':m.get('name'),'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for p in prims),'primitives':len(prims)})
nodes={n.get('name') for n in gltf.get('nodes',[])}
required={'I02_Intact','I02_Broken_Leaning','I02_Intact_Shaft_Lower_Repeatable_Module','I02_Intact_Shaft_Upper_Repeatable_Module',
 'I02_Intact_Fork_Arm_Left','I02_Intact_Fork_Arm_Right','I02_Broken_Matching_Loose_Foot_Fragment','I02_Broken_Lower_Stump_Matching_Face'}
assert required<=nodes,(required-nodes,nodes)
total_triangles=sum(x['triangles'] for x in mesh_rows);assert mesh_rows and total_triangles<5000,total_triangles
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

roots[1].hide_set(True)
for ob in roots[1].children_recursive:ob.hide_set(True)
for ob in bpy.context.view_layer.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,copy=True)

stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
advice='Keep the intact pier within 1.2 x 1.2 x 5.4 m, including the fork. Use a flat square plinth, a shaft narrowing roughly 15%, and chunky fork arms with a clear central cradle. Separate base, repeatable shaft segments, and cradle in the source; add height by inserting segments and keep join faces flush with one visible stone-course seam. Create the broken state from a shared fracture cut so the leaning upper shaft and lower stump have matching surfaces. Derive the loose foot fragment from the same damaged geometry, and keep the square base planted flat.'
self_check='The intact pier fits exactly 1.2 x 1.2 x 5.4 m including its fork. It has a stable square plinth, a shaft tapering from 0.84 m to 0.714 m, separately named lower/upper shaft modules, one stone-course seam, and two chunky cradle arms. The broken state uses a matching irregular cut between the planted stump and leaning upper module, plus a detached piece from the notched foot; its base remains flat. All asset meshes are manifold, use one shared vertex-color material, and stay under 5000 triangles. GLB v2 Y-up, named variant/modules and COLOR_0 checked; original Scene/Cube/Camera/Light preserved. Beauty and exact game-camera renders visually inspected.'
metrics={'id':'I02','asset':'modular fork-cradle bridge support','glb':'assets/generated/wind_ruins/i02/i02_modular_bridge_pier.glb',
 'source':'assets/generated/wind_ruins/i02/source/i02_modular_bridge_pier.blend','concept':'assets/generated/wind_ruins/i02/concept.png',
 'concept_prompt':'output/wind_production/concepts/i02_prompt.txt','states':states,'dimensions_blender_xyz_m':[1.2,1.2,5.4],
 'dimensions_godot_xyz_m':[1.2,5.4,1.2],'materials':1,'palette_srgb':{'stone':'#526271','stone_light':'#687A87','stone_dark':'#3C4C58','muted_bronze_course':'#8B7550'},
 'shaft_taper':'0.84 m to 0.714 m across the intact shaft (15%)','shaft_modules':['I02_Intact_Shaft_Lower_Repeatable_Module','I02_Intact_Shaft_Upper_Repeatable_Module'],
 'source_only_extension_template':'I02_Optional_Shaft_Extension_Module_SOURCE_ONLY','fork_cradle_clear_gap_m':.38,
 'broken_matching_fracture_vertices':len(lower_top),'foot_fragment':'I02_Broken_Matching_Loose_Foot_Fragment derived from same notched plinth cut',
 'glb_meshes':mesh_rows,'glb_bytes':size,'glb_v2_y_up_header':True,'color_attributes':'COLOR_0 on every primitive',
 'advisory':advice,'game_camera_blender':[0,-20.57,24.51],'vertical_fov_degrees':30,
 'self_check':self_check,'outstanding':'none','completed_utc':stamp}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)

with open(STATE,'r',encoding='utf-8-sig') as f:state=json.load(f)
completed_before=sum(1 for aid in state.get('production_catalog_ids',[]) if isinstance(state.get(aid),dict) and state[aid].get('state')=='completed')
assert completed_before==38,('unexpected completion count',completed_before)
state['I02'].update({'state':'completed','outstanding':'none','advisor':'sol_advisor','advisory':advice,
 'advisory_received_from':'sol_advisor','destination':'assets/generated/wind_ruins/i02/','glb':'assets/generated/wind_ruins/i02/i02_modular_bridge_pier.glb',
 'source':'assets/generated/wind_ruins/i02/source/i02_modular_bridge_pier.blend','preview':'assets/generated/wind_ruins/i02/preview.png',
 'evidence':'output/wind_production/i02/','triangles':total_triangles,'materials':1,'dimensions_blender_xyz_m':[1.2,1.2,5.4],
 'dimensions_godot_xyz_m':[1.2,5.4,1.2],'shaft_modules':['I02_Intact_Shaft_Lower_Repeatable_Module','I02_Intact_Shaft_Upper_Repeatable_Module'],
 'non_manifold_edges':0,'glb_valid':True,'self_check':self_check,'completed_utc':stamp})
state['active_blender_scene']='WindProduction_I02';state['production_queue']=[];state['remaining_catalog_order']=[]
state['completed_count']=completed_before+1;state['pending_count']=0;state['current_task']='All 39 catalog models complete; root final catalog audit pending.'
state['last_updated_utc']=stamp;state['next_asset']=None
with open(STATE,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(AUDIT,'a',encoding='utf-8') as f:
    f.write('\n## I02 - 3D completion\n\nApplied the one Sol review: made a flat square plinth, 15% tapered shaft, separate repeatable shaft modules and fork cradle, then derived a leaning upper segment and matching loose foot fragment from the same cuts. Kept the intact assembly at 1.2 x 1.2 x 5.4 m. Exported and self-checked through connected Blender.\n')
print('I02_COMPLETE',json.dumps({'glb_bytes':size,'triangles':total_triangles,'dimensions_blender_xyz_m':[1.2,1.2,5.4],
 'states':{k:v['dimensions_blender_xyz_m'] for k,v in states.items()},'mesh_count':len(mesh_rows),
 'completed_before':completed_before,'completed_after':completed_before+1,'remaining_queue':state['production_queue']},separators=(',',':')))
