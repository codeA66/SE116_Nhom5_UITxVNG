import bpy, bmesh, json, math, os, shutil, struct
from datetime import datetime, timezone
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'; OUT=ROOT+'/assets/generated/wind_ruins/a02'; PRE=ROOT+'/output/wind_production/a02'
GLB=OUT+'/a02_ceremonial_lintel_beam.glb'; SOURCE=OUT+'/source/a02_ceremonial_lintel_beam.blend'; STATE=ROOT+'/output/wind_production/asset_state.json'; AUDIT=ROOT+'/output/wind_production/reviews/workflow_order_audit.md'
assert bpy.context.scene.name=='WindProduction_A02'
assert not os.path.exists(GLB) and not os.path.exists(SOURCE)
scene=bpy.context.scene; camera=bpy.data.objects['A02_PreviewCamera']; scene.camera=camera
intact=bpy.data.objects['A02_Intact']; left=bpy.data.objects['A02_Broken_Left']; right=bpy.data.objects['A02_Broken_Right']
intact_mesh=bpy.data.objects['A02_Intact_Beam']; left_mesh=bpy.data.objects['A02_Broken_Left_Beam']; right_mesh=bpy.data.objects['A02_Broken_Right_Beam']
fox=bpy.data.objects['A02_PreviewFox_FoxRig']

old_cam=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height)
old_render=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising)
asset_objects=[intact,left,right]; old_locs={o.name:o.location.copy() for o in asset_objects}; old_rots={o.name:o.rotation_euler.copy() for o in asset_objects}; old_fox=fox.location.copy()
meshes=[intact_mesh,left_mesh,right_mesh]; old_hide={o.name:o.hide_render for o in meshes}
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24
def aim(loc,target,lens):
    camera.location=loc; camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.lens=lens
def render(name,loc,target,lens):
    aim(loc,target,lens); scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# Beauty view shows the assembled lintel beside its matching two-piece break, with the Idle fox for scale.
intact.location=(-3,0,0); left.location=(3-1-.075,0,0); right.location=(3+1+.075,0,0)
left.rotation_euler.y=math.radians(-1.5); right.rotation_euler.y=math.radians(1.5)
fox.location=(0,-.72,0)
render('beauty_3quarter',(1,-10,6.4),(0,0,.36),46)

# The exact game-camera pose and 30-degree vertical field of view provide a scale/readability check.
intact.location=(0,0,0); left.location=(-1,0,0); right.location=(1,0,0)
left.rotation_euler=(0,0,0); right.rotation_euler=(0,0,0)
left_mesh.hide_render=True; right_mesh.hide_render=True; fox.location=(2.7,-.2,0)
game_lens=24.0/(2.0*math.tan(math.radians(15.0)))
render('game_camera',(0,-20.57,24.51),(0,0,0),game_lens)

# Restore product pivots and scene settings before measuring and exporting only A02_Export.
for o in asset_objects:o.location=old_locs[o.name];o.rotation_euler=old_rots[o.name]
fox.location=old_fox
for o in meshes:o.hide_render=old_hide[o.name]
camera.location,camera.rotation_euler,camera.data.lens,camera.data.type,camera.data.sensor_fit,camera.data.sensor_height=old_cam
scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples,scene.cycles.use_denoising=old_render

def bounds_world(root):
    pts=[]
    for ob in root.children_recursive:
        if ob.type=='MESH': pts.extend(root.matrix_world.inverted()@(ob.matrix_world@v.co) for v in ob.data.vertices)
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]
    return lo,hi,[hi[i]-lo[i] for i in range(3)]
def health(ob):
    bm=bmesh.new();bm.from_mesh(ob.data)
    out={'vertices':len(bm.verts),'faces':len(bm.faces),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(not e.link_faces for e in bm.edges),'loose_vertices':sum(not v.link_edges for v in bm.verts)}
    bm.free();ob.data.calc_loop_triangles();out['triangles']=len(ob.data.loop_triangles);return out
states={}
for root,ob,label in [(intact,intact_mesh,'intact'),(left,left_mesh,'broken_left'),(right,right_mesh,'broken_right')]:
    lo,hi,dims=bounds_world(root)
    if label=='intact': assert all(abs(a-b)<.003 for a,b in zip(dims,(4,.45,.6))),(label,lo,hi,dims)
    else: assert 2.0<dims[0]<2.1 and abs(dims[1]-.45)<.003 and abs(dims[2]-.6)<.003,(label,lo,hi,dims)
    h=health(ob);assert h['non_manifold_edges']==h['boundary_edges']==h['loose_edges']==h['loose_vertices']==0,(label,h)
    assert h['triangles']<5000 and len(ob.data.materials)==1 and ob.data.color_attributes.get('Color')
    states[label]={'bounds_min_local_m':[round(x,6) for x in lo],'bounds_max_local_m':[round(x,6) for x in hi],'dimensions_m':[round(x,6) for x in dims],'mesh_health':h}

# Verify the two fractured profiles coincide in the assembled pose, including the broad planar interface.
def cut_points(ob,side):
    pts=[]; center=1.0 if side=='left' else -1.0
    for v in ob.data.vertices:
        if abs(v.co.x-center)<.12:
            p=ob.matrix_world@v.co;pts.append(tuple(round(float(x),5) for x in p))
    return sorted(pts)
left_cut=cut_points(left_mesh,'left');right_cut=cut_points(right_mesh,'right')
assert len(left_cut)==len(right_cut) and left_cut==right_cut,(len(left_cut),len(right_cut),left_cut[:3],right_cut[:3])

export=bpy.data.collections['A02_Export']
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for ob in export.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12));json_len,json_type=struct.unpack('<I4s',f.read(8));gltf=json.loads(f.read(json_len).decode('utf-8'))
size=os.path.getsize(GLB);assert magic==b'glTF' and version==2 and declared==size and json_type==b'JSON'
assert gltf.get('asset',{}).get('version')=='2.0';assert len(gltf.get('materials',[]))==1
mesh_rows=[]
for m in gltf.get('meshes',[]):
    prims=m.get('primitives',[]);assert prims and all('COLOR_0' in p.get('attributes',{}) for p in prims),(m.get('name'),prims)
    mesh_rows.append({'name':m.get('name'),'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for p in prims),'primitives':len(prims)})
node_names={n.get('name') for n in gltf.get('nodes',[])}
assert {'A02_Intact','A02_Broken_Left','A02_Broken_Right','A02_Intact_Beam','A02_Broken_Left_Beam','A02_Broken_Right_Beam'}<=node_names,node_names
assert len(mesh_rows)==3 and sum(m['triangles'] for m in mesh_rows)<5000,mesh_rows
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
advisory='Keep the underside curve very shallow and retain the exact 4 x 0.45 x 0.60 m section with flat X=±2 m connectors and center-underside pivot. Use clean broad faces, at most one restrained band, and only a few large underside segments. Split the actual intact mesh at X=0 into matching halves using 2-3 broad fracture planes.'
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
metrics={'id':'A02','asset':'ceremonial lintel beam','glb':'assets/generated/wind_ruins/a02/a02_ceremonial_lintel_beam.glb','source':'assets/generated/wind_ruins/a02/source/a02_ceremonial_lintel_beam.blend','concept':'assets/generated/wind_ruins/a02/concept.png','states':states,'dimensions_blender_xyz_m':[4,.45,.6],'dimensions_godot_xyz_m':[4,.6,.45],'pivot':'center of underside, X=0; beam endpoints and connectors at X=±2 m','break':'same beam cross-section split at X=0; matching four broad planar faces (three-level cut profile), no independently sculpted fragment','materials':1,'glb_meshes':mesh_rows,'glb_bytes':size,'glb_v2_y_up_header':True,'color_attributes':'COLOR_0 on every primitive','advisory':advisory,'game_camera':[0,24.51,20.57],'vertical_fov_degrees':30,'self_check':'Intact envelope exactly 4 x 0.45 x 0.60 m; halves fit exact original endpoints and share identical fracture vertices; each mesh manifold, under 5000 triangles, one shared material; GLB v2 header/names/COLOR_0 verified; default Scene/Cube/Camera/Light preserved.','completed_utc':stamp}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f:json.dump(metrics,f,ensure_ascii=False,indent=2)
for img in bpy.data.images:
    if img.filepath.lower().endswith('fox_palette.png') and not img.packed_file:img.pack()

# Source opens on the broken state; the intact mesh remains present and available in the collection.
intact.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,copy=True)
with open(STATE,'r',encoding='utf-8') as f:state=json.load(f)
completed_before=sum(1 for aid in state.get('production_catalog_ids',[]) if isinstance(state.get(aid),dict) and state[aid].get('state')=='completed')
assert completed_before==33,('unexpected completion count',completed_before)
a=state['A02'];a.update({'state':'completed','concept':'output/wind_production/concepts/a02_concept_v1.png','prompt':'output/wind_production/concepts/a02_prompt.txt','generation':'built-in imagegen','advisor':'sol_advisor','advisory':advisory,'advisory_received_from':'sol_advisor','advisory_received_utc':state.get('A02',{}).get('advisory_received_utc',stamp),'modeling_started_utc':state.get('A02',{}).get('modeling_started_utc',stamp),'destination':'assets/generated/wind_ruins/a02/','glb':'assets/generated/wind_ruins/a02/a02_ceremonial_lintel_beam.glb','source':'assets/generated/wind_ruins/a02/source/a02_ceremonial_lintel_beam.blend','preview':'assets/generated/wind_ruins/a02/preview.png','evidence':'output/wind_production/a02/','triangles':sum(m['triangles'] for m in mesh_rows),'materials':1,'dimensions_blender_xyz_m':[4,.45,.6],'dimensions_godot_xyz_m':[4,.6,.45],'non_manifold_edges':0,'glb_valid':True,'self_check':metrics['self_check'],'outstanding':'none','completed_utc':stamp})
state['active_blender_scene']='WindProduction_A02';state['production_queue']=[aid for aid in state.get('production_queue',[]) if aid!='A02'];state['completed_count']=completed_before+1;state['current_task']='A02 complete; next A03, then A04-A05 and I01-I02.';state['last_updated_utc']=stamp
state['next_asset']='A03'
with open(STATE,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
with open(AUDIT,'a',encoding='utf-8') as f:f.write('\n## A02 - 3D completion\n\nApplied the one Sol advisory directly: shallow underside curve, exact connectors and pivot, clean broad faces, and matching planar halves cut from the same intact beam. Exported and self-checked the live Blender GLB; no extra review gate.\n')
print('A02_COMPLETE',json.dumps({'glb_bytes':size,'triangles':sum(m['triangles'] for m in mesh_rows),'dimensions':[4,.45,.6],'states':states,'matching_cut_vertices':len(left_cut),'materials':1,'completed_before':completed_before,'completed_after':completed_before+1,'remaining_queue':state['production_queue']},separators=(',',':')))
