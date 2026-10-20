import bpy, math
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb) + (1.0,)

COLORS = {
    'front_l': lin('#60615D'),
    'front_lm': lin('#686965'),
    'front_mid': lin('#70716C'),
    'front_rm': lin('#686965'),
    'front_r': lin('#60615D'),
    'side': lin('#5A5B57'),
    'back': lin('#646560'),
    'top': lin('#797A74'),
    'bottom': lin('#50514D'),
    'crack_wall': lin('#4B4C48'),
    'crack_floor': lin('#3E403D'),
    'chip': lin('#7B7C76'),
}

Z_ROWS = [0.0, 0.48, 0.95, 1.55, 2.10, 2.75, 4.30, 5.55, 6.0]
BASE_X = [-2.0, -1.72, -1.10, 1.10, 1.72, 2.0]
FRONT_OFFSET = [0.12, 0.07, 0.0, 0.0, 0.07, 0.12]
ROW_DRIFT = [
    [0,0,0,0,0,0],
    [0,-.020,.015,-.015,.018,0],
    [0,.016,-.014,.020,-.016,0],
    [0,-.014,.018,-.018,.014,0],
    [0,.010,-.012,.014,-.010,0],
    [0,-.008,.010,-.008,.006,0],
    [0,.008,-.008,.010,-.008,0],
    [0,-.004,.004,-.004,.004,0],
    [0,0,0,0,0,0],
]

def make_stone_material():
    mat = bpy.data.materials.new('T01_Stone_SharedPalette')
    mat.use_nodes = True
    mat.diffuse_color = lin('#686966')
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (1,1,1,1)
    bsdf.inputs['Roughness'].default_value = 0.9
    attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Color'
    mat.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

def stage_material():
    mat = bpy.data.materials.get('T01_Preview_Ground') or bpy.data.materials.new('T01_Preview_Ground')
    mat.diffuse_color = lin('#777A7B')
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = lin('#777A7B')
    bsdf.inputs['Roughness'].default_value = 0.94
    return mat

def preview_collection(scene):
    col = bpy.data.collections.new('T01_Preview_ONLY')
    scene.collection.children.link(col)
    for src_name, new_name in [('F01_PreviewCamera','T01_PreviewCamera'),
                               ('Preview_Key','T01_Preview_Key'),
                               ('Preview_Fill','T01_Preview_Fill'),
                               ('Preview_Rim','T01_Preview_Rim')]:
        src = bpy.data.objects[src_name]
        obj = src.copy()
        obj.data = src.data.copy()
        obj.name = new_name
        col.objects.link(obj)
    def link_fox(obj):
        if obj.name not in ('Icosphere','Sword') and obj.name not in col.objects:
            col.objects.link(obj)
        for child in obj.children:
            link_fox(child)
    link_fox(bpy.data.objects['FoxRig'])
    mesh = bpy.data.meshes.new('T01_PreviewFloor_Mesh')
    mesh.from_pydata([(-250,-250,-.014),(250,-250,-.014),(250,250,-.014),(-250,250,-.014)],[],[(0,1,2,3)])
    mesh.materials.append(stage_material())
    floor = bpy.data.objects.new('T01_PreviewFloor',mesh)
    col.objects.link(floor)
    scene.world = (bpy.data.worlds.get('T01_PreviewWorld') or bpy.data.worlds['WindPreviewWorld'].copy())
    scene.world.name = 'T01_PreviewWorld'
    scene.camera = bpy.data.objects['T01_PreviewCamera']
    return col

def root(collection, name, loc, design):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = loc
    obj.empty_display_type = 'PLAIN_AXES'
    obj['pivot'] = 'bottom center at ground; nominal module extents X=4m, Y=3m, Z=6m'
    obj['design'] = design
    return obj

def interp_profile(x, s):
    for i in range(len(BASE_X)-1):
        if x <= BASE_X[i+1]:
            t = (x-BASE_X[i])/(BASE_X[i+1]-BASE_X[i])
            return -1.5*s + (FRONT_OFFSET[i]*(1-t)+FRONT_OFFSET[i+1]*t)*s
    return -1.5*s

def ring_for(z, row, variant):
    s = 1.0 - 0.1*(z/6.0)
    if variant == 'crack':
        # One clean diagonal channel in the exposed face. Both side connector edges remain fixed.
        z0, z1 = 0.48, 2.75
        t = max(0.0, min(1.0, (z-z0)/(z1-z0)))
        center = -0.10 + 0.90*t
        w, f = 0.15, 0.055
        active = z0 <= z <= z1
        if active:
            fade = min(1.0, (z-z0)/0.42, (z1-z)/0.42)
            depth = max(0.015,0.19*fade)
        else:
            depth = 0.0
        xs_base = [BASE_X[0], BASE_X[1], BASE_X[2], center-w, center-f, center+f, center+w, BASE_X[4], BASE_X[5]]
        coords=[]
        for j,x0 in enumerate(xs_base):
            x=x0*s
            y=interp_profile(x0,s)
            # Insert an actual inset strip with two bevel walls and a dark floor.
            if j in (4,5) and active:
                y += depth
            coords.append((x,y,z))
    else:
        coords=[]
        for i,x0 in enumerate(BASE_X):
            x=x0*s + ROW_DRIFT[row][i]
            y=interp_profile(x0,s)
            zz=z
            if variant == 'missing' and i == 4 and z <= 1.55:
                fade=max(0.0,1.0-z/1.55)
                # A broad diagonal cut bevel on the exposed lower-right face.
                x -= 0.34*fade
                y += 0.30*fade
            coords.append((x,y,zz))
    # Rear points close the solid while keeping the 4 m connector boundaries unchanged.
    coords.extend([(2.0*s,1.5*s,z),(-2.0*s,1.5*s,z)])
    return coords

def build_mesh(collection, name, material, parent, variant):
    verts=[]
    rings=[ring_for(z,row,variant) for row,z in enumerate(Z_ROWS)]
    n=len(rings[0])
    assert all(len(r)==n for r in rings)
    for r in rings: verts.extend(r)
    faces=[]; keys=[]
    faces.append(tuple(reversed(range(n))));keys.append('bottom')
    front_count = 9 if variant == 'crack' else 6
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
            if i < front_count-1:
                if variant == 'crack' and i in (3,4,5) and Z_ROWS[k+1] > 0.48 and Z_ROWS[k] < 2.75:
                    keys.append(('crack_wall','crack_floor','crack_wall')[i-3])
                else:
                    color_keys=('front_l','front_lm','front_mid','front_rm','front_r')
                    if variant == 'crack':
                        if i < 3: idx=i
                        elif i == 6: idx=3
                        elif i >=7: idx=4
                        else: idx=2
                    else: idx=min(i,4)
                    key=color_keys[idx]
                    if variant == 'missing' and i==4 and Z_ROWS[k] < 1.55:
                        key='chip'
                    keys.append(key)
            elif i == front_count-1:
                keys.append('side')
            elif i == front_count:
                keys.append('back')
            else:
                keys.append('side')
    faces.append(tuple((len(rings)-1)*n+i for i in range(n)));keys.append('top')
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update();me.materials.append(material)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,key in zip(me.polygons,keys):
        color=COLORS[key]
        for li in poly.loop_indices: attr.data[li].color=color
    me.calc_loop_triangles()
    obj=bpy.data.objects.new(name,me);collection.objects.link(obj);obj.parent=parent
    obj['variant']=variant
    obj['nominal_dimensions_m']='4 x 3 x 6; base flare 10%; flat top'
    return obj

previous=bpy.data.scenes.get('WindProduction_T01')
if previous:
    fallback=bpy.data.scenes.get('WindProduction_A01') or bpy.data.scenes.get('Scene')
    if fallback: bpy.context.window.scene=fallback
    for obj in list(previous.objects):
        if obj.name.startswith('T01_'):
            bpy.data.objects.remove(obj,do_unlink=True)
    for col in list(previous.collection.children):
        if col.name in ('T01_Export','T01_Preview_ONLY'):
            previous.collection.children.unlink(col)
            bpy.data.collections.remove(col)
    old_world=previous.world
    bpy.data.scenes.remove(previous,do_unlink=True)
    if old_world and old_world.name=='T01_PreviewWorld' and old_world.users==0:
        bpy.data.worlds.remove(old_world)
    old_mat=bpy.data.materials.get('T01_Stone_SharedPalette')
    if old_mat and old_mat.users==0: bpy.data.materials.remove(old_mat)
    for me in list(bpy.data.meshes):
        if me.name.startswith('T01_') and me.users==0: bpy.data.meshes.remove(me)
old_scene=bpy.context.scene
scene=bpy.data.scenes.new('WindProduction_T01')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
preview=preview_collection(scene)
asset=bpy.data.collections.new('T01_Export');scene.collection.children.link(asset)
stone=make_stone_material()
intact=root(asset,'T01_Intact_Cliff',(-5.8,0,0),'Intact 4 x 3 x 6 m tapered cliff monolith with a dominant broad center face, four angled companion planes, and flat usable top.')
missing=root(asset,'T01_Missing_Corner',(-0.4,0,0),'Same connector envelope; one broad lower-right exposed-face bevel chipped inward.')
cracked=root(asset,'T01_Diagonal_Crack',(5.8,0,0),'Same connector envelope; one recessed diagonal fracture with two broad bevel walls and a deep channel floor.')
build_mesh(asset,'T01_Intact_Stone',stone,intact,'intact')
build_mesh(asset,'T01_Missing_Stone',stone,missing,'missing')
build_mesh(asset,'T01_Cracked_Stone',stone,cracked,'crack')
print('T01_CREATED',scene.name,'variants',3,'mesh_parts',sum(1 for o in asset.objects if o.type=='MESH'),'triangles',sum(len(o.data.loop_triangles) for o in asset.objects if o.type=='MESH'),'objects_preserved',bpy.data.scenes.get('Scene') is not None)
