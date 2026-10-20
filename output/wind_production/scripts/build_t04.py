import bpy, bmesh, math, os
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
CONCEPT = ROOT + '/output/wind_production/concepts/t04_concept_v1.png'
OUT_DIR = ROOT + '/assets/generated/wind_ruins/t04'
PRE_DIR = ROOT + '/output/wind_production/t04'

def lin(hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb) + (1.0,)

COLORS = {
    'top_a': lin('#777872'), 'top_b': lin('#70716B'), 'top_c': lin('#74756F'),
    'front_a': lin('#62635F'), 'front_b': lin('#696A65'), 'front_c': lin('#5B5C58'),
    'fracture_a': lin('#50514D'), 'fracture_b': lin('#585955'), 'fracture_c': lin('#646560'),
    'end': lin('#5E5F5B'), 'back': lin('#62635E'), 'bottom': lin('#4E4F4B'),
    'fragment_a': lin('#777872'), 'fragment_b': lin('#595A56'), 'fragment_c': lin('#666762')
}

def make_stone_material():
    mat = bpy.data.materials.new('T04_Stone_SharedPalette')
    mat.use_nodes = True
    mat.diffuse_color = lin('#656660')
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bsdf.inputs['Roughness'].default_value = .92
    attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Color'
    mat.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

def new_preview_scene():
    scene = bpy.data.scenes.new('WindProduction_T04')
    bpy.context.window.scene = scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    preview = bpy.data.collections.new('T04_Preview_ONLY')
    scene.collection.children.link(preview)
    for src_name, new_name in [
        ('F01_PreviewCamera', 'T04_PreviewCamera'),
        ('Preview_Key', 'T04_Preview_Key'),
        ('Preview_Fill', 'T04_Preview_Fill'),
        ('Preview_Rim', 'T04_Preview_Rim')
    ]:
        src = bpy.data.objects[src_name]
        ob = src.copy()
        ob.data = src.data.copy()
        ob.name = new_name
        preview.objects.link(ob)
        ob.matrix_world = src.matrix_world.copy()
    scene.camera = bpy.data.objects['T04_PreviewCamera']
    scene.world = bpy.data.worlds['WindPreviewWorld'].copy()
    scene.world.name = 'T04_PreviewWorld'

    # Copy the actual idle fox hierarchy into this preview scene. Its source
    # rig and the original/default scene remain untouched.
    src_root = bpy.data.objects['FoxRig']
    sources = []
    def collect(ob):
        if ob.name in ('Icosphere', 'Sword'):
            return
        sources.append(ob)
        for child in ob.children:
            collect(child)
    collect(src_root)
    copies = {}
    world_matrices = {ob: ob.matrix_world.copy() for ob in sources}
    for src in sources:
        ob = src.copy()
        ob.name = 'T04_PreviewFox_' + src.name
        preview.objects.link(ob)
        copies[src] = ob
    for src, ob in copies.items():
        if src.parent in copies:
            ob.parent = copies[src.parent]
        ob.matrix_world = world_matrices[src]
        for modifier in ob.modifiers:
            if modifier.type == 'ARMATURE' and modifier.object in copies:
                modifier.object = copies[modifier.object]
    fox = copies[src_root]
    fox.location.x = -5.35

    floor_mat = bpy.data.materials.new('T04_Preview_Ground_Material')
    floor_mat.use_nodes = True
    floor_mat.diffuse_color = lin('#777A7B')
    bsdf = next(n for n in floor_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = lin('#777A7B')
    bsdf.inputs['Roughness'].default_value = .94
    me = bpy.data.meshes.new('T04_PreviewGround_Mesh')
    me.from_pydata([(-250,-250,-1.0),(250,-250,-1.0),(250,250,-1.0),(-250,250,-1.0)], [], [(0,1,2,3)])
    me.materials.append(floor_mat)
    ground = bpy.data.objects.new('T04_PreviewGround', me)
    preview.objects.link(ground)
    return scene, preview, fox

def add_face(faces, keys, ids, key):
    if len(set(ids)) >= 3:
        faces.append(tuple(ids))
        keys.append(key)

def make_body_mesh(collection, material, name, variant, location, xnodes, zlevels, base_profile):
    verts, faces, face_keys, vcache = [], [], [], {}
    def vi(co):
        key = tuple(round(float(x), 7) for x in co)
        if key not in vcache:
            vcache[key] = len(verts)
            verts.append(tuple(float(x) for x in co))
        return vcache[key]

    profiles = [row[:] for row in base_profile]
    if variant != 'intact':
        center = {'left': -1.12, 'center': .12, 'right': 1.34}[variant]
        for zi in range(1, len(zlevels)):
            strength = {1:.04, 2:.25, 3:.46, 4:.37}[zi]
            for xi, x in enumerate(xnodes):
                # The end connectors at x=+/-2 are fixed for all variants.
                if xi in (0, len(xnodes)-1):
                    continue
                weight = max(0.0, 1.0 - abs(x-center)/.88)
                profiles[zi][xi] += strength * weight

    front = [[vi((x, profiles[zi][xi], z)) for xi, x in enumerate(xnodes)]
             for zi, z in enumerate(zlevels)]
    back = [[vi((x, 1.0, z)) for x in xnodes] for z in zlevels]
    # Three broad low-poly tiers on the exposed face; the damaged zone receives
    # two subdued fracture values and remains below the continuous top slab.
    for zi in range(len(zlevels)-1):
        for xi in range(len(xnodes)-1):
            if variant == 'intact':
                key = ('front_a', 'front_b', 'front_c')[(xi + zi) % 3]
            else:
                center = {'left': -1.12, 'center': .12, 'right': 1.34}[variant]
                midx = (xnodes[xi] + xnodes[xi+1]) * .5
                dist = abs(midx-center)
                key = ('fracture_a', 'fracture_b', 'fracture_c')[(xi + zi) % 3] if zi >= 1 and dist < .88 else ('front_a', 'front_b', 'front_c')[(xi + zi) % 3]
            a, b = front[zi][xi], front[zi][xi+1]
            c, d = front[zi+1][xi+1], front[zi+1][xi]
            if (xi + zi) % 2:
                add_face(faces, face_keys, (a,b,d), key)
                add_face(faces, face_keys, (b,c,d), key)
            else:
                add_face(faces, face_keys, (a,b,c), key)
                add_face(faces, face_keys, (a,c,d), key)
    # Continuous rear support strip and its faceted underside.
    for zi in range(len(zlevels)-1):
        for xi in range(len(xnodes)-1):
            a,b,c,d = back[zi][xi], back[zi][xi+1], back[zi+1][xi+1], back[zi+1][xi]
            add_face(faces, face_keys, (a,b,c,d), 'back')
    # Both fixed connector ends, unchanged across all three damage states.
    for xi in (0, len(xnodes)-1):
        for zi in range(len(zlevels)-1):
            f0,f1 = front[zi][xi], front[zi+1][xi]
            b0,b1 = back[zi][xi], back[zi+1][xi]
            if xi == 0:
                add_face(faces, face_keys, (f0,b0,b1,f1), 'end')
            else:
                add_face(faces, face_keys, (f0,f1,b1,b0), 'end')
    # The full-width full-depth level walking plane is coplanar at local z=0.
    for xi in range(len(xnodes)-1):
        x0, x1 = xnodes[xi], xnodes[xi+1]
        color = ('top_a','top_b','top_c')[xi % 3]
        add_face(faces, face_keys, (vi((x0,-1,0)),vi((x1,-1,0)),vi((x1,1,0)),vi((x0,1,0))), color)
    # Close the underside using the same lower front edge and fixed rear edge.
    for xi in range(len(xnodes)-1):
        add_face(faces, face_keys, (front[-1][xi], back[-1][xi], back[-1][xi+1], front[-1][xi+1]), 'bottom')

    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(verts, [], faces)
    me.materials.append(material)
    attr = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, key in zip(me.polygons, face_keys):
        for li in poly.loop_indices:
            attr.data[li].color = COLORS[key]
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free(); me.update()
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    ob.parent = location
    ob['variant'] = variant
    ob['envelope_blender_xyz_m'] = '4 x 2 x 1; top at local z=0'
    ob['protected_walk_plane'] = 'flat full-width 4 x 2 m at z=0'
    ob['connector_ends'] = 'fixed x=-2 and x=+2 m; full 2 m depth'
    return ob, profiles

def make_fragment(collection, material, name, parent, center_x, variant):
    lo, hi = center_x-.39, center_x+.39
    y0, y1 = -.985, -.755
    z0, z1 = -.99, -.68
    verts = [
        (lo+.06,y0,z0), (hi,y0+.02,z0+.02), (hi-.05,y1,z0+.04), (lo-.02,y1-.01,z0),
        (lo+.13,y0+.05,z1+.015), (hi-.03,y0+.075,z1-.015), (hi-.11,y1-.03,z1+.035), (lo+.02,y1,z1)
    ]
    faces = [(3,2,1,0), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)]
    me = bpy.data.meshes.new(name + '_Mesh'); me.from_pydata(verts, [], faces); me.materials.append(material)
    attr = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    keys = ['fragment_b','fragment_a','fragment_c','fragment_b','fragment_a','fragment_c']
    for poly,key in zip(me.polygons,keys):
        for li in poly.loop_indices: attr.data[li].color = COLORS[key]
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.update()
    ob=bpy.data.objects.new(name,me);collection.objects.link(ob);ob.parent=parent
    ob['role']='matching lower-edge fracture fragment; entirely below/outside protected walk strip'
    ob['cut_profile']='derived from shared parent edge profile; two broad fracture planes'
    return ob

# Rebuild only this generated T04 scene when iterating; preserve the original
# default scene and all previously completed production scenes/assets.
previous = bpy.data.scenes.get('WindProduction_T04')
if previous:
    fallback = bpy.data.scenes.get('WindProduction_T02') or bpy.data.scenes.get('Scene')
    if fallback:
        bpy.context.window.scene = fallback
    for ob in list(previous.objects):
        if ob.name.startswith('T04_'):
            bpy.data.objects.remove(ob, do_unlink=True)
    for col in list(previous.collection.children):
        if col.name.startswith('T04_'):
            previous.collection.children.unlink(col)
            bpy.data.collections.remove(col)
    oldworld = previous.world
    bpy.data.scenes.remove(previous, do_unlink=True)
    if oldworld and oldworld.name == 'T04_PreviewWorld' and oldworld.users == 0:
        bpy.data.worlds.remove(oldworld)
    for me in list(bpy.data.meshes):
        if me.name.startswith('T04_') and me.users == 0:
            bpy.data.meshes.remove(me)
    for mat in list(bpy.data.materials):
        if mat.name.startswith('T04_') and mat.users == 0:
            bpy.data.materials.remove(mat)

# A new production scene is isolated from the original default scene and prior assets.
old_scene = bpy.context.scene
scene, preview, fox = new_preview_scene()
export = bpy.data.collections.new('T04_Export')
scene.collection.children.link(export)
stone = make_stone_material()
xnodes = [-2.0,-1.56,-1.02,-.38,.34,1.02,1.58,2.0]
zlevels = [0.0,-.18,-.42,-.70,-1.0]
base_profile = [
    [-1.0]*len(xnodes),
    [-.91,-.93,-.88,-.90,-.89,-.92,-.91,-.92],
    [-.86,-.89,-.82,-.83,-.81,-.86,-.89,-.86],
    [-.82,-.85,-.77,-.76,-.75,-.81,-.86,-.82],
    [-.79,-.82,-.74,-.72,-.73,-.79,-.84,-.80]
]
specs = [('left',-5.4,-1.12),('center',0.0,.12),('right',5.4,1.34)]
roots=[]
for variant, preview_x, damage_x in specs:
    label = variant.title()
    root = bpy.data.objects.new('T04_' + label + '_Edge_Collapse', None)
    export.objects.link(root)
    root.empty_display_type = 'PLAIN_AXES'
    root.location = (preview_x,0,0)
    root['variant'] = variant + ' edge damage'
    root['pivot'] = 'center of flat walking surface; local z=0; 1 m stone body below'
    root['dimensions_blender_xyz_m'] = [4,2,1]
    root['advisor_applied'] = 'full supported walk plane; fixed back and connector ends; 3 broad lower tiers; matched edge fragment'
    body, profile = make_body_mesh(export,stone,'T04_'+label+'_Stone_Body',variant,root,xnodes,zlevels,base_profile)
    fragment = make_fragment(export,stone,'T04_'+label+'_Matching_Fragment',root,damage_x,variant)
    roots.append(root)

scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.view_settings.view_transform = 'AgX'
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.camera.data.type = 'PERSP'
scene.camera.data.sensor_fit = 'VERTICAL'
scene.camera.data.sensor_height = 24

print('T04_CREATED', scene.name, 'variants', len(roots), 'meshes', sum(o.type=='MESH' for o in export.objects), 'source_default_preserved', bpy.data.scenes.get('Scene') is not None, 'fox_action', fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None)
