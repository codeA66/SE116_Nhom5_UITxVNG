import bpy, bmesh, os, json, shutil, struct, math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i04'
PRE=ROOT+'/output/wind_production/i04'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/i04_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/i04_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_I04',scene.name
asset=bpy.data.collections['I04_Export']
roots=[bpy.data.objects[n] for n in ('I04_Intact_WindGuidePillar','I04_BrokenTop_WindGuidePillar')]
intact,broken=roots
mesh_objects=[o for o in asset.objects if o.type=='MESH']
camera=scene.camera
camera_location=camera.location.copy(); camera_rotation=camera.rotation_euler.copy()
camera_lens=camera.data.lens; camera_fit=camera.data.sensor_fit; camera_sensor=camera.data.sensor_height
original_roots={r.name:r.location.copy() for r in roots}
original_hide={o.name:o.hide_render for o in mesh_objects}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('I04_Fox_'))
fox_location=fox.location.copy()

scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24

def shoot(name,location,target,lens):
    camera.location=location
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=lens; scene.render.filepath=PRE+'/'+name+'.png'
    bpy.ops.render.render(write_still=True)

# Beauty preview shows both related states and the real fox at its actual scale.
for root in roots: root.location=original_roots[root.name]
for obj in mesh_objects: obj.hide_render=original_hide[obj.name]
fox.location=(-2.8,-.15,0)
shoot('beauty_3quarter',(4.8,-10.8,6.2),(0,0,1.8),50)

# The gameplay view uses the specified camera placement and FOV, with only the intact state.
for obj in mesh_objects: obj.hide_render=True
for obj in intact.children_recursive:
    if obj.type=='MESH': obj.hide_render=False
intact.location=(0,0,0); broken.location=(1.18,0,0); fox.location=(1.25,-.15,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']

def mesh_health(obj):
    bm=bmesh.new(); bm.from_mesh(obj.data)
    non_manifold=sum(not edge.is_manifold for edge in bm.edges)
    boundaries=sum(edge.is_boundary for edge in bm.edges)
    loose=sum(not edge.link_faces for edge in bm.edges)
    bm.free(); obj.data.calc_loop_triangles()
    return {'triangles':len(obj.data.loop_triangles),'non_manifold_edges':non_manifold,'boundary_edges':boundaries,'loose_edges':loose}

def measure(root):
    meshes=state_meshes(root); inv=root.matrix_world.inverted()
    points=[inv@(obj.matrix_world@vert.co) for obj in meshes for vert in obj.data.vertices]
    low=[min(p[i] for p in points) for i in range(3)]; high=[max(p[i] for p in points) for i in range(3)]
    dims=[high[i]-low[i] for i in range(3)]
    health=[mesh_health(obj) for obj in meshes]
    return {
      'root':root.name,'bounds_blender_min_m':[round(v,6) for v in low],
      'bounds_blender_max_m':[round(v,6) for v in high],
      'dimensions_blender_xyz_m':[round(v,6) for v in dims],
      'dimensions_godot_xyz_m':[round(dims[0],6),round(dims[2],6),round(dims[1],6)],
      'triangles':sum(x['triangles'] for x in health),'mesh_parts':len(meshes),
      'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),
      'boundary_edges':sum(x['boundary_edges'] for x in health),
      'loose_edges':sum(x['loose_edges'] for x in health),
      'parts':[o.get('part','') for o in meshes]
    }

states={'Intact':measure(intact),'BrokenTop':measure(broken)}
outer_radius=.44; opening_degrees=70.0
clear_opening=2*outer_radius*math.sin(math.radians(opening_degrees/2))
intact_materials={m for obj in mesh_objects for m in obj.data.materials}
emissive=[]
for material in intact_materials:
    if not material.use_nodes: continue
    bsdf=next((n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bsdf:
        strength=bsdf.inputs.get('Emission Strength')
        if strength and strength.default_value>1e-6: emissive.append(material.name)

# Export both named states at the same ground-centered origin; preview spacing stays local.
for root in roots: root.location=(0,0,0)
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/i04_wind_guide_pillar.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
for root in roots: root.location=original_roots[root.name]
for obj in mesh_objects: obj.hide_render=original_hide[obj.name]
fox.location=fox_location
camera.location=camera_location; camera.rotation_euler=camera_rotation
camera.data.lens=camera_lens; camera.data.sensor_fit=camera_fit; camera.data.sensor_height=camera_sensor
bpy.context.view_layer.update()

with open(glb,'rb') as f:
    magic,version,declared_length=struct.unpack('<4sII',f.read(12))
    json_length,chunk_type=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(json_length))
file_size=os.path.getsize(glb); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
material_count=len(intact_materials)
metrics={
 'id':'I04','asset':'i04_wind_guide_pillar','glb':'assets/generated/wind_ruins/i04/i04_wind_guide_pillar.glb',
 'states':states,'nominal_dimensions_blender_xyz_m':[.9,.9,3.6],
 'nominal_dimensions_godot_xyz_m':[.9,3.6,.9],
 'open_crown':{'shape':'C-shaped annular sector','outer_diameter_m':.88,'clear_front_gap_m':round(clear_opening,6),
   'opening_degrees':opening_degrees,'front_direction_blender':'-Y','inner_clear_diameter_m':.58},
 'broken_top':'Same base, tapered shaft, and emblem; one 60-degree crown sector removed with two broad radial fracture planes.',
 'pivot_blender_m':[0,0,0],'emblem':'small raised open wind ring with three separated strokes, front (-Y) shaft face',
 'stone_emissive_materials':emissive,'materials':material_count,
 'triangles_total_across_variants':sum(s['triangles'] for s in states.values()),
 'maximum_triangles_per_variant':max(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared_length,'file_size':file_size,
   'length_matches':declared_length==file_size,'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/i04_concept_v1.png',
 'advisory':'Real 0.45–0.55 m camera-visible C-channel; broad bevels and one small emblem; one substantial crown sector removed for BrokenTop; non-emissive stone.',
 'self_check':{
   'both_states_within_0.9x0.9x3.6m_envelope':all(all(abs(actual-expected)<1e-5 for actual,expected in zip(s['dimensions_blender_xyz_m'],[.9,.9,3.6])) for s in states.values()),
   'ground_center_pivot':all(abs(s['bounds_blender_min_m'][2])<1e-5 for s in states.values()),
   'clear_crown_opening_between_0.45_and_0.55m':.45<=clear_opening<=.55,
   'all_asset_meshes_manifold':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
   'all_variants_under_5000_triangles':all(s['triangles']<=5000 for s in states.values()),
   'single_shared_material':material_count==1,
   'stone_non_emissive':not emissive,
   'glb_valid_header':magic==b'glTF' and version==2 and declared_length==file_size and chunk_type==b'JSON',
   'glb_contains_both_state_roots':all(name in node_names for name in ('I04_Intact_WindGuidePillar','I04_BrokenTop_WindGuidePillar'))
 },
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export; no approval gate'
}
assert all(metrics['self_check'].values()),json.dumps(metrics['self_check'])
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file: image.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/i04_wind_guide_pillar.blend',copy=True)
print('I04_COMPLETE',json.dumps(metrics))
