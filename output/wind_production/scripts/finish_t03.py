import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/t03'
PRE=ROOT+'/output/wind_production/t03'
os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/t03_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/t03_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_T03',scene.name
asset=bpy.data.collections['T03_Export']
roots=[bpy.data.objects[n] for n in ('T03_Intact_Slab','T03_Sealed_Crack','T03_Chipped_Edge')]
intact,sealed,chipped=roots
all_meshes=[o for o in asset.objects if o.type=='MESH']
cam=scene.camera
cam_loc,cam_rot=cam.location.copy(),cam.rotation_euler.copy()
cam_lens,cam_sensor_fit,cam_sensor_height=cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height
engine=scene.render.engine
orig_locs={r.name:r.location.copy() for r in roots}
orig_hide={o.name:o.hide_render for o in all_meshes}

scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.view_layers[0].material_override=None
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24

def shoot(name,loc,target,lens):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=lens
    scene.render.filepath=PRE+'/'+name+'.png';bpy.ops.render.render(write_still=True)

# Hero sheet shows all three states with the actual fox nearby for scale.
shoot('beauty_3quarter',(.3,-11.6,13.8),(0,0,.2),40.0)

# Exact gameplay camera: one state is compared against the fox at the specified camera offset and FOV.
for obj in all_meshes: obj.hide_render=True
for obj in intact.children_recursive:
    if obj.type=='MESH':obj.hide_render=False
intact.location=(-2.4,0,.30)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def bounds(root):
    pts=[];inv=root.matrix_world.inverted()
    for obj in root.children_recursive:
        if obj.type=='MESH':
            for v in obj.data.vertices:pts.append(inv@(obj.matrix_world@v.co))
    mi=[min(p[i] for p in pts) for i in range(3)];ma=[max(p[i] for p in pts) for i in range(3)]
    return mi,ma,[ma[i]-mi[i] for i in range(3)]

def topology(obj):
    bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not e.is_manifold for e in bm.edges);loose=sum(not v.link_edges for v in bm.verts);bm.free()
    obj.data.calc_loop_triangles()
    return {'triangles':len(obj.data.loop_triangles),'non_manifold_edges':bad,'loose_vertices':loose}

state_rows={}
for root in roots:
    mesh=next(o for o in root.children_recursive if o.type=='MESH');mi,ma,d=bounds(root);topo=topology(mesh)
    state_rows[root.name]={
      'pivot':'center of walking face (local z=0)',
      'bounds_blender_min_m':[round(v,5) for v in mi],
      'bounds_blender_max_m':[round(v,5) for v in ma],
      'dimensions_blender_xyz_m':[round(v,5) for v in d],
      'dimensions_godot_xyz_m':[round(d[0],5),round(d[2],5),round(d[1],5)],
      'mesh':mesh.name,**topo
    }

# Export states overlaid at the same origin so the game can select its intended named state.
for root in roots:root.location=(0,0,0)
for obj in all_meshes:obj.hide_render=orig_hide[obj.name]
for obj in bpy.context.view_layer.objects:obj.select_set(False)
for obj in asset.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/t03_architectural_floor_slab.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
for root in roots:root.location=orig_locs[root.name]
for obj in all_meshes:obj.hide_render=orig_hide[obj.name]
bpy.context.view_layer.update()

with open(glb,'rb') as f:magic,version,length=struct.unpack('<4sII',f.read(12))
size=os.path.getsize(glb);tri=sum(x['triangles'] for x in state_rows.values());materials=len({m for o in all_meshes for m in o.data.materials})
metrics={
 'id':'T03','glb':'assets/generated/wind_ruins/t03/t03_architectural_floor_slab.glb','states':state_rows,
 'nominal_dimensions_blender_xyz_m':[4,4,.30],'walk_surface_pivot':'center at local z=0','perimeter_band_width_m':.15,
 'perimeter_band_coplanar':True,'walk_surface_flat':True,'sealed_crack':'0.07 m flush vertex-color mark, no physical opening',
 'connector_extents_xy_m':[-2,2],'triangles_total_across_variants':tri,'maximum_triangles_per_variant':max(x['triangles'] for x in state_rows.values()),
 'materials':materials,'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':size,'length_matches':length==size},
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/t03_concept_v1.png',
 'advisory':'0.15 m coplanar frame; one broad flush diagonal mark; one shallow side-edge bite, with supported top and fixed connectors.',
 'self_check':{
   'all_variants_match_4x4x0.30_envelope':all(all(abs(a-b)<=.01 for a,b in zip(x['dimensions_blender_xyz_m'],[4,4,.30])) for x in state_rows.values()),
   'all_variants_manifold':all(x['non_manifold_edges']==0 for x in state_rows.values()),
   'all_variants_under_5000_triangles':all(x['triangles']<=5000 for x in state_rows.values()),
   'single_shared_material':materials==1,'glb_valid_header':magic==b'glTF' and version==2 and length==size
 },
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

cam.location=cam_loc;cam.rotation_euler=cam_rot;cam.data.lens=cam_lens;cam.data.sensor_fit=cam_sensor_fit;cam.data.sensor_height=cam_sensor_height;scene.render.engine=engine
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file:image.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/t03_architectural_floor_slab.blend',copy=True)
print('T03_COMPLETE',json.dumps(metrics))
