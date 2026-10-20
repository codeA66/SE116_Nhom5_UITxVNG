import bpy, math, os
from mathutils import Euler, Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d01'
PRE=ROOT+'/output/wind_production/d01'
CODE='D01'
TILT_X_DEG=-70.0

def empty(coll,name,parent=None,description=''):
    ob=bpy.data.objects.new(name,None); coll.objects.link(ob); ob.empty_display_type='PLAIN_AXES'
    if parent: ob.parent=parent
    if description: ob['design']=description
    return ob

def locator(coll,name,loc,description):
    ob=empty(coll,'D01_Source_'+name,description=description); ob.location=loc
    ob.hide_render=True; ob.hide_set(True); ob['source_only']=True
    ob['local_coordinates_blender_m']=[float(v) for v in loc]
    return ob

def preview_setup(scene,preview):
    cd=bpy.data.cameras.new('D01_PreviewCamera_Data'); cam=bpy.data.objects.new('D01_PreviewCamera',cd); preview.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('D01_Key',(-9,-12,10),4200,8),('D01_Fill',(10,-5,7),2200,7),('D01_Rim',(1,10,9),3400,7)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); preview.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,1.3))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('D01_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=(.48,.50,.49,1); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('D01_PreviewGround_Mesh'); me.from_pydata([(-80,-80,-.04),(80,-80,-.04),(80,80,-.04),(-80,80,-.04)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('D01_PreviewGround',me); preview.objects.link(floor)
    world=bpy.data.worlds.new('D01_PreviewWorld'); world.use_nodes=True; bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.36,.38,.37,1); bg.inputs['Strength'].default_value=.8; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Actual fox reference did not import as an armature')
    for ob in imported:
        old=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        preview.objects.link(ob); ob.name='D01_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(0,-4.5,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file: im.pack()
    return cam,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None,'Original default Cube/Camera/Light scene must remain preserved'
    assert bpy.data.scenes.get('WindProduction_L04') is not None,'Exact source L04 scene is missing'
    assert bpy.data.scenes.get('WindProduction_D01') is None,'Refusing to duplicate an existing D01 scene'
    source_names=['L04_Intact_RingArc_02','L04_Intact_RingArc_03']
    source_arcs=[bpy.data.objects.get(n) for n in source_names]
    assert all(o and o.type=='MESH' for o in source_arcs),source_names
    assert all(o.data.materials and 'L04_Shared_Stone' in o.data.materials[0].name for o in source_arcs)
    # Calculate a shared rigid transform and bottom-center pivot from the exact source vertices.
    rot=Euler((math.radians(TILT_X_DEG),0,0),'XYZ').to_quaternion()
    pts=[rot@v.co for src in source_arcs for v in src.data.vertices]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    offset=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
    os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True); open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_D01'); bpy.context.window.scene=scene; scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('D01_Export'); scene.collection.children.link(export)
    preview=bpy.data.collections.new('D01_Preview_ONLY'); scene.collection.children.link(preview)
    source_coll=bpy.data.collections.new('D01_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source_coll)
    root=empty(export,'D01_FallenCeremonialRingFragment',
               description='The exact 72-degree missing L04 sector: adjacent intact modules 02 and 03, tilted 40 degrees, with the original shallow recessed channel; no added chunks.')
    root['state']='fallen_72_degree_missing_l04_sector'
    root['source_asset']='L04 exact ring arc modules 02 and 03'
    root['outer_radius_m']=5.0; root['inner_radius_m']=3.5; root['radial_band_m']=1.5
    root['front_to_back_depth_m']=.9; root['source_arc_span_degrees']=72.0; root['tilt_x_degrees']=TILT_X_DEG
    clones=[]
    for idx,src in enumerate(source_arcs,1):
        ob=bpy.data.objects.new(f'D01_ExactL04ArcModule_{idx:02d}',src.data); export.objects.link(ob); ob.parent=root
        ob.location=offset; ob.rotation_euler=(math.radians(TILT_X_DEG),0,0); ob.scale=(1,1,1)
        ob['source_object']=src.name; ob['source_mesh_reused_exactly']=True
        ob['original_module_index']=idx+1; ob['arc_span_degrees']=36.0
        clones.append(ob)
    loc0=locator(source_coll,'BottomCenterPivot',(0,0,0),'Bottom-center ground pivot for this placed fragment.')
    loc1=locator(source_coll,'L04RingCenter',tuple(offset),'Translation from the exact L04 ring-center geometry to D01 local bottom-center coordinates.')
    source_coll['source_mesh_names']=source_names
    source_coll['exact_reuse_count']=len(clones)
    source_coll['pivot']='D01 root origin is centered on the horizontal bounds and lies at the lowest source vertex.'
    cam,fox=preview_setup(scene,preview)
    cam.location=(8,-12,8); target=Vector((0,0,max(1.0,(hi.z-lo.z)/2))); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=42
    scene.render.engine='CYCLES'; scene.cycles.samples=20; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=root
    print('D01_CREATED',{'scene':scene.name,'source_arc_names':source_names,
          'source_data_reused':[clones[i].data is source_arcs[i].data for i in range(2)],
          'local_translation':[float(v) for v in offset],'tilt_x_degrees':TILT_X_DEG,
          'predicted_dimensions_blender_xyz_m':[float(hi[i]-lo[i]) for i in range(3)],
          'default_scene_preserved':bpy.data.scenes.get('Scene') is not None})

main()
