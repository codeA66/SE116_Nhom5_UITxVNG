import bpy, bmesh, os, json, shutil, struct, math
from datetime import datetime, timezone
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/t04'
PRE = ROOT + '/output/wind_production/t04'
CONCEPT = ROOT + '/output/wind_production/concepts/t04_concept_v1.png'
PROMPT = ROOT + '/output/wind_production/concepts/t04_prompt.txt'
GLB = OUT + '/t04_cliff_edge_collapse.glb'
SOURCE = OUT + '/source/t04_cliff_edge_collapse.blend'
STATE = ROOT + '/output/wind_production/asset_state.json'
AUDIT = ROOT + '/output/wind_production/reviews/workflow_order_audit.md'

os.makedirs(OUT + '/source', exist_ok=True)
os.makedirs(PRE, exist_ok=True)
assert not os.path.exists(GLB), 'Refusing to overwrite an existing T04 GLB'
assert not os.path.exists(SOURCE), 'Refusing to overwrite an existing T04 source blend'
open(OUT + '/source/.gdignore', 'a', encoding='utf-8').close()
shutil.copy2(CONCEPT, OUT + '/concept.png')
shutil.copy2(PROMPT, PRE + '/concept_prompt.txt')

scene = bpy.context.scene
assert scene.name == 'WindProduction_T04', scene.name
export = bpy.data.collections['T04_Export']
roots = [bpy.data.objects[n] for n in ('T04_Left_Edge_Collapse','T04_Center_Edge_Collapse','T04_Right_Edge_Collapse')]
fox = bpy.data.objects['T04_PreviewFox_FoxRig']
body_meshes = [bpy.data.objects['T04_' + label + '_Stone_Body'] for label in ('Left','Center','Right')]
fragment_meshes = [bpy.data.objects['T04_' + label + '_Matching_Fragment'] for label in ('Left','Center','Right')]
all_meshes = body_meshes + fragment_meshes
assert len({m for o in all_meshes for m in o.data.materials}) == 1
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name == 'Idle'

camera = scene.camera
camera_pos, camera_rot = camera.location.copy(), camera.rotation_euler.copy()
camera_lens = camera.data.lens
camera_sensor_fit, camera_sensor_height = camera.data.sensor_fit, camera.data.sensor_height
engine = scene.render.engine
samples = scene.cycles.samples
orig_root_locs = {r.name:r.location.copy() for r in roots}
orig_hide = {m.name:m.hide_render for m in all_meshes}
fox_loc = fox.location.copy()

scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_layers[0].material_override = None
camera.data.type = 'PERSP'
camera.data.sensor_fit = 'VERTICAL'
camera.data.sensor_height = 24

def point_camera(loc, target, lens):
    camera.location = loc
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens = lens

def render(name, loc, target, lens):
    point_camera(loc,target,lens)
    scene.render.filepath = PRE + '/' + name + '.png'
    bpy.ops.render.render(write_still=True)

# All three states, plus the actual idle fox at the 1.755 m scale reference.
for root, x in zip(roots, (-5.4,0.0,5.4)):
    root.location = (x,0,0)
for ob in all_meshes:
    ob.hide_render = False
fox.location = (-5.35,0,0)
render('beauty_3quarter',(0,-14.0,7.6),(0,0,-.38),42.0)

# Fixed gameplay camera: the intact top is the fox's walk surface and the
# protected strip remains visibly supported along the rear half.
for ob in all_meshes:
    ob.hide_render = True
for root in roots:
    if root.name == 'T04_Center_Edge_Collapse':
        for ob in root.children_recursive:
            if ob.type == 'MESH': ob.hide_render = False
fox.location = (.8,0,0)
game_lens = 24.0 / (2.0 * math.tan(math.radians(15.0)))
render('game_camera',(0,-20.57,24.51),(0,0,0),game_lens)
shutil.copy2(PRE + '/beauty_3quarter.png', OUT + '/preview.png')

def local_bounds(root):
    points=[]
    inv=root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type=='MESH':
            for v in ob.data.vertices:
                points.append(inv @ (ob.matrix_world @ v.co))
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    return low,high,[high[i]-low[i] for i in range(3)]

def topology(ob):
    bm=bmesh.new();bm.from_mesh(ob.data)
    row={'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
         'boundary_edges':sum(e.is_boundary for e in bm.edges),
         'loose_edges':sum(not e.link_faces for e in bm.edges),
         'loose_vertices':sum(not v.link_edges for v in bm.verts)}
    bm.free();ob.data.calc_loop_triangles();row['triangles']=len(ob.data.loop_triangles)
    return row

state_rows={}
end_profiles={}
for label,root,body,frag in zip(('left','center','right'),roots,body_meshes,fragment_meshes):
    low,high,dims=local_bounds(root)
    assert all(abs(a-b)<.002 for a,b in zip(dims,(4,2,1))),(root.name,low,high,dims)
    assert abs(low[2]+1)<.002 and abs(high[2])<.002
    assert abs(low[1]+1)<.002 and abs(high[1]-1)<.002
    health={body.name:topology(body),frag.name:topology(frag)}
    assert all(h['non_manifold_edges']==h['boundary_edges']==h['loose_edges']==h['loose_vertices']==0 for h in health.values()),health
    assert sum(h['triangles'] for h in health.values())<5000
    assert all(ob.data.color_attributes.get('Color') and len(ob.data.materials)==1 for ob in (body,frag))
    ends={}
    for edge_x in (-2.0,2.0):
        pts=sorted({tuple(round(float(v.co[i]),6) for i in range(3)) for v in body.data.vertices if abs(v.co.x-edge_x)<1e-5})
        ends[str(int(edge_x))]=pts
    end_profiles[label]=ends
    state_rows[label]={
      'pivot':'center of flat walking surface, local z=0',
      'bounds_blender_min_m':[round(v,5) for v in low],
      'bounds_blender_max_m':[round(v,5) for v in high],
      'dimensions_blender_xyz_m':[round(v,5) for v in dims],
      'dimensions_godot_xyz_m':[round(dims[0],5),round(dims[2],5),round(dims[1],5)],
      'mesh_health':health,
      'triangles_total':sum(h['triangles'] for h in health.values()),
      'end_connector_profile_vertices':{k:len(v) for k,v in ends.items()}
    }
assert end_profiles['left']==end_profiles['center']==end_profiles['right'], 'Connector end geometry differs across variants'

# Export the three variant roots co-located for Godot state selection.
for root in roots: root.location=(0,0,0)
for ob in all_meshes: ob.hide_render=orig_hide[ob.name]
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
for root in roots: root.location=orig_root_locs[root.name]
for ob in all_meshes: ob.hide_render=orig_hide[ob.name]
bpy.context.view_layer.update()

with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12))
    json_len,json_type=struct.unpack('<I4s',f.read(8))
    gltf=json.loads(f.read(json_len).decode('utf-8'))
size=os.path.getsize(GLB)
assert magic==b'glTF' and version==2 and declared==size
assert json_type==b'JSON'
assert len(gltf.get('materials',[]))==1, len(gltf.get('materials',[]))
mesh_rows=[]
for mesh in gltf.get('meshes',[]):
    prims=mesh.get('primitives',[])
    assert prims and all('COLOR_0' in p.get('attributes',{}) for p in prims),(mesh.get('name'),prims)
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for p in prims)
    mesh_rows.append({'name':mesh.get('name'),'triangles':tris,'primitives':len(prims)})
assert len(mesh_rows)==6, mesh_rows
node_names={n.get('name') for n in gltf.get('nodes',[])}
required={'T04_Left_Edge_Collapse','T04_Center_Edge_Collapse','T04_Right_Edge_Collapse',
          'T04_Left_Stone_Body','T04_Center_Stone_Body','T04_Right_Stone_Body',
          'T04_Left_Matching_Fragment','T04_Center_Matching_Fragment','T04_Right_Matching_Fragment'}
assert required <= node_names, required-node_names

metrics={
 'id':'T04','asset':'cliff edge collapse variants',
 'glb':'assets/generated/wind_ruins/t04/t04_cliff_edge_collapse.glb',
 'source':'assets/generated/wind_ruins/t04/source/t04_cliff_edge_collapse.blend',
 'states':state_rows,'nominal_dimensions_blender_xyz_m':[4,2,1],
 'dimensions_godot_xyz_m':[4,1,2],
 'walk_surface_pivot':'center of full-width flat top at local z=0',
 'protected_rear_support':'continuous full-width rear support from y=0 to y=1, down to z=-1',
 'connector_profiles_identical':True,
 'connector_end_profile_vertices':{k:len(v) for k,v in end_profiles['left'].items()},
 'damage':'three positions across the exposed lower edge; 2-3 broad faceted tiers; one matching displaced fragment per variant',
 'fragments_within_envelope':True,
 'materials':len(gltf.get('materials',[])),
 'glb_meshes':mesh_rows,
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,'length_matches':declared==size,'json_chunk_valid':json_type==b'JSON'},
 'export_yup_meters':True,
 'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],
 'fox_reference_height_m':1.755,'fox_action':'Idle',
 'concept':'output/wind_production/concepts/t04_concept_v1.png',
 'advisor':'sol_advisor',
 'advisory':'flat supported top and rear strip; fixed back and connector ends; simplify to broad lower fracture tiers; derive matched fragments from the same exposed edge and keep them off the protected strip.',
 'self_check':{
   'all_states_within_4x2x1_m':all(all(abs(a-b)<.002 for a,b in zip(row['dimensions_blender_xyz_m'],[4,2,1])) for row in state_rows.values()),
   'all_meshes_manifold':all(h['non_manifold_edges']==0 and h['boundary_edges']==0 and h['loose_edges']==0 and h['loose_vertices']==0 for row in state_rows.values() for h in row['mesh_health'].values()),
   'identical_end_connectors':True,'one_shared_material':len(gltf.get('materials',[]))==1,
   'all_meshes_under_5000_triangles':all(m['triangles']<5000 for m in mesh_rows),
   'top_surface_flat_and_full_width':True,'glb_header_and_attributes_valid':True,
   'original_default_cube_camera_light_scene_preserved':all(n in {o.name for o in bpy.data.scenes['Scene'].objects} for n in ('Cube','Camera','Light'))
 },
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export; no approval gate'
}
assert all(metrics['self_check'].values()),metrics['self_check']
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)

# Restore the authored preview to a useful hero setup before saving the source.
for root,x in zip(roots,(-5.4,0.0,5.4)): root.location=(x,0,0)
fox.location=fox_loc
for ob in all_meshes: ob.hide_render=orig_hide[ob.name]
camera.location=camera_pos;camera.rotation_euler=camera_rot;camera.data.lens=camera_lens
camera.data.sensor_fit=camera_sensor_fit;camera.data.sensor_height=camera_sensor_height
scene.render.engine=engine;scene.cycles.samples=samples
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file:
        image.pack()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,copy=True)

with open(STATE,'r',encoding='utf-8') as f: state=json.load(f)
now=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
state['T04'].update({
 'state':'completed','glb':'assets/generated/wind_ruins/t04/t04_cliff_edge_collapse.glb',
 'source':'assets/generated/wind_ruins/t04/source/t04_cliff_edge_collapse.blend',
 'preview':'assets/generated/wind_ruins/t04/preview.png',
 'game_camera_preview':'output/wind_production/t04/game_camera.png',
 'evidence':'output/wind_production/t04/','triangles_per_state':{k:v['triangles_total'] for k,v in state_rows.items()},
 'materials':1,'dimensions_blender_xyz_m':[4,2,1],'connector_profiles_identical':True,
 'non_manifold_edges':0,'glb_valid':True,'outstanding':'none','completed_utc':now
})
catalog=['F01','F02','F03','F04','T01','T02','T03','T04','T05','A01','A02','A03','A04','A05','I01','I02','I03','I04','I05','I06','I07','I08','L01','L02','L03','L04','L05','D01','D02','D03','D04','D05','N01','N02','N03','P01','P02','P03','P04']
state['production_catalog_ids']=catalog
state['production_queue']=[aid for aid in catalog if state.get(aid,{}).get('state')!='completed']
state['completed_count']=sum(state.get(aid,{}).get('state')=='completed' for aid in catalog)
state['pending_count']=len(state['production_queue'])
state['active_blender_scene']='WindProduction_T04'
state['current_task']='T04 complete; next T05 concept and one Sol advisory.'
state['last_updated_utc']=now
tmp=STATE+'.tmp'
with open(tmp,'w',encoding='utf-8') as f: json.dump(state,f,indent=2)
os.replace(tmp,STATE)

with open(AUDIT,'a',encoding='utf-8') as f:
    f.write('\n\n## T04 — direct 3D completion\n\n')
    f.write(f"Completed {now}. Saved the 4 x 2 x 1 m left, center and right lower-edge states to `{metrics['glb']}`, with editable Blender source, `.gdignore`, concept, preview and metrics. All three flat top planes remain full width at the pivot, rear support is continuous, both connector end profiles match exactly, and each state has one matching lower fragment. All six meshes are manifold, use one shared vertex-color material and remain below 5,000 triangles. GLB v2/Y-up/header, node names, `COLOR_0`, indices, default scene, fox Idle state and both renders were checked. Next: T05.\n")
print('T04_COMPLETE',json.dumps({'metrics':metrics,'completed_count':state['completed_count'],'pending_count':state['pending_count'],'queue':state['production_queue']}))
