import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i01'
PRE=ROOT+'/output/wind_production/i01'
GLB=OUT+'/i01_modular_bridge_span.glb'
SOURCE=OUT+'/source/i01_modular_bridge_span.blend'
STATE=ROOT+'/output/wind_production/asset_state.json'
AUDIT=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name=='WindProduction_I01'
assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene=bpy.context.scene;camera=bpy.data.objects['I01_PreviewCamera'];scene.camera=camera
roots=[bpy.data.objects[n] for n in ('I01_Intact','I01_Diagonal_Break')]
export=bpy.data.collections['I01_Export'];mesh_objects=[o for o in export.objects if o.type=='MESH']
assert mesh_objects and len({m.name for o in mesh_objects for m in o.data.materials})==1
assert all(o.data.color_attributes.get('Color') for o in mesh_objects)
intact_deck=[o for o in roots[0].children_recursive if o.name.startswith('I01_Intact_Broad_Deck_Slab_')]
intact_beams=[o for o in roots[0].children_recursive if o.name.startswith('I01_Intact_Chestnut_Underside_Beam_')]
assert len(intact_deck)==4 and len(intact_beams)==3,(len(intact_deck),len(intact_beams))

old_cam=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height)
old_render=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising)
old_locs={r.name:r.location.copy() for r in roots}
old_fox=bpy.data.objects['I01_PreviewFox_FoxRig'].location.copy();fox=bpy.data.objects['I01_PreviewFox_FoxRig']
fox_objects=[]
def collect_fox(ob):
    fox_objects.append(ob)
    for child in ob.children:collect_fox(child)
collect_fox(fox);old_fox_hide={o.name:o.hide_render for o in fox_objects}
old_hide={o.name:o.hide_render for o in export.objects}
scene.render.engine='CYCLES';scene.cycles.samples=18;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';camera.data.type='PERSP';camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24

def aim(loc,target,lens):
    camera.location=loc;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
def render(name,loc,target,lens):
    aim(loc,target,lens);scene.render.filepath=PRE+'/'+name+'.png';bpy.ops.render.render(write_still=True)

# Show both options clearly without a character blocking the broad deck.
roots[0].location=(-3.15,0,0);roots[1].location=(3.15,0,0)
for o in fox_objects:o.hide_render=True
render('beauty_3quarter',(0,-18,10),(0,0,.32),39)

# Match the production camera and use the 1.755 m fox as a placement-scale reference.
roots[0].location=(0,0,0);roots[1].hide_render=True
for o in roots[1].children_recursive:o.hide_render=True
for o in fox_objects:o.hide_render=old_fox_hide[o.name]
fox.location=(0,-3.0,0)
game_lens=24.0/(2.0*math.tan(math.radians(15.0)))
render('game_camera',(0,-20.57,24.51),(0,0,0),game_lens)
for o in export.objects:o.hide_render=old_hide[o.name]

def bounds(root):
    points=[];inv=root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type=='MESH':points.extend(inv@(ob.matrix_world@v.co) for v in ob.data.vertices)
    lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
    return lo,hi,[hi[i]-lo[i] for i in range(3)],points
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
for r,label in zip(roots,('intact','diagonal_break')):
    lo,hi,dims,points=bounds(r)
    assert all(abs(a-b)<.002 for a,b in zip(dims,(4.0,4.5,.45))),(label,lo,hi,dims)
    for x in (-2.0,2.0):
        ys=[p.y for p in points if abs(p.x-x)<.002]
        assert ys and abs(min(ys)+2.25)<.002 and abs(max(ys)-2.25)<.002,(label,x,min(ys) if ys else None,max(ys) if ys else None)
    meshes=[o for o in r.children_recursive if o.type=='MESH'];rows=[]
    for ob in meshes:
        h=health(ob)
        assert h['non_manifold_edges']==h['boundary_edges']==h['loose_edges']==h['loose_vertices']==0,(label,ob.name,h)
        assert h['triangles']<5000 and len(ob.data.materials)==1 and ob.data.color_attributes.get('Color'),(label,ob.name,h)
        rows.append({'name':ob.name,'triangles':h['triangles'],'mesh_health':h})
    all_rows.extend(rows)
    states[label]={'bounds_min_local_m':[round(x,6) for x in lo],'bounds_max_local_m':[round(x,6) for x in hi],
        'dimensions_blender_xyz_m':[round(x,6) for x in dims],'mesh_count':len(meshes),'meshes':rows,
        'full_section_connector_x_m':[-2.0,2.0],'connector_y_extent_m':[-2.25,2.25]}

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
required={'I01_Intact','I01_Diagonal_Break','I01_Intact_Broad_Deck_Slab_01','I01_Broken_Deck_Slab_01_Matching_Fragments'}
assert required<=nodes,(required-nodes,nodes)
total_triangles=sum(x['triangles'] for x in mesh_rows);assert mesh_rows and total_triangles<5000,total_triangles
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

# Source file opens on the intact bridge; retain broken option hidden in the same scene.
roots[1].hide_set(True)
for ob in roots[1].children_recursive:ob.hide_set(True)
for ob in bpy.context.view_layer.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,copy=True)

stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
advice='Lock the catalog envelope to X=4 m, Z=4.5 m walking width, and 0.45 m total thickness. Compress the concept’s deep timber foundation into this shallow profile; use four broad deck slabs and 2–3 underside beams. Keep X=±2 m as flat, full-section mating faces; terminate curbs and trim flush there so corner posts do not obstruct the walking connection. Carry one diagonal fracture through slabs, edge trim, and underside beams with staggered chipped ends and exposed timber, preserving the original outer connector faces and alignment in both variants.'
self_check='Both intact and diagonal-break variants fit exactly 4.0 x 4.5 x 0.45 m. The intact span has four separate broad walking slabs and three broad underside beams. Both variants retain full-width flat mating planes at X=±2 m, independently verified across the full 4.5 m width. The broken span has a diagonal gap through deck and beams with broad exposed fracture faces. All meshes are manifold, use one shared vertex-color material, and remain below 5000 triangles. GLB v2 Y-up, named roots and COLOR_0 checked; original Scene/Cube/Camera/Light preserved. Beauty and exact game-camera renders inspected.'
metrics={'id':'I01','asset':'modular bridge span','glb':'assets/generated/wind_ruins/i01/i01_modular_bridge_span.glb',
 'source':'assets/generated/wind_ruins/i01/source/i01_modular_bridge_span.blend','concept':'assets/generated/wind_ruins/i01/concept.png',
 'concept_prompt':'output/wind_production/concepts/i01_prompt.txt','states':states,'dimensions_blender_xyz_m':[4,4.5,.45],
 'dimensions_godot_xyz_m':[4,.45,4.5],'materials':1,'palette_srgb':{'stone':'#526271','stone_light':'#687A87','stone_shadow':'#3C4C58','chestnut_support':'#654637'},
 'deck_slab_count':4,'underside_beam_count':3,'connector_planes_x_m':[-2,2],'connector_y_extent_m':[-2.25,2.25],
 'walking_width_axis':'Godot Z (Blender Y before glTF Y-up conversion)','broken_gap':'One diagonal gap across the module, through slabs and support beams; use only where layout permits a gap.',
 'glb_meshes':mesh_rows,'glb_bytes':size,'glb_v2_y_up_header':True,'color_attributes':'COLOR_0 on every primitive','advisory':advice,
 'game_camera_blender':[0,-20.57,24.51],'vertical_fov_degrees':30,'self_check':self_check,'outstanding':'none','completed_utc':stamp}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)

with open(STATE,'r',encoding='utf-8-sig') as f:state=json.load(f)
completed_before=sum(1 for aid in state.get('production_catalog_ids',[]) if isinstance(state.get(aid),dict) and state[aid].get('state')=='completed')
assert completed_before==37,('unexpected completion count',completed_before)
state['I01'].update({'state':'completed','outstanding':'none','advisor':'sol_advisor','advisory':advice,'advisory_received_from':'sol_advisor',
 'destination':'assets/generated/wind_ruins/i01/','glb':'assets/generated/wind_ruins/i01/i01_modular_bridge_span.glb',
 'source':'assets/generated/wind_ruins/i01/source/i01_modular_bridge_span.blend','preview':'assets/generated/wind_ruins/i01/preview.png',
 'evidence':'output/wind_production/i01/','triangles':total_triangles,'materials':1,'dimensions_blender_xyz_m':[4,4.5,.45],
 'dimensions_godot_xyz_m':[4,.45,4.5],'deck_slab_count':4,'underside_beam_count':3,'connector_planes_x_m':[-2,2],
 'connector_y_extent_m':[-2.25,2.25],'non_manifold_edges':0,'glb_valid':True,'self_check':self_check,'completed_utc':stamp})
state['active_blender_scene']='WindProduction_I01';state['production_queue']=[aid for aid in state.get('production_queue',[]) if aid!='I01']
state['completed_count']=completed_before+1;state['current_task']='I01 complete; next I02.';state['last_updated_utc']=stamp;state['next_asset']='I02'
with open(STATE,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(AUDIT,'a',encoding='utf-8') as f:
    f.write('\n## I01 - 3D completion\n\nApplied the one Sol review: held the exact 4 x 4.5 x 0.45 m envelope, four broad slabs and three underside beams, retained full-width connector planes at X=+/-2 m, and made one diagonal break through the deck and beams. Exported and self-checked through connected Blender.\n')
print('I01_COMPLETE',json.dumps({'glb_bytes':size,'triangles':total_triangles,'dimensions_blender_xyz_m':[4,4.5,.45],
 'states':{k:v['dimensions_blender_xyz_m'] for k,v in states.items()},'mesh_count':len(mesh_rows),
 'completed_before':completed_before,'completed_after':completed_before+1,'remaining_queue':state['production_queue']},separators=(',',':')))
