import bpy, bmesh, json, math, os, shutil, struct
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/l01'
PRE=ROOT+'/output/wind_production/l01'
CONCEPT=ROOT+'/output/wind_production/concepts/l01_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/l01_prompt.txt'
GLB=OUT+'/l01_wind_ritual_gate.glb'
BLEND=OUT+'/source/l01_wind_ritual_gate.blend'
if os.path.exists(GLB):
    with open(PRE+'/metrics.json',encoding='utf-8') as f: prior=json.load(f)
    assert prior.get('id')=='L01' and prior.get('asset')=='l01_wind_ritual_gate','Refusing to replace a different asset'
if os.path.exists(BLEND):
    assert os.path.basename(BLEND)=='l01_wind_ritual_gate.blend','Refusing to replace a different source file'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(CONCEPT,OUT+'/concept.png')
shutil.copy2(PROMPT,PRE+'/concept_prompt.txt')

scene=bpy.data.scenes['WindProduction_L01']; bpy.context.window.scene=scene
export=bpy.data.collections['L01_Export']; source=bpy.data.collections['L01_SourceLocators_NOT_EXPORTED']
intact=bpy.data.objects['L01_Intact_RuinedGate']; damaged=bpy.data.objects['L01_Damaged_RuinedGate']
preview=bpy.data.collections['L01_Preview_ONLY']; cam=bpy.data.objects['L01_PreviewCamera']
fox=next(o for o in preview.objects if o.type=='ARMATURE' and o.name.startswith('L01_Fox_'))
assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name.startswith('Idle')
assert all('Sword' not in o.name and 'Icosphere' not in o.name for o in preview.objects if o.type=='MESH' and not o.hide_render)
assert bpy.data.scenes.get('Scene') is not None

def state_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def measure(root):
    bpy.context.view_layer.update(); meshes=state_meshes(root); pts=[]; health=[]
    for ob in meshes:
        for v in ob.data.vertices: pts.append(root.matrix_world.inverted() @ (ob.matrix_world @ v.co))
        bm=bmesh.new(); bm.from_mesh(ob.data)
        tri=sum(max(0,len(p.verts)-2) for p in bm.faces)
        health.append({'mesh':ob.name,'triangles':tri,
                       'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
                       'boundary_edges':sum(e.is_boundary for e in bm.edges),
                       'loose_edges':sum(not e.link_faces for e in bm.edges)})
        bm.free()
    lo=[min(p[i] for p in pts) for i in range(3)]; hi=[max(p[i] for p in pts) for i in range(3)]
    dims=[hi[i]-lo[i] for i in range(3)]
    return {'bounds_min_blender_m':[round(x,6) for x in lo],
            'bounds_max_blender_m':[round(x,6) for x in hi],
            'dimensions_blender_xyz_m':[round(x,6) for x in dims],
            'dimensions_godot_xyz_m':[round(dims[0],6),round(dims[2],6),round(dims[1],6)],
            'mesh_parts':len(meshes),'triangles':sum(h['triangles'] for h in health),
            'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),
            'boundary_edges':sum(h['boundary_edges'] for h in health),
            'loose_edges':sum(h['loose_edges'] for h in health),'mesh_health':health}

oldloc={r.name:r.location.copy() for r in (intact,damaged)}
foxloc=fox.location.copy(); oldfoxhide=fox.hide_render
# All exported model parts belong in both validation renders and the saved source gallery.
mesh_hides={o.name:False for o in state_meshes(intact)+state_meshes(damaged)}
camstate=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.lens,cam.data.sensor_fit,cam.data.sensor_height)
resolution=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)
scene.render.engine='CYCLES'; scene.cycles.samples=18; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24

# Measure both states at their common bottom-center placement origin.
intact.location=(0,0,0); damaged.location=(0,0,0)
states={'intact':measure(intact),'damaged':measure(damaged)}
materials={m for o in state_meshes(intact)+state_meshes(damaged) for m in o.data.materials}

def shoot(name,location,target,lens):
    cam.location=location; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.lens=lens; scene.camera=cam; scene.render.filepath=PRE+'/'+name+'.png'
    bpy.ops.render.render(write_still=True)

# Studio comparison: both states and the actual Idle fox, at its imported 1.755 m scale.
intact.location=(-4.15,0,0); damaged.location=(4.15,0,0); fox.location=(0,-1.35,0); fox.hide_render=oldfoxhide
for ob in state_meshes(intact)+state_meshes(damaged): ob.hide_render=mesh_hides[ob.name]
shoot('beauty_3quarter',(5,-30,10),(0,0,2.65),40)

# Fixed project gameplay camera: damaged gate is centered, the fox stands inside the doorway.
for ob in state_meshes(intact): ob.hide_render=True
for ob in state_meshes(damaged): ob.hide_render=mesh_hides[ob.name]
intact.location=(12,0,0); damaged.location=(0,0,0); fox.location=(.85,-1.4,0); fox.hide_render=False
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

# Validate catalog limits and the actual measured clear opening at the widest base points.
def world_points(root):
    bpy.context.view_layer.update()
    inv=root.matrix_world.inverted()
    return [inv @ (ob.matrix_world @ v.co) for ob in state_meshes(root) for v in ob.data.vertices]
def opening_width(root):
    pts=world_points(root)
    left=max(p.x for p in pts if p.x < 0 and p.z <= .21)
    right=min(p.x for p in pts if p.x > 0 and p.z <= .21)
    return right-left
beam_bottom=min(v.co.z for o in state_meshes(intact) if 'Crossbeam' in o.name for v in o.data.vertices)
open_w=opening_width(intact); open_h=beam_bottom
assert open_w>=4.5 and open_h>=4.2, (open_w,open_h)
for label,s in states.items():
    x,y,z=s['dimensions_blender_xyz_m']
    assert x<=7.2+1e-6 and y<=2.4+1e-6 and z<=5.8+1e-6,(label,x,y,z)
    assert s['triangles']<5000
    assert s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0, (label,s['mesh_health'])
assert len(materials)==1
assert all(m.name=='L01_SharedPalette_VertexColor' for m in materials)
assert all(o.parent in (intact,damaged) for o in state_meshes(intact)+state_meshes(damaged))
assert len(source.objects)==5 and all(o.get('source_only') for o in source.objects if o.type=='EMPTY' and o.name.startswith('L01_Source_'))

# Restore both states to the same origin and export only the exact L01 asset collection.
for r in (intact,damaged): r.location=(0,0,0)
for o in bpy.context.view_layer.objects: o.select_set(False)
for o in export.objects: o.select_set(True)
bpy.context.view_layer.objects.active=intact
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)

with open(GLB,'rb') as f:
    magic,version,declared=struct.unpack('<4sII',f.read(12)); json_len,chunk_type=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(json_len))
glb_size=os.path.getsize(GLB); node_names=[n.get('name','') for n in gltf.get('nodes',[])]
checks={
 'intact_and_damaged_states_exported':all(n in node_names for n in (intact.name,damaged.name)),
 'source_locators_preview_fox_and_ground_excluded':not any(('L01_Source_' in n or 'L01_Fox_' in n or 'Preview' in n) for n in node_names),
 'portal_width_measured_between_base_faces_at_least_4_5m':open_w>=4.5,
 'portal_height_to_lowest_crossbeam_at_least_4_2m':open_h>=4.2,
 'both_states_inside_7_2_by_2_4_by_5_8m_envelope':all(s['dimensions_blender_xyz_m'][0]<=7.2+1e-6 and s['dimensions_blender_xyz_m'][1]<=2.4+1e-6 and s['dimensions_blender_xyz_m'][2]<=5.8+1e-6 for s in states.values()),
 'all_meshes_closed_manifold_no_boundary_or_loose_edges':all(s['non_manifold_edges']==0 and s['boundary_edges']==0 and s['loose_edges']==0 for s in states.values()),
 'one_shared_vertex_color_material':len(materials)==1 and materials.pop().name=='L01_SharedPalette_VertexColor',
 'source_pivot_is_ground_center':all(tuple(round(v,6) for v in r.location)==(0.0,0.0,0.0) for r in (intact,damaged)),
 'original_default_scene_preserved':bpy.data.scenes.get('Scene') is not None,
 'glb_y_up_header_and_length_valid':magic==b'glTF' and version==2 and declared==glb_size and chunk_type==b'JSON',
 'source_gdignore_exists_and_empty':os.path.exists(OUT+'/source/.gdignore') and os.path.getsize(OUT+'/source/.gdignore')==0,
 'concept_and_prompt_saved':os.path.exists(OUT+'/concept.png') and os.path.exists(PRE+'/concept_prompt.txt')
}
assert all(checks.values()),json.dumps(checks,indent=2)

metrics={
 'id':'L01','asset':'l01_wind_ritual_gate','glb':'assets/generated/wind_ruins/l01/l01_wind_ritual_gate.glb',
 'states':states,'opening_clear_width_m':round(open_w,6),'opening_clear_height_to_lowest_crossbeam_m':round(open_h,6),
 'dimensions_catalog_envelope_m':[7.2,2.4,5.8],
 'materials':{'count':1,'names':['L01_SharedPalette_VertexColor'],'vertex_color_palette':True,'emission':'none'},
 'triangles_total_across_states':states['intact']['triangles']+states['damaged']['triangles'],
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':declared,'file_size':glb_size,'length_matches':declared==glb_size,'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(node_names),'game_camera_blender_location':[0,-20.57,24.51],'game_camera_pitch_down_degrees':50,
 'game_camera_vertical_fov_deg':30,'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'damage':'One right-front roof corner clipped with three broad exposed facets and one recessed chipped plane on the right pedestal; no loose rubble and no doorway obstruction.',
 'banner_emblem':'F01-matched open ring with three same-direction wind strokes on both sides of two broad-fold ivory banners.',
 'source_locators':[{'name':o.name,'coordinates_m':list(o.location),'source_only':True} for o in source.objects if o.name.startswith('L01_Source_')],
 'concept':'output/wind_production/concepts/l01_concept_v1.png',
 'advisory':'Measure clear opening at least 4.5 x 4.2 m between the widest column bases and lowest beam; keep shallow roof and outward banners within 7.2 x 2.4 x 5.8 m. Use A01 column language and one clean crossbeam, omit gold diamonds, fine inset lines, and tiered trim. Reuse F01 open-ring/three-stroke emblem with broad folds. Derive one roof-corner break with 2-3 broad planes and chip one column only; keep doorway clear.',
 'self_check':checks,'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export/save; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for im in bpy.data.images:
    if 'fox_palette' in im.name.lower() and not im.packed_file:
        try: im.pack()
        except Exception: pass

# Preserve the studio gallery arrangement in the source file after preview renders/export.
intact.location=(-4.15,0,0); damaged.location=(4.15,0,0); fox.location=(0,-1.35,0); fox.hide_render=oldfoxhide
for ob in state_meshes(intact)+state_meshes(damaged): ob.hide_render=mesh_hides[ob.name]
cam.location=camstate[0]; cam.rotation_euler=camstate[1]; cam.data.lens=camstate[2]; cam.data.sensor_fit=camstate[3]; cam.data.sensor_height=camstate[4]
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=resolution
scene.render.filepath=PRE+'/beauty_3quarter.png'; scene.camera=cam
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=BLEND,copy=True)
print('L01_COMPLETE',json.dumps({'states':{k:{'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'non_manifold_edges':v['non_manifold_edges'],'boundary_edges':v['boundary_edges']} for k,v in states.items()},'opening_clear_m':[open_w,open_h],'checks':checks,'glb_bytes':glb_size,'source':BLEND}))
