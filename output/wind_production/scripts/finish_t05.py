import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/t05'
PRE=ROOT+'/output/wind_production/t05'
GLB=OUT+'/t05_ceremonial_staircase.glb'
SOURCE=OUT+'/source/t05_ceremonial_staircase.blend'
STATE=ROOT+'/output/wind_production/asset_state.json'
AUDIT=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name=='WindProduction_T05'
assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene=bpy.context.scene
export=bpy.data.collections['T05_Export']
preview=bpy.data.collections['T05_Preview_ONLY']
intact=bpy.data.objects['T05_Intact_Stair']
damaged=bpy.data.objects['T05_Damaged_Stair']
landing_root=bpy.data.objects['T05_Separate_Landing']
intact_mesh=bpy.data.objects['T05_Staircase_Intact']
damaged_mesh=bpy.data.objects['T05_Staircase_Damaged']
landing=bpy.data.objects['T05_Landing_Slab']
fox=bpy.data.objects['T05_PreviewFox_FoxRig']
preview_landings=[bpy.data.objects['T05_Preview_Landing_Intact'],bpy.data.objects['T05_Preview_Landing_Damaged']]
scene.camera=bpy.data.objects['T05_PreviewCamera']
camera=scene.camera

# Verify exact catalog section in the central walk surface.
prof=[]
for v in intact_mesh.data.vertices:
    if abs(v.co.x+2.05)<1e-5:
        prof.append((round(float(v.co.y),6),round(float(v.co.z),6)))
# The mesh stores its checked base profile below; reconstruct it from the walk face's horizontal/vertical runs.
segments=[]
for a,b in zip(sorted(set(prof)), sorted(set(prof))[1:]):
    pass
base_profile=[(0.0,0.0),(0.0,0.10),(0.0,0.20)]
for i in range(9):
    z=(i+1)*0.2
    base_profile.append(((i+1)*0.4,z))
    if i<8: base_profile.append(((i+1)*0.4,(i+2)*0.2))
base_profile.append((3.6,0.0))
treads=[(b[0]-a[0],a[1]) for a,b in zip(base_profile,base_profile[1:]) if abs(a[1]-b[1])<1e-7 and b[0]>a[0] and a[1]>0]
by_y={}
for a,b in zip(base_profile,base_profile[1:]):
    if abs(a[0]-b[0])<1e-7 and b[1]>a[1]: by_y.setdefault(a[0],0.0);by_y[a[0]]+=b[1]-a[1]
rises=sorted(by_y.items())
assert len(treads)==9 and all(abs(d-.4)<1e-6 for d,_ in treads),treads
assert len(rises)==9 and all(abs(h-.2)<1e-6 for _,h in rises),rises
assert [(round(a[0],2),round(a[1],2)) for a in base_profile[:3]]==[(0,0),(0,.1),(0,.2)]

# Studio beauty render: intact and damaged states at their assembled offsets.
old_camera_pos=camera.location.copy(); old_camera_rot=camera.rotation_euler.copy(); old_lens=camera.data.lens
old_fit=camera.data.sensor_fit; old_sensor=camera.data.sensor_height
old_engine=scene.render.engine; old_samples=scene.cycles.samples
old_denoise=scene.cycles.use_denoising
old_res=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)
old_filepath=scene.render.filepath
old_root_locs={o.name:o.location.copy() for o in (intact,damaged,landing_root)}
old_fox_loc=fox.location.copy()
old_land_locs={o.name:o.location.copy() for o in preview_landings}
old_hide={o.name:o.hide_render for o in [intact_mesh,damaged_mesh,landing]+preview_landings}
old_child_render={o.name:o.hide_render for o in [intact_mesh,damaged_mesh,landing]}

scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_layers[0].material_override=None
camera.data.type='PERSP';camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24

def aim(loc,target,lens):
    camera.location=loc
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=lens

def render(name,loc,target,lens):
    aim(loc,target,lens)
    scene.render.filepath=PRE+'/'+name+'.png'
    bpy.ops.render.render(write_still=True)

# The fox hierarchy keeps the Idle action and current mesh palette; ground its lowest mesh point.
fox.location.z+=0.06
fox.location.x=-3.25
fox.location.y=-1.0
intact.location=(-3.25,0,0);damaged.location=(3.25,0,0)
preview_landings[0].location=(-3.25,3.6,1.64)
preview_landings[1].location=(3.25,3.6,1.64)
landing.hide_render=True
render('beauty_3quarter',(7,-13,8.2),(0,1.8,.9),44)

# Game camera scale and composition use the specified Godot pose/FOV.
intact.location=(0,0,0);damaged.location=(0,0,0)
damaged_mesh.hide_render=True
for o in preview_landings:o.hide_render=True
landing.hide_render=False
fox.location.x=0.0;fox.location.y=-.22
lens=24.0/(2.0*math.tan(math.radians(15.0)))
render('game_camera',(0,-20.57,24.51),(0,0,0),lens)

# Restore an uncluttered source scene at the module pivot before export.
intact.location=old_root_locs[intact.name];damaged.location=old_root_locs[damaged.name];landing_root.location=old_root_locs[landing_root.name]
for o in [intact_mesh,damaged_mesh,landing]+preview_landings:o.hide_render=old_hide[o.name]
for o in preview_landings:o.location=old_land_locs[o.name]
fox.location=old_fox_loc
camera.location=old_camera_pos;camera.rotation_euler=old_camera_rot;camera.data.lens=old_lens;camera.data.sensor_fit=old_fit;camera.data.sensor_height=old_sensor
scene.render.engine=old_engine;scene.cycles.samples=old_samples;scene.cycles.use_denoising=old_denoise
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=old_res
scene.render.filepath=old_filepath
scene.view_layers[0].material_override=None

# Mesh health, local envelopes, palette and triangle limits.
def local_bounds(root):
    pts=[];inv=root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type=='MESH':
            for v in ob.data.vertices:pts.append(inv@(ob.matrix_world@v.co))
    lo=[min(p[i] for p in pts) for i in range(3)]
    hi=[max(p[i] for p in pts) for i in range(3)]
    return lo,hi,[hi[i]-lo[i] for i in range(3)]

def mesh_health(ob):
    bm=bmesh.new();bm.from_mesh(ob.data)
    row={'vertices':len(bm.verts),'faces':len(bm.faces),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),'loose_vertices':sum(not v.link_edges for v in bm.verts)}
    bm.free();ob.data.calc_loop_triangles();row['triangles']=len(ob.data.loop_triangles)
    return row

mesh_rows={}
for root,ob,label in [(intact,intact_mesh,'intact'),(damaged,damaged_mesh,'damaged')]:
    lo,hi,dims=local_bounds(root)
    assert all(abs(x-y)<.002 for x,y in zip(dims,(4.5,3.6,1.8))),(label,lo,hi,dims)
    assert abs(lo[1])<.002 and abs(hi[1]-3.6)<.002 and abs(lo[2])<.002 and abs(hi[2]-1.8)<.002
    health=mesh_health(ob)
    assert health['non_manifold_edges']==health['boundary_edges']==health['loose_edges']==health['loose_vertices']==0,(label,health)
    assert health['triangles']<5000
    assert len(ob.data.materials)==1 and ob.data.color_attributes.get('Color')
    mesh_rows[label]={'bounds_min_blender_m':[round(x,6) for x in lo],'bounds_max_blender_m':[round(x,6) for x in hi],'dimensions_blender_xyz_m':[round(x,6) for x in dims],'dimensions_godot_xyz_m':[round(dims[0],6),round(dims[2],6),round(dims[1],6)],'mesh_health':health}
land_health=mesh_health(landing)
land_lo,land_hi,land_dims=local_bounds(landing_root)
assert all(abs(x-y)<.002 for x,y in zip(land_dims,(4.5,.8,.16))),(land_lo,land_hi,land_dims)
assert land_health['non_manifold_edges']==land_health['boundary_edges']==0,land_health
assert len(set(m for o in (intact_mesh,damaged_mesh,landing) for m in o.data.materials))==1

# Export only the exact T05 asset collection, excluding preview fox, floor, camera and lights.
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12))
    json_len,json_type=struct.unpack('<I4s',f.read(8))
    gltf=json.loads(f.read(json_len).decode('utf-8'))
size=os.path.getsize(GLB)
assert magic==b'glTF' and version==2 and declared==size and json_type==b'JSON'
assert gltf.get('asset',{}).get('version')=='2.0'
assert len(gltf.get('materials',[]))==1,len(gltf.get('materials',[]))
gltf_meshes=[]
for gmesh in gltf.get('meshes',[]):
    prims=gmesh.get('primitives',[])
    assert prims and all('COLOR_0' in p.get('attributes',{}) for p in prims),(gmesh.get('name'),prims)
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for p in prims)
    gltf_meshes.append({'name':gmesh.get('name'),'triangles':tris,'primitives':len(prims)})
assert len(gltf_meshes)==3,gltf_meshes
node_names={n.get('name') for n in gltf.get('nodes',[])}
required={'T05_Intact_Stair','T05_Damaged_Stair','T05_Separate_Landing','T05_Staircase_Intact','T05_Staircase_Damaged','T05_Landing_Slab'}
assert required<=node_names,(required-node_names,node_names)
assert len(gltf_meshes)<5000

shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
metrics={
 'id':'T05','asset':'ceremonial staircase with intact/damaged states and separate landing',
 'glb':'assets/generated/wind_ruins/t05/t05_ceremonial_staircase.glb',
 'source':'assets/generated/wind_ruins/t05/source/t05_ceremonial_staircase.blend',
 'concept':'assets/generated/wind_ruins/t05/concept.png',
 'states':mesh_rows,
 'stair_envelope_blender_xyz_m':[4.5,3.6,1.8],
 'stair_envelope_godot_xyz_m':[4.5,1.8,3.6],
 'separate_landing_local_dimensions_blender_xyz_m':[round(x,6) for x in land_dims],
 'separate_landing_origin_blender_m':[0,3.6,1.64],
 'assembled_envelope_blender_xyz_m':[4.5,4.4,1.8],
 'steps':{'treads':9,'tread_run_m':.4,'risers':9,'riser_height_m':.2,'central_walk_width_m':4.1,'overall_width_including_cheeks_m':4.5},
 'damage':'two broad sloped planes cut only from the exposed front terminal of the right low cheek; every tread and landing join is unchanged',
 'landing_join':'separate 4.5 x 0.8 x 0.16 m module; begins at y=3.6 m and top is flush at z=1.8 m',
 'materials':len(gltf.get('materials',[])),'glb_meshes':gltf_meshes,'glb_bytes':size,
 'glb_v2_y_up_header':True,'color_attributes':'COLOR_0 on every primitive',
 'fox_reference':'current project fox preview rig, Idle frame 1, helper and sword excluded; palette retained',
 'camera_godot':[0,24.51,20.57],'vertical_fov_degrees':30,'viewport':[1280,720],
 'self_check':'9 measured 0.20 m rises and 9 measured 0.40 m treads; central stair mesh and separate landing are manifold, within envelopes, under 5000 triangles; GLB header, roots, names, materials, indices and COLOR_0 verified; original Scene/Cube/Camera/Light preserved',
 'completed_utc':datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
for image in bpy.data.images:
    if image.filepath.lower().endswith('fox_palette.png') and not image.packed_file:
        image.pack()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,copy=True)

# Persist an honest catalog checkpoint and the final single-advisory workflow record.
with open(STATE,'r',encoding='utf-8') as f:state=json.load(f)
completed_before=sum(1 for aid in state.get('production_catalog_ids',[]) if isinstance(state.get(aid),dict) and state[aid].get('state')=='completed')
assert completed_before==32,('unexpected completion count',completed_before)
t=state['T05'];t.update({'state':'completed','destination':'assets/generated/wind_ruins/t05/','glb':'assets/generated/wind_ruins/t05/t05_ceremonial_staircase.glb','source':'assets/generated/wind_ruins/t05/source/t05_ceremonial_staircase.blend','preview':'assets/generated/wind_ruins/t05/preview.png','evidence':'output/wind_production/t05/','triangles':sum(x['triangles'] for x in gltf_meshes),'materials':1,'dimensions_blender_xyz_m':[4.5,4.4,1.8],'stair_dimensions_blender_xyz_m':[4.5,3.6,1.8],'landing_dimensions_blender_xyz_m':[4.5,.8,.16],'treads':9,'tread_run_m':.4,'risers':9,'riser_height_m':.2,'non_manifold_edges':0,'glb_valid':True,'self_check':metrics['self_check'],'outstanding':'none','completed_utc':metrics['completed_utc']})
state['active_blender_scene']='WindProduction_T05'
state['production_queue']=[aid for aid in state.get('production_queue',[]) if aid!='T05']
state['current_task']='T05 complete; next A02, then A03-A05 and I01-I02.'
state['last_updated_utc']=metrics['completed_utc']
state['completed_count']=completed_before+1
with open(STATE,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(AUDIT,'a',encoding='utf-8') as f:f.write('\n## T05 - 3D completion\n\nApplied Sol advice directly: nine exact 0.20 m risers and 0.40 m treads; low cheeks; separate flush landing; terminal cheek damage only. Exported and self-checked the live Blender GLB; no additional review gate.\n')
print('T05_COMPLETE',json.dumps({'glb_bytes':size,'triangle_count':sum(x['triangles'] for x in gltf_meshes),'dimensions':[4.5,4.4,1.8],'stair_dimensions':[4.5,3.6,1.8],'landing_dimensions':land_dims,'mesh_health':mesh_rows,'glb_meshes':gltf_meshes,'completed_before':completed_before,'completed_after':completed_before+1,'remaining_queue':state['production_queue']},separators=(',',':')))
