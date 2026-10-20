import bpy, bmesh, math, os, shutil
from mathutils import Matrix, Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/a04'
PRE = ROOT + '/output/wind_production/a04'
CONCEPT = ROOT + '/output/wind_production/concepts/a04_concept_v1.png'
COLOR_STUDY = ROOT + '/output/wind_production/concepts/a04_color_study_v1.png'
PROMPT = ROOT + '/output/wind_production/concepts/a04_prompt.txt'
COLOR_PROMPT = ROOT + '/output/wind_production/concepts/a04_color_study_v1_prompt.txt'
assert all(os.path.isfile(p) for p in (CONCEPT, COLOR_STUDY, PROMPT, COLOR_PROMPT))
assert not os.path.exists(OUT), 'Refusing to overwrite existing A04 outputs'
assert bpy.context.scene.name == 'WindProduction_A03', bpy.context.scene.name
assert 'Scene' in bpy.data.scenes and all(n in bpy.data.objects for n in ('Cube', 'Camera', 'Light'))
os.makedirs(OUT + '/source', exist_ok=False)
os.makedirs(PRE, exist_ok=True)
open(OUT + '/source/.gdignore', 'w', encoding='utf-8').close()
shutil.copy2(CONCEPT, OUT + '/concept.png')
shutil.copy2(COLOR_STUDY, OUT + '/color_study.png')
shutil.copy2(PROMPT, PRE + '/concept_prompt.txt')
shutil.copy2(COLOR_PROMPT, PRE + '/color_study_prompt.txt')

old = bpy.data.scenes['WindProduction_A03']
scene = bpy.data.scenes.new('WindProduction_A04')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.world = old.world.copy() if old.world else bpy.data.worlds.new('A04_PreviewWorld')
scene.world.name = 'A04_PreviewWorld'
scene.render.engine = old.render.engine
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.render.film_transparent = False
preview = bpy.data.collections.new('A04_Preview_ONLY')
export = bpy.data.collections.new('A04_Export')
scene.collection.children.link(preview)
scene.collection.children.link(export)

for src_name, name in [('A03_PreviewCamera', 'A04_PreviewCamera'),
                       ('A03_Preview_Key', 'A04_Preview_Key'),
                       ('A03_Preview_Fill', 'A04_Preview_Fill'),
                       ('A03_Preview_Rim', 'A04_Preview_Rim')]:
    src = bpy.data.objects[src_name]
    ob = src.copy()
    if src.data:
        ob.data = src.data.copy()
    ob.name = name
    preview.objects.link(ob)
    ob.matrix_world = src.matrix_world.copy()
    if ob.type == 'CAMERA':
        scene.camera = ob

src_rig = bpy.data.objects['A03_PreviewFox_FoxRig']
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
    ob.name = 'A04_PreviewFox_' + src.name.replace('A03_PreviewFox_', '')
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
if fox.animation_data:
    fox.animation_data_clear()
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create()
    fox.animation_data.action = src_rig.animation_data.action
fox.location = (0, -0.8, 0)
scene.frame_set(1)

def lin(h):
    q = [int(h[i:i+2], 16) / 255 for i in (1, 3, 5)]
    q = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in q]
    return tuple(q) + (1,)

PALETTE = {
    'roof': lin('#344F60'),
    'edge': lin('#526A78'),
    'bronze': lin('#8B7550'),
    'chestnut': lin('#654637'),
}
mat = bpy.data.materials.new('A04_Shared_Slate_Bronze_Chestnut_VertexColor')
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
bsdf.inputs['Roughness'].default_value = .78
attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
attr.layer_name = 'Color'
mat.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])

ground_mat = bpy.data.materials.new('A04_Preview_Neutral_Gray_Ground')
ground_mat.use_nodes = True
ground_bsdf = next(n for n in ground_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
ground_bsdf.inputs['Base Color'].default_value = lin('#7C7E7F')
ground_bsdf.inputs['Roughness'].default_value = .88
ground_mesh = bpy.data.meshes.new('A04_PreviewGround_Mesh')
ground_mesh.from_pydata([(-60, -60, -.05), (60, -60, -.05), (60, 60, -.05), (-60, 60, -.05)], [], [(0, 1, 2, 3)])
ground_mesh.materials.append(ground_mat)
ground = bpy.data.objects.new('A04_PreviewGround', ground_mesh)
preview.objects.link(ground)

def assign_color(mesh, tone):
    mesh.update()
    col = mesh.color_attributes.get('Color') or mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    color = PALETTE[tone]
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            col.data[li].color = color

def box(name, center, dims, tone, parent, rot=(0, 0, 0), bevel=.018):
    # All asset meshes are closed, bevelled, broad-faced low-poly solids.
    me = bpy.data.meshes.new(name + '_Mesh')
    hx, hy, hz = (d / 2 for d in dims)
    verts = [(-hx,-hy,-hz),(hx,-hy,-hz),(hx,hy,-hz),(-hx,hy,-hz),
             (-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me.from_pydata(verts, [], faces)
    me.materials.append(mat)
    me.update()
    ob = bpy.data.objects.new(name, me)
    export.objects.link(ob)
    ob.location = center
    ob.rotation_euler = rot
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    if bevel > 0:
        mod = ob.modifiers.new('Broad_Edge_Bevel', 'BEVEL')
        mod.width = min(bevel, min(dims) * .2)
        mod.segments = 1
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(25)
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.select_set(False)
    assign_color(ob.data, tone)
    return ob

def root(name):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = 'PLAIN_AXES'
    ob.empty_display_size = .3
    export.objects.link(ob)
    return ob

def attach(ob, parent):
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    return ob

THETA = math.atan2(.92, 2.0)
SLOPE = math.sqrt(2.0**2 + .92**2)
BAND = SLOPE / 5.0
RIDGE = 1.30

def make_roof(parent, prefix, damaged=False, exploded_offset=0.0):
    front = bpy.data.objects.new(prefix + '_Front_Removable_Panel', None)
    front.empty_display_type = 'PLAIN_AXES'
    front.empty_display_size = .18
    export.objects.link(front)
    front.parent = parent
    front.matrix_parent_inverse = Matrix.Identity(4)
    # Five wide, lightly bevelled slate courses on each pitch. The negative-Y half
    # is a separately removable node, with a shared root origin and matching seams.
    for side in (-1, 1):
        rot = (-THETA, 0, 0) if side > 0 else (-THETA, 0, math.pi)
        for band in range(5):
            dist = (band + .5) * BAND
            y = side * dist * math.cos(THETA)
            z = RIDGE - dist * math.sin(THETA)
            xlo, xhi = -3.0, 3.0
            if damaged and side < 0 and band == 3:
                xhi = 1.55
            elif damaged and side < 0 and band == 4:
                xhi = .30
            if xhi - xlo < .2:
                continue
            center = ((xlo + xhi) / 2, y, z)
            dims = (xhi - xlo, BAND - .050, .075)
            name = f'{prefix}_Slope_{"Front" if side < 0 else "Rear"}_Band_{band+1:02d}'
            ob = box(name, center, dims, 'roof', parent, rot, 0)
            if side < 0:
                ob.parent = front
                ob.matrix_parent_inverse = Matrix.Identity(4)

    # Muted slate-blue edge rails stay distinct from the broad roof fields.
    for side in (-1, 1):
        eave_z = RIDGE - 2.0 * math.sin(THETA)
        eave_y = side * 1.92
        length = 6.0
        if damaged and side < 0:
            length = 3.3
        center_x = (3.0 - length / 2) if damaged and side < 0 else 0.0
        eave = box(f'{prefix}_Eave_Rail_{side:+d}', (center_x, eave_y, eave_z),
                   (length, .16, .16), 'edge', parent, (0,0,0), 0)
        if side < 0:
            eave.parent = front
            eave.matrix_parent_inverse = Matrix.Identity(4)

    # Compact ridge cap, no stacked ornaments.
    box(prefix + '_Continuous_Ridge_Cap', (0,0,RIDGE+.045), (5.88,.26,.11), 'edge', parent, (0,0,0), 0)

    # A low open tie-frame establishes the catalog support plane at z=0 and
    # keeps a large clear void beneath the standalone roof module.
    for side in (-1, 0, 1):
        y = side * 1.56
        tie = box(f'{prefix}_Underside_Tie_Beam_{side:+d}', (0,y,.08), (5.8,.14,.16), 'chestnut', parent, (0,0,0), 0)
        if side < 0:
            tie.parent = front
            tie.matrix_parent_inverse = Matrix.Identity(4)

    # Four restrained bronze corner caps and subtly lifted eave tips; one
    # front-corner pair is absent in the damaged version.
    for sx in (-1, 1):
        for sy in (-1, 1):
            if damaged and (sx, sy) == (1, -1):
                continue
            x = sx * 2.82
            y = sy * 1.84
            z = RIDGE - 1.84 * math.sin(THETA) + .055
            cap = box(f'{prefix}_Corner_Cap_{sx:+d}_{sy:+d}', (x,y,z), (.34,.30,.20), 'bronze', parent, (0,0,0), .035)
            if sy < 0:
                cap.parent = front
                cap.matrix_parent_inverse = Matrix.Identity(4)
            tip = box(f'{prefix}_Upturned_Eave_Tip_{sx:+d}_{sy:+d}',
                      (sx*2.68, sy*1.92, RIDGE-2.0*math.sin(THETA)+.075),
                      (.60,.14,.14), 'edge', parent, (0,-sx*.20,0), 0)
            if sy < 0:
                tip.parent = front
                tip.matrix_parent_inverse = Matrix.Identity(4)

    # Three broad timber rafters run under each slope. In the broken state, three
    # staggered rafters terminate under the missing corner and remain exposed.
    for side in (-1, 1):
        for idx, x in enumerate((-2.0, 0.0, 2.0)):
            if damaged and side < 0:
                continue
            rot = (-THETA, 0, 0) if side > 0 else (-THETA, 0, math.pi)
            rafter_len = SLOPE - .08
            center = (x, side * rafter_len * .5 * math.cos(THETA), RIDGE - rafter_len * .5 * math.sin(THETA) - .14)
            ob = box(f'{prefix}_Under_Rafter_{side:+d}_{idx+1}', center, (.18,rafter_len,.20), 'chestnut', parent, rot, .026)
            if side < 0:
                ob.parent = front
                ob.matrix_parent_inverse = Matrix.Identity(4)
    if damaged:
        for idx, (x, length) in enumerate(((1.00,1.42),(1.72,1.62),(2.48,1.83)), 1):
            center = (x, -length*.5*math.cos(THETA), RIDGE-length*.5*math.sin(THETA)-.13)
            box(f'{prefix}_Exposed_Broken_Rafter_{idx}', center, (.20,length,.21), 'chestnut', parent, (-THETA,0,math.pi), .025)
    return front

intact = root('A04_Intact')
make_roof(intact, 'A04_Intact')
damaged = root('A04_Damaged_Corner')
make_roof(damaged, 'A04_Damaged', damaged=True)

# A non-exported alignment guide records the removable front panel fit.
locator = bpy.data.objects.new('A04_Source_Assembly_Notes', None)
locator.empty_display_type = 'CUBE'
locator.empty_display_size = .12
locator.location = (0,0,0)
locator['pivot'] = 'center of footprint on lower support plane; shared by all states'
locator['front_removable_node'] = 'A04_Intact/A04_Intact_Front_Removable_Panel'
locator['catalog_envelope_m_blender_xyz'] = '6.0 x 4.0 x 1.4'
locator['palette_provenance'] = 'user-approved A04 color-only ImageGen study: slate #344F60, edge #526A78, bronze #8B7550, rafter #654637'
preview.objects.link(locator)

# Keep renders in neutral studio light so the chosen colors stay readable.
world_bg = next((n for n in scene.world.node_tree.nodes if n.type == 'BACKGROUND'), None) if scene.world and scene.world.use_nodes else None
if world_bg:
    world_bg.inputs['Color'].default_value = (0.8,0.8,0.8,1)
    world_bg.inputs['Strength'].default_value = .45
camera = bpy.data.objects['A04_PreviewCamera']
camera.location = (8.0,-11.0,7.5)
camera.rotation_euler = (Vector((0,0,.78))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.lens = 46
camera.data.type = 'PERSP'
for light_name in ('A04_Preview_Key','A04_Preview_Fill','A04_Preview_Rim'):
    light = bpy.data.objects[light_name]
    light.data.color = (1.0, .98, .94)
    light.data.energy *= .44
    light.data.color = (1.0,1.0,1.0)
    light.data.use_shadow = True
scene.render.engine = 'CYCLES'
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
for ob in bpy.context.view_layer.objects:
    ob.select_set(False)
bpy.context.view_layer.objects.active = intact
print('A04_BUILD_OK', scene.name, 'roots', intact.name, damaged.name, 'parts', len(export.objects), 'fox_idle', getattr(getattr(fox.animation_data,'action',None),'name',None), 'palette', {k: tuple(round(v,4) for v in c[:3]) for k,c in PALETTE.items()}, 'original_scene_preserved', bpy.data.scenes['Scene'].name)
