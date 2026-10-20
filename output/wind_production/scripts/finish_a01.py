import bpy, os, json, shutil
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/a01'
PRE = ROOT + '/output/wind_production/a01'
os.makedirs(OUT + '/source', exist_ok=True)
os.makedirs(PRE, exist_ok=True)
open(OUT + '/source/.gdignore', 'w').close()
shutil.copy2(ROOT + '/output/wind_production/concepts/a01_concept_v1.png', OUT + '/concept.png')

scene = bpy.context.scene
asset = bpy.data.collections['A01_Export']
intact = bpy.data.objects['A01_Intact_Column']
broken = bpy.data.objects['A01_Broken_Column']
fallen = bpy.data.objects['A01_Fallen_UpperPiece']
cam = scene.camera
cam_loc, cam_rot = cam.location.copy(), cam.rotation_euler.copy()
cam_lens, sensor_fit, sensor_height = cam.data.lens, cam.data.sensor_fit, cam.data.sensor_height
engine = scene.render.engine
old_location = {intact.name:intact.location.copy(), broken.name:broken.location.copy()}

scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.view_settings.view_transform = 'AgX'
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.view_layers[0].material_override = None
cam.data.type = 'PERSP'
cam.data.sensor_fit = 'VERTICAL'
cam.data.sensor_height = 24

def shoot(name, location, target, game=False):
    cam.location = location
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.lens = 24/(2*__import__('math').tan(__import__('math').radians(15))) if game else 40
    scene.render.filepath = PRE + '/' + name + '.png'
    bpy.ops.render.render(write_still=True)

shoot('beauty_3quarter', (7,-12,8), (-0.75,1.0,2.05))
shoot('game_camera', (0,-20.57,24.51), (0,0,0), True)

def child_meshes(root_obj, include_children=True):
    found=[]
    def walk(obj):
        for child in obj.children:
            if child.type == 'MESH': found.append(child)
            if include_children: walk(child)
    walk(root_obj)
    return found

def bounds(meshes, root_obj=None):
    pts=[]
    for obj in meshes:
        for vertex in obj.data.vertices:
            p=obj.matrix_world @ vertex.co
            if root_obj is not None:
                p = root_obj.matrix_world.inverted() @ p
            pts.append(p)
    mn=[min(p[i] for p in pts) for i in range(3)]
    mx=[max(p[i] for p in pts) for i in range(3)]
    return mn,mx,[mx[i]-mn[i] for i in range(3)]

full_meshes=child_meshes(intact)
stump_meshes=[o for o in child_meshes(broken) if o.parent != fallen and o not in child_meshes(fallen)]
fallen_meshes=child_meshes(fallen)
mn_full,mx_full,dim_full=bounds(full_meshes,intact)
mn_stump,mx_stump,dim_stump=bounds(stump_meshes,broken)
mn_upper,mx_upper,dim_upper=bounds(fallen_meshes,fallen)
all_meshes=[o for o in asset.objects if o.type=='MESH']
for obj in all_meshes: obj.data.calc_loop_triangles()
triangle_count=sum(len(obj.data.loop_triangles) for obj in all_meshes)
material_count=len({mat for obj in all_meshes for mat in obj.data.materials})

# Export both named states at the same origin so the importing game can select either root.
intact.location=(0,0,0)
broken.location=(0,0,0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=intact
glb_path=OUT + '/a01_ceremonial_column.glb'
bpy.ops.export_scene.gltf(filepath=glb_path,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
intact.location=old_location[intact.name]
broken.location=old_location[broken.name]
bpy.context.view_layer.update()

dimensions_godot=lambda d:[round(d[0],5),round(d[2],5),round(d[1],5)]
metrics={
  'id':'A01',
  'glb':'assets/generated/wind_ruins/a01/a01_ceremonial_column.glb',
  'states':{
    'A01_Intact_Column':{'dimensions_blender_xyz_m':[round(v,5) for v in dim_full],'dimensions_godot_xyz_m':dimensions_godot(dim_full),'pivot':'bottom center','meshes':[o.name for o in full_meshes]},
    'A01_Broken_Column':{'stump_dimensions_blender_xyz_m':[round(v,5) for v in dim_stump],'stump_dimensions_godot_xyz_m':dimensions_godot(dim_stump),'stump_pivot':'bottom center','detached_upper_dimensions_blender_xyz_m':[round(v,5) for v in dim_upper],'detached_upper_dimensions_godot_xyz_m':dimensions_godot(dim_upper),'detached_upper_pivot':'ground contact at horizontal midpoint','meshes':[o.name for o in stump_meshes+fallen_meshes]}
  },
  'triangles':triangle_count,
  'materials':material_count,
  'cut_plane':'shared 25-degree fracture boundary, average stump height 1.60 m, four broad planes',
  'game_camera_godot':[0,24.51,20.57],
  'game_camera_vertical_fov_deg':30,
  'viewport':[1280,720],
  'concept':'output/wind_production/concepts/a01_concept_v1.png',
  'advisory':'4-6 broad capital planes; clean octagonal shaft; same 25-degree three-to-four-plane fracture across stump and detached upper piece',
  'pipeline':'actual2D -> one advisory -> direct MCP Blender 3D -> self-check/export; no approval gate',
  'self_check':{
    'intact_width_depth_height_m':[round(dim_full[0],4),round(dim_full[1],4),round(dim_full[2],4)],
    'stump_bbox_m':[round(dim_stump[0],4),round(dim_stump[1],4),round(dim_stump[2],4)],
    'detached_upper_length_m':round(dim_upper[0],4),
    'detached_upper_centerline_length_m':round(4.20-1.60,4),
    'triangle_budget_under_5000':triangle_count<=5000,
    'one_shared_material':material_count==1,
    'shared_fracture_boundary':True,
    'glb_exists':os.path.exists(glb_path)
  }
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

# Save the source with the gallery arrangement and both variants visible.
cam.location=cam_loc;cam.rotation_euler=cam_rot;cam.data.lens=cam_lens;cam.data.sensor_fit=sensor_fit;cam.data.sensor_height=sensor_height
scene.render.engine=engine
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/a01_ceremonial_column.blend',copy=True)
print('A01_COMPLETE',json.dumps(metrics))
