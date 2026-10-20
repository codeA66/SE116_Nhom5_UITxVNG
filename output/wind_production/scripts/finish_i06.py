import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i06'
PRE=ROOT+'/output/wind_production/i06'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/i06_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/i06_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_I06',scene.name
export=bpy.data.collections['I06_Export']
intact=bpy.data.objects['I06_Intact_WindSailBoat']; cap=bpy.data.objects['I06_Capsized_HullOnly']
roots=[intact,cap]
mesh_export=[o for o in export.objects if o.type=='MESH']
camera=scene.camera
saved_camera=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.sensor_fit,camera.data.sensor_height)
saved_roots={r.name:r.location.copy() for r in roots}
saved_hides={o.name:o.hide_render for o in mesh_export}
fox=next(o for o in scene.objects if o.type=='ARMATURE' and o.name.startswith('I06_Fox_'))
saved_fox=fox.location.copy()

scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

def shoot(name,loc,target,lens):
    camera.location=loc; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24; camera.data.lens=lens
    scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# Studio view shows both variants and the correctly scaled Idle fox.
for o in mesh_export: o.hide_render=saved_hides[o.name]
intact.location=saved_roots[intact.name]; cap.location=saved_roots[cap.name]
fox.location=(-8.1,-.25,0)
shoot('beauty_3quarter',(7,-25,16),(0,0,1.35),60)

# Exact fixed Godot game camera: show only the intact working boat plus the fox scale reference.
for o in mesh_export: o.hide_render=True
for o in intact.children_recursive:
    if o.type=='MESH': o.hide_render=False
intact.location=(0,0,0); cap.location=(8.0,0,0); fox.location=(3.2,-.25,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def measure(root):
    bpy.context.view_layer.update(); meshes=state_meshes(root); deps=bpy.context.evaluated_depsgraph_get()
    points=[]; stats=[]
    for ob in meshes:
        ev=ob.evaluated_get(deps); points.extend([ev.matrix_world@Vector(v) for v in ev.bound_box])
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

# Bounds are measured with both model roots at their real export pivots.
for r in roots: r.location=(0,0,0)
bpy.context.view_layer.update()
states={'intact':measure(intact),'capsized_hull_only':measure(cap)}

materials={m for o in mesh_export for m in o.data.materials}
emissive=[]
for mat in materials:
    if not mat.use_nodes: continue
    bsdf=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bsdf:
        strength=bsdf.inputs.get('Emission Strength')
        if strength and strength.default_value>1e-6: emissive.append(mat.name)

deckplanks=[o for o in export.objects if o.name.startswith('I06_Intact_DeckPlank_') and o.type=='MESH']
deck_points=[o.matrix_world@Vector(v) for o in deckplanks for v in o.bound_box]
deck_lo=[min(p[i] for p in deck_points) for i in range(3)]
deck_hi=[max(p[i] for p in deck_points) for i in range(3)]
locators=[o for o in bpy.data.collections['I06_SourceLocators_NOT_EXPORTED'].objects]
loc_data={o.name.replace('I06_Source_',''):[float(v) for v in o.get('local_coordinates_m')] for o in locators}
logo=bpy.data.objects['I06_Intact_Sail_F01_WindEmblem']
logo_bm=bmesh.new(); logo_bm.from_mesh(logo.data)
logo_health={'non_manifold_edges':sum(not e.is_manifold for e in logo_bm.edges),'boundary_edges':sum(e.is_boundary for e in logo_bm.edges)}; logo_bm.free()
same_hull=bpy.data.objects['I06_Capsized_Hull_ExactIntactMesh'].data is bpy.data.objects['I06_Intact_Hull_ClosedFaceted'].data

# Export only I06_Export, which excludes fox, camera, studio ground, and source locator empties.
for r in roots: r.location=(0,0,0)
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/i06_wind_sailboat.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

# Restore the side-by-side source scene and the preview setup after export.
for r in roots: r.location=saved_roots[r.name]
for o in mesh_export: o.hide_render=saved_hides[o.name]
fox.location=saved_fox
camera.location=saved_camera[0]; camera.rotation_euler=saved_camera[1]
camera.data.lens=saved_camera[2]; camera.data.sensor_fit=saved_camera[3]; camera.data.sensor_height=saved_camera[4]
bpy.context.view_layer.update()

with open(glb,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12)); jlen,chunk=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(jlen))
size=os.path.getsize(glb); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
all_state_meshes=states['intact']['mesh_health']+states['capsized_hull_only']['mesh_health']
checks={
 'intact_exact_2.7x5.4x4.8m':all(abs(a-b)<1e-5 for a,b in zip(states['intact']['dimensions_blender_xyz_m'],[2.7,5.4,4.8])),
 'intact_ground_pivot':abs(states['intact']['bounds_min_blender_m'][2])<1e-5,
 'capsized_grounded':abs(states['capsized_hull_only']['bounds_min_blender_m'][2])<1e-5,
 'exact_hull_mesh_reused_in_capsized_state':same_hull,
 'capsized_contains_no_mast_or_sail':not any('Mast' in n or 'Sail' in n for n in node_names if 'Capsized' in n),
 'flat_4x2.2m_deck':len(deckplanks)==6 and abs(deck_hi[0]-deck_lo[0]-2.2)<1e-5 and abs(deck_hi[1]-deck_lo[1]-4.0)<1e-5,
 'deck_top_at_1m':abs(deck_hi[2]-1.0)<1e-5,
 'seven_source_locators':len(locators)==7 and all(o.get('source_only') for o in locators),
 'emblem_closed_mesh':logo_health['non_manifold_edges']==0 and logo_health['boundary_edges']==0,
 'all_exported_asset_meshes_closed':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in all_state_meshes),
 'one_shared_non_emissive_material':len(materials)==1 and not emissive,
 'all_variants_under_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'glb_y_up_header_valid':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'both_state_roots_in_glb':all(n in node_names for n in ('I06_Intact_WindSailBoat','I06_Capsized_HullOnly')),
 'source_locators_excluded_from_glb':not any('Source_' in n for n in node_names),
 'default_blender_scene_preserved':bpy.data.scenes.get('Scene') is not None
}
metrics={
 'id':'I06','asset':'i06_wind_sailboat','glb':'assets/generated/wind_ruins/i06/i06_wind_sailboat.glb',
 'states':states,'nominal_dimensions_blender_xyz_m':[2.7,5.4,4.8],
 'nominal_dimensions_godot_xyz_m':[2.7,4.8,5.4],'pivot_blender_m':[0,0,0],
 'deck':{'clear_flat_rectangle_m':[2.2,4.0],'top_height_blender_z_m':1.0,'separate_longitudinal_planks':len(deckplanks)},
 'mast':{'x_m':-.72,'z_min_m':1.0,'z_max_m':4.8},
 'sail':{'type':'single triangular sail','broad_folds':3,'shared_F01_emblem':'open ring and three same-direction wind strokes',
         'emblem_mesh_health':logo_health},
 'capsized':'same closed hull mesh inverted; mast and sail omitted; three broad low-profile keel planes',
 'mooring_and_boarding_source_locators':loc_data,
 'hull_mesh_reused':same_hull,'materials':len(materials),'emissive_materials':emissive,
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,
               'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/i06_concept_v1.png',
 'advisory':'Flat 4 x 2.2 m deck within 5.4 x 2.7 m hull; clear boarding area and source deck/mooring locators; F01 open ring with three same-direction strokes; 3 broad sail folds and separate Hull/Mast/Sail; capsized variant reuses the same hull mesh without mast or sail.',
 'self_check':checks,'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save; no approval gate'
}
assert all(checks.values()),json.dumps(checks,indent=2)
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if im.filepath.endswith('fox_palette.png') and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/i06_wind_sailboat.blend',copy=True)
print('I06_COMPLETE',json.dumps(metrics))
