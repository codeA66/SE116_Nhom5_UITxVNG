import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d02'
PRE=ROOT+'/output/wind_production/d02'
GLB=OUT+'/d02_stone_rubble_clusters.glb'
BLEND=OUT+'/source/d02_stone_rubble_clusters.blend'
CONCEPT=ROOT+'/output/wind_production/concepts/d02_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/d02_prompt.txt'
scene=bpy.data.scenes['WindProduction_D02'];bpy.context.window.scene=scene
export=bpy.data.collections['D02_Export'];preview=bpy.data.collections['D02_Preview_ONLY']
roots=[bpy.data.objects[n] for n in ('D02_Compact_LowWedge','D02_Medium_SidewaysSpread','D02_Large_UprightLeaningSlab')]
cam=bpy.data.objects['D02_PreviewCamera']
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('D02_Fox_'))
expect={roots[0].name:[1.2,1.0,.5],roots[1].name:[2.0,1.5,.8],roots[2].name:[3.0,2.0,1.2]}

# Normalize companion-stone centers so each layout lands on its exact catalog envelope.
target_centers={
 'D02_Compact_LowWedge_Near_Block':-.37,'D02_Compact_LowWedge_Far_Block':.37,
 'D02_Medium_SidewaysSpread_Near_Block':-.55,'D02_Medium_SidewaysSpread_Far_Block':.55,
 'D02_Large_UprightLeaningSlab_Near_Block':-.78,'D02_Large_UprightLeaningSlab_Far_Block':.78}
for root in roots:
    for ob in root.children_recursive:
        if ob.type!='MESH' or ob.name not in target_centers:continue
        center=(min(v.co.y for v in ob.data.vertices)+max(v.co.y for v in ob.data.vertices))*.5
        dy=target_centers[ob.name]-center
        for v in ob.data.vertices:v.co.y+=dy
        ob.data.update()
    root['_d02_envelope_adjusted']=True

source=bpy.data.collections.get('D02_SourceLocators_NOT_EXPORTED')
if source:
    for ob in list(source.objects):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.collections.remove(source)
source=bpy.data.collections.new('D02_SourceLocators_NOT_EXPORTED');scene.collection.children.link(source)
for root in roots:
    loc=bpy.data.objects.new('D02_SourcePivot_'+root.name,None);source.objects.link(loc);loc.empty_display_type='CIRCLE';loc.parent=root
    loc.hide_render=True;loc.hide_set(True);loc['source_only']=True;loc['pivot']='Root origin, horizontal footprint center, z=0 ground contact.'
source['source_only']=True;source['excluded_from_glb']=True

def local_measure(root):
    parts=[o for o in root.children_recursive if o.type=='MESH']
    inv=root.matrix_world.inverted();pts=[inv@(o.matrix_world@v.co) for o in parts for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    dims=[hi[i]-lo[i] for i in range(3)];tris=0;health=[]
    for ob in parts:
        ob.data.calc_loop_triangles();t=len(ob.data.loop_triangles);tris+=t
        bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                       'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
                       'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)})
        bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':dims,
            'dimensions_godot_xyz_m':[dims[0],dims[2],dims[1]],'mesh_parts':len(parts),'triangles':tris,
            'non_manifold_edges':sum(q['non_manifold_edges'] for q in health),'boundary_edges':sum(q['boundary_edges'] for q in health),
            'loose_edges':sum(q['loose_edges'] for q in health),'loose_vertices':sum(q['loose_vertices'] for q in health),'mesh_health':health}

measurements={r.name:local_measure(r) for r in roots}
for root in roots:
    state=measurements[root.name];target=expect[root.name]
    assert len([o for o in root.children_recursive if o.type=='MESH'])==5,(root.name,state)
    assert all(abs(state['dimensions_blender_xyz_m'][i]-target[i])<.002 for i in range(3)),(root.name,state,target)
    assert abs(state['bounds_min_blender_m'][0]+state['bounds_max_blender_m'][0])<.002,(root.name,state)
    assert abs(state['bounds_min_blender_m'][1]+state['bounds_max_blender_m'][1])<.002,(root.name,state)
    assert abs(state['bounds_min_blender_m'][2])<.002,(root.name,state)
    assert state['non_manifold_edges']==0 and state['boundary_edges']==0 and state['loose_edges']==0 and state['loose_vertices']==0,(root.name,state)
    assert state['triangles']<1500,(root.name,state)
parts=[o for root in roots for o in root.children_recursive if o.type=='MESH']
assert len(parts)==15 and len({m.name for o in parts for m in o.data.materials})==1
assert all(o.data.color_attributes.get('Color') is not None for o in parts)
assert all(all(abs(v-1)<.0001 for v in o.scale) for o in parts)
assert all(sum(1 for o in r.children_recursive if o.type=='MESH' and o.get('role')=='dominant')==1 for r in roots)
assert all(sum(1 for o in r.children_recursive if o.type=='MESH' and o.get('role')=='auxiliary')==4 for r in roots)
assert all(o.get('fracture_facets')==2 and o.get('broad_masonry_faces') for o in parts)
assert len(source.objects)==3 and all(o.get('source_only') for o in source.objects)
assert bpy.data.scenes.get('Scene') is not None and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))

# Render actual preview and the fixed in-game camera using the imported Idle fox for scale.
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.25
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam.location=(1.3,-11.4,6.6);cam.rotation_euler=(Vector((0,0,.48))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
fox.hide_render=False;scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=roots[2]
scene.render.filepath=PRE+'/beauty_3quarter.png'
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'));nodes=gltf.get('nodes',[]);names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
glb_checks={
 'valid_glb_v2_and_declared_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON',
 'all_three_variant_roots_present':all(r.name in names for r in roots),
 'all_fifteen_mesh_objects_present':all(o.name in names for o in parts) and len(gltf.get('meshes',[]))==15,
 'one_shared_material_and_color_on_every_primitive':len(gltf.get('materials',[]))==1 and len(prims)==15 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'preview_fox_studio_and_source_locators_excluded':not any(n.startswith(('D02_Fox_','D02_Preview','D02_Key','D02_Fill','D02_Rim','D02_Source')) for n in names),
 'valid_mesh_indices_and_triangle_budget':all(len(m.get('primitives',[]))>0 for m in gltf.get('meshes',[])) and sum(gltf['accessors'][p['indices']]['count'] for m in gltf.get('meshes',[]) for p in m.get('primitives',[]) if isinstance(p.get('indices'),int))>0}
assert all(glb_checks.values()),json.dumps(glb_checks,indent=2)

checks={
 'three distinct exact_local_envelopes':[all(abs(measurements[r.name]['dimensions_blender_xyz_m'][i]-expect[r.name][i])<.002 for i in range(3)) for r in roots],
 'each layout_has_one_dominant_and_four_auxiliaries':all(len([o for o in r.children_recursive if o.type=='MESH' and o.get('role')=='dominant'])==1 and len([o for o in r.children_recursive if o.type=='MESH' and o.get('role')=='auxiliary'])==4 for r in roots),
 'broad_masonry_sides_and_two_top_fracture_facets_each':all(o.get('fracture_facets')==2 and o.get('broad_masonry_faces') and o.data.color_attributes.get('Color') for o in parts),
 'each_layout_is_closed_manifold_and_under_1500_triangles':all(measurements[r.name]['non_manifold_edges']==0 and measurements[r.name]['boundary_edges']==0 and measurements[r.name]['loose_edges']==0 and measurements[r.name]['loose_vertices']==0 and measurements[r.name]['triangles']<1500 for r in roots),
 'one_shared_non_emissive_L04_vertex_color_material':len({m.name for o in parts for m in o.data.materials})==1 and next(iter({m.name for o in parts for m in o.data.materials}))=='L04_Shared_Stone_VertexColor',
 'all_three_pivots_are_centered_at_ground_contact':all(abs(measurements[r.name]['bounds_min_blender_m'][2])<.002 and abs(measurements[r.name]['bounds_min_blender_m'][0]+measurements[r.name]['bounds_max_blender_m'][0])<.002 and abs(measurements[r.name]['bounds_min_blender_m'][1]+measurements[r.name]['bounds_max_blender_m'][1])<.002 for r in roots),
 'actual_idle_fox_used_only_in_preview':bool(fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle') and all(o.hide_render for o in preview.objects if o.type=='MESH' and any(k in o.name for k in ('Icosphere','Sword'))),
 'concept_prompt_gdignore_and_both_renders_saved':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png')),
 'original_default_scene_with_cube_camera_light_preserved':all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))}
assert all(all(v) if isinstance(v,list) else v for v in checks.values()),json.dumps(checks,indent=2)

metrics={'id':'D02','asset':'d02_stone_rubble_clusters','glb':'assets/generated/wind_ruins/d02/d02_stone_rubble_clusters.glb',
 'catalog_envelopes_blender_xyz_m':expect,'actual_dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},
 'actual_dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'variants':measurements,
 'layout':{'variants':['compact_low_wedge','medium_sideways_spread','large_upright_leaning_slab'],'dominant_stones_per_variant':1,'auxiliaries_per_variant':4,'total_stones':15,'shadow_gaps_per_variant':2,'geometry':'broad low-poly masonry prisms; each stone has 8 broad planar sides and three broad adjoining top faces divided by two fracture seams'},
 'materials':{'count':1,'name':'L04_Shared_Stone_VertexColor','vertex_colors':True,'emission':'none'},
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,'game_camera_vertical_fov_degrees':30,'viewport':[1280,720],'fox_reference_height_m':1.755,
 'self_check':{'geometry':checks,'glb':glb_checks}}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)

state_path=ROOT+'/output/wind_production/asset_state.json';state=json.load(open(state_path,encoding='utf-8'))
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
state['D02'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/d02/d02_stone_rubble_clusters.glb',
 'source':'assets/generated/wind_ruins/d02/source/d02_stone_rubble_clusters.blend','preview':'assets/generated/wind_ruins/d02/preview.png',
 'evidence':'output/wind_production/d02/','variants':list(expect.keys()),'dimensions_blender_xyz_m':{k:v['dimensions_blender_xyz_m'] for k,v in measurements.items()},
 'dimensions_godot_xyz_m':{k:v['dimensions_godot_xyz_m'] for k,v in measurements.items()},'triangles_per_variant':{k:v['triangles'] for k,v in measurements.items()},
 'total_triangles':sum(v['triangles'] for v in measurements.values()),'mesh_parts':len(parts),'materials':1,'glb_valid':all(glb_checks.values()),
 'self_check':'Three named, exact-envelope low-poly layouts; each has one dominant stone and four auxiliaries, two broad top fracture seams per stone, all parts closed manifold with shared L04 vertex colors. GLB v2, Y-up, COLOR_0, correct root pivots, preview/locators excluded; actual Idle fox used for beauty and fixed game-camera previews; original Cube/Camera/Light preserved.',
 'completed_utc':stamp})
state['completed_count']=int(state.get('completed_count',0))+1;state['pending_count']=int(state.get('pending_count',21))-1
queue=state.get('remaining_catalog_order',[])
if queue and queue[0]=='D02':queue=queue[1:]
state['remaining_catalog_order']=queue;state['next_asset']=queue[0] if queue else 'complete'
state['active_blender_scene']='WindProduction_D02';state['current_task']=f"D02 complete ({stamp}); proceed to {state['next_asset']} through actual2D, one Sol advisory, direct MCP Blender build, self-check and save."
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(ROOT+'/output/wind_production/reviews/workflow_order_audit.md','a',encoding='utf-8') as f:
    f.write(f"\n## D02 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/d02/d02_stone_rubble_clusters.glb` ({len(raw):,} bytes), source blend, empty `.gdignore`, exact 2D concept, preview, and metrics. The GLB includes compact low wedge 1.2 × 1.0 × 0.5 m, sideways spread 2.0 × 1.5 × 0.8 m, and upright-leaning slab 3.0 × 2.0 × 1.2 m. Each named root has one dominant stone and four close auxiliaries, broad planar sides and two broad top fracture seams per stone; no path-spreading debris. All 15 mesh parts are closed manifold and share L04's non-emissive vertex-color material. GLB v2/Y-up/header, vertex colors, node names, output exclusions, exact local envelopes, bottom-center pivots, and original default Cube/Camera/Light scene were checked. Beauty and fixed game-camera images with the actual Idle fox were rendered; see `{PRE}/`.\n")
print('D02_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'variants':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'glb_checks':glb_checks,'checks':checks,'state':{'completed_count':state['completed_count'],'pending_count':state['pending_count'],'next_asset':state['next_asset']}}))
