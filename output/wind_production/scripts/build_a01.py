import bpy, math
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/a01'
PRE = ROOT + '/output/wind_production/a01'

def linear(hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb) + (1.0,)

def material_a01():
    mat = bpy.data.materials.new('A01_Stone_SharedPalette')
    mat.use_nodes = True
    mat.diffuse_color = linear('#686966')
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bsdf.inputs['Roughness'].default_value = 0.9
    attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Color'
    mat.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

COLORS = {
    'stone': linear('#686966'),
    'light': linear('#747570'),
    'shade': linear('#5B5C59'),
    'band': linear('#50514F'),
    'fracture': linear('#858681'),
    'fracture_shadow': linear('#70716D'),
}

def make_mesh(collection, name, verts, faces, face_colors, mat, parent):
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    obj.parent = parent
    me.materials.append(mat)
    color_attr = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, color_key in zip(me.polygons, face_colors):
        color = COLORS[color_key]
        for loop_index in poly.loop_indices:
            color_attr.data[loop_index].color = color
    return obj

def ring_vertices(z, rx, ry, n=8, angle_offset=math.pi/8):
    return [(rx * math.cos(angle_offset + i * 2*math.pi/n),
             ry * math.sin(angle_offset + i * 2*math.pi/n), z) for i in range(n)]

def loft(collection, name, rings, mat, parent, n=8, bottom='shade', top='light', alternating=True):
    verts = []
    for z, rx, ry in rings:
        verts.extend(ring_vertices(z, rx, ry, n))
    faces = [tuple(reversed(range(n)))]
    colors = [bottom]
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i, k*n+(i+1)%n, (k+1)*n+(i+1)%n, (k+1)*n+i))
            colors.append(('stone','light','stone','shade')[i%4] if alternating else 'stone')
    faces.append(tuple((len(rings)-1)*n+i for i in range(n)))
    colors.append(top)
    return make_mesh(collection, name, verts, faces, colors, mat, parent)

def cut_ring(center_z, radius, n=8):
    # One shared irregular fracture boundary; both broken halves use these exact points.
    offsets = [0.000, 0.010, -0.006, 0.014, -0.012, 0.008, -0.010, 0.000]
    out = []
    slope_x, slope_y = math.tan(math.radians(25))*0.8, math.tan(math.radians(25))*0.6
    for i, (x, y, _) in enumerate(ring_vertices(center_z, radius, radius, n)):
        out.append((x, y, center_z + slope_x*x + slope_y*y + offsets[i]))
    return out

def shaft_piece(collection, name, rings, mat, parent, cut_bottom=False, cut_top=False):
    n = 8
    verts = []
    for z, radius in rings[:-1]:
        verts.extend(ring_vertices(z, radius, radius, n))
    if cut_top:
        end_radius = rings[-1][1]
        verts.extend(cut_ring(rings[-1][0], end_radius, n))
    elif cut_bottom:
        verts.extend(ring_vertices(rings[-1][0], rings[-1][1], rings[-1][1], n))
    else:
        verts.extend(ring_vertices(rings[-1][0], rings[-1][1], rings[-1][1], n))

    faces, colors = [], []
    if not cut_bottom:
        faces.append(tuple(reversed(range(n))))
        colors.append('shade')
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i, k*n+(i+1)%n, (k+1)*n+(i+1)%n, (k+1)*n+i))
            colors.append(('stone','light','stone','shade')[i%4])
    if cut_top:
        base = (len(rings)-1)*n
        center = sum(verts[base+i][0] for i in range(n))/n, sum(verts[base+i][1] for i in range(n))/n, rings[-1][0]
        center_index = len(verts)
        verts.append(center)
        # Four broad fracture planes keep the break legible from the game camera.
        for i in range(0, n, 2):
            faces.append((center_index, base+i, base+(i+1)%n, base+(i+2)%n))
            colors.append('fracture' if i in (0,4) else 'fracture_shadow')
    elif not cut_bottom:
        faces.append(tuple((len(rings)-1)*n+i for i in range(n)))
        colors.append('light')
    if cut_bottom:
        base = 0
        center = sum(verts[base+i][0] for i in range(n))/n, sum(verts[base+i][1] for i in range(n))/n, rings[0][0]
        center_index = len(verts)
        verts.append(center)
        for i in range(0, n, 2):
            faces.append((center_index, base+(i+2)%n, base+(i+1)%n, base+i))
            colors.append('fracture' if i in (0,4) else 'fracture_shadow')
    return make_mesh(collection, name, verts, faces, colors, mat, parent)

def root(collection, name, location, description):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = location
    obj.empty_display_type = 'PLAIN_AXES'
    obj['pivot'] = 'bottom center at ground' if name != 'A01_Fallen_UpperPiece' else 'ground contact at horizontal midpoint'
    obj['design'] = description
    return obj

def build_base(collection, name, mat, parent):
    loft(collection, name+'_FootPlinth', [(0.00,.405,.405),(.045,.433,.433),(.15,.433,.433),(.19,.405,.405)], mat, parent, bottom='shade', top='light')
    loft(collection, name+'_Pedestal', [(.15,.398,.398),(.25,.376,.376),(.65,.350,.350),(.73,.315,.315)], mat, parent, bottom='shade', top='stone')
    loft(collection, name+'_BaseShoulder', [(.66,.328,.328),(.75,.285,.285),(.80,.245,.245)], mat, parent, bottom='shade', top='stone')

def shaft_r(z):
    return .244 - (z-.80) * (.028/2.48)

def build_full_column(collection, mat, parent):
    build_base(collection, 'A01_Intact', mat, parent)
    loft(collection, 'A01_Intact_BaseCollar', [(.78,.244,.244),(.82,.258,.258),(.91,.258,.258),(.96,.229,.229)], mat, parent, bottom='shade', top='light')
    shaft_piece(collection, 'A01_Intact_OctagonalShaft', [(.80,shaft_r(.80)),(.95,shaft_r(.95)),(1.35,shaft_r(1.35)),(2.20,shaft_r(2.20)),(3.12,shaft_r(3.12)),(3.28,shaft_r(3.28))], mat, parent)
    loft(collection, 'A01_Intact_UpperCollar', [(3.13,.221,.221),(3.18,.238,.238),(3.27,.238,.238),(3.32,.207,.207)], mat, parent, bottom='shade', top='light')
    loft(collection, 'A01_Intact_FlaredCapital', [(3.24,.205,.205),(3.39,.232,.232),(3.56,.275,.275),(3.78,.365,.365),(3.90,.379,.379),(4.08,.379,.379),(4.20,.350,.350)], mat, parent, bottom='shade', top='light')

def build_broken_stump(collection, mat, parent):
    build_base(collection, 'A01_Broken', mat, parent)
    loft(collection, 'A01_Broken_BaseCollar', [(.78,.244,.244),(.82,.258,.258),(.91,.258,.258),(.96,.229,.229)], mat, parent, bottom='shade', top='light')
    shaft_piece(collection, 'A01_Broken_StumpShaft', [(.80,shaft_r(.80)),(.95,shaft_r(.95)),(1.25,shaft_r(1.25)),(1.60,shaft_r(1.60))], mat, parent, cut_top=True)

def build_upper_piece(collection, mat, parent):
    # Transform the exact intact upper geometry onto its side, centered over a ground-contact pivot.
    p = root(collection, 'A01_Fallen_UpperPiece', (2.15,2.70,0.0), 'Same shaft and 25-degree fracture surface as the broken stump; laid beside it.')
    p.parent = parent
    cut_z = 1.60
    center_x = (4.20-cut_z)/2
    def point(x, y, z):
        return (z-cut_z-center_x, y, .40-x)
    rings = [ (cut_z, shaft_r(cut_z)), (2.15,shaft_r(2.15)), (3.12,shaft_r(3.12)), (3.28,shaft_r(3.28)) ]
    # Build a detached upper shaft section from the same cut ring; transform all vertices into its display pose.
    n=8; verts=[]
    verts.extend(point(x,y,z) for x,y,z in cut_ring(cut_z, shaft_r(cut_z), n))
    for z,r in rings[1:]:
        verts.extend(point(x,y,z) for x,y,z in ring_vertices(z,r,r,n))
    faces=[]; colors=[]
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
            colors.append(('stone','light','stone','shade')[i%4])
    faces.append(tuple((len(rings)-1)*n+i for i in range(n)));colors.append('shade')
    # Upper broken cap mirrors the stump boundary and is closed with four broad planes.
    base=0; center=(sum(verts[i][0] for i in range(n))/n,sum(verts[i][1] for i in range(n))/n,sum(verts[i][2] for i in range(n))/n)
    ci=len(verts);verts.append(center)
    for i in range(0,n,2):faces.append((ci,(i+2)%n,(i+1)%n,i));colors.append('fracture' if i in (0,4) else 'fracture_shadow')
    make_mesh(collection,'A01_Fallen_Upper_BrokenShaft',verts,faces,colors,mat,p)
    # Capital dimensions and planes match the intact column; all vertices receive the same pose transform.
    capital_rings=[(3.24,.205,.205),(3.39,.232,.232),(3.56,.275,.275),(3.78,.365,.365),(3.90,.379,.379),(4.08,.379,.379),(4.20,.350,.350)]
    verts=[]
    for z,rx,ry in capital_rings:
        verts.extend(point(x,y,z) for x,y,z in ring_vertices(z,rx,ry,n))
    faces=[tuple(reversed(range(n)))];colors=['shade']
    for k in range(len(capital_rings)-1):
        for i in range(n):
            faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i));colors.append(('stone','light','stone','shade')[i%4])
    faces.append(tuple((len(capital_rings)-1)*n+i for i in range(n)));colors.append('light')
    make_mesh(collection,'A01_Fallen_Upper_FlaredCapital',verts,faces,colors,mat,p)
    loft(collection, 'A01_Fallen_Upper_Collar', [(3.13,.221,.221),(3.18,.238,.238),(3.27,.238,.238),(3.32,.207,.207)], mat, p, bottom='shade', top='light')
    # The collar loft above is upright; replace its mesh with the same side pose.
    collar=bpy.data.objects['A01_Fallen_Upper_Collar']
    for v in collar.data.vertices:
        v.co = point(v.co.x, v.co.y, v.co.z)

def setup_preview_stage(scene):
    source=bpy.data.collections['F01_Preview_ONLY']
    preview=bpy.data.collections.get('A01_Preview_ONLY') or bpy.data.collections.new('A01_Preview_ONLY')
    if preview.name not in scene.collection.children:
        scene.collection.children.link(preview)
    if source.name in scene.collection.children:
        scene.collection.children.unlink(source)
    for name in ('F01_PreviewCamera','Preview_Key','Preview_Fill','Preview_Rim'):
        obj=bpy.data.objects[name]
        if obj.name not in preview.objects: preview.objects.link(obj)
    fox=bpy.data.objects['FoxRig']
    def link_fox(obj):
        if obj.name not in ('Icosphere','Sword') and obj.name not in preview.objects:
            preview.objects.link(obj)
        for child in obj.children: link_fox(child)
    link_fox(fox)
    floor_mesh=bpy.data.meshes.new('A01_PreviewFloor_Mesh')
    floor_mesh.from_pydata([(-250,-250,-.012),(250,-250,-.012),(250,250,-.012),(-250,250,-.012)],[],[(0,1,2,3)])
    floor_mesh.materials.append(bpy.data.materials['Preview_Ground'])
    floor=bpy.data.objects.new('A01_PreviewFloor',floor_mesh)
    preview.objects.link(floor)
    scene.world=bpy.data.worlds.get('A01_PreviewWorld') or bpy.data.worlds['WindPreviewWorld'].copy()
    scene.world.name='A01_PreviewWorld'
    scene.camera=bpy.data.objects['F01_PreviewCamera']
    return preview

def setup_scene():
    old_scene=bpy.context.scene
    scene=bpy.data.scenes.new('WindProduction_A01')
    bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    preview=setup_preview_stage(scene)
    export=bpy.data.collections.new('A01_Export');scene.collection.children.link(export)
    mat=material_a01()
    intact=root(export,'A01_Intact_Column',(-4.10,0,0),'0.8 x 0.8 x 4.2 m; octagonal base and shaft; flared 0.7 m ceremonial capital.')
    broken=root(export,'A01_Broken_Column',(-1.10,0,0),'1.7 m stump plus matching detached upper section; 25-degree break with four broad planes.')
    build_full_column(export,mat,intact)
    build_broken_stump(export,mat,broken)
    build_upper_piece(export,mat,broken)
    return scene,export,intact,broken,old_scene

scene, asset, intact_root, broken_root, previous_scene = setup_scene()
print('A01_CREATED', scene.name, 'parts', len(asset.objects), 'triangles', sum((len(o.data.loop_triangles) if o.type=='MESH' else 0) for o in asset.objects))
