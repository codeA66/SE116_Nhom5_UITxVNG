import bpy, bmesh, math
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def linear(hex_color):
    values = [int(hex_color[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values) + (1.0,)

PALETTE = {
    'stone': linear('#777A75'), 'stone_light': linear('#92948D'),
    'stone_band': linear('#686B66'), 'stone_dark': linear('#535752')
}

class MeshBuilder:
    def __init__(self):
        self.vertices, self.faces, self.keys, self.cache = [], [], [], {}
    def vertex(self, p):
        p = tuple(float(v) for v in p)
        key = tuple(round(v, 7) for v in p)
        if key not in self.cache:
            self.cache[key] = len(self.vertices)
            self.vertices.append(p)
        return self.cache[key]
    def face(self, points, color):
        ids = [self.vertex(p) for p in points]
        clean = []
        for i in ids:
            if not clean or clean[-1] != i: clean.append(i)
        if len(clean) > 2 and clean[0] == clean[-1]: clean.pop()
        if len(set(clean)) >= 3:
            self.faces.append(tuple(clean)); self.keys.append(color)

def make_material():
    mat = bpy.data.materials.new('I04_Stone_SharedPalette')
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bsdf.inputs['Roughness'].default_value = .9
    attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Color'
    mat.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

def make_object(collection, name, builder, mat, parent=None, part=None):
    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(builder.vertices, [], builder.faces); mesh.update(); mesh.materials.append(mat)
    colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, key in zip(mesh.polygons, builder.keys):
        for loop_index in poly.loop_indices: colors.data[loop_index].color = PALETTE[key]
    bm = bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh); collection.objects.link(obj)
    if parent:
        obj.parent = parent; obj.location = (0, 0, 0)
    if part: obj['part'] = part
    return obj

def empty(collection, name, loc=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None); collection.objects.link(obj)
    if parent: obj.parent = parent
    obj.location = loc; obj.empty_display_type = 'PLAIN_AXES'
    return obj

def make_base(builder):
    # Chamfered-square plinth; exact outside width is 0.90 m and the foot is grounded at z=0.
    outline = [( .733, 1),(-.733, 1),(-1, .733),(-1,-.733),(-.733,-1),(.733,-1),(1,-.733),(1,.733)]
    rings = [(0.00,.45),(.10,.45),(.16,.41),(.28,.41),(.34,.36),(.40,.36)]
    loops = [[(x*half,y*half,z) for x,y in outline] for z,half in rings]
    builder.face(list(reversed(loops[0])), 'stone_dark')
    bands = ['stone_dark','stone_band','stone','stone_light','stone']
    for j in range(len(loops)-1):
        for i in range(8):
            shade = bands[j]
            if j in (2,4) and i in (1,4,6): shade = 'stone_light'
            builder.face([loops[j][i],loops[j][(i+1)%8],loops[j+1][(i+1)%8],loops[j+1][i]],shade)
    builder.face(loops[-1], 'stone_light')

def make_shaft(builder):
    # A restrained eight-plane taper with a broad shoulder where it meets the crown.
    rings = [(.40,.178),(.48,.172),(.60,.158),(2.88,.151),(3.10,.180),(3.14,.205)]
    count = 8; loops=[]
    for z,radius in rings:
        loops.append([(radius*math.cos(2*math.pi*i/count+math.pi/8),
                       radius*math.sin(2*math.pi*i/count+math.pi/8),z) for i in range(count)])
    builder.face(list(reversed(loops[0])), 'stone_dark')
    for j in range(len(loops)-1):
        for i in range(count):
            color = 'stone'
            if i in (1,4,6): color = 'stone_light'
            elif i in (2,5): color = 'stone_band'
            builder.face([loops[j][i],loops[j][(i+1)%count],loops[j+1][(i+1)%count],loops[j+1][i]],color)
    builder.face(loops[-1], 'stone_light')

def make_crown(builder, start_deg, end_deg, segments=18):
    # A closed annular sector. The 70-degree front gap has a true 0.505 m clear chord.
    r_inner, r_outer, z0, z1 = .29, .44, 3.12, 3.60
    angles = [math.radians(start_deg + (end_deg-start_deg)*i/segments) for i in range(segments+1)]
    outer_bottom=[]; outer_top=[]; inner_bottom=[]; inner_top=[]
    for a in angles:
        c,s=math.cos(a),math.sin(a)
        outer_bottom.append((r_outer*c,r_outer*s,z0)); outer_top.append((r_outer*c,r_outer*s,z1))
        inner_bottom.append((r_inner*c,r_inner*s,z0)); inner_top.append((r_inner*c,r_inner*s,z1))
    for i in range(segments):
        builder.face([inner_top[i],outer_top[i],outer_top[i+1],inner_top[i+1]],'stone_light')
        builder.face([inner_bottom[i+1],outer_bottom[i+1],outer_bottom[i],inner_bottom[i]],'stone_dark')
        builder.face([outer_bottom[i],outer_bottom[i+1],outer_top[i+1],outer_top[i]],'stone')
        builder.face([inner_bottom[i+1],inner_bottom[i],inner_top[i],inner_top[i+1]],'stone_band')
    # Broad planar radial caps read as the large fracture planes on the broken variant.
    builder.face([inner_bottom[0],outer_bottom[0],outer_top[0],inner_top[0]],'stone_light')
    builder.face([outer_bottom[-1],inner_bottom[-1],inner_top[-1],outer_top[-1]],'stone_light')

def beam_xz(builder, a, b, width, depth, color):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); side=Vector((-axis.z,0,axis.x))
    dy=Vector((0,depth/2,0)); sw=side*(width/2)
    verts=[a-sw-dy,a+sw-dy,a+sw+dy,a-sw+dy,b-sw-dy,b+sw-dy,b+sw+dy,b-sw+dy]
    for f in ((3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)):
        builder.face([verts[i] for i in f],color)

def make_emblem(builder):
    # Compact raised copy of F01's open wind ring and three separated strokes, on the front face only.
    center_z=2.28; radius=.118; y=-.163
    angles=[math.radians(55+i*250/9) for i in range(10)]
    points=[(radius*math.cos(a),y,center_z+radius*math.sin(a)) for a in angles]
    for a,b in zip(points,points[1:]): beam_xz(builder,a,b,.019,.012,'stone_light')
    strokes=[((-.050,center_z+.028),(.055,center_z+.075)),
             ((-.060,center_z),(.066,center_z+.020)),
             ((-.046,center_z-.031),(.052,center_z-.024))]
    for (x0,z0),(x1,z1) in strokes:
        beam_xz(builder,(x0,y-.003,z0),(x1,y-.003,z1),.018,.012,'stone_light')

def add_variant(collection, mat, label, root_x, broken=False):
    root=empty(collection,f'I04_{label}_WindGuidePillar',(root_x,0,0))
    root['variant']='BrokenTop' if broken else 'Intact'
    root['nominal_dimensions_blender_xyz_m']=[.9,.9,3.6]
    root['pivot']='ground-center (0,0,0)'
    root['simple_collider']='lower plinth and shaft only; crown is non-colliding'
    root['design']='Ruined East Asian wind guide; broad bevel planes, open C-shaped stone crown, shared F01 wind mark.'
    base=MeshBuilder(); make_base(base); make_object(collection,f'I04_{label}_Base',base,mat,root,'Base')
    shaft=MeshBuilder(); make_shaft(shaft); make_object(collection,f'I04_{label}_Shaft',shaft,mat,root,'Shaft')
    if broken:
        # One 60-degree crown sector is removed; two broad radial faces remain exposed.
        crown=MeshBuilder(); make_crown(crown,365,595,14)
        make_object(collection,f'I04_{label}_Crown_BrokenSector',crown,mat,root,'Crown')
    else:
        crown=MeshBuilder(); make_crown(crown,305,595,18)
        make_object(collection,f'I04_{label}_Crown_OpenChannel',crown,mat,root,'Crown')
    emblem=MeshBuilder(); make_emblem(emblem)
    make_object(collection,f'I04_{label}_WindEmblem',emblem,mat,root,'Emblem')
    return root

def setup_preview(scene, preview):
    camera_data=bpy.data.cameras.new('I04_PreviewCamera_Data')
    camera=bpy.data.objects.new('I04_PreviewCamera',camera_data); preview.objects.link(camera); scene.camera=camera
    for name,loc,power,size in [('I04_Key',(-6,-7,9),1500,6),('I04_Fill',(6,-2,6),850,5),('I04_Rim',(0,7,8),1100,4)]:
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
        obj=bpy.data.objects.new(name,data); preview.objects.link(obj); obj.location=loc
        obj.rotation_euler=(Vector((0,0,1.8))-obj.location).to_track_quat('-Z','Y').to_euler()
    groundmat=bpy.data.materials.new('I04_Preview_Ground'); groundmat.use_nodes=True
    bsdf=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=linear('#777A78'); bsdf.inputs['Roughness'].default_value=.95
    floor_mesh=bpy.data.meshes.new('I04_PreviewFloor_Mesh')
    floor_mesh.from_pydata([(-250,-250,-.012),(250,-250,-.012),(250,250,-.012),(-250,250,-.012)],[],[(0,1,2,3)])
    floor_mesh.materials.append(groundmat)
    floor=bpy.data.objects.new('I04_PreviewFloor',floor_mesh); preview.objects.link(floor)
    world=bpy.data.worlds.new('I04_PreviewWorld'); world.use_nodes=True
    background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    background.inputs['Color'].default_value=(.40,.42,.43,1); background.inputs['Strength'].default_value=.55
    scene.world=world
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before)
    rig=next((obj for obj in imported if obj.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not locate actual fox armature for preview scale.')
    names={obj:obj.name for obj in imported}
    for obj in imported:
        for col in list(obj.users_collection): col.objects.unlink(obj)
        preview.objects.link(obj)
        obj.name='I04_Fox_'+names[obj].replace('.','_')
        if any(token in names[obj].lower() for token in ('icosphere','sword')):
            obj.hide_render=True; obj.hide_set(True)
    idle=next((action for action in bpy.data.actions if 'idle' in action.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-2.8,-.15,0)
    return camera,rig

# Replace only this generated scene during iteration; leave the default and earlier scenes intact.
old=bpy.data.scenes.get('WindProduction_I04')
if old:
    fallback=bpy.data.scenes.get('WindProduction_I03') or bpy.data.scenes.get('Scene')
    if fallback: bpy.context.window.scene=fallback
    bpy.data.scenes.remove(old,do_unlink=True)
for collection in list(bpy.data.collections):
    if collection.name.startswith('I04_') and collection.users==0: bpy.data.collections.remove(collection)
for obj in list(bpy.data.objects):
    if obj.name.startswith('I04_') and obj.users==0: bpy.data.objects.remove(obj,do_unlink=True)
for datablocks in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
    for block in list(datablocks):
        if block.name.startswith('I04_') and block.users==0: datablocks.remove(block)

scene=bpy.data.scenes.new('WindProduction_I04'); bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
export=bpy.data.collections.new('I04_Export'); scene.collection.children.link(export)
preview=bpy.data.collections.new('I04_Preview_ONLY'); scene.collection.children.link(preview)
material=make_material()
intact=add_variant(export,material,'Intact',-1.18,False)
broken=add_variant(export,material,'BrokenTop',1.18,True)
camera,fox=setup_preview(scene,preview)
camera.location=(4.8,-10.8,6.2); camera.rotation_euler=(Vector((0,0,1.8))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24; camera.data.lens=50
scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in export.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=intact
assert bpy.data.scenes.get('Scene') is not None, 'The original default scene was not preserved.'
print('I04_CREATED',scene.name,'states=2','export_objects',len(export.objects),'meshes',sum(o.type=='MESH' for o in export.objects),'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,'default_scene_preserved=True')
