import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i08'
PRE=ROOT+'/output/wind_production/i08'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/i08_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/i08_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_I08',scene.name
export=bpy.data.collections['I08_Export']
intact=bpy.data.objects['I08_Intact_AbandonedCargoCrane']
broken=bpy.data.objects['I08_Broken_AbandonedCargoCrane']
roots=[intact,broken]
mesh_export=[o for o in export.objects if o.type=='MESH']
camera=scene.camera
camera_state=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.sensor_fit,camera.data.sensor_height)
root_locations={r.name:r.location.copy() for r in roots}
mesh_hides={o.name:o.hide_render for o in mesh_export}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('I08_Fox_'))
fox_location=fox.location.copy()
resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)

scene.render.engine='CYCLES'; scene.cycles.samples=20; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

def shoot(name,loc,target,lens):
    camera.location=loc; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24; camera.data.lens=lens
    scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# Matched studio comparison: intact and ruined crane with the correctly scaled Idle fox.
for o in mesh_export: o.hide_render=mesh_hides[o.name]
intact.location=root_locations[intact.name]; broken.location=root_locations[broken.name]
fox.location=(-7.2,-.25,0)
shoot('beauty_3quarter',(6,-24,11),(-.9,0,2.0),55)

# Exact project camera transform and 30 degree vertical FOV, focused on the intact prop.
for o in mesh_export: o.hide_render=True
for o in intact.children_recursive:
    if o.type=='MESH': o.hide_render=False
intact.location=(0,0,0); broken.location=(8,0,0); fox.location=(4.3,-.25,0)
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

for r in roots: r.location=(0,0,0)
bpy.context.view_layer.update()
states={'intact':measure(intact),'broken_boom_fallen_basket':measure(broken)}
materials={m for o in mesh_export for m in o.data.materials}
emissive=[]
for mat in materials:
    if mat.use_nodes:
        bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        strength=bs.inputs.get('Emission Strength') if bs else None
        if strength and strength.default_value>1e-6: emissive.append(mat.name)
intact_rim=bpy.data.objects['I08_Intact_Pulley_WheelRim']
rim_dimensions=[round(float(v),6) for v in intact_rim.dimensions]
spokes=[o for o in export.objects if o.name.startswith('I08_Intact_Pulley_BroadSpoke_')]
locators=list(bpy.data.collections['I08_SourceLocators_NOT_EXPORTED'].objects)

# Export selected collection objects only; fox, studio, and source locators are omitted.
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/i08_abandoned_cargo_crane.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

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
checks={
 'intact_envelope_within_3.6x1.8x4.5m':all(a<=b+1e-5 for a,b in zip(states['intact']['dimensions_blender_xyz_m'],[3.6,1.8,4.5])) and abs(states['intact']['dimensions_blender_xyz_m'][1]-1.8)<1e-5 and abs(states['intact']['dimensions_blender_xyz_m'][2]-4.5)<1e-5,
 'intact_pivot_grounded_at_mast_foot':abs(states['intact']['bounds_min_blender_m'][2])<1e-5,
 'broken_state_fits_catalog_envelope':all(a<=b+1e-5 for a,b in zip(states['broken_boom_fallen_basket']['dimensions_blender_xyz_m'],[3.6,1.8,4.5])),
 'broken_pivot_grounded':abs(states['broken_boom_fallen_basket']['bounds_min_blender_m'][2])<1e-4,
 'pulley_exact_0.7m_diameter':rim_dimensions==[.7,.12,.7],
 'five_broad_pulley_spokes':len(spokes)==5,
 'all_state_meshes_closed_and_no_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
 'one_shared_non_emissive_material':len(materials)==1 and not emissive,
 'both_named_states_in_glb':all(n in node_names for n in (intact.name,broken.name)),
 'source_locators_excluded_from_glb':not any('Source_' in n for n in node_names),
 'glb_y_up_header_valid':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'all_states_under_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'four_source_locators_retained':len(locators)==4 and all(o.get('source_only') for o in locators),
 'source_default_blender_scene_preserved':bpy.data.scenes.get('Scene') is not None
}
assert all(checks.values()),json.dumps(checks,indent=2)
metrics={
 'id':'I08','asset':'i08_abandoned_cargo_crane','glb':'assets/generated/wind_ruins/i08/i08_abandoned_cargo_crane.glb',
 'states':states,'nominal_catalog_envelope_blender_xyz_m':[3.6,1.8,4.5],
 'pivot_blender_m':[0,0,0],'pivot_description':'bottom-center of compact mast plinth',
 'pulley':{'diameter_m':.70,'spokes':len(spokes),'rim_dimensions_blender_m':rim_dimensions},
 'broken':{'boom_derived_from_intact_segment':True,'fracture_planes_per_cut':3,'fallen_direction':'down and right toward tilted basket'},
 'materials':len(materials),'emissive_materials':emissive,
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,
               'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'source_locators':[{'name':o.name,'local_coordinates_m':list(o.get('local_coordinates_m',[]))} for o in locators],
 'concept':'output/wind_production/concepts/i08_concept_v1.png',
 'advisory':'Remove the illustrated dock; compact plinth, upright mast and diagonal boom/brace with open triangle. Use a 0.7 m pulley with 4–6 broad spokes, a small box-frame basket and a few thick slack ropes. Derive fallen boom from intact beam with three broad matching cut planes; basket grounded, tilted and fallen in the same direction.',
 'self_check':checks,'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if im.filepath.lower().endswith('fox_palette.png') and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/i08_abandoned_cargo_crane.blend',copy=True)
print('I08_COMPLETE',json.dumps(metrics))
