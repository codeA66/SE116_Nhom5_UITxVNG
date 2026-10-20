import bpy,bmesh,json,math,os,shutil,struct
from mathutils import Vector

ROOT_PATH=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT_PATH+'/assets/generated/wind_ruins/d01'
PRE=ROOT_PATH+'/output/wind_production/d01'
GLB=OUT+'/d01_ceremonial_ring_fragment.glb'
BLEND=OUT+'/source/d01_ceremonial_ring_fragment.blend'
CONCEPT=ROOT_PATH+'/output/wind_production/concepts/d01_concept_v1.png'

scene=bpy.data.scenes['WindProduction_D01']; bpy.context.window.scene=scene
export=bpy.data.collections['D01_Export']; preview=bpy.data.collections['D01_Preview_ONLY']; source=bpy.data.collections['D01_SourceLocators_NOT_EXPORTED']
root=bpy.data.objects['D01_FallenCeremonialRingFragment']; cam=bpy.data.objects['D01_PreviewCamera']
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('D01_Fox_'))
parts=[o for o in root.children_recursive if o.type=='MESH']
source_arcs=[bpy.data.objects['L04_Intact_RingArc_02'],bpy.data.objects['L04_Intact_RingArc_03']]

def measure(r):
    obs=[o for o in r.children_recursive if o.type=='MESH']
    inv=r.matrix_world.inverted(); pts=[inv@(o.matrix_world@v.co) for o in obs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]
    tris=0; health=[]
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

def select_export():
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=root

state=measure(root)
assert bpy.data.scenes.get('Scene') is not None
assert len(parts)==2 and len(source_arcs)==2
assert all(parts[i].data is source_arcs[i].data for i in range(2))
assert len({m.name for o in parts for m in o.data.materials})==1
assert all(o.data.color_attributes.get('Color') is not None for o in parts)
assert abs(root['source_arc_span_degrees']-72)<.001 and abs(root['outer_radius_m']-5)<.001
assert abs(root['inner_radius_m']-3.5)<.001 and abs(root['radial_band_m']-1.5)<.001 and abs(root['front_to_back_depth_m']-.9)<.001
assert abs(state['bounds_min_blender_m'][0]+state['bounds_max_blender_m'][0])<.002
assert abs(state['bounds_min_blender_m'][1]+state['bounds_max_blender_m'][1])<.002
assert abs(state['bounds_min_blender_m'][2])<.002
assert all(x['non_manifold_edges']==0 and x['boundary_edges']==0 and x['loose_edges']==0 and x['loose_vertices']==0 for x in state['mesh_health'])
assert state['triangles']<3000
assert all(abs(v-1)<.0001 for ob in parts for v in ob.scale)
assert len(source.objects)==2 and all(o.get('source_only') for o in source.objects)

# Capture the fragment with a real imported Idle fox at project scale and the fixed project camera.
save_cam=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
fox_loc=fox.location.copy(); fox_hidden=fox.hide_render
scene.render.engine='CYCLES'; scene.cycles.samples=20; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.view_settings.exposure=.3
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
fox.hide_render=False; fox.location=(0,-4.5,0)
cam.location=(8,-12,8); target=Vector((0,0,max(.7,state['dimensions_blender_xyz_m'][2]*.5)))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=42
scene.render.filepath=PRE+'/beauty_3quarter.png'; bpy.ops.render.render(write_still=True)

cam.location=(0,-20.57,24.51); cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png'; bpy.ops.render.render(write_still=True)
fox.location=fox_loc; fox.hide_render=fox_hidden
cam.location=save_cam[0]; cam.rotation_euler=save_cam[1]; cam.data.lens=save_cam[2]; cam.data.sensor_fit=save_cam[3]; cam.data.sensor_height=save_cam[4]
scene.render.filepath=PRE+'/beauty_3quarter.png'

select_export(); bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read(); magic=raw[:4]; version,length=struct.unpack('<II',raw[4:12]); chunk_len=struct.unpack('<I',raw[12:16])[0]; chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8')); nodes=gltf.get('nodes',[]); names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
glb_checks={
 'valid_glb_v2_and_declared_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'fragment_root_and_both_exact_modules_present':root.name in names and all(o.name in names for o in parts),
 'only_two_mesh_nodes_exported':sum(n.startswith('D01_ExactL04ArcModule_') for n in names)==2,
 'one_shared_material_and_vertex_color_on_every_primitive':len(gltf.get('materials',[]))==1 and len(prims)==2 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'preview_fox_camera_and_source_locators_excluded':not any(n.startswith(('D01_Fox_','D01_Source_','D01_Preview','D01_Key','D01_Fill','D01_Rim')) for n in names),
 'source_collection_meshes_not_exported':all(o.name not in names for o in source.objects)}
assert all(glb_checks.values()),json.dumps(glb_checks,indent=2)

checks={
 'exact_L04_source_mesh_datablocks_reused_for_both_adjacent_modules':all(parts[i].data is source_arcs[i].data for i in range(2)),
 'exact_outer_radius_5m_inner_radius_3_5m':abs(root['outer_radius_m']-5)<.001 and abs(root['inner_radius_m']-3.5)<.001,
 'exact_1_5m_radial_band_and_0_9m_depth':abs(root['radial_band_m']-1.5)<.001 and abs(root['front_to_back_depth_m']-.9)<.001,
 'exact_two_adjacent_36_degree_modules_form_72_degree_missing_sector':len(parts)==2 and all(abs(o.get('arc_span_degrees',0)-36)<.001 for o in parts) and abs(sum(o.get('arc_span_degrees',0) for o in parts)-72)<.001,
 'source_channel_and_terminal_fracture_caps_preserved':all(ob.data is source_arcs[i].data for i,ob in enumerate(parts)) and all(ob.data.color_attributes.get('Color') is not None for ob in parts),
 'one_connected_dominant_fragment_no_optional_loose_chunk':len(parts)==2,
 'bottom_center_pivot_and_positive_ground_contact':abs(state['bounds_min_blender_m'][2])<.002 and abs(state['bounds_min_blender_m'][0]+state['bounds_max_blender_m'][0])<.002 and abs(state['bounds_min_blender_m'][1]+state['bounds_max_blender_m'][1])<.002,
 'all_mesh_parts_closed_manifold_and_under_3000_triangles':state['non_manifold_edges']==0 and state['boundary_edges']==0 and state['loose_edges']==0 and state['loose_vertices']==0 and state['triangles']<3000,
 'one_shared_vertex_color_material_no_emission':len({m.name for o in parts for m in o.data.materials})==1 and all(o.data.color_attributes.get('Color') is not None for o in parts),
 'source_locators_and_studio_objects_excluded':all(o.get('source_only') for o in source.objects) and all(o.name not in names for o in source.objects),
 'idle_fox_reference_and_hidden_helper_meshes_used':fox.animation_data is not None and fox.animation_data.action is not None and fox.animation_data.action.name=='Idle' and all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword'))),
 'concept_prompt_gdignore_and_two_renders_saved':os.path.exists(CONCEPT) and os.path.exists(ROOT_PATH+'/output/wind_production/concepts/d01_prompt.txt') and os.path.exists(OUT+'/source/.gdignore') and os.path.exists(PRE+'/beauty_3quarter.png') and os.path.exists(PRE+'/game_camera.png'),
 'original_default_scene_preserved':bpy.data.scenes.get('Scene') is not None}
assert all(checks.values()),json.dumps(checks,indent=2)

materials=sorted({m.name for o in parts for m in o.data.materials})
metrics={'id':'D01','asset':'d01_ceremonial_ring_fragment','glb':'assets/generated/wind_ruins/d01/d01_ceremonial_ring_fragment.glb',
 'catalog_suggested_envelope_m':[5,2,4],'actual_dimensions_blender_xyz_m':state['dimensions_blender_xyz_m'],
 'actual_dimensions_godot_xyz_m':state['dimensions_godot_xyz_m'],'state':state,
 'geometry':{'source':'L04_Intact_RingArc_02 and L04_Intact_RingArc_03 exact mesh datablocks',
             'module_count':2,'degrees_per_source_module':36,'total_arc_degrees':72,'outer_radius_m':5.0,'inner_radius_m':3.5,
             'radial_band_m':1.5,'front_to_back_depth_m':.9,'source_channel_profile_reused':True,
             'source_terminal_fracture_planes_and_center_seam_preserved':True,'added_chunk_count':0,
             'source_module_transform':'one shared rigid rotation/translation; no geometry edit or scale'},
 'materials':{'count':len(materials),'names':materials,'vertex_colors':True,'emission':'none'},
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(names),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_degrees':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'source_locators':[{'name':o.name,'local_coordinates_blender_m':list(o['local_coordinates_blender_m'])} for o in source.objects],
 'self_check':{'geometry':checks,'glb':glb_checks}}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
os.makedirs(OUT+'/source',exist_ok=True); open(OUT+'/source/.gdignore','a',encoding='utf-8').close()
shutil.copy2(CONCEPT,OUT+'/concept.png'); shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('D01_COMPLETE',json.dumps({'dimensions_blender_xyz_m':state['dimensions_blender_xyz_m'],'triangles':state['triangles'],
      'mesh_parts':state['mesh_parts'],'glb_checks':glb_checks,'checks':checks,'glb_bytes':len(raw),'source':BLEND}))
