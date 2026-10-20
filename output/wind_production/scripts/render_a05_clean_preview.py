import bpy, os, shutil
from mathutils import Vector
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/a05'
PRE=ROOT+'/output/wind_production/a05'
assert bpy.context.scene.name=='WindProduction_A05'
scene=bpy.context.scene
roots=[bpy.data.objects[n] for n in ('A05_Intact','A05_Missing_Rail','A05_Fallen_Post_Displaced_Rail')]
fox=bpy.data.objects['A05_PreviewFox_FoxRig']
fox_objects=[]
def walk(ob):
    fox_objects.append(ob)
    for child in ob.children:walk(child)
walk(fox)
old_locs={r.name:r.location.copy() for r in roots}
old_hide={o.name:o.hide_render for o in fox_objects}
camera=bpy.data.objects['A05_PreviewCamera']
old_cam=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height)
old_render=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising)
for root,x in zip(roots,(-5.2,0.0,5.2)):root.location=(x,0,0)
for ob in fox_objects:ob.hide_render=True
camera.data.type='PERSP';camera.data.sensor_fit='VERTICAL';camera.data.sensor_height=24;camera.data.lens=40
camera.location=(0,-19,9);camera.rotation_euler=(Vector((0,0,.48))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=18;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=PRE+'/beauty_3quarter.png'
bpy.ops.render.render(write_still=True)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for root in roots:root.location=old_locs[root.name]
for ob in fox_objects:ob.hide_render=old_hide[ob.name]
camera.location,camera.rotation_euler,camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height=old_cam
scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising=old_render
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/a05_ceremonial_barrier_module.blend',copy=True)
print('A05_PREVIEW_UPDATED','three states unobscured','fox retained in source and game-camera proof')
