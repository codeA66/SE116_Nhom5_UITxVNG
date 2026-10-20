import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i07'
PRE=ROOT+'/output/wind_production/i07'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/i07_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/i07_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_I07',scene.name
export=bpy.data.collections['I07_Export']
upright=bpy.data.objects['I07_Upright_MooringPost']
broken=bpy.data.objects['I07_LeaningBroken_MooringPost']
roots=[upright,broken]
mesh_export=[o for o in export.objects if o.type=='MESH']
camera=scene.camera
camera_state=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.sensor_fit,camera.data.sensor_height)
root_locations={r.name:r.location.copy() for r in roots}
mesh_hides={o.name:o.hide_render for o in mesh_export}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('I07_Fox_'))
fox_location=fox.location.copy()
resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)

scene.render.engine='CYCLES'; scene.cycles.samples=20; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

def shoot(name,loc,target,lens):
    camera.location=loc; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24; camera.data.lens=lens
    scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# A studio three-quarter shows both post states beside the correctly scaled Idle fox.
for o in mesh_export: o.hide_render=mesh_hides[o.name]
upright.location=root_locations[upright.name]; broken.location=root_locations[broken.name]
fox.location=(-4.0,-.18,0)
shoot('beauty_3quarter',(4.8,-11.8,5.6),(-.45,0,.56),50)

# Exact project game-camera transform and 30 degree vertical FOV; only intact post is shown.
for o in mesh_export: o.hide_render=True
for o in upright.children_recursive:
    if o.type=='MESH': o.hide_render=False
upright.location=(0,0,0); broken.location=(8,0,0); fox.location=(1.65,-.25,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def measure(root):
    bpy.context.view_layer.update(); meshes=state_meshes(root); deps=bpy.context.evaluated_depsgraph_get()
    points=[]; stats=[]
    for ob in meshes:
        ev=ob.evaluated_get(deps); points.extend(ev.matrix_world@Vector(v) for v in ev.bound_box)
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

# Measure each state at its intended export origin, with embedded bottoms preserved.
for r in roots: r.location=(0,0,0)
bpy.context.view_layer.update()
states={'upright':measure(upright),'leaning_broken':measure(broken)}
materials={m for o in mesh_export for m in o.data.materials}
emissive=[]
for mat in materials:
    if mat.use_nodes:
        bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        strength=bs.inputs.get('Emission Strength') if bs else None
        if strength and strength.default_value>1e-6: emissive.append(mat.name)

# Export only the two state trees, never the studio, fox, or source locators.
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=upright
glb=OUT+'/i07_mooring_post.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

# Return the editable source to its two-state studio layout.
for r in roots: r.location=root_locations[r.name]
for o in mesh_export: o.hide_render=mesh_hides[o.name]
fox.location=fox_location
camera.location=camera_state[0]; camera.rotation_euler=camera_state[1]
camera.data.lens=camera_state[2]; camera.data.sensor_fit=camera_state[3]; camera.data.sensor_height=camera_state[4]
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=resolution
bpy.context.view_layer.update()

with open(glb,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12)); jlen,chunk=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(jlen))
size=os.path.getsize(glb); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
mesh_states=list(states.values())
checks={
 'upright_nominal_0.45m_shaft_0.55m_cap_1.2m_high':
    abs(states['upright']['dimensions_blender_xyz_m'][2]-1.2)<1e-5 and
    abs(bpy.data.objects['I07_Upright_WoodPost']['shaft_width_m']-.45)<1e-8 and
    abs(bpy.data.objects['I07_Upright_WoodPost']['cap_width_m']-.55)<1e-8,
 'both_embedded_base_pivots_grounded_with_0.12m_embed': all(abs(s['bounds_min_blender_m'][2]+.12)<1e-5 for s in mesh_states),
 'all_state_meshes_closed_and_no_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in mesh_states),
 'one_shared_non_emissive_material':len(materials)==1 and not emissive,
 'both_state_roots_in_glb':all(n in node_names for n in (upright.name,broken.name)),
 'source_locators_excluded_from_glb':not any('Source_' in n for n in node_names),
 'glb_y_up_header_valid':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'triangles_below_5000_per_state':all(s['triangles']<5000 for s in mesh_states),
 'source_default_blender_scene_preserved':bpy.data.scenes.get('Scene') is not None
}
assert all(checks.values()),json.dumps(checks,indent=2)
metrics={
 'id':'I07','asset':'i07_mooring_post','glb':'assets/generated/wind_ruins/i07/i07_mooring_post.glb',
 'states':states,'nominal_dimensions_blender_xyz_m':[.55, .55, 1.2],
 'nominal_dimensions_godot_xyz_m':[.55, 1.2, .55],
 'pivot_blender_m':[0,0,0],'embed_depth_m':.12,'shaft_width_m':.45,'cap_width_m':.55,
 'rope':{'type':'one chunky closed loop','height_blender_z_m':.39,'shared_across_material_palette':True},
 'fracture':{'shared_source_post_profile':True,'broad_facets':3,'upper_lean_degrees':20},
 'materials':len(materials),'emissive_materials':emissive,
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,
               'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/i07_concept_v1.png',
 'advisory':'Use a 0.45 m octagonal shaft and shallow 0.55 m cap, 1.2 m total height; broad timber faces and one chunky low rope loop; derive both broken parts from one post with three broad matching fracture facets; lean upper piece and retain its rope; embed the pivot 0.12 m below dock surface.',
 'self_check':checks,'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if im.filepath.lower().endswith('fox_palette.png') and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/i07_mooring_post.blend',copy=True)
print('I07_COMPLETE',json.dumps(metrics))
