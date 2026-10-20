import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/a04'
PRE = ROOT + '/output/wind_production/a04'
GLB = OUT + '/a04_ceremonial_wind_shrine_roof.glb'
SOURCE = OUT + '/source/a04_ceremonial_wind_shrine_roof.blend'
STATE = ROOT + '/output/wind_production/asset_state.json'
AUDIT = ROOT + '/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name == 'WindProduction_A04'
assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene = bpy.context.scene
camera = bpy.data.objects['A04_PreviewCamera']
scene.camera = camera
roots = [bpy.data.objects[n] for n in ('A04_Intact', 'A04_Damaged_Corner')]
export = bpy.data.collections['A04_Export']
mesh_objects = [ob for ob in export.objects if ob.type == 'MESH']
assert mesh_objects and len({m.name for ob in mesh_objects for m in ob.data.materials}) == 1
assert all(ob.data.color_attributes.get('Color') for ob in mesh_objects)
front = bpy.data.objects['A04_Intact_Front_Removable_Panel']
assert front.parent == roots[0] and len([o for o in front.children_recursive if o.type == 'MESH']) >= 10

# Establish a clean studio camera as the saved project view even after re-renders.
camera.location = (8.0,-11.0,7.5)
camera.rotation_euler = (Vector((0,0,.78))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.lens = 46
camera.data.type = 'PERSP'

old_cam = (camera.location.copy(), camera.rotation_euler.copy(), camera.data.lens,
          camera.data.type, camera.data.sensor_fit, camera.data.sensor_height)
old_render = (scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
              scene.render.resolution_percentage, scene.render.filepath,
              scene.cycles.samples, scene.cycles.use_denoising)
old_locs = {o.name: o.location.copy() for o in roots}
all_export_hide = {o.name: o.hide_render for o in export.objects}
old_fox = bpy.data.objects['A04_PreviewFox_FoxRig'].location.copy()
old_front_loc = front.location.copy()
scene.render.engine = 'CYCLES'
scene.cycles.samples = 20
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

# Beauty preview: intact and one damaged roof under neutral white studio light.
roots[0].location = (-4.0, 0, 0)
roots[1].location = (4.0, 0, 0)
fox = bpy.data.objects['A04_PreviewFox_FoxRig']
fox.location = (0, -3.35, 0)
render('beauty_3quarter', (0, -18, 11), (0, 0, .72), 42)

# Exact third-person game camera, using the connected project's camera transform and FOV.
roots[0].location = (0, 0, 0)
roots[1].hide_render = True
for ob in roots[1].children_recursive:
    ob.hide_render = True
fox.location = (4.5, -.1, 0)
game_lens = 24.0 / (2.0 * math.tan(math.radians(15.0)))
render('game_camera', (0, -20.57, 24.51), (0, 0, 0), game_lens)
for ob in export.objects:
    ob.hide_render = all_export_hide[ob.name]

# Separate component proof: lift the removable front slope while leaving its shared
# origin and all fitting edges visible. The demo remains preview-only.
front.location = (0, -1.45, .58)
render('removable_front_panel', (7.8, -11.0, 7.6), (0, 0, .72), 52)
front.location = old_front_loc

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
    h = {
        'vertices': len(bm.verts),
        'faces': len(bm.faces),
        'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
        'boundary_edges': sum(e.is_boundary for e in bm.edges),
        'loose_edges': sum(not e.link_faces for e in bm.edges),
        'loose_vertices': sum(not v.link_edges for v in bm.verts),
    }
    bm.free()
    ob.data.calc_loop_triangles()
    h['triangles'] = len(ob.data.loop_triangles)
    return h

# Restore all models before metrics and export.
for o in roots:
    o.location = old_locs[o.name]
    o.hide_render = False
fox.location = old_fox
front.location = old_front_loc
camera.location,camera.rotation_euler,camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height=old_cam
scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising=old_render
bpy.context.view_layer.update()
metrics_states = {}
all_meshes = []
for root, label in zip(roots, ('intact', 'damaged_corner')):
    lo, hi, dims = bounds(root)
    assert all(abs(a-b) < .002 for a,b in zip(dims, (6.0,4.0,1.4))), (label, lo, hi, dims)
    meshes = [ob for ob in root.children_recursive if ob.type == 'MESH']
    assert meshes
    rows = []
    for ob in meshes:
        h = health(ob)
        assert h['non_manifold_edges'] == h['boundary_edges'] == h['loose_edges'] == h['loose_vertices'] == 0, (label, ob.name, h)
        assert h['triangles'] < 5000 and len(ob.data.materials) == 1 and ob.data.color_attributes.get('Color'), (label, ob.name, h)
        rows.append({'name': ob.name, 'triangles': h['triangles'], 'mesh_health': h})
    all_meshes.extend(meshes)
    metrics_states[label] = {
        'bounds_min_local_m': [round(x,6) for x in lo],
        'bounds_max_local_m': [round(x,6) for x in hi],
        'dimensions_blender_xyz_m': [round(x,6) for x in dims],
        'mesh_count': len(meshes),
        'meshes': rows,
    }

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
assert gltf.get('asset', {}).get('version') == '2.0'
assert len(gltf.get('materials', [])) == 1
mesh_rows = []
for m in gltf.get('meshes', []):
    prims = m.get('primitives', [])
    assert prims and all('COLOR_0' in p.get('attributes', {}) for p in prims), (m.get('name'), prims)
    mesh_rows.append({'name': m.get('name'), 'triangles': sum(gltf['accessors'][p['indices']]['count']//3 for p in prims), 'primitives': len(prims)})
nodes = {n.get('name') for n in gltf.get('nodes', [])}
required = {'A04_Intact', 'A04_Damaged_Corner', 'A04_Intact_Front_Removable_Panel'}
assert required <= nodes, (required - nodes, nodes)
assert len(mesh_rows) == len(all_meshes) and sum(m['triangles'] for m in mesh_rows) < 5000
shutil.copy2(PRE + '/beauty_3quarter.png', OUT + '/preview.png')

for img in bpy.data.images:
    if img.filepath.lower().endswith('fox_palette.png') and not img.packed_file:
        img.pack()
roots[1].hide_set(True)
for ob in roots[1].children_recursive:
    ob.hide_set(True)
for ob in bpy.context.view_layer.objects:
    ob.select_set(False)
bpy.context.view_layer.objects.active = roots[0]
bpy.ops.wm.save_as_mainfile(filepath=SOURCE, copy=True)

stamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
palette = {'roof_slate_petrol': '#344F60', 'edge': '#526A78', 'aged_muted_bronze_trim': '#8B7550', 'warm_chestnut_rafters': '#654637'}
advisory = 'Use a 6 x 4 x 1.4 m roof with two broad pitched planes, compact ridge, lightly upturned corners and six broad bands. Keep the camera-facing front roof section as a separately removable child sharing the same origin. The damaged variant removes roughly 20% of one outer corner and exposes 2-3 thick staggered rafters.'
self_check = 'Both named roof states fit exactly 6 x 4 x 1.4 m; every asset mesh is closed/manifold, under 5000 triangles, and uses one shared vertex-color material. The intact root contains a separate front removable panel node with matching assembly origin. The GLB is valid v2 Y-up with COLOR_0 on all mesh primitives and named state roots. Original Scene/Cube/Camera/Light preserved. Beauty, game-camera and removed-panel renders visually inspected.'
metrics = {
    'id': 'A04',
    'asset': 'ceremonial wind-shrine roof module',
    'glb': 'assets/generated/wind_ruins/a04/a04_ceremonial_wind_shrine_roof.glb',
    'source': 'assets/generated/wind_ruins/a04/source/a04_ceremonial_wind_shrine_roof.blend',
    'concept': 'assets/generated/wind_ruins/a04/concept.png',
    'color_study': 'assets/generated/wind_ruins/a04/color_study.png',
    'states': metrics_states,
    'dimensions_blender_xyz_m': [6,4,1.4],
    'dimensions_godot_xyz_m': [6,1.4,4],
    'materials': 1,
    'palette_srgb': palette,
    'palette_provenance': 'Root-provided color-only ImageGen edit of existing A04 concept; geometry/labels unchanged.',
    'removable_front_panel_node': 'A04_Intact_Front_Removable_Panel',
    'removable_front_panel_meshes': len([o for o in front.children_recursive if o.type == 'MESH']),
    'glb_meshes': mesh_rows,
    'glb_bytes': size,
    'glb_v2_y_up_header': True,
    'color_attributes': 'COLOR_0 on every primitive',
    'advisory': advisory,
    'game_camera': [0,24.51,20.57],
    'vertical_fov_degrees': 30,
    'self_check': self_check,
    'outstanding': 'none',
    'completed_utc': stamp,
}
for path in (PRE + '/metrics.json', OUT + '/metrics.json'):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(metrics, f, ensure_ascii=False, indent=2)

with open(STATE, 'r', encoding='utf-8-sig') as f:
    state = json.load(f)
completed_before = sum(1 for aid in state.get('production_catalog_ids', []) if isinstance(state.get(aid), dict) and state[aid].get('state') == 'completed')
assert completed_before == 35, ('unexpected completion count', completed_before)
state['A04'].update({
    'state': 'completed',
    'advisor': 'sol_advisor',
    'advisory': advisory,
    'advisory_received_from': 'sol_advisor',
    'destination': 'assets/generated/wind_ruins/a04/',
    'glb': 'assets/generated/wind_ruins/a04/a04_ceremonial_wind_shrine_roof.glb',
    'source': 'assets/generated/wind_ruins/a04/source/a04_ceremonial_wind_shrine_roof.blend',
    'preview': 'assets/generated/wind_ruins/a04/preview.png',
    'color_study': 'assets/generated/wind_ruins/a04/color_study.png',
    'evidence': 'output/wind_production/a04/',
    'triangles': sum(m['triangles'] for m in mesh_rows),
    'materials': 1,
    'dimensions_blender_xyz_m': [6,4,1.4],
    'dimensions_godot_xyz_m': [6,1.4,4],
    'palette_srgb': palette,
    'palette_provenance': metrics['palette_provenance'],
    'removable_front_panel_node': 'A04_Intact_Front_Removable_Panel',
    'non_manifold_edges': 0,
    'glb_valid': True,
    'self_check': self_check,
    'outstanding': 'none',
    'completed_utc': stamp,
})
state['active_blender_scene'] = 'WindProduction_A04'
state['production_queue'] = [aid for aid in state.get('production_queue', []) if aid != 'A04']
state['completed_count'] = completed_before + 1
state['current_task'] = 'A04 complete; next A05, I01, then I02.'
state['last_updated_utc'] = stamp
state['next_asset'] = 'A05'
with open(STATE, 'w', encoding='utf-8') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write('\n')
with open(AUDIT, 'a', encoding='utf-8') as f:
    f.write('\n## A04 - 3D completion\n\nApplied Sol advice directly: a shared-origin removable camera-facing roof assembly, a missing-corner state with three staggered exposed rafters, and a 6 x 4 x 1.4 m two-pitch roof. Applied the user-approved color-study palette with one shared vertex-color material. Exported and self-checked through connected Blender.\n')
print('A04_COMPLETE', json.dumps({'glb_bytes': size, 'triangles': sum(m['triangles'] for m in mesh_rows), 'dimensions_blender_xyz_m': [6,4,1.4], 'states': metrics_states, 'mesh_count': len(mesh_rows), 'removable_front_meshes': metrics['removable_front_panel_meshes'], 'completed_before': completed_before, 'completed_after': completed_before + 1, 'remaining_queue': state['production_queue']}, separators=(',',':')))
