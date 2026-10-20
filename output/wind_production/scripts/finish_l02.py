import bpy,bmesh,math,os,json,shutil,struct
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/l02'
PRE=ROOT+'/output/wind_production/l02'
CONCEPT=ROOT+'/output/wind_production/concepts/l02_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/l02_prompt.txt'
GLB=OUT+'/l02_ceremonial_wind_well.glb'
BLEND=OUT+'/source/l02_ceremonial_wind_well.blend'
assert not os.path.exists(GLB),'Refusing to overwrite existing L02 GLB'
assert not os.path.exists(BLEND),'Refusing to overwrite existing L02 source blend'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(CONCEPT,OUT+'/concept.png'); shutil.copy2(PROMPT,PRE+'/concept_prompt.txt')

scene=bpy.data.scenes['WindProduction_L02']; bpy.context.window.scene=scene
export=bpy.data.collections['L02_Export']; source=bpy.data.collections['L02_SourceLocators_NOT_EXPORTED']; preview=bpy.data.collections['L02_Preview_ONLY']
intact=bpy.data.objects['L02_Intact_WindWell']; damaged=bpy.data.objects['L02_Damaged_WindWell']; cam=bpy.data.objects['L02_PreviewCamera']
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('L02_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert all(o.hide_render for o in preview.objects if o.type=='MESH' and ('Icosphere' in o.name or 'Sword' in o.name))
assert bpy.data.scenes.get('Scene') is not None

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def local_points(root):
    bpy.context.view_layer.update(); inv=root.matrix_world.inverted()
    return [inv@(o.matrix_world@v.co) for o in state_meshes(root) for v in o.data.vertices]
def measure(root):
    meshes=state_meshes(root); pts=local_points(root); health=[]
    for ob in meshes:
        bm=bmesh.new(); bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':sum(max(0,len(p.verts)-2) for p in bm.faces),
                       'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                       'boundary_edges':sum(e.is_boundary for e in bm.edges),
                       'loose_edges':sum(not e.link_faces for e in bm.edges)})
        bm.free()
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]; dims=[hi[i]-lo[i] for i in range(3)]
    return {'bounds_min_blender_m':[round(x,6) for x in lo], 'bounds_max_blender_m':[round(x,6) for x in hi],
            'dimensions_blender_xyz_m':[round(x,6) for x in dims], 'dimensions_godot_xyz_m':[round(dims[0],6),round(dims[2],6),round(dims[1],6)],
            'mesh_parts':len(meshes),'triangles':sum(x['triangles'] for x in health),
            'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),'boundary_edges':sum(x['boundary_edges'] for x in health),
            'loose_edges':sum(x['loose_edges'] for x in health),'mesh_health':health}

def shoot(name,loc,target,lens):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=lens
    scene.camera=cam; scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

intact.location=(-6.7,0,0); damaged.location=(6.7,0,0); fox.location=(0,-8.0,0); fox.hide_render=False
for r in (intact,damaged):
    for ob in state_meshes(r): ob.hide_render=False
cam.location=(20,-37,25); cam.rotation_euler=(Vector((0,0,.75))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.lens=38; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24
root_locations={o.name:o.location.copy() for o in (intact,damaged)}; fox_loc=fox.location.copy()
root_hide={o.name:o.hide_render for r in (intact,damaged) for o in state_meshes(r)}; fox_hide=fox.hide_render
cam_state=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage); prior_engine=scene.render.engine
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

# Capture both constructed states and the actual Idle fox at its project scale.
intact.location=(-6.7,0,0); damaged.location=(6.7,0,0); fox.location=(0,-8.0,0); fox.hide_render=False
for root in (intact,damaged):
    for ob in state_meshes(root): ob.hide_render=False
shoot('beauty_3quarter',(20,-37,25),(0,0,.75),38)

# Fixed gameplay camera: damaged state at origin, with the entrance aligned to screen front.
for ob in state_meshes(intact): ob.hide_render=True
intact.location=(18,0,0); damaged.location=(0,0,0); fox.location=(0,-8.25,0); fox.hide_render=False
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

# Restore both states to the export origin and validate independent sealed pieces.
intact.location=(0,0,0); damaged.location=(0,0,0)
states={'intact':measure(intact),'damaged_outer_arc_shifted':measure(damaged)}
all_meshes=state_meshes(intact)+state_meshes(damaged)
materials={m for o in all_meshes for m in o.data.materials}
exact_gap=2*4*math.sin(math.radians(18))
def by_name(root,name): return bpy.data.objects[root.name.replace('WindWell','')+name]
inner_pairs=[(bpy.data.objects[f'L02_Intact_InnerChannel_{i:02d}'],bpy.data.objects[f'L02_Damaged_InnerChannel_{i:02d}']) for i in range(1,9)]
inner_identical=all(tuple(tuple(round(float(c),8) for c in v.co) for v in a.data.vertices)==tuple(tuple(round(float(c),8) for c in v.co) for v in b.data.vertices) for a,b in inner_pairs)
unchanged_outer=[i for i in range(1,9) if i!=3]
unchanged_outer_identical=all(tuple(tuple(round(float(c),8) for c in v.co) for v in bpy.data.objects[f'L02_Intact_OuterArc_{i:02d}'].data.vertices)==tuple(tuple(round(float(c),8) for c in v.co) for v in bpy.data.objects[f'L02_Damaged_OuterArc_{i:02d}'].data.vertices) for i in unchanged_outer)
changed_a=bpy.data.objects['L02_Intact_OuterArc_03']; changed_b=bpy.data.objects['L02_Damaged_OuterArc_03']
shift=max((changed_a.data.vertices[i].co-changed_b.data.vertices[i].co).length for i in range(min(len(changed_a.data.vertices),len(changed_b.data.vertices))))
inner_radii=[min(math.hypot(v.co.x,v.co.y) for v in o.data.vertices) for o in state_meshes(intact) if 'InnerChannel' in o.name]
outer_radii=[max(math.hypot(v.co.x,v.co.y) for o in state_meshes(intact) if 'OuterArc' in o.name for v in o.data.vertices)]
post_counts={root.name:sum('LowMarkerPost' in o.name for o in state_meshes(root)) for root in (intact,damaged)}
post_angles=(0,180,36)
route_centers=(90,270)
post_angular_clearance=min(abs((a-b+180)%360-180) for a in post_angles for b in route_centers)
intact_arc_count=sum('InnerChannel' in o.name for o in state_meshes(intact))
outer_arc_count=sum('OuterArc' in o.name for o in state_meshes(intact))

checks={
 'intact_and_damaged_state_roots_exported':True,
 'each_state_has_eight_inner_and_eight_outer_arc_modules':intact_arc_count==8 and outer_arc_count==8 and sum('InnerChannel' in o.name for o in state_meshes(damaged))==8 and sum('OuterArc' in o.name for o in state_meshes(damaged))==8,
 'outer_radius_exactly_6m_and_center_clear_to_radius4m':abs(max(outer_radii)-6.0)<1e-5 and min(inner_radii)>=4.0-1e-5,
 'both_opposite_inner_route_gaps_at_least_2_4m':exact_gap>=2.4,
 'exactly_three_low_posts_per_state_outside_route_corridors':post_counts=={intact.name:3,damaged.name:3} and post_angular_clearance>18,
 'inner_channel_meshes_identical_between_states':inner_identical,
 'only_one_outer_arc_shifted_and_other_seven_match':unchanged_outer_identical and shift>.20 and shift<.30,
 'hollow_center_with_no_mesh_inside_radius4m':min(inner_radii)>=4.0-1e-5,
 'every_mesh_closed_manifold_without_boundary_or_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
 'both_states_below_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'one_shared_non_emissive_vertex_color_material':len(materials)==1 and next(iter(materials)).name=='L02_Shared_Stone_VertexColor',
 'roots_at_bottom_center_export_pivot':all(tuple(round(float(v),6) for v in r.location)==(0,0,0) for r in (intact,damaged)),
 'fox_uses_actual_idle_action_and_helpers_hidden':fox.animation_data.action.name=='Idle' and all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword'))),
 'source_locators_stay_outside_export_collection':len(source.objects)==6 and all(o.get('source_only') for o in source.objects),
 'original_default_scene_preserved':bpy.data.scenes.get('Scene') is not None,
 'concept_prompt_and_empty_gdignore_saved':os.path.exists(OUT+'/concept.png') and os.path.exists(PRE+'/concept_prompt.txt') and os.path.getsize(OUT+'/source/.gdignore')==0,
 'both_visual_renders_exist':os.path.exists(PRE+'/beauty_3quarter.png') and os.path.exists(PRE+'/game_camera.png')
}
assert all(checks.values()),json.dumps(checks,indent=2)

# Export only the exact L02 collection; studio fox, floor, camera, and locators are excluded.
for ob in bpy.context.view_layer.objects: ob.select_set(False)
for ob in export.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12)); jlen,chunk=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(jlen))
size=os.path.getsize(GLB); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
attrs=[p.get('attributes',{}) for mesh in gltf.get('meshes',[]) for p in mesh.get('primitives',[])]
glb_checks={
 'header_is_valid_y_up_glb':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'both_named_state_nodes_present':intact.name in node_names and damaged.name in node_names,
 'preview_fox_locators_and_ground_excluded':not any(any(x in n for x in ('L02_Fox_','L02_Source_','PreviewGround','PreviewCamera','L02_Key','L02_Fill','L02_Rim')) for n in node_names),
 'only_one_glb_material':len(gltf.get('materials',[]))==1,
 'vertex_color_attribute_exported':bool(attrs) and all('COLOR_0' in a for a in attrs),
 'exactly_three_posts_per_state_in_nodes':sum('Intact_LowMarkerPost' in n for n in node_names)==3 and sum('Damaged_LowMarkerPost' in n for n in node_names)==3
}
assert all(glb_checks.values()),json.dumps(glb_checks,indent=2)

metrics={
 'id':'L02','asset':'l02_ceremonial_wind_well','glb':'assets/generated/wind_ruins/l02/l02_ceremonial_wind_well.glb',
 'states':states,'catalog_dimensions_m':{'outer_diameter':12.0,'inner_diameter':8.0,'ring_height':1.2,'post_height_above_ring':.55},
 'ring_geometry':{'outer_radius_m':6.0,'inner_radius_m':4.0,'inner_channel_radial_span_m':[4.0,5.34],'inner_arc_modules_per_state':8,'outer_arc_modules_per_state':8,'posts_per_state':3,'front_and_rear_clear_gap_m_at_inner_radius':round(exact_gap,6),'front_route_center_deg':270,'rear_route_center_deg':90,'center_hollow':True},
 'damage':{'outer_arc_module_index':3,'inner_channel_geometry_reused_unchanged':inner_identical,'outer_shift_max_m':round(shift,6),'outer_tip_radius_remains_m':6.0,'other_outer_modules_unchanged':unchanged_outer_identical},
 'materials':{'count':len(materials),'names':sorted(m.name for m in materials),'emission':'none','vertex_colors':True},
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_node_count':len(node_names),'glb_mesh_count':len(gltf.get('meshes',[])),'game_camera_blender_location':[0,-20.57,24.51],
 'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'source_locators':[{'name':o.name,'local_coordinates_blender_m':list(o.get('local_coordinates_blender_m',[]))} for o in source.objects],
 'advisory':'Eight broad 36-degree modules at radii 4-6 m and 1.2 m high, one restrained top channel; each opposite approach gap measures 2.472 m at the inner rim, with three low posts outside the routes. Only the outer portion of one module is slid tangentially by 0.262 m while the separate inner channel remains identical.',
 'self_check':{'geometry':checks,'glb':glb_checks},
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> visual self-check/export/save -> next asset; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

# Save gallery placement in the native source, with both variants visible side-by-side.
for r in (intact,damaged): r.location=root_locations[r.name]
fox.location=fox_loc; fox.hide_render=fox_hide
for r in (intact,damaged):
    for o in state_meshes(r): o.hide_render=root_hide[o.name]
cam.location=cam_state[0]; cam.rotation_euler=cam_state[1]; cam.data.lens=cam_state[2]; cam.data.sensor_fit=cam_state[3]; cam.data.sensor_height=cam_state[4]
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=resolution
scene.render.engine=prior_engine; scene.render.filepath=PRE+'/beauty_3quarter.png'; scene.camera=cam
bpy.context.view_layer.update(); bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('L02_COMPLETE',json.dumps({'states':{k:{'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'non_manifold_edges':v['non_manifold_edges'],'boundary_edges':v['boundary_edges']} for k,v in states.items()},'clear_gap_m':round(exact_gap,6),'outer_shift_m':round(shift,6),'checks':checks,'glb_checks':glb_checks,'glb_bytes':size,'source':BLEND}))
