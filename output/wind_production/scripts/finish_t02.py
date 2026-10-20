import bpy,bmesh,json,math,os,shutil,struct
from datetime import datetime,timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/t02';PRE=ROOT+'/output/wind_production/t02'
CONCEPT=ROOT+'/output/wind_production/concepts/t02_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/t02_prompt.txt'
GLB=OUT+'/t02_cliff_corner_wall.glb';BLEND=OUT+'/source/t02_cliff_corner_wall.blend'
LEVELS=[0.0,.48,.95,1.55,2.10,2.75,4.30,5.55,6.0]

scene=bpy.data.scenes['WindProduction_T02'];bpy.context.window.scene=scene
export=bpy.data.collections['T02_Export'];preview=bpy.data.collections['T02_Preview_ONLY']
roots=[bpy.data.objects[n] for n in ('T02_Convex_Outer_Corner','T02_Concave_Inner_Corner','T02_Broken_Exposed_Upper_Corner')]
meshes=[bpy.data.objects[r.name+'_Stone'] for r in roots]
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('T02_Fox_'))
template=bpy.data.objects['T01_Intact_Stone']
assert not os.path.exists(GLB),'Refusing to overwrite existing T02 GLB'

def source_profile(z):
    at_z=[v.co for v in template.data.vertices if abs(v.co.z-z)<1e-4]
    xmax=max(v.x for v in at_z)
    edge=[v for v in at_z if abs(v.x-xmax)<1e-4]
    ylo=min(v.y for v in edge);yhi=max(v.y for v in edge)
    return xmax,ylo,yhi,-yhi,-ylo

def local_bounds(ob):
    ps=[v.co for v in ob.data.vertices]
    return [min(p[i] for p in ps) for i in range(3)],[max(p[i] for p in ps) for i in range(3)]

def topology(ob):
    ob.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(ob.data)
    row={'triangles':len(ob.data.loop_triangles),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
         'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),
         'loose_vertices':sum(not v.link_edges for v in bm.verts)}
    bm.free();return row

def plane_error(points):
    p0=Vector(points[0]);normal=None
    for a in range(1,len(points)):
        for b in range(a+1,len(points)):
            n=(Vector(points[a])-p0).cross(Vector(points[b])-p0)
            if n.length>1e-7:normal=n.normalized();break
        if normal:break
    assert normal is not None
    return max(abs((Vector(p)-p0).dot(normal)) for p in points)

variants={}
connector_checks={};triangles_total=0
for root,ob in zip(roots,meshes):
    lo,hi=local_bounds(ob);dims=[hi[i]-lo[i] for i in range(3)]
    assert all(abs(a-b)<.002 for a,b in zip(dims,[4,4,6])),(root.name,dims,lo,hi)
    assert abs(lo[2])<.001 and abs(hi[2]-6)<.001,(root.name,lo,hi)
    health=topology(ob);triangles_total+=health['triangles']
    assert health['non_manifold_edges']==health['boundary_edges']==health['loose_edges']==health['loose_vertices']==0,(root.name,health)
    assert ob.data.color_attributes.get('Color') and len(ob.data.materials)==1
    assert health['triangles']<5000
    n=8;assert len(ob.data.vertices)==len(LEVELS)*n,(ob.name,len(ob.data.vertices))
    east_points=[];north_points=[];row_errors=[]
    for ri,z in enumerate(LEVELS):
        xedge,ylo,yhi,xnlo,xnhi=source_profile(z)
        ring=[ob.data.vertices[ri*n+i].co for i in range(n)]
        expected_e=[(xedge,ylo,z),(xedge,yhi,z)]
        expected_n=[(xnhi,xedge,z),(xnlo,xedge,z)]
        actual_e=[tuple(ring[i]) for i in (2,3)]
        actual_n=[tuple(ring[i]) for i in (5,6)]
        row_errors.append(max([abs(a-b) for pa,pb in zip(actual_e,expected_e) for a,b in zip(pa,pb)]+[abs(a-b) for pa,pb in zip(actual_n,expected_n) for a,b in zip(pa,pb)]))
        east_points.extend(actual_e);north_points.extend(actual_n)
    east_plane=plane_error(east_points);north_plane=plane_error(north_points)
    connector_checks[root.name]={'max_profile_deviation_m':max(row_errors),'east_plane_error_m':east_plane,'north_plane_error_m':north_plane,
                                 'profile_levels_checked':len(LEVELS),'east_connector':'same mesh-derived T01 x+ edge','north_connector':'same T01 profile rotated 90 degrees'}
    assert max(row_errors)<1e-5 and east_plane<1e-5 and north_plane<1e-5,(root.name,connector_checks[root.name])
    variants[root.name]={'pivot':'bottom center at z=0','bounds_min_blender_m':lo,'bounds_max_blender_m':hi,
                         'dimensions_blender_xyz_m':dims,'dimensions_godot_xyz_m':[dims[0],dims[2],dims[1]],
                         **health,'connector_check':connector_checks[root.name]}

material_names={m.name for ob in meshes for m in ob.data.materials}
assert len(material_names)==1,material_names
assert all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))

# Actual beauty sheet with all three states, then the fixed Godot game-camera view.
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
cam=bpy.data.objects['T02_PreviewCamera'];scene.camera=cam
cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=42
cam.location=(13,-19,12);cam.rotation_euler=(Vector((0,0,2.7))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=PRE+'/beauty_3quarter.png';bpy.ops.render.render(write_still=True)
orig_locs={r.name:r.location.copy() for r in roots};orig_hide={o.name:o.hide_render for o in meshes};fox_loc=fox.location.copy()
for ob in meshes:ob.hide_render=True
meshes[0].hide_render=False;roots[0].location=(0,0,0);fox.location=(3.2,-2.6,0)
cam.location=(0,-20.57,24.51);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.lens=24/(2*math.tan(math.radians(15)))
scene.render.filepath=PRE+'/game_camera.png';bpy.ops.render.render(write_still=True)

# Export mutually exclusive states as named meshes sharing the same bottom-center pivot.
for r in roots:r.location=(0,0,0)
for ob in meshes:ob.hide_render=orig_hide[ob.name]
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
raw=open(GLB,'rb').read();magic=raw[:4];version,length=struct.unpack('<II',raw[4:12]);chunk_len=struct.unpack('<I',raw[12:16])[0];chunk_type=raw[16:20]
gltf=json.loads(raw[20:20+chunk_len].decode('utf-8'));nodes=gltf.get('nodes',[]);node_names=[n.get('name','') for n in nodes]
prims=[p for m in gltf.get('meshes',[]) for p in m.get('primitives',[])]
checks={
 'glb_v2_header_and_json_length':magic==b'glTF' and version==2 and length==len(raw) and chunk_type==b'JSON' and chunk_len>0,
 'three_named_mutually_exclusive_variants':all(n in node_names for n in [r.name for r in roots]+[m.name for m in meshes]),
 'all_variants_4x4x6_and_grounded':all(all(abs(a-b)<.002 for a,b in zip(variants[r.name]['dimensions_blender_xyz_m'],[4,4,6])) and abs(variants[r.name]['bounds_min_blender_m'][2])<.001 for r in roots),
 'both_T01_connector_profiles_exact_and_planar':all(v['max_profile_deviation_m']<1e-5 and v['east_plane_error_m']<1e-5 and v['north_plane_error_m']<1e-5 for v in connector_checks.values()),
 'single_shared_T01_vertex_color_material':len(gltf.get('materials',[]))==1 and len(material_names)==1 and all('COLOR_0' in p.get('attributes',{}) for p in prims),
 'all_3_variants_manifold_under_5000_triangles':all(v['non_manifold_edges']==v['boundary_edges']==v['loose_edges']==v['loose_vertices']==0 and v['triangles']<5000 for v in variants.values()),
 'preview_fox_stage_and_source_note_excluded':not any(n.startswith(('T02_Fox_','T02_Preview','T02_Source')) for n in node_names),
 'all_indices_reference_nonempty_accessors':all(isinstance(p.get('indices'),int) and 0<=p['indices']<len(gltf.get('accessors',[])) and gltf['accessors'][p['indices']]['count']>0 for p in prims),
 'idle_fox_and_original_default_scene_preserved':fox.animation_data.action.name=='Idle' and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light')),
 'concept_prompt_source_and_both_previews_present':all(os.path.isfile(p) for p in (CONCEPT,PROMPT,OUT+'/source/.gdignore',PRE+'/beauty_3quarter.png',PRE+'/game_camera.png'))
}
assert all(checks.values()),json.dumps(checks,indent=2)
for r in roots:r.location=orig_locs[r.name]
fox.location=fox_loc
shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)

stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={'id':'T02','asset':'t02_cliff_corner_wall','glb':'assets/generated/wind_ruins/t02/t02_cliff_corner_wall.glb',
 'states':variants,'nominal_dimensions_blender_xyz_m':[4,4,6], 'connector_profiles':'At both perpendicular terminal faces, copied from the actual T01 mesh: east x-positive profile and the same profile rotated 90 degrees.',
 'corner_design':'Convex state closes the elbow with one broad diagonal chamfer; concave state pushes the same elbow inward while leaving both connector faces unchanged; broken state derives from convex and removes only one exposed upper corner.',
 'damage':'One large upper corner recession on broad planes; lower support and both T01 connector faces unchanged. No walkable lower ledges.',
 'materials':{'count':len(gltf.get('materials',[])),'names':sorted(material_names),'vertex_colors':True},'triangles_total_across_variants':triangles_total,
 'mesh_parts':len(meshes),'mesh_health':{o.name:topology(o) for o in meshes},'connector_checks':connector_checks,
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':len(raw),'length_matches':length==len(raw),'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(nodes),'glb_mesh_count':len(gltf.get('meshes',[])),'glb_primitive_count':len(prims),'checks':checks,
 'preview':{'beauty':'output/wind_production/t02/beauty_3quarter.png','game_camera':'output/wind_production/t02/game_camera.png','fox':'actual fox_spirit.glb; Idle, correct palette, helper and sword hidden',
            'camera_godot':[0,24.51,20.57],'pitch_down_degrees':50,'vertical_fov_degrees':30,'viewport':[1280,720]},
 'completed_utc':stamp}
for p in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(p,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2);f.write('\n')

state_path=ROOT+'/output/wind_production/asset_state.json'
with open(state_path,encoding='utf-8-sig') as f:state=json.load(f)
was=state['T02'].get('state')=='completed'
state['T02'].update({'state':'completed','outstanding':'none','glb':'assets/generated/wind_ruins/t02/t02_cliff_corner_wall.glb',
 'source':'assets/generated/wind_ruins/t02/source/t02_cliff_corner_wall.blend','preview':'assets/generated/wind_ruins/t02/preview.png',
 'evidence':'output/wind_production/t02/','dimensions_blender_xyz_m':[4,4,6],'variants':variants,'triangles_total':triangles_total,
 'mesh_parts':len(meshes),'materials':sorted(material_names),'connector_checks':connector_checks,'glb_valid':all(checks.values()),
 'self_check':'The convex, concave and broken variants each measure 4 x 4 x 6 m, are grounded at z=0, manifold and under 5,000 triangles. Both perpendicular terminal profiles were sampled at all nine T01 height rings and match the actual T01 end profile to under 0.00001 m; their faces remain planar. Convex uses one broad chamfer, concave recesses the elbow without changing either connector, and broken removes one exposed upper corner while preserving both ends. One T01 vertex-color material, GLB v2/Y-up/header, names, COLOR_0, indices, staging exclusions, actual idle fox, source, concept, previews, original default scene and artifacts checked.',
 'completed_utc':stamp})
state['builder']='luna_builder';state['advisor']='sol_advisor';state['protocol']='Actual2D -> one Sol advisory -> direct3D -> selfcheck/save; no3D approval gate'
if not was:state['completed_count']=int(state.get('completed_count',30))+1;state['pending_count']=int(state.get('pending_count',9))-1
q=state.get('remaining_catalog_order',[])
if q and q[0]=='T02':q=q[1:]
elif 'T02' in q:q.remove('T02')
state['remaining_catalog_order']=q;state['next_asset']=q[0] if q else 'complete'
state['active_blender_scene']='WindProduction_T02'
state['current_task']=f'T02 complete ({stamp}); proceed to {state["next_asset"]} through actual 2D, one Sol advisory, direct MCP Blender build, self-check and save.'
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
if not was:
    audit=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
    with open(audit,'a',encoding='utf-8') as f:
        f.write(f"\n## T02 — direct 3D completion\n\nCompleted {stamp}. Saved `assets/generated/wind_ruins/t02/t02_cliff_corner_wall.glb` ({len(raw):,} bytes), editable Blender source, `.gdignore`, concept, preview and metrics. The convex, concave and broken states each measure 4 x 4 x 6 m. Both flat connector profiles were sampled at all nine T01 height rings from its actual mesh and match within 0.00001 m; connector faces remain planar. The broken state removes only one exposed upper corner. All three states are manifold and use one shared T01 vertex-color material. GLB v2/Y-up/header, node names, `COLOR_0`, indices, staging exclusions, fox, source artifacts and default scene checked. Beauty and fixed game-camera previews saved. Next: {state['next_asset']}.\n")
print('T02_COMPLETE',json.dumps({'glb_bytes':len(raw),'source_bytes':os.path.getsize(BLEND),'triangles_total':triangles_total,
 'variants':variants,'connector_checks':connector_checks,'checks':checks,'next_asset':state['next_asset'],
 'completed_count':state['completed_count'],'pending_count':state['pending_count']}))
