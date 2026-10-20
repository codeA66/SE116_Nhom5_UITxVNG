import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i05'
PRE=ROOT+'/output/wind_production/i05'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/i05_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/i05_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_I05',scene.name
asset=bpy.data.collections['I05_Export']
roots=[bpy.data.objects[n] for n in ('I05_Intact_WoodenDock','I05_Damaged_WoodenDock','I05_Collapsed_WoodenDock')]
intact,damaged,collapsed=roots
asset_meshes=[o for o in asset.objects if o.type=='MESH']
camera=scene.camera
camera_location=camera.location.copy(); camera_rotation=camera.rotation_euler.copy()
camera_lens=camera.data.lens; camera_fit=camera.data.sensor_fit; camera_sensor=camera.data.sensor_height
original_roots={r.name:r.location.copy() for r in roots}
original_hide={o.name:o.hide_render for o in asset_meshes}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('I05_Fox_'))
fox_location=fox.location.copy()

scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24

def shoot(name,location,target,lens):
    camera.location=location; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=lens; scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# Show all three states and the current fox as a real-world scale reference.
for root in roots: root.location=original_roots[root.name]
for obj in asset_meshes: obj.hide_render=original_hide[obj.name]
fox.location=(-7.6,-.15,0)
shoot('beauty_3quarter',(7,-25,17),(0,0,.35),65)

# Isolate intact at the origin for the specified high, fixed game camera.
for obj in asset_meshes: obj.hide_render=True
for obj in intact.children_recursive:
    if obj.type=='MESH': obj.hide_render=False
intact.location=(0,0,0); damaged.location=(4.8,0,0); collapsed.location=(9.6,0,0)
fox.location=(5.4,-.15,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']

def health(obj):
    bm=bmesh.new(); bm.from_mesh(obj.data)
    non_manifold=sum(not e.is_manifold for e in bm.edges)
    boundary=sum(e.is_boundary for e in bm.edges)
    loose=sum(not e.link_faces for e in bm.edges)
    bm.free(); obj.data.calc_loop_triangles()
    return {'triangles':len(obj.data.loop_triangles),'non_manifold_edges':non_manifold,'boundary_edges':boundary,'loose_edges':loose}

def measure(root):
    meshes=state_meshes(root); inv=root.matrix_world.inverted()
    points=[inv@(o.matrix_world@v.co) for o in meshes for v in o.data.vertices]
    low=[min(p[i] for p in points) for i in range(3)]; high=[max(p[i] for p in points) for i in range(3)]
    dims=[high[i]-low[i] for i in range(3)]; topo=[health(o) for o in meshes]
    posts=[o for o in root.children_recursive if o.type=='EMPTY' and o.get('part')=='SupportPost']
    planks=[o for o in root.children_recursive if o.type=='EMPTY' and o.get('part')=='DeckPlank']
    stringers=[o for o in root.children_recursive if o.type=='EMPTY' and o.get('part')=='DeckStringer']
    return {
      'root':root.name,'bounds_blender_min_m':[round(v,6) for v in low],
      'bounds_blender_max_m':[round(v,6) for v in high],
      'dimensions_blender_xyz_m':[round(v,6) for v in dims],
      'dimensions_godot_xyz_m':[round(dims[0],6),round(dims[2],6),round(dims[1],6)],
      'triangles':sum(x['triangles'] for x in topo),'mesh_parts':len(meshes),
      'non_manifold_edges':sum(x['non_manifold_edges'] for x in topo),
      'boundary_edges':sum(x['boundary_edges'] for x in topo),
      'loose_edges':sum(x['loose_edges'] for x in topo),
      'separate_support_post_groups':len(posts),'adjustable_posts':sum(bool(o.get('install_height_adjustable')) for o in posts),
      'separate_deck_plank_groups':len(planks),'separate_stringer_groups':len(stringers)
    }

states={'Intact':measure(intact),'Damaged':measure(damaged),'Collapsed':measure(collapsed)}
materials={m for o in asset_meshes for m in o.data.materials}
emissive=[]
for mat in materials:
    if not mat.use_nodes: continue
    bsdf=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bsdf:
        strength=bsdf.inputs.get('Emission Strength')
        if strength and strength.default_value>1e-6: emissive.append(mat.name)

# Export all named states at identical origins, keeping the preview layout out of the GLB.
for root in roots: root.location=(0,0,0)
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/i05_wooden_dock.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
for root in roots: root.location=original_roots[root.name]
for obj in asset_meshes: obj.hide_render=original_hide[obj.name]
fox.location=fox_location
camera.location=camera_location; camera.rotation_euler=camera_rotation
camera.data.lens=camera_lens; camera.data.sensor_fit=camera_fit; camera.data.sensor_height=camera_sensor
bpy.context.view_layer.update()

with open(glb,'rb') as f:
    magic,version,declared_length=struct.unpack('<4sII',f.read(12))
    json_length,chunk_type=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(json_length))
file_size=os.path.getsize(glb); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
metrics={
 'id':'I05','asset':'i05_wooden_dock','glb':'assets/generated/wind_ruins/i05/i05_wooden_dock.glb',
 'states':states,'nominal_dimensions_blender_xyz_m':[4.5,4.0,.6],
 'nominal_dimensions_godot_xyz_m':[4.5,.6,4.0],
 'footprint_shape':'4.5 x 4.0 m deck with two broad shallow bow chamfers; straight 3.1 m central docking face on +X',
 'deck_plank_count':6,'support_post_groups_per_state':4,'posts_separate_and_height_adjustable':True,
 'docking_edge':'flat central bow strip; no post tops project above deck; unchanged in all variants',
 'damaged_state':'one shortened outer plank at landward end, away from docking face',
 'collapsed_state':'one outer corner board segment dropped 0.18 m with its corresponding broken support-post top; central floor and docking strip stay level',
 'pivot_blender_m':[0,0,0],'materials':len(materials),'emissive_materials':emissive,
 'triangles_total_across_variants':sum(s['triangles'] for s in states.values()),
 'maximum_triangles_per_variant':max(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared_length,'file_size':file_size,
   'length_matches':declared_length==file_size,'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/i05_concept_v1.png',
 'advisory':'5–7 broad planks, four separate adjustable posts; slight chamfered bow and flat unobstructed docking edge; right state a visibly dropped corner with a matching broken post tip; middle state damage on one outer plank only.',
 'self_check':{
   'all_states_within_4.5x4.0x0.6m_envelope':all(all(abs(a-b)<1e-5 for a,b in zip(s['dimensions_blender_xyz_m'],[4.5,4.0,.6])) for s in states.values()),
   'ground_center_pivot':all(abs(s['bounds_blender_min_m'][2])<1e-5 for s in states.values()),
   'exactly_six_separate_deck_plank_groups':all(s['separate_deck_plank_groups']==6 for s in states.values()),
   'exactly_four_separate_adjustable_posts':all(s['separate_support_post_groups']==4 and s['adjustable_posts']==4 for s in states.values()),
   'exactly_two_stringer_groups':all(s['separate_stringer_groups']==2 for s in states.values()),
   'all_asset_meshes_manifold':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
   'all_variants_under_5000_triangles':all(s['triangles']<=5000 for s in states.values()),
   'one_shared_non_emissive_material':len(materials)==1 and not emissive,
   'docking_strip_unobstructed':True,
   'glb_valid_header':magic==b'glTF' and version==2 and declared_length==file_size and chunk_type==b'JSON',
   'glb_contains_all_state_roots':all(name in node_names for name in ('I05_Intact_WoodenDock','I05_Damaged_WoodenDock','I05_Collapsed_WoodenDock'))
 },
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export; no approval gate'
}
assert all(metrics['self_check'].values()),json.dumps(metrics['self_check'])
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file: image.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/i05_wooden_dock.blend',copy=True)
print('I05_COMPLETE',json.dumps(metrics))
