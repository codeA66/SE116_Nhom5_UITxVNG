import bpy, os, json, math, shutil
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/t04'
PRE=ROOT+'/output/wind_production/t04'
scene=bpy.context.scene
assert scene.name=='WindProduction_T04'
fox=bpy.data.objects['T04_PreviewFox_FoxRig']
source_fox=bpy.data.objects['FoxRig']

# The copied skin must deform from its copied Idle armature. Keeping the source
# rig reference would mix two world transforms and stretch the preview mesh.
changed=[]
for ob in scene.objects:
    if not ob.name.startswith('T04_PreviewFox_'):
        continue
    for modifier in ob.modifiers:
        if modifier.type=='ARMATURE' and modifier.object is source_fox:
            modifier.object=fox
            changed.append(ob.name)
assert changed, 'Expected to retarget the preview fox armature modifier'
scene.view_layers[0].update()
assert max(bpy.data.objects['T04_PreviewFox_Body'].dimensions) < 2.0, bpy.data.objects['T04_PreviewFox_Body'].dimensions[:]
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'

camera=scene.camera
pos,rot=camera.location.copy(),camera.rotation_euler.copy()
lens,fit,height=camera.data.lens,camera.data.sensor_fit,camera.data.sensor_height
engine=scene.render.engine;samples=scene.cycles.samples
roots=[bpy.data.objects[n] for n in ('T04_Left_Edge_Collapse','T04_Center_Edge_Collapse','T04_Right_Edge_Collapse')]
meshes=[o for r in roots for o in r.children_recursive if o.type=='MESH']
locations={r.name:r.location.copy() for r in roots};fox_loc=fox.location.copy()
hidden={o.name:o.hide_render for o in meshes}
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
camera.data.type='PERSP';camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24

def shoot(name,loc,target,focal):
    camera.location=loc
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=focal
    scene.render.filepath=PRE+'/'+name+'.png'
    bpy.ops.render.render(write_still=True)

for root,x in zip(roots,(-5.4,0,5.4)):root.location=(x,0,0)
for ob in meshes:ob.hide_render=False
fox.location=(-5.35,0,0)
shoot('beauty_3quarter',(0,-14.0,7.6),(0,0,-.38),42.0)
for ob in meshes:ob.hide_render=True
for r in roots:
    if r.name=='T04_Center_Edge_Collapse':
        for ob in r.children_recursive:
            if ob.type=='MESH':ob.hide_render=False
fox.location=(.8,0,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

for r in roots:r.location=locations[r.name]
for ob in meshes:ob.hide_render=hidden[ob.name]
fox.location=fox_loc
camera.location=pos;camera.rotation_euler=rot;camera.data.lens=lens;camera.data.sensor_fit=fit;camera.data.sensor_height=height
scene.render.engine=engine;scene.cycles.samples=samples
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file:image.pack()
metrics_path=PRE+'/metrics.json'
with open(metrics_path,'r',encoding='utf-8') as f:metrics=json.load(f)
metrics['fox_preview_rig_modifier_target']='T04_PreviewFox_FoxRig'
metrics['fox_preview_rig_modifier_fixed']=True
metrics['fox_action']='Idle'
for path in (metrics_path,OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/t04_cliff_edge_collapse.blend',copy=True)
print('T04_PREVIEW_FIXED',json.dumps({'retargeted':changed,'body_dimensions':list(bpy.data.objects['T04_PreviewFox_Body'].dimensions),'action':fox.animation_data.action.name,'saved_blend':OUT+'/source/t04_cliff_edge_collapse.blend'}))
