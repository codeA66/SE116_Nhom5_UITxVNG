import bpy, bmesh, json, math, os, shutil, struct
from mathutils import Vector

ROOT_PATH=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT_PATH+'/assets/generated/wind_ruins/l05'
PRE=ROOT_PATH+'/output/wind_production/l05'
GLB=OUT+'/l05_broken_observatory_tower.glb'
BLEND=OUT+'/source/l05_broken_observatory_tower.blend'
CONCEPT=ROOT_PATH+'/output/wind_production/concepts/l05_concept_v1.png'

scene=bpy.data.scenes['WindProduction_L05']; bpy.context.window.scene=scene
export=bpy.data.collections['L05_Export']; preview=bpy.data.collections['L05_Preview_ONLY']; source=bpy.data.collections['L05_SourceLocators_NOT_EXPORTED']
intact=bpy.data.objects['L05_Intact_ObservatoryTower']; broken=bpy.data.objects['L05_Broken_ObservatoryTower']
top_i=bpy.data.objects['L05_Intact_ExactTopSection_3m']; top_f=bpy.data.objects['L05_Broken_FallenExactTopSection']
cam=bpy.data.objects['L05_PreviewCamera']; fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('L05_Fox_'))

def meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def measure(root):
    obs=meshes(root); inv=root.matrix_world.inverted(); pts=[inv@(o.matrix_world@v.co) for o in obs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]
    health=[]; tris=0
    for ob in obs:
        ob.data.calc_loop_triangles(); t=len(ob.data.loop_triangles); tris+=t
        bm=bmesh.new(); bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                       'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
                       'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)})
        bm.free()
    dims=[hi[i]-lo[i] for i in range(3)]
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':dims,
            'dimensions_godot_xyz_m':[dims[0],dims[2],dims[1]],'mesh_parts':len(obs),'triangles':tris,
            'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),'boundary_edges':sum(x['boundary_edges'] for x in health),
            'loose_edges':sum(x['loose_edges'] for x in health),'loose_vertices':sum(x['loose_vertices'] for x in health),'mesh_health':health}

def local_bounds(root,ob):
    inv=root.matrix_world.inverted(); ps=[inv@(ob.matrix_world@Vector(c)) for c in ob.bound_box]
    return ([min(p[i] for p in ps) for i in range(3)],[max(p[i] for p in ps) for i in range(3)])

def select_collection(coll,active):
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in coll.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=active

states={'intact':measure(intact),'broken':measure(broken)}
all_meshes=meshes(intact)+meshes(broken)
all_export_meshes=[o for o in export.objects if o.type=='MESH']
assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain preserved'
assert len([o for o in meshes(top_i) if o.type=='MESH'])==17
fallen=[o for o in meshes(top_f) if o.type=='MESH']
intact_top=[o for o in meshes(top_i) if o.type=='MESH']
assert len(fallen)==len(intact_top)==17
assert all(any(o.data is x.data for x in intact_top) for o in fallen),'Fallen top must use the exact intact mesh datablocks'
assert all(x['non_manifold_edges']==0 and x['boundary_edges']==0 and x['loose_edges']==0 and x['loose_vertices']==0
           for s in states.values() for x in s['mesh_health'])
assert all(s['triangles']<5000 for s in states.values())
assert abs(states['intact']['dimensions_blender_xyz_m'][0]-3)<.002
assert abs(states['intact']['dimensions_blender_xyz_m'][1]-3)<.002
assert abs(states['intact']['dimensions_blender_xyz_m'][2]-9)<.002
assert abs(states['intact']['bounds_min_blender_m'][2])<.002
assert abs(states['broken']['dimensions_blender_xyz_m'][2]-6)<.002,'Broken lower body must remain exactly 6 m tall'
assert abs(top_i.location.z-6)<.001 and abs(top_i.get('designed_section_height_m',0)-3)<.001
assert abs(top_f.scale.x-1)<.0001 and abs(top_f.scale.y-1)<.0001 and abs(top_f.scale.z-1)<.0001
assert abs(math.degrees(top_f.rotation_euler.y)-76)<.01
assert abs(top_f.location.z-.9)<.001 and abs(top_f.location.x-1.9)<.001
assert all(o.get('source_only') for o in source.objects)
assert all(not o.hide_render and not o.hide_get() for o in all_export_meshes)
materials=sorted({m.name for o in all_export_meshes for m in o.data.materials})
assert len(materials)==1,materials
assert all(len(o.data.materials)==1 for o in all_export_meshes)

# Required production renders: side-by-side silhouette and the exact project game camera.
root_locs={intact.name:intact.location.copy(),broken.name:broken.location.copy()}
mesh_hidden={o.name:o.hide_render for o in all_meshes}
fox_state=(fox.location.copy(),fox.hide_render)
cam_state=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
scene.render.engine='CYCLES'; scene.cycles.samples=20; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.view_settings.exposure=.35
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
for o in all_meshes: o.hide_render=False
fox.hide_render=False; fox.location=(-4.05,-2.4,0)
intact.location=(-4.05,0,0); broken.location=(4.05,0,0)
cam.location=(0,-26,17); target=Vector((0,0,4.25)); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=40
scene.render.filepath=PRE+'/beauty_3quarter.png'; bpy.ops.render.render(write_still=True)

for o in meshes(intact): o.hide_render=True
for o in meshes(broken): o.hide_render=False
intact.location=(-4.05,0,0); broken.location=(0,0,0); fox.location=(0,-4.0,0)
cam.location=(0,-20.57,24.51); cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png'; bpy.ops.render.render(write_still=True)

# Restore the studio state before exporting source scene and selected asset collection.
for o in all_meshes: o.hide_render=mesh_hidden[o.name]
fox.hide_render=fox_state[1]; fox.location=fox_state[0]
intact.location=root_locs[intact.name]; broken.location=root_locs[broken.name]
cam.location=cam_state[0]; cam.rotation_euler=cam_state[1]; cam.data.lens=cam_state[2]
cam.data.sensor_fit=cam_state[3]; cam.data.sensor_height=cam_state[4]
scene.render.filepath=PRE+'/beauty_3quarter.png'
select_collection(export,intact)
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

raw=open(GLB,'rb').read(); magic=raw[:4]; version,length=struct.unpack('<II',raw[4:12]); chunk_len=struct.unpack('<I',raw[12:16])[0]; chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'))
nodes=gltf.get('nodes',[]); names=[n.get('name','') for n in nodes]; prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
glb_checks={
 'valid_glb_v2_and_declared_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'both_state_roots_present':intact.name in names and broken.name in names,
 'preview_objects_and_source_locators_excluded':not any(n.startswith(('L05_Fox_','L05_Source_','L05_Preview','L05_Key','L05_Fill','L05_Rim')) for n in names),
 'one_shared_material':len(gltf.get('materials',[]))==1,
 'all_export_primitives_have_vertex_colors':len(prims)>0 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'top_section_named_and_exact_geometry_reused':top_i.name in names and top_f.name in names and len(fallen)==17 and len(intact_top)==17,
 'no_preview_camera_in_asset':cam.name not in names,
 'source_collection_not_exported':all(o.name not in names for o in source.objects)}
assert all(glb_checks.values()),json.dumps(glb_checks,indent=2)

idle=fox.animation_data is not None and fox.animation_data.action is not None and fox.animation_data.action.name=='Idle'
hidden_helpers=all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword')))
checks={
 'intact_exact_3x3x9m_with_ground_pivot':all(abs(a-b)<.002 for a,b in zip(states['intact']['dimensions_blender_xyz_m'],[3,3,9])) and abs(states['intact']['bounds_min_blender_m'][2])<.002,
 'broken_retained_body_is_exactly_6m':abs(states['broken']['dimensions_blender_xyz_m'][2]-6)<.002,
 'intact_and_broken_meshes_closed_manifold':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 and s['loose_vertices']==0 for s in states.values()),
 'both_states_below_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'three_major_tier_masses_and_broad_open_bays':all(sum(1 for o in all_export_meshes if o.name.startswith(prefix+'_Tier') and o.name.endswith('_BroadMass'))==3 for prefix in ('L05_Intact','L05_Broken')),
 'upper_section_exactly_3m_and_tip_at_9m':abs(top_i['designed_section_height_m']-3)<.001 and abs(top_i.location.z+3-9)<.001,
 'fallen_upper_section_reuses_all_17_exact_mesh_datablocks':all(any(o.data is x.data for x in intact_top) for o in fallen),
 'fallen_section_not_scaled_and_rotated_76deg_to_rest_beside_body':all(abs(v-1)<.0001 for v in top_f.scale) and abs(math.degrees(top_f.rotation_euler.y)-76)<.01 and abs(top_f.location.x-1.9)<.001,
 'base_exactly_3m_square':all(abs(v-3)<.002 for v in states['intact']['dimensions_blender_xyz_m'][:2]),
 'single_shared_non_emissive_vertex_color_material':len(materials)==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims) and all(o.data.color_attributes.get('Color') is not None for o in all_export_meshes),
 'source_locators_excluded_and_gdignore_present':all(o.get('source_only') for o in source.objects) and os.path.exists(OUT+'/source/.gdignore'),
 'idle_fox_reference_and_hidden_helper_meshes_used':idle and hidden_helpers,
 'concept_prompt_and_both_renders_saved':os.path.exists(CONCEPT) and os.path.exists(ROOT_PATH+'/output/wind_production/concepts/l05_prompt.txt') and os.path.exists(PRE+'/beauty_3quarter.png') and os.path.exists(PRE+'/game_camera.png'),
 'original_default_scene_preserved':bpy.data.scenes.get('Scene') is not None}
assert all(checks.values()),json.dumps(checks,indent=2)

metrics={'id':'L05','asset':'l05_broken_observatory_tower','glb':'assets/generated/wind_ruins/l05/l05_broken_observatory_tower.glb',
 'states':states,'catalog_dimensions_m':{'base':[3,3],'intact_height':9,'retained_lower_body':6,'detached_top_section':3},
 'structure':{'major_tier_masses':3,'base_width_depth_m':[3,3],'fracture_height_m':6,'intact_sail_frame_tip_m':9,'upper_section_local_z_bounds_m':[0,3],
              'upper_section_mesh_parts':len(intact_top),'upper_section_source_mesh_reuse_count':len(fallen),'broken_top_scale':[float(v) for v in top_f.scale],
              'fallen_anchor_blender_m':[float(v) for v in top_f.location],'fallen_rotation_degrees':[float(math.degrees(v)) for v in top_f.rotation_euler],
              'upper_section_meshes_reused_exactly':all(any(o.data is x.data for x in intact_top) for o in fallen)},
 'materials':{'count':len(materials),'names':materials,'vertex_color_palette':True,'emission':'none'},
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(names),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_degrees':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'source_locators':[{'name':o.name,'local_coordinates_blender_m':list(o['local_coordinates_blender_m'])} for o in source.objects],
 'self_check':{'geometry':checks,'glb':glb_checks}}
for path in [PRE+'/metrics.json',OUT+'/metrics.json']:
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
os.makedirs(OUT+'/source',exist_ok=True); open(OUT+'/source/.gdignore','a',encoding='utf-8').close()
shutil.copy2(CONCEPT,OUT+'/concept.png'); shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('L05_COMPLETE',json.dumps({'states':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'triangles':v['triangles'],'non_manifold_edges':v['non_manifold_edges']} for k,v in states.items()},
      'structure':metrics['structure'],'checks':checks,'glb_checks':glb_checks,'glb_bytes':len(raw),'source':BLEND}))
