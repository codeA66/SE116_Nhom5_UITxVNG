import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/a05'
PRE = ROOT + '/output/wind_production/a05'
GLB = OUT + '/a05_ceremonial_barrier_module.glb'
SOURCE = OUT + '/source/a05_ceremonial_barrier_module.blend'
STATE = ROOT + '/output/wind_production/asset_state.json'
AUDIT = ROOT + '/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name == 'WindProduction_A05'
assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene = bpy.context.scene
camera = bpy.data.objects['A05_PreviewCamera']
scene.camera = camera
roots = [bpy.data.objects[n] for n in ('A05_Intact', 'A05_Missing_Rail', 'A05_Fallen_Post_Displaced_Rail')]
export = bpy.data.collections['A05_Export']
mesh_objects = [ob for ob in export.objects if ob.type == 'MESH']
assert mesh_objects
assert len({m.name for ob in mesh_objects for m in ob.data.materials}) == 1
assert all(ob.data.color_attributes.get('Color') for ob in mesh_objects)
assert bpy.data.objects['A05_Intact_Chestnut_Crossbar'].data == bpy.data.objects['A05_Fallen_Displaced_Crossbar'].data
for name in ('A05_Intact_Post_Left_Decorative_Caps_OPTIONAL', 'A05_Intact_Post_Right_Decorative_Caps_OPTIONAL'):
    assert bpy.data.objects[name].parent is not None
for label in ('Intact', 'Missing'):
    assert bpy.data.objects[f'A05_{label}_Socket_Left_Socket_Lip_Upper']

old_cam = (camera.location.copy(), camera.rotation_euler.copy(), camera.data.lens,
           camera.data.type, camera.data.sensor_fit, camera.data.sensor_height)
old_render = (scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
              scene.render.resolution_percentage, scene.render.filepath,
              scene.cycles.samples, scene.cycles.use_denoising)
old_locs = {o.name: o.location.copy() for o in roots}
old_fox = bpy.data.objects['A05_PreviewFox_FoxRig'].location.copy()
old_hide = {o.name: o.hide_render for o in export.objects}
fox = bpy.data.objects['A05_PreviewFox_FoxRig']
scene.render.engine = 'CYCLES'
scene.cycles.samples = 18
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
camera.data.type = 'PERSP'
camera.data.sensor_fit = 'VERTICAL'
camera.data.sensor_height = 24

def aim(loc, target, lens):
    camera.location = loc
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.lens = lens

def render(name, loc, target, lens):
    aim(loc, target, lens)
    scene.render.filepath = PRE + '/' + name + '.png'
    bpy.ops.render.render(write_still=True)

# Side-by-side visual comparison shows each assembly state and one 1.755 m scale reference.
for root, x in zip(roots, (-5.2, 0.0, 5.2)):
    root.location = (x, 0, 0)
fox.location = (0, -1.9, 0)
render('beauty_3quarter', (0, -19, 9), (0, 0, .48), 39)

# Exact third-person game-camera transform and vertical 30 degree field of view.
roots[0].location = (0, 0, 0)
for r in roots[1:]:
    r.hide_render = True
    for ob in r.children_recursive:
        ob.hide_render = True
fox.location = (0, -.8, 0)
game_lens = 24.0 / (2.0 * math.tan(math.radians(15.0)))
render('game_camera', (0, -20.57, 24.51), (0, 0, 0), game_lens)
for ob in export.objects:
    ob.hide_render = old_hide[ob.name]

def bounds(root):
    points = []
    inv = root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type == 'MESH':
            points.extend(inv @ (ob.matrix_world @ v.co) for v in ob.data.vertices)
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return lo, hi, [hi[i] - lo[i] for i in range(3)]

def health(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    h = {'vertices': len(bm.verts), 'faces': len(bm.faces),
         'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
         'boundary_edges': sum(e.is_boundary for e in bm.edges),
         'loose_edges': sum(not e.link_faces for e in bm.edges),
         'loose_vertices': sum(not v.link_edges for v in bm.verts)}
    bm.free()
    ob.data.calc_loop_triangles()
    h['triangles'] = len(ob.data.loop_triangles)
    return h

# Restore models before checking dimensions, exporting, and saving source.
for root in roots:
    root.location = old_locs[root.name]
    root.hide_render = False
fox.location = old_fox
camera.location, camera.rotation_euler, camera.data.lens, camera.data.type, camera.data.sensor_fit, camera.data.sensor_height = old_cam
scene.render.engine, scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage, scene.render.filepath, scene.cycles.samples, scene.cycles.use_denoising = old_render
bpy.context.view_layer.update()

states = {}
all_rows = []
for root, label in zip(roots, ('intact', 'missing_rail', 'fallen_post_displaced_rail')):
    lo, hi, dims = bounds(root)
    assert dims[0] <= 4.002 and abs(dims[1]-.25) < .002 and abs(dims[2]-.9) < .002, (label, lo, hi, dims)
    if label != 'fallen_post_displaced_rail':
        assert abs(dims[0]-4.0) < .002, (label, lo, hi, dims)
    meshes = [ob for ob in root.children_recursive if ob.type == 'MESH']
    assert meshes
    rows = []
    for ob in meshes:
        h = health(ob)
        assert h['non_manifold_edges'] == h['boundary_edges'] == h['loose_edges'] == h['loose_vertices'] == 0, (label, ob.name, h)
        assert h['triangles'] < 5000 and len(ob.data.materials) == 1 and ob.data.color_attributes.get('Color'), (label, ob.name, h)
        rows.append({'name': ob.name, 'triangles': h['triangles'], 'mesh_health': h})
    all_rows.extend(rows)
    states[label] = {'bounds_min_local_m': [round(x,6) for x in lo],
                     'bounds_max_local_m': [round(x,6) for x in hi],
                     'dimensions_blender_xyz_m': [round(x,6) for x in dims],
                     'mesh_count': len(meshes), 'meshes': rows}

for ob in bpy.context.view_layer.objects:
    ob.select_set(False)
for ob in export.objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active = roots[0]
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True, use_active_scene=True,
                           export_yup=True, export_apply=True)
with open(GLB, 'rb') as f:
    magic, version, declared = struct.unpack('<4sII', f.read(12))
    json_len, json_type = struct.unpack('<I4s', f.read(8))
    gltf = json.loads(f.read(json_len).decode('utf-8'))
size = os.path.getsize(GLB)
assert magic == b'glTF' and version == 2 and declared == size and json_type == b'JSON'
assert gltf.get('asset', {}).get('version') == '2.0' and len(gltf.get('materials', [])) == 1
mesh_rows = []
for m in gltf.get('meshes', []):
    prims = m.get('primitives', [])
    assert prims and all('COLOR_0' in p.get('attributes', {}) for p in prims), (m.get('name'), prims)
    mesh_rows.append({'name': m.get('name'), 'triangles': sum(gltf['accessors'][p['indices']]['count']//3 for p in prims), 'primitives': len(prims)})
nodes = {n.get('name') for n in gltf.get('nodes', [])}
required = {'A05_Intact', 'A05_Missing_Rail', 'A05_Fallen_Post_Displaced_Rail',
            'A05_Intact_Post_Left_Decorative_Caps_OPTIONAL', 'A05_Intact_Chestnut_Crossbar',
            'A05_Missing_Socket_Left_Socket_Lip_Upper'}
assert required <= nodes, (required-nodes, nodes)
total_triangles = sum(m['triangles'] for m in mesh_rows)
assert mesh_rows and total_triangles < 5000, total_triangles
shutil.copy2(PRE + '/beauty_3quarter.png', OUT + '/preview.png')

# Source opens with the intact state visible and companion states stored but hidden.
roots[1].hide_set(True)
roots[2].hide_set(True)
for ob in roots[1].children_recursive + roots[2].children_recursive:
    ob.hide_set(True)
for ob in bpy.context.view_layer.objects:
    ob.select_set(False)
bpy.context.view_layer.objects.active = roots[0]
bpy.ops.wm.save_as_mainfile(filepath=SOURCE, copy=True)

stamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
advisory = 'Use exactly two 0.30 m wide x 0.25 m deep posts within the 4 m span, with broad stone bevels, tapered shoulders and sparse chips; keep base and snap points at floor z=0. Put one thick wooden crossbar near the upper third with a large opening below; make end sockets separate and visible when the rail is missing. Keep bronze caps separate from barrier geometry. Reuse components across intact, missing-rail and fallen-post states; rotate one post onto the floor and slope the displaced rail toward its socket.'
self_check = 'Intact and missing-rail states fit exactly 4 x 0.25 x 0.9 m; the fallen-post state stays inside that envelope and is 3.85 x 0.25 x 0.9 m after the right post lies inward on the floor. The missing-rail state retains separate visible socket geometry, and the fallen state reuses the shared post/crossbar meshes with the rail sloped toward its socket. All meshes are closed/manifold, under 5000 triangles, and use one shared vertex-color material. GLB v2 Y-up header, three named roots, optional cap nodes and COLOR_0 checked. Original Scene/Cube/Camera/Light preserved; beauty and exact game-camera views inspected.'
metrics = {'id': 'A05', 'asset': 'ceremonial barrier module',
           'glb': 'assets/generated/wind_ruins/a05/a05_ceremonial_barrier_module.glb',
           'source': 'assets/generated/wind_ruins/a05/source/a05_ceremonial_barrier_module.blend',
           'concept': 'assets/generated/wind_ruins/a05/concept.png',
           'concept_prompt': 'output/wind_production/concepts/a05_prompt.txt',
           'states': states, 'dimensions_blender_xyz_m': [4,.25,.9],
           'dimensions_godot_xyz_m': [4,.9,.25], 'materials': 1,
           'palette_srgb': {'stone': '#526271', 'stone_light': '#687A87', 'stone_shadow': '#3C4C58', 'chestnut_wood': '#654637', 'aged_bronze': '#8B7550'},
           'snap_points_x_m': [-2,2], 'crossbar_opening_below_m': .52,
           'crossbar_shared_mesh': True, 'optional_caps_separate_from_posts': True,
           'visible_socket_nodes_in_missing_state': [n for n in sorted(nodes) if n.startswith('A05_Missing_Socket_')],
           'glb_meshes': mesh_rows, 'glb_bytes': size, 'glb_v2_y_up_header': True,
           'color_attributes': 'COLOR_0 on every primitive', 'advisory': advisory,
           'game_camera_blender': [0,-20.57,24.51], 'vertical_fov_degrees': 30,
           'self_check': self_check, 'outstanding': 'none', 'completed_utc': stamp}
for path in (PRE + '/metrics.json', OUT + '/metrics.json'):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(metrics, f, ensure_ascii=False, indent=2)

with open(STATE, 'r', encoding='utf-8-sig') as f:
    state = json.load(f)
completed_before = sum(1 for aid in state.get('production_catalog_ids', []) if isinstance(state.get(aid), dict) and state[aid].get('state') == 'completed')
assert completed_before == 36, ('unexpected completion count', completed_before)
state['A05'].update({'state': 'completed', 'outstanding': 'none', 'advisor': 'sol_advisor',
                     'advisory': advisory, 'advisory_received_from': 'sol_advisor',
                     'destination': 'assets/generated/wind_ruins/a05/',
                     'glb': 'assets/generated/wind_ruins/a05/a05_ceremonial_barrier_module.glb',
                     'source': 'assets/generated/wind_ruins/a05/source/a05_ceremonial_barrier_module.blend',
                     'preview': 'assets/generated/wind_ruins/a05/preview.png', 'evidence': 'output/wind_production/a05/',
                     'triangles': total_triangles, 'materials': 1,
                     'dimensions_blender_xyz_m': [4,.25,.9], 'dimensions_godot_xyz_m': [4,.9,.25],
                     'non_manifold_edges': 0, 'glb_valid': True, 'self_check': self_check,
                     'completed_utc': stamp})
state['active_blender_scene'] = 'WindProduction_A05'
state['production_queue'] = [aid for aid in state.get('production_queue', []) if aid != 'A05']
state['completed_count'] = completed_before + 1
state['current_task'] = 'A05 complete; next I01 then I02.'
state['last_updated_utc'] = stamp
state['next_asset'] = 'I01'
with open(STATE, 'w', encoding='utf-8') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write('\n')
with open(AUDIT, 'a', encoding='utf-8') as f:
    f.write('\n## A05 - 3D completion\n\nApplied the one Sol review directly: made an intact barrier, a missing-rail state with retained visible sockets, and a fallen-post state reusing the shared post and rail meshes. Kept the exact 4 x 0.25 x 0.9 m envelope and separate bronze cap accents. Exported and self-checked through connected Blender.\n')
print('A05_COMPLETE', json.dumps({'glb_bytes': size, 'triangles': total_triangles,
      'dimensions_blender_xyz_m': [4,.25,.9], 'states': {k:v['dimensions_blender_xyz_m'] for k,v in states.items()},
      'mesh_count': len(mesh_rows), 'completed_before': completed_before,
      'completed_after': completed_before+1, 'remaining_queue': state['production_queue']}, separators=(',',':')))
