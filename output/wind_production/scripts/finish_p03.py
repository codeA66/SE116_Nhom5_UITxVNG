import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/p03'
PRE=ROOT+'/output/wind_production/p03'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
GLB=OUT+'/p03_wind_reading_pedestal.glb'
BLEND=OUT+'/source/p03_wind_reading_pedestal.blend'
assert not os.path.exists(GLB),'Refusing to overwrite an existing P03 GLB'
assert not os.path.exists(BLEND),'Refusing to overwrite an existing P03 source blend'
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/p03_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/p03_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.data.scenes['WindProduction_P03']; bpy.context.window.scene=scene
export=bpy.data.collections['P03_Export']; source=bpy.data.collections['P03_SourceLocators_NOT_EXPORTED']
intact=bpy.data.objects['P03_Intact_WindReadingPedestal']
broken=bpy.data.objects['P03_Chipped_WindReadingPedestal']
roots=[intact,broken]
mesh_export=[o for o in export.objects if o.type=='MESH']
cam=scene.camera
camera_state=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
root_locations={r.name:r.location.copy() for r in roots}
mesh_hides={o.name:o.hide_render for o in mesh_export}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('P03_Fox_'))
fox_location=fox.location.copy(); fox_hide=fox.hide_render
resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)
saved_scene_camera=scene.camera

scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

def shoot(name,loc,target,lens):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=lens
    scene.camera=cam; scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# Close, matched studio view makes the intact reading pedestal and chipped corner easy to inspect.
for o in mesh_export: o.hide_render=mesh_hides[o.name]
intact.location=root_locations[intact.name]; broken.location=root_locations[broken.name]
fox.location=(-4.2,-.25,0); fox.hide_render=fox_hide
shoot('beauty_3quarter',(5.8,-12.5,6.6),(-.15,0,.78),48)

# The exact user camera position, 50-degree downward pitch, and 30-degree vertical FOV.
for o in mesh_export: o.hide_render=True
for o in intact.children_recursive:
    if o.type=='MESH': o.hide_render=False
intact.location=(0,0,0); broken.location=(4,0,0); fox.location=(2.15,-.25,0); fox.hide_render=False
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
states={'intact':measure(intact),'chipped_corner':measure(broken)}
materials={m for o in mesh_export for m in o.data.materials}
emissive=[]
for mat in materials:
    if mat.use_nodes:
        bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        strength=bs.inputs.get('Emission Strength') if bs else None
        if strength and strength.default_value>1e-6: emissive.append(mat.name)
book_a=bpy.data.objects['P03_Intact_WindReadingPedestal_OpenBook_PagesAndCover']
book_b=bpy.data.objects['P03_Chipped_WindReadingPedestal_OpenBook_PagesAndCover']
book_mesh_shared=book_a.data is book_b.data
book_local_points=[v.co for v in book_a.data.vertices]
book_local_dimensions=[round(max(v[i] for v in book_local_points)-min(v[i] for v in book_local_points),6) for i in range(3)]
book_world_points=[book_a.matrix_world@v.co for v in book_a.data.vertices]
book_world_dimensions=[round(max(v[i] for v in book_world_points)-min(v[i] for v in book_world_points),6) for i in range(3)]
locators=list(source.objects)

# Export the two named prop states from the asset collection only; preview fox and studio stay out.
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

# Restore the source scene presentation after the isolated gameplay-camera render.
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
envelope=[1.5,1.2,1.5]
checks={
 'both_states_within_1.5x1.2x1.5m':all(all(d<=lim+1e-4 for d,lim in zip(s['dimensions_blender_xyz_m'],envelope)) for s in states.values()),
 'intact_top_meets_1.5m_envelope':abs(states['intact']['bounds_max_blender_m'][2]-1.5)<.002,
 'both_pivots_grounded_at_bottom_center':all(abs(s['bounds_min_blender_m'][2])<1e-5 for s in states.values()),
 'one_book_mesh_reused_unchanged':book_mesh_shared,
 'book_is_0.70x0.50m_local_size':abs(book_local_dimensions[0]-.70)<1e-5 and abs(book_local_dimensions[1]-.50)<1e-5,
 'all_state_meshes_closed_and_no_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
 'one_shared_non_emissive_material':len(materials)==1 and not emissive,
 'both_named_states_in_glb':all(n in node_names for n in (intact.name,broken.name)),
 'source_locators_excluded_from_glb':not any('P03_Source_' in n for n in node_names),
 'preview_fox_and_helpers_excluded_from_glb':not any('P03_Fox_' in n for n in node_names),
 'glb_y_up_header_valid':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'all_states_under_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'four_source_locators_retained':len(locators)==4 and all(o.get('source_only') for o in locators),
 'source_approach_clearance_is_1.5m':list(source.get('approach_clear_zone_m',[]))==[1.5,1.5,2.0],
 'source_default_blender_scene_preserved':bpy.data.scenes.get('Scene') is not None,
 'source_gdignore_exists_empty':os.path.exists(OUT+'/source/.gdignore') and os.path.getsize(OUT+'/source/.gdignore')==0
}
assert all(checks.values()),json.dumps(checks,indent=2)
metrics={
 'id':'P03','asset':'p03_wind_reading_pedestal','glb':'assets/generated/wind_ruins/p03/p03_wind_reading_pedestal.glb',
 'states':states,'nominal_catalog_envelope_blender_xyz_m':envelope,
 'pivot_blender_m':[0,0,0],'pivot_description':'center of bottom plinth; ground at z=0',
 'reading_surface':{'slab_local_dimensions_m':[1.5,1.2,.12],'inclination_degrees':16,'book_local_dimensions_m':[.7,.5]},
 'book':{'dimensions_local_xyz_m':book_local_dimensions,'bounds_world_xyz_m':book_world_dimensions,'same_mesh_datablock_reused':book_mesh_shared,'unchanged_in_chipped_state':True},
 'approach':{'side':'negative Y','clear_zone_m':[1.5,1.5,2.0],'source_locators':len(locators)},
 'materials':len(materials),'emissive_materials':emissive,
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,
               'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_deg':30,'viewport':[1280,720],
 'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/p03_concept_v1.png',
 'advisory':'Retain tapered pedestal and inclined face, simplify stacked details; use a separate 0.7 x 0.5 m book; replace sweeping ornament with one subdued shallow non-emissive curve; reuse the unchanged book; make one broad base-corner chip; keep the negative-Y 1.5 m approach side clear.',
 'self_check':checks,'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if im.filepath.lower().endswith('fox_palette.png') and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('P03_COMPLETE',json.dumps(metrics))
