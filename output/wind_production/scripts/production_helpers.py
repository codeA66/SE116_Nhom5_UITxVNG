import bpy,math,os,json
from mathutils import Vector
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
def make_material(name,hexcolor):
    def lin(x):return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
    col=tuple(lin(int(hexcolor[i:i+2],16)/255) for i in (1,3,5))
    m=bpy.data.materials.new(name);m.use_nodes=True;b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');b.inputs['Base Color'].default_value=(*col,1);b.inputs['Roughness'].default_value=.9;return m
def new_scene(code):
    s=bpy.data.scenes.new('WindProduction_'+code);bpy.context.window.scene=s
    s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    s.collection.children.link(bpy.data.collections['F01_Preview_ONLY']);s.world=bpy.data.worlds['WindPreviewWorld'];s.camera=bpy.data.objects['F01_PreviewCamera']
    c=bpy.data.collections.new(code+'_Export');s.collection.children.link(c)
    return s,c
def mesh(c,name,vs,fs,mat):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);c.objects.link(o);me.materials.append(mat);return o
def loft(c,name,rings,mat,n=8):
    vs=[]
    for z,rx,ry in rings:
        for i in range(n):
            a=(i+.5)*2*math.pi/n;vs.append((rx*math.cos(a),ry*math.sin(a),z))
    fs=[tuple(reversed(range(n)))]
    for k in range(len(rings)-1):
        for i in range(n):fs.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
    fs.append(tuple((len(rings)-1)*n+i for i in range(n)))
    return mesh(c,name,vs,fs,mat)
def finish(code,c,stem,target=(0,0,2),camera=(7,-11,7),extras=None):
    s=bpy.context.scene;out=ROOT+'/assets/generated/wind_ruins/'+code.lower();pre=ROOT+'/output/wind_production/'+code.lower();os.makedirs(out+'/source',exist_ok=True);os.makedirs(pre,exist_ok=True);open(out+'/source/.gdignore','w').close()
    s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=True;s.view_settings.view_transform='AgX';s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=100
    cam=s.camera;d=cam.data
    def shot(name,loc,tgt,game=False):
        cam.location=loc;cam.rotation_euler=(Vector(tgt)-cam.location).to_track_quat('-Z','Y').to_euler();d.type='PERSP';d.sensor_fit='VERTICAL';d.sensor_height=24;d.lens=24/(2*math.tan(math.radians(15))) if game else 40
        s.render.filepath=pre+'/'+name+'.png';bpy.ops.render.render(write_still=True)
    shot('beauty_3quarter',camera,target)
    shot('game_camera',(0,-20.57,24.51),(0,0,0),True)
    s.view_layers[0].material_override=bpy.data.materials['Preview_Clay'];shot('clay',camera,target)
    s.view_layers[0].material_override=bpy.data.materials['Preview_Silhouette'];shot('silhouette',camera,target);s.view_layers[0].material_override=None
    for ob in bpy.data.objects:ob.select_set(False)
    for ob in c.objects:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out+'/'+stem+'.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
    meshes=[o for o in c.objects if o.type=='MESH'];pts=[o.matrix_world@Vector(p) for o in meshes for p in o.bound_box];mi=[min(p[i] for p in pts) for i in range(3)];ma=[max(p[i] for p in pts) for i in range(3)];tri=0
    for o in meshes:o.data.calc_loop_triangles();tri+=len(o.data.loop_triangles)
    metrics={'id':code,'triangles':tri,'materials':len(set(m for o in meshes for m in o.data.materials)),'bounds_blender_min':mi,'bounds_blender_max':ma,'dimensions_godot_xyz_m':[ma[0]-mi[0],ma[2]-mi[2],ma[1]-mi[1]],'mesh_parts':[o.name for o in meshes],'camera_godot':[0,24.51,20.57],'vertical_fov':30,'viewport':[1280,720],'fox_reference':'actual fox_spirit.glb; Idle frame1; runtime fox_palette.png; helper and Sword hidden','pipeline':'actual2D->single Astra advisory->MCP3D->selfcheck; no aesthetic gate'}
    if extras:metrics.update(extras)
    for file in [pre+'/metrics.json',out+'/metrics.json']:open(file,'w').write(json.dumps(metrics,indent=2))
    for im in bpy.data.images:
        if im.filepath.endswith('fox_palette.png') and not im.packed_file:im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=out+'/source/'+stem+'.blend',copy=True)
    import shutil
    shutil.copy2(pre+'/beauty_3quarter.png',out+'/preview.png')
    print('COMPLETE',json.dumps(metrics))
