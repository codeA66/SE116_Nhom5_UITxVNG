import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/n02'
PRE = ROOT + '/output/wind_production/n02'
CONCEPT = ROOT + '/output/wind_production/concepts/n02_concept_v1.png'
PROMPT = ROOT + '/output/wind_production/concepts/n02_prompt.txt'

def srgb8(hex_value):
    q = [int(hex_value[i:i+2], 16) / 255 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in q) + (1,)

COLORS = {
    'leaf_dark': srgb8('#59634F'), 'leaf_base': srgb8('#68745B'),
    'leaf_mid': srgb8('#727F63'), 'leaf_light': srgb8('#7B876A'),
    'leaf_edge': srgb8('#515C4A'), 'grass_dark': srgb8('#58634E'),
    'grass_base': srgb8('#68735A'), 'grass_mid': srgb8('#748066'),
    'grass_light': srgb8('#7D886D')
}

def material():
    m = bpy.data.materials.new('N02_Shared_Muted_Sage_VertexColor')
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bs.inputs['Roughness'].default_value = .93
    vc = m.node_tree.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = 'Color'
    m.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
    return m

def make_mesh(collection, name, verts, faces, mat, face_colors, props=None):
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(verts, [], faces)
    me.update()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(mat)
    ca = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    assert len(me.polygons) == len(face_colors), (name, len(me.polygons), len(face_colors))
    for poly, color in zip(me.polygons, face_colors):
        rgba = COLORS[color]
        for li in poly.loop_indices:
            ca.data[li].color = rgba
    ob = bpy.data.objects.new(name, me); collection.objects.link(ob)
    ob['surface_style'] = 'broad_faceted_low_poly_planes'
    if props:
        for key, value in props.items(): ob[key] = value
    return ob

def swept_leaf(collection, name, center, length, depth, height, mat, tint='leaf'):
    """One closed, broad faceted leaf-mass swept along local +X with pointed ends."""
    cx, cy, cz = center
    stations = [(-1.0, .52), (-.72, .78), (-.35, .96), (0.0, 1.0), (.42, .74), (.78, .38)]
    sides = 8
    verts = []
    ring_starts = []
    for t, scale in stations:
        ring_starts.append(len(verts))
        for j in range(sides):
            a = 2 * math.pi * j / sides
            wind_sweep = max(0.0, (t+1.0)/2.0)
            verts.append((cx + t*length/2, cy + math.cos(a)*depth/2*scale + .035*wind_sweep,
                          cz + math.sin(a)*height/2*scale + .075*wind_sweep))
    end_tip = len(verts); verts.append((cx + length/2, cy+.035, cz+.075))
    faces=[tuple(reversed(range(ring_starts[0],ring_starts[0]+sides)))]; colors=[tint+'_dark']
    palette = [tint+'_mid', tint+'_base', tint+'_light', tint+'_light',
               tint+'_light', tint+'_mid', tint+'_base', tint+'_dark']
    for r in range(len(stations)-1):
        a0, a1 = ring_starts[r], ring_starts[r+1]
        for j in range(sides):
            faces.append((a0+j, a1+j, a1+(j+1)%sides, a0+(j+1)%sides))
            colors.append(palette[j])
    last = ring_starts[-1]
    for j in range(sides):
        faces.append((last+j, end_tip, last+(j+1)%sides))
        colors.append(tint+'_base' if j in (1, 2, 3) else tint+'_dark')
    return make_mesh(collection, name, verts, faces, mat, colors, {
        'part_role': 'broad_swept_foliage_mass', 'wind_direction_local_x': 1.0,
        'mass_length_m': length, 'silhouette': 'one tapered faceted mass; not individual leaves'
    })

def bent_blade(collection, name, points, widths, thicknesses, mat, color_prefix='grass'):
    """Closed four-sided tapered ribbon following a bent centerline, ending in a point."""
    p = [Vector(v) for v in points]
    verts = [tuple(p[0])]; rings=[]; faces=[]; colors=[]
    for k in range(1, len(p)-1):
        tangent = (p[k+1] - p[k-1]).normalized()
        horizontal = Vector((tangent.x, tangent.y, 0))
        if horizontal.length < 1e-5: horizontal = Vector((1, 0, 0))
        horizontal.normalize()
        width_axis = Vector((-horizontal.y, horizontal.x, 0)).normalized()
        normal = tangent.cross(width_axis).normalized()
        start = len(verts); rings.append(start)
        w, d = widths[k], thicknesses[k]
        for a,b in ((-1,-1),(1,-1),(1,1),(-1,1)):
            v = p[k] + width_axis*(a*w) + normal*(b*d)
            verts.append(tuple(v))
    tip = len(verts); verts.append(tuple(p[-1]))
    for j in range(4):
        faces.append((0, rings[0]+(j+1)%4, rings[0]+j))
        colors.append(color_prefix+'_dark' if j in (0,3) else color_prefix+'_base')
    for r in range(len(rings)-1):
        for j in range(4):
            faces.append((rings[r]+j, rings[r]+(j+1)%4,
                          rings[r+1]+(j+1)%4, rings[r+1]+j))
            colors.append((color_prefix+'_base',color_prefix+'_mid',color_prefix+'_light',color_prefix+'_mid')[j])
    for j in range(4):
        faces.append((rings[-1]+j, rings[-1]+(j+1)%4, tip))
        colors.append(color_prefix+'_mid' if j in (1,2) else color_prefix+'_dark')
    return make_mesh(collection, name, verts, faces, mat, colors, {
        'part_role': 'one_bent_grass_blade', 'wind_direction_local_x': 1.0,
        'surface_style': 'slender_broad_plane_with_thick_closed_edge'
    })

def parent_mesh(ob, root):
    ob.parent = root
    ob.matrix_parent_inverse = type(ob.matrix_parent_inverse).Identity(4)

def normalize_envelope(root, target):
    meshes = [o for o in root.children_recursive if o.type == 'MESH']
    coords = [v.co.copy() for o in meshes for v in o.data.vertices]
    lo = [min(v[i] for v in coords) for i in range(3)]
    hi = [max(v[i] for v in coords) for i in range(3)]
    dims = [hi[i]-lo[i] for i in range(3)]
    assert min(dims) > 1e-5, (root.name, dims)
    center = [(lo[i]+hi[i])/2 for i in range(3)]
    for ob in meshes:
        for v in ob.data.vertices:
            v.co.x = (v.co.x-center[0])*target[0]/dims[0]
            v.co.y = (v.co.y-center[1])*target[1]/dims[1]
            v.co.z = (v.co.z-lo[2])*target[2]/dims[2]
        ob.data.update()
        bm=bmesh.new(); bm.from_mesh(ob.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return target

def measure(root):
    obs=[o for o in root.children_recursive if o.type=='MESH']
    pts=[v.co for o in obs for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)]; hi=[max(v[i] for v in pts) for i in range(3)]
    health=[]; tris=0
    for ob in obs:
        ob.data.calc_loop_triangles(); tris += len(ob.data.loop_triangles)
        bm=bmesh.new(); bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':len(ob.data.loop_triangles),
            'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
            'boundary_edges':sum(e.is_boundary for e in bm.edges),
            'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
            'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)})
        bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,
        'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],
        'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],
        'mesh_parts':len(obs),'triangles':tris,
        'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),
        'boundary_edges':sum(h['boundary_edges'] for h in health),
        'loose_edges':sum(h['loose_edges'] for h in health),
        'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

def area_light(collection,name,loc,power,size,target):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    ob=bpy.data.objects.new(name,data); collection.objects.link(ob); ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler(); return ob

def main():
    default=bpy.data.scenes.get('Scene')
    assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    previous=bpy.data.scenes.get('WindProduction_N02')
    if previous:
        assert not os.path.isfile(OUT+'/n02_shrub_and_grass_set.glb'),'Refusing to overwrite an exported N02 asset'
        bpy.context.window.scene=default
        previous_objects=list(previous.objects)
        bpy.data.scenes.remove(previous)
        for ob in previous_objects:
            if bpy.data.objects.get(ob.name): bpy.data.objects.remove(ob,do_unlink=True)
        for datablocks in (bpy.data.meshes,bpy.data.curves,bpy.data.cameras,bpy.data.lights,bpy.data.materials,bpy.data.worlds):
            for block in list(datablocks):
                if block.name.startswith('N02_') and block.users==0: datablocks.remove(block)
        for col in list(bpy.data.collections):
            if col.name.startswith('N02_') and col.users==0: bpy.data.collections.remove(col)
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'N02 concept and exact prompt must be saved first'
    os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
    open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_N02'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('N02_Export'); scene.collection.children.link(export)
    preview=bpy.data.collections.new('N02_Preview_ONLY'); scene.collection.children.link(preview)
    source=bpy.data.collections.new('N02_Source_NOT_EXPORTED'); scene.collection.children.link(source)
    mat=material()
    roots=[]
    specs=[
      ('N02_Shrub_LowHorizontal',(-1.15,0,0),(1.2,1.0,.65),'low horizontal spread'),
      ('N02_Shrub_RisingAsymmetric',(.40,0,0),(1.2,1.0,.65),'asymmetric ascending sweep'),
      ('N02_Grass_ThreeBentBlades',(1.95,0,0),(.7,.5,.4),'three slender bent blades')]
    for name,loc,dims,shape in specs:
        root=bpy.data.objects.new(name,None); export.objects.link(root); root.location=loc
        root['catalog_dimensions_blender_xyz_m']=list(dims); root['silhouette']=shape
        root['pivot']='bottom-center; Blender ground plane z=0; Godot up=+Y after Y-up export'
        root['prevailing_wind_local_x']=1.0; roots.append(root)
    # A: low horizontal group, arranged in three airy plan-separated lobes.
    a=roots[0]
    for name,c,l,d,h in [
      ('A_LowWindward', (0,-.30,.15),1.2,.40,.30),
      ('A_MidRear', (.12,.30,.225),.72,.40,.45),
      ('A_HighShort', (-.42,.12,.325),.30,.34,.65)]:
        ob=swept_leaf(export,'N02_'+name,c,l,d,h,mat); parent_mesh(ob,a)
    # B: three masses rise diagonally downwind, with the same overall catalog envelope.
    b=roots[1]
    for name,c,l,d,h in [
      ('B_LowStart',(-.40,-.30,.13),.40,.40,.26),
      ('B_RisingMiddle',(.08,.10,.22),.42,.30,.44),
      ('B_HighTip',(.475,.40,.325),.25,.20,.65)]:
        ob=swept_leaf(export,'N02_'+name,c,l,d,h,mat); parent_mesh(ob,b)
    # Grass: three slim ribbon blades; bases cluster at the root and all tips lean with the wind.
    g=roots[2]
    blade_specs=[
      ('Blade_West',[(0,0,0),(-.05,-.035,.075),(-.20,-.12,.20),(-.29,-.18,.32),(-.34,-.20,.40)],[0,.035,.032,.018,0],[0,.009,.008,.004,0]),
      ('Blade_East',[(0,0,0),(.04,.035,.085),(.16,.12,.21),(.27,.18,.32),(.34,.21,.38)],[0,.035,.031,.017,0],[0,.009,.008,.004,0]),
      ('Blade_South',[(0,0,0),(.07,-.02,.08),(.19,-.12,.18),(.28,-.18,.28),(.31,-.22,.34)],[0,.032,.028,.016,0],[0,.008,.007,.004,0])]
    for label,points,widths,thicknesses in blade_specs:
        ob=bent_blade(export,'N02_Grass_'+label,points,widths,thicknesses,mat); parent_mesh(ob,g)
    # Center/ground all pivots and fit each exact catalog envelope after adding the directional bend.
    for root in roots: normalize_envelope(root,root['catalog_dimensions_blender_xyz_m'])
    for root in roots:
        m=measure(root); root['measured_dimensions_blender_xyz_m']=m['dimensions_blender_xyz_m']; root['triangles']=m['triangles']
        assert m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0,(root.name,m)
        assert all(abs(m['dimensions_blender_xyz_m'][i]-root['catalog_dimensions_blender_xyz_m'][i])<1e-5 for i in range(3)),(root.name,m)
        assert abs(m['bounds_min_blender_m'][2])<1e-5,(root.name,m['bounds_min_blender_m'])
    assert [sum(1 for o in r.children_recursive if o.type=='MESH' and o.get('part_role')=='broad_swept_foliage_mass') for r in roots[:2]]==[3,3]
    assert sum(1 for o in roots[2].children_recursive if o.type=='MESH' and o.get('part_role')=='one_bent_grass_blade')==3
    # Preview studio, distinct from exported geometry.
    groundmat=bpy.data.materials.new('N02_PreviewGround_Material'); groundmat.diffuse_color=(.13,.14,.15,1); groundmat.use_nodes=True
    bs=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=(.13,.14,.15,1); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('N02_PreviewGround_Mesh'); me.from_pydata([(-80,-80,-.025),(80,-80,-.025),(80,80,-.025),(-80,80,-.025)],[],[(0,1,2,3)]); me.materials.append(groundmat)
    floor=bpy.data.objects.new('N02_PreviewGround',me); preview.objects.link(floor)
    world=bpy.data.worlds.new('N02_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.20,.21,.22,1); bg.inputs['Strength'].default_value=.55; scene.world=world
    for name,loc,power,size in [('N02_Key',(-4,-7,6),1900,7),('N02_Fill',(5,-4,3),1200,6),('N02_Rim',(0,5,5),1500,6)]: area_light(preview,name,loc,power,size,(0,0,.25))
    camdata=bpy.data.cameras.new('N02_PreviewCamera_Data'); cam=bpy.data.objects.new('N02_PreviewCamera',camdata); preview.objects.link(cam); scene.camera=cam
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=40
    cam.location=(0,-7.6,3.7); cam.rotation_euler=(Vector((0,-.05,.42))-cam.location).to_track_quat('-Z','Y').to_euler()
    # Import the real project fox for visual scale; isolate it in preview-only collection.
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None); assert rig,'Actual fox reference import failed'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection): col.objects.unlink(ob)
        preview.objects.link(ob); ob.name='N02_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((act for act in bpy.data.actions if act.name=='Idle'),None); assert idle,'Fox Idle action missing'
    if not rig.animation_data: rig.animation_data_create()
    rig.animation_data.action=idle; rig.location=(-3.45,-.75,0); scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file: im.pack()
    source['source_only']=True; source['excluded_from_glb']=True
    for r in roots:
        note=bpy.data.objects.new('N02_PivotNote_'+r.name,None); source.objects.link(note); note.parent=r; note.hide_render=True; note.hide_set(True); note['source_only']=True
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    scene.render.engine='CYCLES'; scene.cycles.samples=8; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.view_settings.exposure=.05
    scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    print('N02_BUILD_READY',json.dumps({'scene':scene.name,'variants':{r.name:measure(r) for r in roots},'mass_counts':[3,3,3],'shared_material':mat.name,'fox_action':rig.animation_data.action.name,'fox_helper_hidden':True,'default_scene_preserved':True}))

main()
