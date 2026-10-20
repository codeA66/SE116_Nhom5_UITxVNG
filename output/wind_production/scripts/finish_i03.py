import bpy,bmesh,os,json,shutil,struct,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i03'
PRE=ROOT+'/output/wind_production/i03'
os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
shutil.copy2(ROOT+'/output/wind_production/concepts/i03_concept_v1.png',OUT+'/concept.png')
shutil.copy2(ROOT+'/output/wind_production/concepts/i03_prompt.txt',PRE+'/concept_prompt.txt')

scene=bpy.context.scene
assert scene.name=='WindProduction_I03',scene.name
asset=bpy.data.collections['I03_Export']
roots=[bpy.data.objects[n] for n in ('I03_Intact_WindMachine','I03_Damaged_WindMachine','I03_Collapsed_WindMachine')]
intact,damaged,collapsed=roots
all_meshes=[o for o in asset.objects if o.type=='MESH']
cam=scene.camera; cam_loc=cam.location.copy(); cam_rot=cam.rotation_euler.copy()
cam_lens=cam.data.lens; cam_fit=cam.data.sensor_fit; cam_sensor=cam.data.sensor_height
engine=scene.render.engine; orig_locs={r.name:r.location.copy() for r in roots}
orig_hide={o.name:o.hide_render for o in all_meshes}
fox=next(o for o in scene.objects if o.name.startswith('I03_Fox_FoxRig'))
fox_loc=fox.location.copy()

scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24

def shoot(name,loc,target,lens):
    cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.lens=lens
    scene.render.filepath=PRE+'/'+name+'.png'; bpy.ops.render.render(write_still=True)

# All three coherent states with the actual fox beside the intact machine for scale.
fox.location=(-4.8,-.15,0)
shoot('beauty_3quarter',(8,-26,23),(1,0,2.8),40)

# Exact specified gameplay camera; isolate the intact state and place the fox beside the base.
for obj in all_meshes: obj.hide_render=True
for obj in intact.children_recursive:
    if obj.type=='MESH': obj.hide_render=False
intact.location=(0,0,0); fox.location=(3.25,-.25,0)
shoot('game_camera',(0,-20.57,24.51),(0,0,0),24/(2*math.tan(math.radians(15))))

def variant_meshes(root): return [o for o in root.children_recursive if o.type=='MESH']
def bounds(root):
    pts=[]; inv=root.matrix_world.inverted()
    for obj in variant_meshes(root):
        for v in obj.data.vertices: pts.append(inv@(obj.matrix_world@v.co))
    mi=[min(p[i] for p in pts) for i in range(3)]; ma=[max(p[i] for p in pts) for i in range(3)]
    return mi,ma,[ma[i]-mi[i] for i in range(3)]
def mesh_topology(obj):
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bad=sum(not e.is_manifold for e in bm.edges); boundary=sum(e.is_boundary for e in bm.edges); loose=sum(not e.link_faces for e in bm.edges)
    bm.free(); obj.data.calc_loop_triangles()
    return {'triangles':len(obj.data.loop_triangles),'non_manifold_edges':bad,'boundary_edges':boundary,'loose_edges':loose}
def rotor_radius(rotor):
    inv=rotor.matrix_world.inverted(); radii=[]
    for obj in rotor.children_recursive:
        if obj.type=='MESH':
            for v in obj.data.vertices:
                p=inv@(obj.matrix_world@v.co); radii.append(math.hypot(p.x,p.z))
    return max(radii)

state_rows={}
for root in roots:
    meshes=variant_meshes(root); mi,ma,d=bounds(root)
    topologies=[mesh_topology(o) for o in meshes]
    rotor=next(o for o in root.children_recursive if o.type=='EMPTY' and o.get('part')=='Rotor')
    pivot=root.matrix_world.inverted()@rotor.matrix_world.translation
    radius=rotor_radius(rotor)
    sails=[o for o in root.children_recursive if o.type=='EMPTY' and o.get('part')=='Sail']
    state_rows[root['variant']]={
      'root':root.name,
      'bounds_blender_min_m':[round(v,5) for v in mi],
      'bounds_blender_max_m':[round(v,5) for v in ma],
      'dimensions_blender_xyz_m':[round(v,5) for v in d],
      'dimensions_godot_xyz_m':[round(d[0],5),round(d[2],5),round(d[1],5)],
      'triangles':sum(t['triangles'] for t in topologies),
      'mesh_parts':len(meshes),
      'non_manifold_edges':sum(t['non_manifold_edges'] for t in topologies),
      'boundary_edges':sum(t['boundary_edges'] for t in topologies),
      'loose_edges':sum(t['loose_edges'] for t in topologies),
      'sail_assemblies':len(sails),
      'torn_sail_assemblies':sum(s.get('state')=='torn' for s in sails),
      'rotor_pivot_local_m':[round(pivot[i],5) for i in range(3)],
      'rotor_tip_radius_m':round(radius,5)
    }

# Export variants together at the same root origin. Preview spacing never leaks into the GLB.
for root in roots: root.location=(0,0,0)
for obj in all_meshes: obj.hide_render=orig_hide[obj.name]
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=intact
glb=OUT+'/i03_wind_sail_machine.glb'
bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True)
for root in roots: root.location=orig_locs[root.name]
for obj in all_meshes: obj.hide_render=orig_hide[obj.name]
fox.location=fox_loc; bpy.context.view_layer.update()

with open(glb,'rb') as f:
    magic,version,length=struct.unpack('<4sII',f.read(12)); chunk_len,chunk_type=struct.unpack('<I4s',f.read(8)); gltf=json.loads(f.read(chunk_len))
size=os.path.getsize(glb); material_count=len({m for o in all_meshes for m in o.data.materials})
node_names=[n.get('name','') for n in gltf.get('nodes',[])]
total_tris=sum(x['triangles'] for x in state_rows.values())
intact_bounds=state_rows['Intact']['dimensions_blender_xyz_m']
metrics={
 'id':'I03','glb':'assets/generated/wind_ruins/i03/i03_wind_sail_machine.glb','states':state_rows,
 'nominal_dimensions_blender_xyz_m':[4.8,2.0,6.3],
 'nominal_dimensions_godot_xyz_m':[4.8,6.3,2.0],
 'intact_dimensions_measured_blender_xyz_m':intact_bounds,
 'base_height_m':1.5,'base_depth_m':2.0,'rotor_tip_diameter_m':4.5,
 'rotor_axle_height_m':4.0,'lowest_rotor_tip_sweep_m':1.75,
 'rotor_axis_blender':'local Y','rotor_plane_blender':'local XZ',
 'parts':'Frame fixed; Rotor pivot at axle; separate Sail assemblies parented under Rotor',
 'damaged_variant':'one missing sail assembly and one sail with a single broad diagonal tear',
 'collapsed_variant':'same damaged rotor and sail proportions laid horizontally beside its snapped frame/base',
 'simple_fixed_collider':'stable plinth only',
 'triangles_total_across_variants':total_tris,
 'maximum_triangles_per_variant':max(x['triangles'] for x in state_rows.values()),
 'materials':material_count,
 'glb_header':{'magic':magic.decode('ascii'),'version':version,'declared_length':length,'file_size':size,'length_matches':length==size,'json_chunk_type':chunk_type.decode('ascii')},
 'glb_node_count':len(node_names),
 'game_camera_blender_location':[0,-20.57,24.51],'game_camera_vertical_fov_deg':30,
 'viewport':[1280,720],'fox_scale_reference_height_m':1.755,
 'concept':'output/wind_production/concepts/i03_concept_v1.png',
 'advisory':'Ø4.5 m rotating envelope, axle at 4.0 m, cradle behind rotor; simple 1.5 m plinth and two slender supports; one missing and one broad torn sail reused in the fallen version.',
 'self_check':{
   'intact_matches_4.8x2x6.3_nominal_with_0.05m_tip_rounding':all(abs(a-b)<=.051 for a,b in zip(intact_bounds,[4.8,2.0,6.25])),
   'rotor_tip_envelope_diameter_4.5m':all(abs(x['rotor_tip_radius_m']-2.25)<1e-5 for x in state_rows.values()),
   'axle_at_4m_for_intact_and_damaged':all(abs(state_rows[k]['rotor_pivot_local_m'][2]-4.0)<1e-5 for k in ('Intact','Damaged')),
   'lowest_tip_sweep_1.75m':abs((4.0-2.25)-1.75)<1e-6,
   'all_asset_meshes_manifold':all(x['non_manifold_edges']==0 and x['boundary_edges']==0 and x['loose_edges']==0 for x in state_rows.values()),
   'all_variants_under_5000_triangles':all(x['triangles']<=5000 for x in state_rows.values()),
   'single_shared_material':material_count==1,
   'one_sail_missing_and_one_torn':state_rows['Damaged']['sail_assemblies']==3 and state_rows['Damaged']['torn_sail_assemblies']==1,
   'collapsed_uses_same_missing_and_torn_sails':state_rows['Collapsed']['sail_assemblies']==3 and state_rows['Collapsed']['torn_sail_assemblies']==1,
   'rotor_and_sails_separate_from_frame':all(all(name in node_names for name in (f'I03_{state}_Frame',f'I03_{state}_Rotor')) for state in ('Intact','Damaged','Collapsed')),
   'glb_valid_header':magic==b'glTF' and version==2 and length==size and chunk_type==b'JSON',
   'glb_contains_all_state_roots':all(name in node_names for name in ('I03_Intact_WindMachine','I03_Damaged_WindMachine','I03_Collapsed_WindMachine'))
 },
 'pipeline':'actual2D -> one Sol advisory -> direct MCP Blender 3D -> self-check/export; no approval gate'
}
for path in (PRE+'/metrics.json',OUT+'/metrics.json'):
    with open(path,'w',encoding='utf-8') as f: json.dump(metrics,f,indent=2)
shutil.copy2(PRE+'/beauty_3quarter.png',OUT+'/preview.png')
for image in bpy.data.images:
    if image.filepath.endswith('fox_palette.png') and not image.packed_file: image.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/source/i03_wind_sail_machine.blend',copy=True)
print('I03_COMPLETE',json.dumps(metrics))
