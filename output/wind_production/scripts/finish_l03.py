import bpy,bmesh,math,os,json,shutil,struct
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/l03'; PRE=ROOT+'/output/wind_production/l03'
CONCEPT=ROOT+'/output/wind_production/concepts/l03_concept_v1.png'; PROMPT=ROOT+'/output/wind_production/concepts/l03_prompt.txt'
GLB=OUT+'/l03_wind_archive_pavilion.glb'; BLEND=OUT+'/source/l03_wind_archive_pavilion.blend'
assert not os.path.exists(GLB),'Refusing to overwrite an existing L03 GLB'
assert not os.path.exists(BLEND),'Refusing to overwrite an existing L03 source blend'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True); open(OUT+'/source/.gdignore','w').close()
shutil.copy2(CONCEPT,OUT+'/concept.png'); shutil.copy2(PROMPT,PRE+'/concept_prompt.txt')

scene=bpy.data.scenes['WindProduction_L03']; bpy.context.window.scene=scene
export=bpy.data.collections['L03_Export']; source=bpy.data.collections['L03_SourceLocators_NOT_EXPORTED']; preview=bpy.data.collections['L03_Preview_ONLY']
intact=bpy.data.objects['L03_Intact_WindArchivePavilion']; damaged=bpy.data.objects['L03_Damaged_WindArchivePavilion']; cam=bpy.data.objects['L03_PreviewCamera']
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('L03_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword')))
assert bpy.data.scenes.get('Scene') is not None

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def measure(root):
    bpy.context.view_layer.update(); inv=root.matrix_world.inverted(); meshes=state_meshes(root)
    pts=[inv@(o.matrix_world@v.co) for o in meshes for v in o.data.vertices]; health=[]
    for ob in meshes:
        bm=bmesh.new(); bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':sum(max(0,len(p.verts)-2) for p in bm.faces),
                       'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                       'boundary_edges':sum(e.is_boundary for e in bm.edges),
                       'loose_edges':sum(not e.link_faces for e in bm.edges)})
        bm.free()
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]; d=[hi[i]-lo[i] for i in range(3)]
    return {'bounds_min_blender_m':[round(x,6) for x in lo],'bounds_max_blender_m':[round(x,6) for x in hi],
            'dimensions_blender_xyz_m':[round(x,6) for x in d],'dimensions_godot_xyz_m':[round(d[0],6),round(d[2],6),round(d[1],6)],
            'mesh_parts':len(meshes),'triangles':sum(x['triangles'] for x in health),
            'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),'boundary_edges':sum(x['boundary_edges'] for x in health),
            'loose_edges':sum(x['loose_edges'] for x in health),'mesh_health':health}

def shoot(name,loc,target,lens):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=lens
    scene.camera=cam; scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

intact.location=(-4.1,0,0); damaged.location=(4.1,0,0); fox.location=(0,-4.25,0); fox.hide_render=False
for r in (intact,damaged):
    for o in state_meshes(r): o.hide_render=False
cam.location=(13,-26,14); cam.rotation_euler=(Vector((0,0,2.2))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.lens=42
roots_home={r.name:r.location.copy() for r in (intact,damaged)}; fox_home=fox.location.copy()
hides={o.name:o.hide_render for r in (intact,damaged) for o in state_meshes(r)}; fox_hide=fox.hide_render
cam_home=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage); engine=scene.render.engine
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True; scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100

if not os.path.exists(PRE+'/beauty_3quarter.png'):
    shoot('beauty_3quarter',(13,-26,14),(0,0,2.2),42)
# The fixed gameplay view faces the unobstructed front opening; retain only the damaged state and scale fox.
for o in state_meshes(intact): o.hide_render=True
intact.location=(14,0,0); damaged.location=(0,0,0); fox.location=(0,-4.25,0); fox.hide_render=False
# In the fixed-camera proof image, detach the named camera-facing roof plane so the interior book reads.
front_roof=[o for o in export.objects if o.type=='EMPTY' and 'RoofFront_Removable' in o.name]
for g in front_roof:
    for part in g.children_recursive:
        if part.type=='MESH': part.hide_render=True
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

for r in (intact,damaged): r.location=(0,0,0)
states={'intact':measure(intact),'damaged':measure(damaged)}
meshes=state_meshes(intact)+state_meshes(damaged); mats={m for o in meshes for m in o.data.materials}
intact_cols=[o for o in state_meshes(intact) if '_A01_CornerColumn_' in o.name]
damaged_cols=[o for o in state_meshes(damaged) if '_A01_CornerColumn_' in o.name]
intact_panels=[o for o in state_meshes(intact) if o.name=='L03_Intact_RearWallPanel']
damaged_panels=[o for o in state_meshes(damaged) if 'RearPanel_Rubble' in o.name]
intact_rafters=[o for o in state_meshes(intact) if '_A04_Rafter_' in o.name]
damaged_rafters=[o for o in state_meshes(damaged) if '_A04_Rafter_' in o.name]
intact_banners=[o for o in state_meshes(intact) if o.name.endswith('_F01_Banner_1') or o.name.endswith('_F01_Banner_2')]
damaged_banners=[o for o in state_meshes(damaged) if o.name.endswith('_F01_Banner_1') or o.name.endswith('_F01_Banner_2')]
front_roof=[o for o in export.objects if o.type=='EMPTY' and 'RoofFront_Removable' in o.name]
roof_groups=[o for o in export.objects if o.type=='EMPTY' and 'A04_RoofGroup' in o.name]
def object_group_dims(group):
    bpy.context.view_layer.update(); inv=group.matrix_world.inverted()
    pts=[inv@(o.matrix_world@v.co) for o in group.children_recursive if o.type=='MESH' for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]
    return [round(hi[i]-lo[i],6) for i in range(3)]
roof_dimensions={o.name:object_group_dims(o) for o in roof_groups}
book_parts=lambda r:sorted(o.name.replace('Intact','STATE').replace('Damaged','STATE') for o in state_meshes(r) if 'Book' in o.name or 'OpenBook' in o.name)
intact_books=book_parts(intact); damaged_books=book_parts(damaged)
front_approach_to_book=1.64-(-2.24)
source_names=[o.name for o in source.objects]
roof_corner_missing_area=3.0*(2.0-.67); roof_plan_area=6.0*4.0

checks={
 'both_state_envelopes_exact_7_2_by_6_by_5_8m':all(all(abs(a-b)<1e-5 for a,b in zip(s['dimensions_blender_xyz_m'],(7.2,6.0,5.8))) for s in states.values()),
 'four_A01_corner_columns_per_state':len(intact_cols)==4 and len(damaged_cols)==4,
 'one_separate_6_by_4_by_1_4m_A04_roof_per_state':all(list(r['nominal_envelope_m'])==[7.2,6.0,5.8] for r in (intact,damaged)) and len(roof_dimensions)==2 and all(abs(d[0]-6.0)<.03 and abs(d[1]-4.0)<.03 and abs(d[2]-1.4)<.02 for d in roof_dimensions.values()),
 'exactly_three_broad_roof_bands_on_each_plane':sum('Front_BroadBand' in o.name for o in state_meshes(intact))==3 and sum('Rear_BroadBand' in o.name for o in state_meshes(damaged))==3,
 'front_roof_is_a_separate_removable_part':len(front_roof)==2 and all(o.get('camera_occlusion_part') for o in front_roof),
 'one_rear_wall_panel_intact_and_same_bay_removed_in_damage':len(intact_panels)==1 and not any(o.name=='L03_Damaged_RearWallPanel' for o in state_meshes(damaged)) and len(damaged_panels)==2,
 'exactly_three_rafters_visible_under_damaged_corner':len(intact_rafters)==3 and len(damaged_rafters)==3,
 'two_sparse_F01_emblem_banners_per_state':len(intact_banners)==2 and len(damaged_banners)==2 and sum('_F01_OpenRing' in o.name for o in state_meshes(intact))==2 and sum('_F01_WindStroke_' in o.name for o in state_meshes(intact))==6,
 'rear_book_pedestal_and_at_least_1_5m_clear_front':len(intact_books)==len(damaged_books)>0 and front_approach_to_book>=1.5,
 'four_only_structural_corner_columns_no_extra_posts':len(intact_cols)==4 and len(damaged_cols)==4,
 'all_meshes_closed_manifold_no_boundary_or_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
 'both_states_below_5000_triangles':all(s['triangles']<5000 for s in states.values()),
 'one_shared_non_emissive_vertex_color_material':len(mats)==1 and next(iter(mats)).name=='L03_Shared_StoneAndCloth_VertexColor',
 'source_pivots_at_ground_center':all(tuple(round(float(v),6) for v in r.location)==(0,0,0) for r in (intact,damaged)),
 'actual_fox_idle_and_preview_helpers_hidden':fox.animation_data.action.name=='Idle' and all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword'))),
 'source_locators_are_only_in_their_unexported_collection':len(source_names)==6 and all(o.get('source_only') for o in source.objects),
 'default_blender_scene_preserved':bpy.data.scenes.get('Scene') is not None,
 'concept_prompt_and_empty_gdignore_saved':os.path.exists(OUT+'/concept.png') and os.path.exists(PRE+'/concept_prompt.txt') and os.path.getsize(OUT+'/source/.gdignore')==0,
 'beauty_and_game_camera_renders_exist':os.path.exists(PRE+'/beauty_3quarter.png') and os.path.exists(PRE+'/game_camera.png')
}
assert all(checks.values()),json.dumps(checks,indent=2)

# Export selected L03 assets only; no fox, ground, lights, camera, or source locators.
for o in bpy.context.view_layer.objects: o.select_set(False)
for o in export.objects: o.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12)); jlen,chunk=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(jlen))
size=os.path.getsize(GLB); nodes=[n.get('name','') for n in gltf.get('nodes',[])]; attrs=[p.get('attributes',{}) for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
glb_checks={
 'valid_glb_v2_header_and_declared_file_length':magic==b'glTF' and version==2 and declared==size and chunk==b'JSON',
 'both_variant_roots_present':intact.name in nodes and damaged.name in nodes,
 'preview_fox_and_source_items_excluded':not any(any(x in n for x in ('L03_Fox_','L03_Source_','PreviewGround','PreviewCamera','L03_Key','L03_Fill','L03_Rim')) for n in nodes),
 'one_glb_material':len(gltf.get('materials',[]))==1,
 'vertex_color_data_exported':bool(attrs) and all('COLOR_0' in a for a in attrs),
 'four_corner_columns_each_state':sum('Intact_A01_CornerColumn_' in n for n in nodes)==4 and sum('Damaged_A01_CornerColumn_' in n for n in nodes)==4,
 'front_roof_and_book_nodes_separate':any('RoofFront_Removable' in n for n in nodes) and any('BookStand' in n for n in nodes)
}
assert all(glb_checks.values()),json.dumps(glb_checks,indent=2)

metrics={
 'id':'L03','asset':'l03_wind_archive_pavilion','glb':'assets/generated/wind_ruins/l03/l03_wind_archive_pavilion.glb',
 'states':states,'catalog_envelope_m':{'width':7.2,'depth':6.0,'height':5.8},
 'architecture':{'platform_width_m':7.2,'platform_depth_m':6.0,'corner_columns_per_state':4,
                 'A04_roof_outer_dimensions_m':[6.0,4.0,1.4],'measured_roof_group_dimensions_blender_xyz_m':roof_dimensions,'front_roof_detachable':True,'broad_bands_per_roof_plane':3,
                 'rear_wall_panels_intact':len(intact_panels),'rear_wall_panels_damaged':0,'damaged_rear_panel_rubble_parts':len(damaged_panels),
                 'rafters_visible_at_damaged_corner':len(damaged_rafters),'missing_roof_corner_area_fraction':round(roof_corner_missing_area/roof_plan_area,6)},
 'book_pedestal':{'style':'P03-like tapered low pedestal with one open cream book','front_clear_approach_m':round(front_approach_to_book,3),'source_interaction_locator':'L03_Source_BookInteractionPoint'},
 'banners':{'count_per_state':2,'emblem':'F01 open ring and three same-direction wind strokes'},
 'materials':{'count':len(mats),'names':sorted(m.name for m in mats),'vertex_color_palette':True,'emission':'none'},
 'triangles_total_across_states':sum(s['triangles'] for s in states.values()),
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':size,'length_matches':declared==size,'json_chunk_type':chunk.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'source_locators':[{'name':o.name,'local_coordinates_blender_m':list(o.get('local_coordinates_blender_m',[]))} for o in source.objects],
 'advisory':'Exactly four A01-style corner columns; separate 6 x 4 x 1.4 m A04 roof, two planes and 6 broad bands; one removable front roof plane; two F01-mark banners; P03-like rear book pedestal with clear approach; one rear wall panel removed with the rear roof corner, exposing 3 rafters and two rubble slabs outside the front approach.',
 'self_check':{'geometry':checks,'glb':glb_checks},
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save -> next asset; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')

# Return the live source scene to the two-state gallery and save its native Blender copy.
for r in (intact,damaged): r.location=roots_home[r.name]
for r in (intact,damaged):
    for o in state_meshes(r): o.hide_render=hides[o.name]
fox.location=fox_home; fox.hide_render=fox_hide
cam.location=cam_home[0]; cam.rotation_euler=cam_home[1]; cam.data.lens=cam_home[2]; cam.data.sensor_fit=cam_home[3]; cam.data.sensor_height=cam_home[4]
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=resolution
scene.render.engine=engine; scene.render.filepath=PRE+'/beauty_3quarter.png'; scene.camera=cam; bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('L03_COMPLETE',json.dumps({'states':{k:{'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'non_manifold_edges':v['non_manifold_edges'],'boundary_edges':v['boundary_edges']} for k,v in states.items()},'clear_approach_m':round(front_approach_to_book,3),'checks':checks,'glb_checks':glb_checks,'glb_bytes':size,'source':BLEND}))
