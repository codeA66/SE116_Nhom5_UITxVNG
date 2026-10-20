import bpy, bmesh, math, os, shutil
from mathutils import Vector, Matrix

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
CODE = 'T05'
OUT = ROOT + '/assets/generated/wind_ruins/t05'
PRE = ROOT + '/output/wind_production/t05'
CONCEPT = ROOT + '/output/wind_production/concepts/t05_concept_v1.png'
PROMPT = ROOT + '/output/wind_production/concepts/t05_prompt.txt'

assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
assert not os.path.exists(OUT), 'Refusing to overwrite existing T05 output'
assert not os.path.exists('assets/generated/wind_ruins/t05/t05_ceremonial_staircase.glb')
assert bpy.context.scene.name == 'WindProduction_T04', bpy.context.scene.name
assert 'Scene' in bpy.data.scenes, 'Original startup scene missing; preserve user scene'
assert all(n in bpy.data.objects for n in ('Cube','Camera','Light')), 'Original startup objects missing'

os.makedirs(OUT + '/source', exist_ok=False)
os.makedirs(PRE, exist_ok=True)
open(OUT + '/source/.gdignore', 'w', encoding='utf-8').close()
shutil.copy2(CONCEPT, OUT + '/concept.png')
shutil.copy2(PROMPT, PRE + '/concept_prompt.txt')

old = bpy.data.scenes['WindProduction_T04']
scene = bpy.data.scenes.new('WindProduction_T05')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.world = old.world.copy() if old.world else bpy.data.worlds.new('T05_PreviewWorld')
scene.world.name = 'T05_PreviewWorld'
scene.render.engine = old.render.engine
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.render.film_transparent = False

preview = bpy.data.collections.new('T05_Preview_ONLY')
export = bpy.data.collections.new('T05_Export')
scene.collection.children.link(preview)
scene.collection.children.link(export)

# Copy the proven studio camera and soft lights into this isolated scene.
for src_name, name in [('T04_PreviewCamera','T05_PreviewCamera'),('T04_Preview_Key','T05_Preview_Key'),('T04_Preview_Fill','T05_Preview_Fill'),('T04_Preview_Rim','T05_Preview_Rim')]:
    src = bpy.data.objects[src_name]
    ob = src.copy()
    if src.data:
        ob.data = src.data.copy()
    ob.name = name
    preview.objects.link(ob)
    ob.matrix_world = src.matrix_world.copy()
    if ob.type == 'CAMERA': scene.camera = ob

# Duplicate the already-checked Idle fox preview rig, preserving correct palette and modifiers.
src_rig = bpy.data.objects['T04_PreviewFox_FoxRig']
source_objects = []
def collect(ob):
    source_objects.append(ob)
    for child in ob.children:
        collect(child)
collect(src_rig)
copies = {}
world_matrices = {ob: ob.matrix_world.copy() for ob in source_objects}
for src in source_objects:
    ob = src.copy()
    if src.data:
        ob.data = src.data.copy()
    ob.name = 'T05_PreviewFox_' + src.name.replace('T04_PreviewFox_','')
    preview.objects.link(ob)
    copies[src] = ob
for src, ob in copies.items():
    if src.parent in copies:
        ob.parent = copies[src.parent]
    ob.matrix_world = world_matrices[src]
    for mod in ob.modifiers:
        if mod.type == 'ARMATURE' and mod.object in copies:
            mod.object = copies[mod.object]
fox = copies[src_rig]
fox.animation_data_clear() if fox.animation_data else None
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create()
    fox.animation_data.action = src_rig.animation_data.action
fox.location.x = -3.25
fox.location.y = -0.55
fox.location.z = 0.0
scene.frame_set(1)

# A subdued ground exists for preview renders only and is excluded from the GLB.
def srgb(v):
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
def color(hexv):
    return tuple(srgb(int(hexv[i:i+2],16)) for i in (1,3,5)) + (1.0,)
palette = {
  'stone': color('#74766F'), 'top_a': color('#82847B'), 'top_b': color('#797B73'),
  'riser': color('#5F625C'), 'side': color('#6A6C66'), 'cheek': color('#85877E'),
  'chip': color('#555751'), 'landing_top': color('#7B7D75'), 'landing_side': color('#5F615B'),
  'ground': color('#777A7B')
}
mat = bpy.data.materials.new('T05_Shared_Ruined_Stone')
mat.use_nodes = True
mat.diffuse_color = palette['stone']
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Base Color'].default_value = (1,1,1,1)
bsdf.inputs['Roughness'].default_value = .92
attr_node = mat.node_tree.nodes.new('ShaderNodeVertexColor')
attr_node.layer_name = 'Color'
mat.node_tree.links.new(attr_node.outputs['Color'], bsdf.inputs['Base Color'])

floor_mat = bpy.data.materials.new('T05_Preview_Ground_Material')
floor_mat.use_nodes = True
floor_bsdf = next(n for n in floor_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
floor_bsdf.inputs['Base Color'].default_value = palette['ground']
floor_bsdf.inputs['Roughness'].default_value = .94
floor_me = bpy.data.meshes.new('T05_PreviewGround_Mesh')
floor_me.from_pydata([(-250,-250,-.03),(250,-250,-.03),(250,250,-.03),(-250,250,-.03)],[],[(0,1,2,3)])
floor_me.materials.append(floor_mat)
floor = bpy.data.objects.new('T05_PreviewGround',floor_me)
preview.objects.link(floor)

# Canonical step section: exactly 9 rises of 0.20 m and 9 treads of 0.40 m.
def stair_profile():
    pts=[(0.0,0.0),(0.0,0.10),(0.0,0.20)]
    for i in range(9):
        z=(i+1)*0.2
        pts.append(((i+1)*0.4,z))
        if i<8:
            pts.append(((i+1)*0.4,(i+2)*0.2))
    pts.append((3.6,0.0))
    return pts

base_profile=stair_profile()
# Verify the 9 treads are 0.40 m and the 9 risers are 0.20 m in the central walk strip.
tread_segments=[]
for a,b in zip(base_profile,base_profile[1:]):
    if abs(a[1]-b[1])<1e-7 and b[0]>a[0]: tread_segments.append(round(b[0]-a[0],6))
riser_segments=[]
for a,b in zip(base_profile,base_profile[1:]):
    if abs(a[0]-b[0])<1e-7 and b[1]>a[1]: riser_segments.append(round(b[1]-a[1],6))
assert tread_segments == [0.4]*9, tread_segments
assert len(riser_segments)==10 and riser_segments[0]==0.1, riser_segments
# A split front face keeps the first true rise 0.20 m; the .10 split is only a mesh vertex.
assert abs(sum(riser_segments)-1.8)<1e-6

# Low, integrated cheek bands lift the outer 0.20 m strips by at most 0.10 m;
# the central 4.10 m walk surface retains all exact stair dimensions.
def cheek_profile(base):
    out=[]
    for i,(y,z) in enumerate(base):
        if i in (0,len(base)-1):
            out.append((y,z))
        else:
            out.append((y, min(1.8,z+0.10) if z>0 else z))
    return out

base=base_profile
raised=cheek_profile(base)
# Damage only the exposed front/top terminal of the right cheek, using two broad sloped planes.
damaged=raised[:]
damaged[1]=(0.04,0.15)
damaged[2]=(0.14,0.24)

# Single watertight staircase mesh, with outer cheek bands integrated across the two edges.
def stair_mesh(name, right_outer_profile):
    xs=[-2.25,-2.05,2.05,2.25]
    profiles=[raised,base,base,right_outer_profile]
    verts=[]
    for x,prof in zip(xs,profiles):
        verts.extend([(x,y,z) for y,z in prof])
    n=len(base)
    faces=[]
    # Exterior end caps only; interior sections bridge continuously without coincident faces.
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple((len(xs)-1)*n+i for i in range(n)))
    for j in range(len(xs)-1):
        left=j*n; right=(j+1)*n
        for i in range(n):
            k=(i+1)%n
            faces.append((left+i,left+k,right+k,right+i))
    me=bpy.data.meshes.new(name+'_Mesh')
    me.from_pydata(verts,[],faces)
    me.materials.append(mat)
    me.update()
    bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(me); bm.free(); me.update()
    col=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    # Broad flat planes use quiet tonal changes; the damaged end gets 2 darker cut planes.
    for poly in me.polygons:
        c=poly.center; no=poly.normal
        if abs(no.z)>0.82:
            chosen=palette['top_a'] if int(round(c.y/.4))%2==0 else palette['top_b']
            if abs(c.x)>2.04: chosen=palette['cheek']
        elif abs(no.y)>0.75:
            chosen=palette['riser']
        elif abs(no.x)>0.8:
            chosen=palette['side']
            if name.endswith('Damaged') and c.x>2.20 and c.y<0.30 and c.z>0.08:
                chosen=palette['chip']
        else:
            chosen=palette['side']
        for li in poly.loop_indices:
            col.data[li].color=chosen
    return me

stair_root_specs=[('T05_Intact_Stair','intact'),('T05_Damaged_Stair','damaged')]
stairs=[]
for root_name,state in stair_root_specs:
    root=bpy.data.objects.new(root_name,None)
    root.empty_display_type='PLAIN_AXES'
    root.empty_display_size=.28
    export.objects.link(root)
    mesh_name='T05_Staircase_'+('Intact' if state=='intact' else 'Damaged')
    profile=raised if state=='intact' else damaged
    me=stair_mesh(mesh_name,profile)
    ob=bpy.data.objects.new(mesh_name,me)
    export.objects.link(ob)
    ob.parent=root
    ob.matrix_parent_inverse=Matrix.Identity(4)
    ob.location=(0,0,0)
    stairs.append((root,ob,state))

# Separate landing module: 4.5 m wide, 0.8 m deep, top flush at y=3.6 and z=1.8.
landing_root=bpy.data.objects.new('T05_Separate_Landing',None)
landing_root.empty_display_type='PLAIN_AXES'; landing_root.empty_display_size=.24
export.objects.link(landing_root)
fp=[(-2.17,0.0),(2.17,0.0),(2.25,.08),(2.25,.72),(2.17,.8),(-2.17,.8),(-2.25,.72),(-2.25,.08)]
vs=[(x,y,z) for z in (0,.16) for x,y in fp]
faces=[tuple(reversed(range(8))),tuple(range(8,16))]
for i in range(8): faces.append((i,(i+1)%8,(i+1)%8+8,i+8))
lme=bpy.data.meshes.new('T05_Landing_Slab_Mesh'); lme.from_pydata(vs,[],faces); lme.materials.append(mat); lme.update()
bm=bmesh.new();bm.from_mesh(lme);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(lme);bm.free();lme.update()
lcol=lme.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
for poly in lme.polygons:
    color_value=palette['landing_top'] if poly.normal.z>.7 else palette['landing_side']
    for li in poly.loop_indices:lcol.data[li].color=color_value
landing=bpy.data.objects.new('T05_Landing_Slab',lme);export.objects.link(landing)
landing.parent=landing_root;landing.matrix_parent_inverse=Matrix.Identity(4);landing.location=(0,0,0)
landing_root.location=(0,3.6,1.64)

# Separate preview copies of the landing make both states visible in the beauty render.
landing_preview=[]
for label,xoff in [('Intact',-3.25),('Damaged',3.25)]:
    p=bpy.data.objects.new('T05_Preview_Landing_'+label,lme.copy())
    preview.objects.link(p);p.location=(xoff,3.6,1.64)
    landing_preview.append(p)

# Add a small, subdued broad chamfer accent at the front of the landing via its clipped footprint.
scene.frame_set(1)
for ob in bpy.context.view_layer.objects: ob.select_set(False)
bpy.context.view_layer.objects.active=stairs[0][0]
print('T05_BUILD_OK',scene.name,'verts',len(stairs[0][1].data.vertices),'faces',len(stairs[0][1].data.polygons),'landing_dims',4.5,.8,.16,'fox_action',getattr(getattr(fox.animation_data,'action',None),'name',None),'source_scene_preserved',bpy.data.scenes['Scene'].name)
