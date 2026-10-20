import bpy, bmesh, json, math, os, shutil
from mathutils import Matrix, Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
CODE = 'A02'
OUT = ROOT + '/assets/generated/wind_ruins/a02'
PRE = ROOT + '/output/wind_production/a02'
CONCEPT = ROOT + '/output/wind_production/concepts/a02_concept_v1.png'
PROMPT = ROOT + '/output/wind_production/concepts/a02_prompt.txt'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
assert not os.path.exists(OUT), 'Refusing to overwrite an existing A02 output'
assert bpy.context.scene.name == 'WindProduction_T05', bpy.context.scene.name
assert 'Scene' in bpy.data.scenes and all(n in bpy.data.objects for n in ('Cube','Camera','Light'))
os.makedirs(OUT + '/source', exist_ok=False)
os.makedirs(PRE, exist_ok=True)
open(OUT + '/source/.gdignore', 'w', encoding='utf-8').close()
shutil.copy2(CONCEPT, OUT + '/concept.png')
shutil.copy2(PROMPT, PRE + '/concept_prompt.txt')

# Start an isolated production scene while preserving the original startup scene.
old = bpy.data.scenes['WindProduction_T05']
scene = bpy.data.scenes.new('WindProduction_A02')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'; scene.unit_settings.scale_length = 1.0
scene.world = old.world.copy() if old.world else bpy.data.worlds.new('A02_PreviewWorld')
scene.world.name = 'A02_PreviewWorld'
scene.render.engine = old.render.engine
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='AgX'; scene.render.film_transparent=False
preview=bpy.data.collections.new('A02_Preview_ONLY'); export=bpy.data.collections.new('A02_Export')
scene.collection.children.link(preview); scene.collection.children.link(export)

# Reuse the tested production camera and studio lights, with the correctly posed idle fox as the scale reference.
for src_name,name in [('T05_PreviewCamera','A02_PreviewCamera'),('T05_Preview_Key','A02_Preview_Key'),('T05_Preview_Fill','A02_Preview_Fill'),('T05_Preview_Rim','A02_Preview_Rim')]:
    src=bpy.data.objects[src_name]; ob=src.copy()
    if src.data: ob.data=src.data.copy()
    ob.name=name; preview.objects.link(ob); ob.matrix_world=src.matrix_world.copy()
    if ob.type=='CAMERA': scene.camera=ob
src_rig=bpy.data.objects['T05_PreviewFox_FoxRig']; source_objects=[]
def collect(ob):
    source_objects.append(ob)
    for child in ob.children: collect(child)
collect(src_rig); copies={}; world_matrices={ob:ob.matrix_world.copy() for ob in source_objects}
for src in source_objects:
    ob=src.copy()
    if src.data: ob.data=src.data.copy()
    ob.name='A02_PreviewFox_'+src.name.replace('T05_PreviewFox_','')
    preview.objects.link(ob); copies[src]=ob
for src,ob in copies.items():
    if src.parent in copies: ob.parent=copies[src.parent]
    ob.matrix_world=world_matrices[src]
    for mod in ob.modifiers:
        if mod.type=='ARMATURE' and mod.object in copies: mod.object=copies[mod.object]
fox=copies[src_rig]
if fox.animation_data: fox.animation_data_clear()
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create(); fox.animation_data.action=src_rig.animation_data.action
fox.location=(0,-.65,0); scene.frame_set(1)

def lin(hexv):
    vals=[int(hexv[i:i+2],16)/255.0 for i in (1,3,5)]
    vals=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals]
    return tuple(vals)+(1.0,)
palette={
    'stone':lin('#777871'),'top_a':lin('#86867D'),'top_b':lin('#7E7F77'),
    'side':lin('#696B65'),'end':lin('#898980'),'band':lin('#66756E'),
    'fracture':lin('#565851'),'ground':lin('#777A7B')}
mat=bpy.data.materials.new('A02_Shared_Ruined_Limestone'); mat.use_nodes=True
next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=(1,1,1,1)
next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Roughness'].default_value=.92
attr=mat.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name='Color'
mat.node_tree.links.new(attr.outputs['Color'],next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'])
floor_mat=bpy.data.materials.new('A02_Preview_Ground'); floor_mat.use_nodes=True
next(n for n in floor_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=palette['ground']
fm=bpy.data.meshes.new('A02_PreviewGround_Mesh'); fm.from_pydata([(-50,-50,-.04),(50,-50,-.04),(50,50,-.04),(-50,50,-.04)],[],[(0,1,2,3)]); fm.materials.append(floor_mat)
floor=bpy.data.objects.new('A02_PreviewGround',fm); preview.objects.link(floor)

# The beam uses an eight-sided, chamfered section with a shallow rising underside and broad flat faces.
def section(x):
    ax=abs(x); d=.225 if ax>=1.82 else .205
    bot=.024*(ax/2.0)**2
    top=.60 if ax>=1.82 else .54
    c=.035
    return [(-d+c,bot),(d-c,bot),(d,bot+c),(d,top-c),(d-c,top),(-d+c,top),(-d,top-c),(-d,bot+c)]

def cut_offset(y,z):
    if z>.43: return -.052
    if z<.11: return .043
    if y<-.08: return -.025
    return .030

def build_mesh(name,stations,half=None):
    # half is None for intact; otherwise the inner boundary at X=0 is one exact, shared 3-plane cut.
    verts=[]; rings=[]
    for x in stations:
        loop=[]
        for i,(y,z) in enumerate(section(x)):
            gx=x
            if half and abs(x)<1e-8: gx += cut_offset(y,z)
            loop.append(len(verts)); verts.append((gx,y,z))
        rings.append(loop)
    faces=[]; m=8
    # Outer end cap is opposite winding for left and right, corrected below by normal recalculation.
    faces.append(tuple(reversed(rings[0])))
    for ri in range(len(rings)-1):
        a,b=rings[ri],rings[ri+1]
        for i in range(m):
            j=(i+1)%m; faces.append((a[i],a[j],b[j],b[i]))
    faces.append(tuple(rings[-1]))
    if half:
        # Replace the inner end ngon with four broad matched facets meeting at one central point.
        faces.pop()
        center=tuple(sum(verts[v][k] for v in rings[-1])/m for k in range(3))
        ci=len(verts); verts.append(center)
        for i in range(0,m,2): faces.append((ci,rings[-1][i],rings[-1][(i+1)%m],rings[-1][(i+2)%m]))
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces); me.materials.append(mat); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(me); bm.free(); me.update()
    col=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        n=poly.normal; c=poly.center
        cut_x=1.0 if half=='left' else -1.0
        if half and abs(c.x-cut_x)<.12 and abs(n.x)>.45: chosen=palette['fracture']
        elif abs(n.z)>.82: chosen=palette['top_a'] if abs(c.x)<1.7 else palette['end']
        elif abs(n.x)>.8: chosen=palette['end']
        else: chosen=palette['side']
        for li in poly.loop_indices: col.data[li].color=chosen
    return me

def make_root(name,mesh_name,stations,half=None,loc=(0,0,0)):
    root=bpy.data.objects.new(name,None); root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.26; export.objects.link(root)
    me=build_mesh(mesh_name,stations,half)
    # Localize each 2 m broken half about its underside-center pivot at world X=-1 or +1.
    if half:
        shift=1.0 if half=='left' else -1.0
        for v in me.vertices: v.co.x += shift
        me.update()
    ob=bpy.data.objects.new(mesh_name,me); export.objects.link(ob); ob.parent=root; ob.matrix_parent_inverse=Matrix.Identity(4); ob.location=(0,0,0)
    root.location=loc
    return root,ob

intact_stations=[-2,-1.82,-1.65,0,1.65,1.82,2]
left_stations=[-2,-1.82,-1.65,0]
right_stations=[2,1.82,1.65,0]
intact,intact_mesh=make_root('A02_Intact','A02_Intact_Beam',intact_stations)
broken_left,left_mesh=make_root('A02_Broken_Left','A02_Broken_Left_Beam',left_stations,'left',(-1,0,0))
broken_right,right_mesh=make_root('A02_Broken_Right','A02_Broken_Right_Beam',right_stations,'right',(1,0,0))
scene.frame_set(1)
for ob in bpy.context.view_layer.objects: ob.select_set(False)
bpy.context.view_layer.objects.active=intact
print('A02_BUILD_OK',scene.name,'intact_verts',len(intact_mesh.data.vertices),'broken_left_verts',len(left_mesh.data.vertices),'broken_right_verts',len(right_mesh.data.vertices),'fox_idle',getattr(getattr(fox.animation_data,'action',None),'name',None),'original_scene_preserved',bpy.data.scenes['Scene'].name)
