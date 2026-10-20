import bpy,math,json,os
from mathutils import Vector
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/f01';PRE=ROOT+'/output/wind_production/f01'
scene=bpy.context.scene; asset=bpy.data.collections['F01_Export'];preview=bpy.data.collections['F01_Preview_ONLY'];cloth=bpy.data.objects['Cloth_Wind_Animated']
# Keep cloth consistently in front of pole. Surface offset of emblem retained.
for v in cloth.data.vertices:
    x,z=v.co.x,v.co.z;t=(4.3-z)/2.4;q=(x+.6)/1.2
    old=-.13+.16*t*t+.095*math.sin(q*2*math.pi+.3)*t+.045*math.sin(q*4*math.pi)*t
    new=-.16-.20*t*t+.095*math.sin(q*2*math.pi+.3)*t+.045*math.sin(q*4*math.pi)*t
    v.co.y+=new-old
# Import actual fox as reference only, with its original proportions.
before=set(scene.objects)
bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
fox=set(scene.objects)-before
for ob in fox:
    for col in list(ob.users_collection):col.objects.unlink(ob)
    preview.objects.link(ob)
    if ob.parent not in fox:ob.location.x+=1.8
    ob['preview_only']=True
def simplemat(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=.9;return m
groundmat=simplemat('Preview_Ground',(.055,.060,.064))
me=bpy.data.meshes.new('PreviewFloor');me.from_pydata([(-30,-30,-.012),(30,-30,-.012),(30,30,-.012),(-30,30,-.012)],[],[(0,1,2,3)])
ground=bpy.data.objects.new('PreviewFloor',me);preview.objects.link(ground);me.materials.append(groundmat)
world=bpy.data.worlds.new('WindPreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.13,.15,.18,1);bg.inputs['Strength'].default_value=.45;scene.world=world
for name,loc,power,size in [('Key',(-5,-7,11),1700,7),('Fill',(6,-2,7),850,6),('Rim',(0,5,9),1300,5)]:
    data=bpy.data.lights.new('Preview_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size;o=bpy.data.objects.new(data.name,data);preview.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,2))-o.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('F01_PreviewCamera');cam=bpy.data.objects.new(data.name,data);preview.objects.link(cam);scene.camera=cam
try:scene.render.engine='CYCLES'
except TypeError:pass
scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'
scene.render.resolution_percentage=100
def render(name,loc,target,res=(1280,720),game=False):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    data.type='PERSP';data.sensor_fit='VERTICAL';data.sensor_height=24;data.lens=24/(2*math.tan(math.radians(15))) if game else 40
    scene.render.resolution_x=res[0];scene.render.resolution_y=res[1];scene.render.filepath=PRE+'/'+name+'.png';bpy.ops.render.render(write_still=True)
render('beauty_3quarter',(7,-11,7),(0.5,0,2.3))
render('game_camera',(0,-20.57,24.51),(0,0,0),game=True)
# Close geometry and silhouette checks at same beauty angle.
clay=simplemat('Preview_Clay',(.34,.36,.38));scene.view_layers[0].material_override=clay
render('clay',(7,-11,7),(.5,0,2.3))
scene.view_layers[0].material_override=None
sil=simplemat('Preview_Silhouette',(0,0,0));scene.view_layers[0].material_override=sil
render('silhouette',(7,-11,7),(.5,0,2.3))
scene.view_layers[0].material_override=None
# Export exactly the model, not the reference stage.
bpy.ops.object.select_all(action='DESELECT')
for ob in asset.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Cloth_Wind_Animated']
bpy.ops.export_scene.gltf(filepath=OUT+'/f01_wind_main_banner.glb',export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
meshes=[ob for ob in asset.objects if ob.type=='MESH'];pts=[ob.matrix_world@Vector(c) for ob in meshes for c in ob.bound_box]
mins=[min(p[i] for p in pts) for i in range(3)];maxs=[max(p[i] for p in pts) for i in range(3)]
tris=0
for ob in meshes:ob.data.calc_loop_triangles();tris+=len(ob.data.loop_triangles)
metrics={'id':'F01','dimensions_blender_xyz_m':[maxs[i]-mins[i] for i in range(3)],'dimensions_godot_xyz_m':[maxs[0]-mins[0],maxs[2]-mins[2],maxs[1]-mins[1]],'bounds_blender_min':mins,'bounds_blender_max':maxs,'triangles':tris,'materials':1,'mesh_parts':[o.name for o in meshes],'pivot':'pole center ground','fox_reference_height_m':1.75496,'game_camera_godot':[0,24.51,20.57],'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'concept':'f01_concept_v2.png','pipeline':'2D exists before MCP 3D; reviewer now process monitor per user override'}
open(PRE+'/metrics.json','w').write(json.dumps(metrics,indent=2))
open(OUT+'/metrics.json','w').write(json.dumps(metrics,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/f01_wind_main_banner.blend',copy=True)
print(json.dumps(metrics))
