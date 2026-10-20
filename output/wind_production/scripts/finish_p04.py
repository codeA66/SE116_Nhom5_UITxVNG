import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/p04'
PRE=ROOT+'/output/wind_production/p04'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
GLB=OUT+'/p04_wind_checkpoint_beacon.glb'
BLEND=OUT+'/source/p04_wind_checkpoint_beacon.blend'
assert not os.path.exists(GLB),'Refusing to overwrite an existing P04 GLB'
assert not os.path.exists(BLEND),'Refusing to overwrite an existing P04 source blend'
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/p04_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/p04_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.data.scenes['WindProduction_P04']; bpy.context.window.scene=scene
export=bpy.data.collections['P04_Export']; source=bpy.data.collections['P04_SourceLocators_NOT_EXPORTED']
off=bpy.data.objects['P04_Off_WindCheckpoint']; active=bpy.data.objects['P04_Activated_WindCheckpoint']
roots=[off,active]
mesh_export=[o for o in export.objects if o.type=='MESH']
cam=scene.camera
camera_state=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
root_locations={r.name:r.location.copy() for r in roots}
mesh_hides={o.name:o.hide_render for o in mesh_export}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('P04_Fox_'))
fox_location=fox.location.copy(); fox_hide=fox.hide_render; resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)
saved_scene_camera=scene.camera

scene.render.engine='CYCLES'; scene.cycles.samples=28; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

def shoot(name,loc,target,lens):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=lens
    scene.camera=cam; scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# Matched studio view shows identical geometry in OFF/ACTIVATED and a correctly scaled Idle fox.
for o in mesh_export: o.hide_render=mesh_hides[o.name]
off.location=root_locations[off.name]; active.location=root_locations[active.name]
fox.location=(-5.4,-.35,0); fox.hide_render=fox_hide
shoot('beauty_3quarter',(7,-14,8),(-.7,0,1.0),43)

# Exact project camera transform, pitch, and 30-degree vertical FOV for gameplay-scale inspection.
for o in mesh_export: o.hide_render=True
for o in active.children_recursive:
    if o.type=='MESH': o.hide_render=False
active.location=(0,0,0); off.location=(6,0,0); fox.location=(2.5,-.35,0); fox.hide_render=False
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def measure(root):
    bpy.context.view_layer.update(); meshes=state_meshes(root); deps=bpy.context.evaluated_depsgraph_get()
    points=[]; stats=[]
    for ob in meshes:
        ev=ob.evaluated_get(deps); points.extend(ev.matrix_world@v.co for v in ob.data.vertices)
        bm=bmesh.new(); bm.from_mesh(ob.data)
        stats.append({'mesh':ob.name,'triangles':sum(max(0,len(p.vertices)-2) for p in ob.data.polygons),
                      'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                      'boundary_edges':sum(e.is_boundary for e in bm.edges),
                      'loose_edges':sum(not e.link_faces for e in bm.edges)})
        bm.free()
    lo=[min(p[i] for p in points) for i in range(3)]; hi=[max(p[i] for p in points) for i in range(3)]
    dims=[hi[i]-lo[i] for i in range(3)]
    return {'root':root.name,'bounds_min_blender_m':[round(x,6) for x in lo],
            'bounds_max_blender_m':[round(x,6) for x in hi],
            'dimensions_blender_xyz_m':[round(x,6) for x in dims],
            'dimensions_godot_xyz_m':[round(dims[0],6),round(dims[2],6),round(dims[1],6)],
            'mesh_parts':len(meshes),'triangles':sum(s['triangles'] for s in stats),
            'non_manifold_edges':sum(s['non_manifold_edges'] for s in stats),
            'boundary_edges':sum(s['boundary_edges'] for s in stats),
            'loose_edges':sum(s['loose_edges'] for s in stats),'mesh_health':stats}

for r in roots: r.location=(0,0,0)
for o in mesh_export: o.hide_render=mesh_hides[o.name]
fox.hide_render=fox_hide
bpy.context.view_layer.update()
states={'off':measure(off),'activated':measure(active)}
materials={m for o in mesh_export for m in o.data.materials}
mat_by_name={m.name:m for m in materials}
def emission_strength(mat):
    bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) if mat.use_nodes else None
    inp=bs.inputs.get('Emission Strength') if bs else None
    return float(inp.default_value) if inp else 0.0
emission={name:emission_strength(mat) for name,mat in mat_by_name.items()}
off_crystal=bpy.data.objects['P04_Off_WindCheckpoint_FacetedCrystal']
on_crystal=bpy.data.objects['P04_Activated_WindCheckpoint_FacetedCrystal']
crystal_coords=lambda ob: tuple(tuple(round(float(v.co[j]),8) for j in range(3)) for v in ob.data.vertices)
crystal_faces=lambda ob: tuple(tuple(int(i) for i in p.vertices) for p in ob.data.polygons)
crystals_same_geometry=crystal_coords(off_crystal)==crystal_coords(on_crystal) and crystal_faces(off_crystal)==crystal_faces(on_crystal)
off_segments=[bpy.data.objects[f'P04_Off_WindCheckpoint_RingSegment_{i}'] for i in range(1,4)]
on_segments=[bpy.data.objects[f'P04_Activated_WindCheckpoint_RingSegment_{i}'] for i in range(1,4)]
segments_same_data=all(a.data is b.data for a,b in zip(off_segments,on_segments))
segments_same_transform=all(tuple(round(float(x),7) for x in a.rotation_euler)==tuple(round(float(x),7) for x in b.rotation_euler) for a,b in zip(off_segments,on_segments))
locators=list(source.objects)
stone=mat_by_name['P04_SharedNonEmissiveBasalt']; off_mat=mat_by_name['P04_Crystal_Off_DarkTeal']; active_mat=mat_by_name['P04_Crystal_Activated_WarmAmber']

# Export both intentional checkpoint states only; preview, fox, and locators are omitted.
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=off
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

for r in roots: r.location=root_locations[r.name]
for o in mesh_export: o.hide_render=mesh_hides[o.name]
fox.location=fox_location; fox.hide_render=fox_hide
cam.location=camera_state[0]; cam.rotation_euler=camera_state[1]
cam.data.lens=camera_state[2]; cam.data.sensor_fit=camera_state[3]; cam.data.sensor_height=camera_state[4]
scene.camera=saved_scene_camera
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=resolution
bpy.context.view_layer.update()

with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12)); jlen,chunk=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(jlen))
size=os.path.getsize(GLB); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
nodes_by_name={n.get('name',''):n for n in gltf.get('nodes',[])}
materials_gltf=gltf.get('materials',[]); meshes_gltf=gltf.get('meshes',[])
def node_material_id(name):
    mesh_index=nodes_by_name[name]['mesh']; return meshes_gltf[mesh_index]['primitives'][0]['material']
off_material_id=node_material_id(off_crystal.name); active_material_id=node_material_id(on_crystal.name)
gltf_off_mat=materials_gltf[off_material_id]; gltf_active_mat=materials_gltf[active_material_id]
stone_gltf=next(m for m in materials_gltf if m.get('name')==stone.name)
emissive_off=any(v>1e-6 for v in gltf_off_mat.get('emissiveFactor',[0,0,0]))
emissive_active=any(v>1e-6 for v in gltf_active_mat.get('emissiveFactor',[0,0,0]))
emissive_stone=any(v>1e-6 for v in stone_gltf.get('emissiveFactor',[0,0,0]))
base_top_heights=[max(v.co.z for v in ob.data.vertices) for ob in off_segments]
crystal_world_center=float(off_crystal.matrix_world.translation.z)
crystal_world_bounds=[min((off_crystal.matrix_world@v.co).z for v in off_crystal.data.vertices),max((off_crystal.matrix_world@v.co).z for v in off_crystal.data.vertices)]
radial_max=max(math.hypot(v.co.x,v.co.y) for v in off_segments[0].data.vertices)

checks={
 'three_low_arc_modules_per_state':len(off_segments)==3 and len(on_segments)==3,
 'ring_outer_radius_1.8m_and_open_center':abs(radial_max-1.8)<1e-5 and all(abs(min(math.hypot(v.co.x,v.co.y) for v in ob.data.vertices)-1.15)<1e-5 for ob in off_segments),
 'base_thickness_exactly_0.18m':all(abs(max(v.co.z for v in ob.data.vertices)-min(v.co.z for v in ob.data.vertices)-.18)<1e-5 for ob in off_segments),
 'crystal_center_exactly_z1.8m':abs(crystal_world_center-1.8)<1e-5,
 'crystal_height_exactly_0.9m':abs((crystal_world_bounds[1]-crystal_world_bounds[0])-.9)<1e-5,
 'no_cradle_or_support_geometry':len(state_meshes(off))==4 and len(state_meshes(active))==4,
 'off_on_crystal_geometry_identical':crystals_same_geometry,
 'off_on_ring_geometry_and_transforms_match':segments_same_data and segments_same_transform,
 'all_state_meshes_closed_no_boundary_or_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
 'only_crystal_is_emissive_when_activated':emission_strength(stone)==0 and emission_strength(off_mat)==0 and emission_strength(active_mat)>0 and not emissive_stone and not emissive_off and emissive_active,
 'crystal_off_and_active_use_distinct_materials':off_material_id!=active_material_id,
 'both_named_states_in_glb':all(n in node_names for n in (off.name,active.name)),
 'source_locators_excluded_from_glb':not any('P04_Source_' in n for n in node_names),
 'preview_fox_and_helpers_excluded_from_glb':not any('P04_Fox_' in n for n in node_names),
 'glb_y_up_header_valid':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'both_states_under_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'three_source_locators_retained':len(locators)==3 and all(o.get('source_only') for o in locators),
 'source_approach_clearance_is_1.5m':list(source.get('approach_clear_zone_m',[]))==[2.0,1.5,2.1],
 'source_default_blender_scene_preserved':bpy.data.scenes.get('Scene') is not None,
 'source_gdignore_exists_empty':os.path.exists(OUT+'/source/.gdignore') and os.path.getsize(OUT+'/source/.gdignore')==0
}
assert all(checks.values()),json.dumps(checks,indent=2)

metrics={
 'id':'P04','asset':'p04_wind_checkpoint_beacon','glb':'assets/generated/wind_ruins/p04/p04_wind_checkpoint_beacon.glb',
 'states':states,'nominal_catalog_base_m':{'outer_diameter':3.6,'thickness':.18},
 'base':{'segments_per_state':3,'nominal_open_center_diameter_m':2.3,'outer_radius_m':1.8,'inner_radius_m':1.15,'walkable':True},
 'crystal':{'center_blender_z_m':crystal_world_center,'height_m':round(crystal_world_bounds[1]-crystal_world_bounds[0],6),
            'world_bounds_z_m':[round(x,6) for x in crystal_world_bounds],'broad_facets':6,'geometry_identical_off_on':crystals_same_geometry,
            'off_material':off_mat.name,'activated_material':active_mat.name},
 'materials':{'count':len(materials),'names':sorted(m.name for m in materials),'emission_strengths':emission},
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,
               'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_material_emission':{'off_crystal_emissive':emissive_off,'active_crystal_emissive':emissive_active,'stone_emissive':emissive_stone,
                          'off_material_id':off_material_id,'active_material_id':active_material_id},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_deg':30,'viewport':[1280,720],
 'fox_scale_reference_height_m':1.755,
 'source_locators':[{'name':o.name,'local_coordinates_m':list(o.get('local_coordinates_m',[]))} for o in locators],
 'concept':'output/wind_production/concepts/p04_concept_v1.png',
 'advisory':'Use exactly three low arc segments as a 3.6 m diameter ring, 0.18 m high overall; leave the center open and keep seams narrow and flush. Float the separate 0.9 m crystal with its center at z=1.8 m, without the illustrated tall cradle; use 5–6 broad facets and no internal crack texture. Reuse identical off/on geometry and change only the crystal material to warm emission when active; all stone remains non-emissive.',
 'self_check':checks,'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if im.filepath.lower().endswith('fox_palette.png') and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('P04_COMPLETE',json.dumps(metrics))
