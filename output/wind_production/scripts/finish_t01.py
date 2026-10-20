import bpy, bmesh, os, json, shutil, struct
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/t01'
PRE=ROOT+'/output/wind_production/t01'
CONCEPT=ROOT+'/output/wind_production/concepts/t01_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/t01_prompt.txt'
os.makedirs(OUT+'/source',exist_ok=True)
os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(CONCEPT,OUT+'/concept.png')
shutil.copy2(PROMPT,PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_T01',scene.name
asset=bpy.data.collections['T01_Export']
roots=[bpy.data.objects[n] for n in ('T01_Intact_Cliff','T01_Missing_Corner','T01_Diagonal_Crack')]
intact,missing,cracked=roots
cam=scene.camera
cam_loc,cam_rot=cam.location.copy(),cam.rotation_euler.copy()
cam_lens,cam_sensor_fit,cam_sensor_height=cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height
engine=scene.render.engine
orig_locs={r.name:r.location.copy() for r in roots}
all_meshes=[o for o in asset.objects if o.type=='MESH']
orig_hide={o.name:o.hide_render for o in all_meshes}

scene.render.engine='CYCLES'
scene.cycles.samples=12
scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1280
scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.view_layers[0].material_override=None
cam.data.type='PERSP'
cam.data.sensor_fit='VERTICAL'
cam.data.sensor_height=24

def shoot(name,loc,target,lens):
    cam.location=loc
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.lens=lens
    scene.render.filepath=PRE+'/'+name+'.png'
    bpy.ops.render.render(write_still=True)

# Hero sheet: all named states, with the project fox at its true 1.8 m design scale.
shoot('beauty_3quarter',(1.0,-18.0,11.0),(0.1,0.0,2.65),40.0)

# In-game scale check: single intact module and fox against the specified camera offset/FOV.
for obj in all_meshes:
    obj.hide_render=True
for obj in intact.children_recursive:
    if obj.type=='MESH': obj.hide_render=False
intact.location=(-3.6,0,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*__import__('math').tan(__import__('math').radians(15))) )

def local_bounds(root):
    pts=[]
    inv=root.matrix_world.inverted()
    for obj in root.children_recursive:
        if obj.type=='MESH':
            for v in obj.data.vertices:
                pts.append(inv @ (obj.matrix_world @ v.co))
    mi=[min(p[i] for p in pts) for i in range(3)]
    ma=[max(p[i] for p in pts) for i in range(3)]
    return mi,ma,[ma[i]-mi[i] for i in range(3)]

def topology(obj):
    bm=bmesh.new();bm.from_mesh(obj.data)
    bad=sum(1 for e in bm.edges if not e.is_manifold)
    loose=sum(1 for v in bm.verts if not v.link_edges)
    bm.free()
    obj.data.calc_loop_triangles()
    return {'triangles':len(obj.data.loop_triangles),'non_manifold_edges':bad,'loose_vertices':loose}

state_rows={}
for root in roots:
    mesh=next(o for o in root.children_recursive if o.type=='MESH')
    mi,ma,d=local_bounds(root)
    topo=topology(mesh)
    state_rows[root.name]={
      'pivot':'bottom center at origin',
      'bounds_blender_min_m':[round(v,5) for v in mi],
      'bounds_blender_max_m':[round(v,5) for v in ma],
      'dimensions_blender_xyz_m':[round(v,5) for v in d],
      'dimensions_godot_xyz_m':[round(d[0],5),round(d[2],5),round(d[1],5)],
      'mesh':mesh.name,**topo
    }

# Export all named states with the same bottom-center pivot, overlapping at the origin.
for root in roots: root.location=(0,0,0)
for mesh in all_meshes: mesh.hide_render=orig_hide[mesh.name]
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/t01_straight_cliff_wall.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
for root in roots: root.location=orig_locs[root.name]
for obj in all_meshes: obj.hide_render=orig_hide[obj.name]
bpy.context.view_layer.update()

with open(glb,'rb') as f:
    magic,version,length=struct.unpack('<4sII',f.read(12))
file_size=os.path.getsize(glb)
triangles=sum(row['triangles'] for row in state_rows.values())
materials=len({m for o in all_meshes for m in o.data.materials})
metrics={
  'id':'T01',
  'glb':'assets/generated/wind_ruins/t01/t01_straight_cliff_wall.glb',
  'states':state_rows,
  'nominal_dimensions_blender_xyz_m':[4,3,6],
  'connector_width_m':4,
  'top_to_base_ratio':0.9,
  'flat_top':True,
  'triangles_total_across_variants':triangles,
  'maximum_triangles_per_variant':max(row['triangles'] for row in state_rows.values()),
  'materials':materials,
  'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':file_size,'length_matches':length==file_size},
  'game_camera_blender_location':[0,-20.57,24.51],
  'game_camera_vertical_fov_deg':30,
  'viewport':[1280,720],
  'fox_scale_reference_height_m':1.755,
  'concept':'output/wind_production/concepts/t01_concept_v1.png',
  'advisory':'5 broad planes; 10% base flare; one recessed diagonal groove; fixed 4 m connector edges across states.',
  'self_check':{
    'all_variants_match_4x3x6_envelope':all(all(abs(a-b)<=0.01 for a,b in zip(row['dimensions_blender_xyz_m'],[4,3,6])) for row in state_rows.values()),
    'all_variants_manifold':all(row['non_manifold_edges']==0 for row in state_rows.values()),
    'all_variants_under_5000_triangles':all(row['triangles']<=5000 for row in state_rows.values()),
    'single_shared_stone_material':materials==1,
    'glb_valid_header':magic==b'glTF' and version==2 and length==file_size,
  },
  'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

# Keep the source as a labeled gallery with all states and the actual fox reference.
cam.location=cam_loc;cam.rotation_euler=cam_rot
cam.data.lens=cam_lens;cam.data.sensor_fit=cam_sensor_fit;cam.data.sensor_height=cam_sensor_height
scene.render.engine=engine
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file:
        image.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/t01_straight_cliff_wall.blend',copy=True)
print('T01_COMPLETE',json.dumps(metrics))
