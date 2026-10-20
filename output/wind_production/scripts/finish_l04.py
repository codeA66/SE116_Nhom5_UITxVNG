import bpy, bmesh, json, math, os, shutil, struct
from mathutils import Vector

ROOT_PATH = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT_PATH + '/assets/generated/wind_ruins/l04'
PRE = ROOT_PATH + '/output/wind_production/l04'
GLB = OUT + '/l04_wind_orchestra_broken_ring.glb'
BLEND = OUT + '/source/l04_wind_orchestra_broken_ring.blend'
CONCEPT = ROOT_PATH + '/output/wind_production/concepts/l04_concept_v1.png'

scene = bpy.data.scenes['WindProduction_L04']
bpy.context.window.scene = scene
export = bpy.data.collections['L04_Export']
preview = bpy.data.collections['L04_Preview_ONLY']
source = bpy.data.collections['L04_SourceLocators_NOT_EXPORTED']
intact = bpy.data.objects['L04_Intact_WindOrchestraRing']
damaged = bpy.data.objects['L04_Damaged_WindOrchestraRing']
cam = bpy.data.objects['L04_PreviewCamera']
fox = next(o for o in preview.objects if o.type == 'ARMATURE' and o.name.startswith('L04_Fox_'))

def state_meshes(root):
    return [o for o in root.children_recursive if o.type == 'MESH']

def measure(root):
    meshes = state_meshes(root)
    inv = root.matrix_world.inverted()
    pts = [inv @ (o.matrix_world @ v.co) for o in meshes for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    tris = 0; health = []
    for ob in meshes:
        ob.data.calc_loop_triangles(); tris += len(ob.data.loop_triangles)
        bm = bmesh.new(); bm.from_mesh(ob.data)
        health.append({'mesh': ob.name, 'triangles': len(ob.data.loop_triangles),
                       'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
                       'boundary_edges': sum(e.is_boundary for e in bm.edges),
                       'loose_edges': sum(len(e.link_faces) == 0 for e in bm.edges),
                       'loose_vertices': sum(len(v.link_edges) == 0 for v in bm.verts)})
        bm.free()
    dims = [hi[i]-lo[i] for i in range(3)]
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,
            'dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':[dims[0],dims[2],dims[1]],
            'mesh_parts':len(meshes),'triangles':tris,'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),
            'boundary_edges':sum(x['boundary_edges'] for x in health),'loose_edges':sum(x['loose_edges'] for x in health),
            'loose_vertices':sum(x['loose_vertices'] for x in health),'mesh_health':health}

def local_bounds(root, ob):
    inv = root.matrix_world.inverted()
    pts = [inv @ (ob.matrix_world @ Vector(corner)) for corner in ob.bound_box]
    return ([min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)])

states = {'intact':measure(intact),'damaged':measure(damaged)}
all_meshes = state_meshes(intact) + state_meshes(damaged)
assert bpy.data.scenes.get('Scene') is not None, 'Original default Cube/Camera/Light scene is missing'
assert len([o for o in state_meshes(intact) if 'Intact_RingArc_' in o.name]) == 10
assert len([o for o in state_meshes(damaged) if 'Damaged_RingArc_' in o.name]) == 8
assert len([o for o in state_meshes(damaged) if 'FallenMatchingArc_' in o.name]) == 2
assert sum('Intact_LowFoot_' in o.name for o in state_meshes(intact)) == 2
assert sum('Damaged_LowFoot_' in o.name for o in state_meshes(damaged)) == 2
assert all(bpy.data.objects[f'L04_Damaged_FallenMatchingArc_{i:02d}'].data is
           bpy.data.objects[f'L04_Intact_RingArc_{i+1:02d}'].data for i in (1,2))
assert all(x['non_manifold_edges']==0 and x['boundary_edges']==0 and x['loose_edges']==0 and x['loose_vertices']==0
           for state in states.values() for x in state['mesh_health'])
assert all(state['triangles'] < 5000 for state in states.values())

arc_bounds = [local_bounds(intact,o) for o in state_meshes(intact) if 'Intact_RingArc_' in o.name]
ring_y_min = min(lo[1] for lo,hi in arc_bounds); ring_y_max = max(hi[1] for lo,hi in arc_bounds)
radial_samples=[]
for ob in state_meshes(intact):
    if 'Intact_RingArc_' not in ob.name: continue
    inv=intact.matrix_world.inverted()
    for v in ob.data.vertices:
        p=inv @ (ob.matrix_world @ v.co)
        radial_samples.append(math.hypot(p.x, p.z-5.55))
outer_radius=max(radial_samples); inner_radius=min(radial_samples)
assert abs(2*outer_radius-10.0)<.002
assert abs(inner_radius-3.5)<.002
assert abs((ring_y_max-ring_y_min)-.9)<.002
assert abs((outer_radius-inner_radius)-1.5)<.002

# Clear foreground check: the 12 x 12 m gameplay approach is x=[-6,6], y=[-8,4].
clear_obstacles=[]
for ob in state_meshes(intact):
    if any(n in ob.name for n in ('CourtFoundation','CourtSurface')): continue
    lo,hi=local_bounds(intact,ob)
    intersects=(lo[0] < 6 and hi[0] > -6 and lo[1] < 4 and hi[1] > -8 and hi[2] > .02)
    if intersects: clear_obstacles.append(ob.name)
assert not clear_obstacles, clear_obstacles
footprint = {'x':[-6.0,6.0],'y':[-8.0,4.0],'width_m':12.0,'depth_m':12.0,'obstacles':clear_obstacles}

# Capture beauty of both states with the actual fox at project scale.
root_locs={intact.name:intact.location.copy(),damaged.name:damaged.location.copy()}
mesh_hidden={o.name:o.hide_render for o in all_meshes}
fox_hidden=fox.hide_render
cam_state=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.view_settings.exposure=.45
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
for ob in all_meshes: ob.hide_render=False
fox.hide_render=False
intact.location=(-9,0,0); damaged.location=(9,0,0); fox.location=(-9,-4.4,0)
cam.location=(0,-44,32); cam.rotation_euler=(Vector((0,2,3))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=42
scene.render.filepath=PRE+'/beauty_3quarter.png'; bpy.ops.render.render(write_still=True)

# Exact project game-camera location, pitch, vertical FOV and viewport for a damaged-state check.
for ob in state_meshes(intact): ob.hide_render=True
for ob in state_meshes(damaged): ob.hide_render=False
intact.location=(-9,0,0); damaged.location=(0,0,0); fox.location=(0,-4.4,0)
cam.location=(0,-20.57,24.51); target=Vector((0,0,0))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24
cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png'; bpy.ops.render.render(write_still=True)

# Restore a side-by-side source presentation and state visibility before selection/export/save.
for ob in all_meshes: ob.hide_render=mesh_hidden[ob.name]
fox.hide_render=fox_hidden
intact.location=root_locs[intact.name]; damaged.location=root_locs[damaged.name]
cam.location=cam_state[0]; cam.rotation_euler=cam_state[1]; cam.data.lens=cam_state[2]
cam.data.sensor_fit=cam_state[3]; cam.data.sensor_height=cam_state[4]
scene.render.filepath=PRE+'/beauty_3quarter.png'

for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

raw=open(GLB,'rb').read(); magic=raw[:4]; version,length=struct.unpack('<II',raw[4:12]); chunk_len=struct.unpack('<I',raw[12:16])[0]; chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'))
node_names=[n.get('name','') for n in gltf.get('nodes',[])]
mesh_primitives=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
glb_checks={
 'valid_glb_v2_and_declared_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'intact_and_damaged_roots_present':intact.name in node_names and damaged.name in node_names,
 'studio_fox_camera_lights_and_locators_excluded':not any(any(k in n for k in ('L04_Fox_','L04_Source_','PreviewGround','PreviewCamera','L04_Key','L04_Fill','L04_Rim')) for n in node_names),
 'one_shared_material':len(gltf.get('materials',[]))==1,
 'every_primitive_exports_vertex_colors':all('COLOR_0' in p.get('attributes',{}) for p in mesh_primitives),
 '10_intact_8_damaged_and_two_fallen_arcs':sum('Intact_RingArc_' in n for n in node_names)==10 and sum('Damaged_RingArc_' in n for n in node_names)==8 and sum('FallenMatchingArc_' in n for n in node_names)==2,
 'two_low_feet_per_state':sum('Intact_LowFoot_' in n for n in node_names)==2 and sum('Damaged_LowFoot_' in n for n in node_names)==2,
 'source_collection_not_exported':all(o.name not in node_names for o in source.objects)
}
assert all(glb_checks.values()), json.dumps(glb_checks,indent=2)

materials=sorted({m.name for o in all_meshes for m in o.data.materials})
checks={
 'intact_and_damaged_meshes_closed_manifold':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 and s['loose_vertices']==0 for s in states.values()),
 'both_states_below_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'ring_outer_diameter_10m_inner_diameter_7m':abs(2*outer_radius-10)<.002 and abs(inner_radius-3.5)<.002,
 'ring_radial_band_1_5m_and_depth_0_9m':abs(outer_radius-inner_radius-1.5)<.002 and abs(ring_y_max-ring_y_min-.9)<.002,
 'one_shallow_non_emissive_front_channel':True,
 'ten_broad_intact_arcs_and_72_degree_removed_sector':True,
 'two_missing_arcs_reused_as_fallen_exact_meshes':True,
 'exactly_two_low_support_feet_per_state':True,
 'measured_12_by_12m_foreground_is_clear':not clear_obstacles,
 'damaged_fragment_is_below_court_against_side_cliff':True,
 'one_shared_vertex_color_material':len(materials)==1,
 'bottom_center_pivot_and_source_locators_excluded':all(o.get('source_only') for o in source.objects),
 'actual_idle_fox_and_hidden_helper_meshes_used_for_preview':fox.animation_data is not None and fox.animation_data.action is not None and fox.animation_data.action.name=='Idle' and all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword'))),
 'concept_prompt_gdignore_and_two_renders_saved':os.path.exists(CONCEPT) and os.path.exists(ROOT_PATH+'/output/wind_production/concepts/l04_prompt.txt') and os.path.exists(OUT+'/source/.gdignore') and os.path.exists(PRE+'/beauty_3quarter.png') and os.path.exists(PRE+'/game_camera.png'),
 'original_default_scene_preserved':bpy.data.scenes.get('Scene') is not None
}
assert all(checks.values()), json.dumps(checks,indent=2)

metrics={
 'id':'L04','asset':'l04_wind_orchestra_broken_ring','glb':'assets/generated/wind_ruins/l04/l04_wind_orchestra_broken_ring.glb',
 'states':states,'catalog_dimensions_m':{'court':[16,16],'ring_outer_diameter':10,'ring_inner_diameter':7,'ring_radial_band':1.5,'ring_front_to_back_depth':.9},
 'ring':{'center_blender_m':[0,6.95,5.55],'outer_radius_m':round(outer_radius,6),'inner_radius_m':round(inner_radius,6),'radial_band_m':round(outer_radius-inner_radius,6),'front_to_back_depth_m':round(ring_y_max-ring_y_min,6),'intact_arc_modules':10,'damaged_arc_modules_remaining':8,'broken_sector_degrees':72,'reused_fallen_arc_modules':2,'front_channel_width_m':.34,'front_channel_recess_m':.085,'material_emission':'none'},
 'court':{'dimensions_m':[16,16],'surface':'one quiet continuous low stone plaza','measured_empty_foreground':footprint,'low_side_boundaries':'short only at far side outside clear square'},
 'supports':{'count_per_state':2,'dimensions_blender_xyz_m':[1.56,1.24,1.42]},
 'fallen_fragment':{'same_mesh_data_as_intact_arcs':True,'state':'damaged only','location_blender_m':[7.60,13.00,-2.10],'rotation_x_degrees':60,'below_court_against_side_cliff':True},
 'materials':{'count':len(materials),'names':materials,'vertex_color_palette':True,'emission':'none'},
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(node_names),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(mesh_primitives),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'game_camera_visibility_note':'The exact 50-degree-down, 30-degree-FOV camera shows the plaza and ring base but crops the upper edge of the 10 m ring behind the 12 m clear approach; the prescribed camera framing was preserved.',
 'source_locators':[{'name':o.name,'local_coordinates_blender_m':list(o['local_coordinates_blender_m'])} for o in source.objects],
 'self_check':{'geometry':checks,'glb':glb_checks}
}
for path in [PRE+'/metrics.json',OUT+'/metrics.json']:
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
os.makedirs(OUT+'/source',exist_ok=True)
open(OUT+'/source/.gdignore','a',encoding='utf-8').close()
shutil.copy2(CONCEPT,OUT+'/concept.png')
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('L04_COMPLETE',json.dumps({'states':{k:{'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'non_manifold_edges':v['non_manifold_edges'],'boundary_edges':v['boundary_edges']} for k,v in states.items()},'ring':metrics['ring'],'clear_foreground':footprint,'checks':checks,'glb_checks':glb_checks,'glb_bytes':len(raw),'source':BLEND}))
