import bpy,bmesh,math,os,json
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/n03'
PRE=ROOT+'/output/wind_production/n03'
CONCEPT=ROOT+'/output/wind_production/concepts/n03_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/n03_prompt.txt'
SIDES=6

def srgb8(h):
    q=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in q)+(1,)

COLORS={'bark_dark':srgb8('#383832'),'bark_base':srgb8('#49483F'),
 'bark_mid':srgb8('#56564A'),'bark_light':srgb8('#626153'),
 'bark_underside':srgb8('#33342F'),'moss':srgb8('#5E684D'),
 'moss_light':srgb8('#687253')}

def make_material():
    m=bpy.data.materials.new('N03_Shared_WeatheredRoot_VertexColor');m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.94
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def make_mesh(collection,name,verts,faces,mat,colors,props):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
    me.materials.append(mat);ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    assert len(me.polygons)==len(colors),(name,len(me.polygons),len(colors))
    for poly,key in zip(me.polygons,colors):
        for li in poly.loop_indices:ca.data[li].color=COLORS[key]
    ob=bpy.data.objects.new(name,me);collection.objects.link(ob);ob['surface_style']='broad_faceted_weathered_root'
    for k,v in props.items():ob[k]=v
    return ob

def root_tube(collection,name,points,radii,mat,mount_normal,moss_segment=None,cap_start=False,role='primary_line'):
    """Closed hexagonal root tube with invariant section; point ends taper without stretched elbows."""
    ps=[Vector(p) for p in points];assert len(ps)>=4 and len(ps)==len(radii)
    normal=Vector(mount_normal).normalized();verts=[];rings=[];faces=[];face_colors=[]
    first=0
    if cap_start:
        tangent=(ps[1]-ps[0]).normalized();u=tangent.cross(normal).normalized();v=tangent.cross(u).normalized()
        first=len(verts);rings.append(first)
        for j in range(SIDES):
            a=2*math.pi*j/SIDES+math.pi/6
            verts.append(tuple(ps[0]+radii[0]*(math.cos(a)*u+math.sin(a)*v)))
    else:verts.append(tuple(ps[0]))
    for k in range(1,len(ps)-1):
        tangent=(ps[k+1]-ps[k-1]).normalized();u=tangent.cross(normal).normalized();v=tangent.cross(u).normalized()
        start=len(verts);rings.append(start)
        for j in range(SIDES):
            a=2*math.pi*j/SIDES+math.pi/6
            verts.append(tuple(ps[k]+radii[k]*(math.cos(a)*u+math.sin(a)*v)))
    end_tip=len(verts);verts.append(tuple(ps[-1]))
    if cap_start:
        faces.append(tuple(reversed(range(rings[0],rings[0]+SIDES))));face_colors.append('bark_underside')
    else:
        for j in range(SIDES):
            faces.append((0,rings[0]+j,rings[0]+(j+1)%SIDES))
            face_colors.append('bark_dark' if j in (3,4) else 'bark_base')
    palette=['bark_mid','bark_light','bark_light','bark_mid','bark_underside','bark_base']
    for r in range(len(rings)-1):
        for j in range(SIDES):
            faces.append((rings[r]+j,rings[r]+(j+1)%SIDES,
                          rings[r+1]+(j+1)%SIDES,rings[r+1]+j))
            if moss_segment==r and j in (1,2):face_colors.append('moss' if j==1 else 'moss_light')
            else:face_colors.append(palette[j])
    last=rings[-1]
    for j in range(SIDES):
        faces.append((last+j,last+(j+1)%SIDES,end_tip))
        face_colors.append('bark_dark' if j in (3,4) else 'bark_base')
    props={'part_role':role,'cross_section_sides':SIDES,'max_section_radius_m':max(radii),
           'mount_surface_normal_local':list(mount_normal),'profile_reused_across_variants':True,
           'fracture_or_hair_detail':'none'}
    if moss_segment is not None:props['single_subdued_moss_patch']=True
    return make_mesh(collection,name,verts,faces,mat,face_colors,props)

def parent_mesh(ob,root):
    ob.parent=root;ob.matrix_parent_inverse=type(ob.matrix_parent_inverse).Identity(4)

def measure(root):
    obs=[o for o in root.children_recursive if o.type=='MESH']
    pts=[v.co for o in obs for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
    health=[];tris=0
    for ob in obs:
        ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles);tris+=n;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':n,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
          'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
          'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,
      'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],
      'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],
      'mesh_parts':len(obs),'triangles':tris,'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),
      'boundary_edges':sum(x['boundary_edges'] for x in health),'loose_edges':sum(x['loose_edges'] for x in health),
      'loose_vertices':sum(x['loose_vertices'] for x in health),'mesh_health':health}

def cube_guide(collection,name,center,size,mat):
    x,y,z=center;dx,dy,dz=[v/2 for v in size]
    verts=[(x+sx*dx,y+sy*dy,z+sz*dz) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.materials.append(mat);me.update()
    ob=bpy.data.objects.new(name,me);collection.objects.link(ob);ob['placement_guide_only']=True;return ob

def area_light(collection,name,loc,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o

def arc_corner_points(L1,L2,r,start_y,z):
    pts=[(0,start_y,z)]
    for x in (.18,.55,1.05,L1-r):
        if x>0 and x<L1-r-1e-5:pts.append((x,start_y,z))
    c=(L1-r,start_y+r)
    for j in range(1,5):
        a=-math.pi/2+(math.pi/2)*j/4
        pts.append((c[0]+r*math.cos(a),c[1]+r*math.sin(a),z))
    for y in (start_y+r+.12,start_y+r+.28,start_y+L2):
        if y>pts[-1][1]+1e-5:pts.append((L1,y,z))
    return pts

def radii_along(points,total,peak=.06,base=.034):
    lengths=[0.0]
    for a,b in zip(points,points[1:]):lengths.append(lengths[-1]+(Vector(b)-Vector(a)).length)
    assert abs(lengths[-1]-total)<.003,(lengths[-1],total)
    return [0.0]+[base+(peak-base)*math.sin(math.pi*d/total) for d in lengths[1:-1]]+[0.0]

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    previous=bpy.data.scenes.get('WindProduction_N03')
    if previous:
        assert not os.path.isfile(OUT+'/n03_roots_and_vines.glb'),'Refusing to overwrite an exported N03 asset'
        bpy.context.window.scene=default;old=list(previous.objects);bpy.data.scenes.remove(previous)
        for ob in old:
            if bpy.data.objects.get(ob.name):bpy.data.objects.remove(ob,do_unlink=True)
        for blocks in (bpy.data.meshes,bpy.data.curves,bpy.data.cameras,bpy.data.lights,bpy.data.materials,bpy.data.worlds):
            for block in list(blocks):
                if block.name.startswith('N03_') and block.users==0:blocks.remove(block)
        for c in list(bpy.data.collections):
            if c.name.startswith('N03_') and c.users==0:bpy.data.collections.remove(c)
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'N03 concept and prompt must be saved before modeling'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_N03');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('N03_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('N03_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('N03_Source_NOT_EXPORTED');scene.collection.children.link(source)
    mat=make_material()
    guide_mat=bpy.data.materials.new('N03_PreviewGuide_Gray');guide_mat.use_nodes=True
    bs=next(n for n in guide_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.21,.22,.23,1);bs.inputs['Roughness'].default_value=.96
    roots=[]
    specs=[('N03_Root_Straight',(-3.35,0,0),'straight'),('N03_Root_Corner',(-.15,0,0),'corner'),('N03_Root_Hanging',(3.25,0,2.4),'hanging')]
    for name,loc,variant in specs:
        r=bpy.data.objects.new(name,None);export.objects.link(r);r.location=loc
        r['variant']=variant;r['pivot']='mounting anchor at principal-line start';r['principal_run_length_m']=2.4
        r['branch_count']=2;r['max_relief_normal_m']=.12;r['total_branch_spread_m']=.6;roots.append(r)
    straight,corner,hanging=roots
    main_points=[(0,0,.06),(.12,0,.06),(.45,0,.06),(.90,0,.06),(1.50,0,.06),(1.95,0,.06),(2.28,0,.06),(2.4,0,.06)]
    main_r=[0,.035,.052,.06,.06,.052,.035,0]
    ob=root_tube(export,'N03_Straight_PrimaryLine',main_points,main_r,mat,(0,0,1),moss_segment=2,role='primary_line');parent_mesh(ob,straight)
    branch_defs=[
      ('N03_Straight_Branch_Left',[(.62,0,.06),(.49,-.09,.06),(.30,-.22,.06),(.18,-.30,.06)],[0,.044,.028,0]),
      ('N03_Straight_Branch_Right',[(1.52,0,.06),(1.68,.09,.06),(1.91,.22,.06),(2.12,.30,.06)],[0,.044,.028,0])]
    for name,pts,rr in branch_defs:parent_mesh(root_tube(export,name,pts,rr,mat,(0,0,1),role='large_branch'),straight)
    corner_L2=.54;corner_r=.08;corner_L1=2.4-corner_L2+(2-math.pi/2)*corner_r;corner_sy=.06
    corner_points=arc_corner_points(corner_L1,corner_L2,corner_r,corner_sy,.06)
    corner_radii=radii_along(corner_points,2.4,.06,.035)
    ob=root_tube(export,'N03_Corner_PrimaryLine',corner_points,corner_radii,mat,(0,0,1),moss_segment=2,role='primary_line');parent_mesh(ob,corner)
    branch_defs=[
      ('N03_Corner_Branch_Inner',[(.60,.06,.06),(.45,.055,.06),(.24,.04,.06),(.12,.035,.06)],[0,.044,.028,0]),
      ('N03_Corner_Branch_Outer',[(corner_L1,.25,.06),(corner_L1-.12,.35,.06),(corner_L1-.30,.46,.06),(corner_L1-.44,.50,.06)],[0,.044,.028,0])]
    for name,pts,rr in branch_defs:parent_mesh(root_tube(export,name,pts,rr,mat,(0,0,1),role='large_branch'),corner)
    hang_points=[(0,.06,0),(0,.06,-.18),(0,.06,-.55),(0,.06,-1.05),(0,.06,-1.55),(0,.06,-2.05),(0,.06,-2.28),(0,.06,-2.4)]
    hang_r=[0,.035,.052,.06,.06,.052,.035,0]
    ob=root_tube(export,'N03_Hanging_PrimaryLine',hang_points,hang_r,mat,(0,1,0),moss_segment=2,role='primary_line');parent_mesh(ob,hanging)
    branch_defs=[
      ('N03_Hanging_Branch_Left',[(0,.06,-.58),(-.10,.06,-.73),(-.22,.06,-.92),(-.30,.06,-1.10)],[0,.044,.028,0]),
      ('N03_Hanging_Branch_Right',[(0,.06,-1.00),(.10,.06,-1.17),(.22,.06,-1.37),(.30,.06,-1.55)],[0,.044,.028,0])]
    for name,pts,rr in branch_defs:parent_mesh(root_tube(export,name,pts,rr,mat,(0,1,0),role='large_branch'),hanging)
    assert abs(sum((Vector(b)-Vector(a)).length for a,b in zip(corner_points,corner_points[1:]))-2.4)<.003
    for r in roots:
        m=measure(r);r['dimensions_blender_xyz_m']=m['dimensions_blender_xyz_m'];r['triangles']=m['triangles']
        assert m['mesh_parts']==3 and m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0,(r.name,m)
        assert len([o for o in r.children_recursive if o.type=='MESH' and o.get('part_role')=='large_branch'])==2
    # Measured max relief and branch envelope. Corner path length is the sum of both legs and the rounded bend.
    assert abs(measure(straight)['dimensions_blender_xyz_m'][2]-.12)<.002,measure(straight)
    assert abs(measure(straight)['dimensions_blender_xyz_m'][1]-.60)<.004,measure(straight)
    assert abs(measure(hanging)['dimensions_blender_xyz_m'][1]-.12)<.002,measure(hanging)
    assert abs(measure(hanging)['dimensions_blender_xyz_m'][0]-.60)<.004,measure(hanging)
    # Simple gray placement guides echo the concept sheet but stay out of the GLB.
    cube_guide(preview,'N03_PreviewGuide_Straight',(-3.35+1.2,0,-.18),(2.52,.72,.36),guide_mat)
    cube_guide(preview,'N03_PreviewGuide_Corner',(-.15+corner_L1/2,.30,-.18),(corner_L1+.12,.60,.36),guide_mat)
    cube_guide(preview,'N03_PreviewGuide_CornerLeg',(-.15+corner_L1,.30,-.18),(.72,.72,.36),guide_mat)
    cube_guide(preview,'N03_PreviewGuide_HangingWall',(3.25,.30,1.2),(.72,.36,2.50),guide_mat)
    floor_mat=bpy.data.materials.new('N03_PreviewGround_Material');floor_mat.use_nodes=True
    bs=next(n for n in floor_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.12,.13,.14,1);bs.inputs['Roughness'].default_value=.96
    floor_me=bpy.data.meshes.new('N03_PreviewGround_Mesh');floor_me.from_pydata([(-80,-80,-.4),(80,-80,-.4),(80,80,-.4),(-80,80,-.4)],[],[(0,1,2,3)]);floor_me.materials.append(floor_mat)
    floor=bpy.data.objects.new('N03_PreviewGround',floor_me);preview.objects.link(floor)
    world=bpy.data.worlds.new('N03_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.19,.20,.21,1);bg.inputs['Strength'].default_value=.55;scene.world=world
    for name,loc,power,size in [('N03_Key',(-5,-8,8),2100,8),('N03_Fill',(6,-5,4),1300,7),('N03_Rim',(0,7,7),1700,8)]:area_light(preview,name,loc,power,size,(0,0,1.1))
    cd=bpy.data.cameras.new('N03_PreviewCamera_Data');cam=bpy.data.objects.new('N03_PreviewCamera',cd);preview.objects.link(cam);scene.camera=cam
    cam.location=(0,-11,5.6);cam.rotation_euler=(Vector((0,-.05,.95))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before);rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox reference import failed'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='N03_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((act for act in bpy.data.actions if act.name=='Idle'),None);assert idle,'Fox Idle action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(-5.05,-.85,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    for r in roots:
        note=bpy.data.objects.new('N03_PivotNote_'+r.name,None);source.objects.link(note);note.parent=r;note.hide_render=True;note.hide_set(True);note['source_only']=True
    source['source_only']=True;source['excluded_from_glb']=True
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    print('N03_BUILD_READY',json.dumps({'scene':scene.name,'variants':{r.name:measure(r) for r in roots},
      'principal_run_lengths_m':{'straight':2.4,'corner':sum((Vector(b)-Vector(a)).length for a,b in zip(corner_points,corner_points[1:])),'hanging':2.4},
      'branch_count_per_variant':[2,2,2],'cross_section_sides':SIDES,'moss_patch_per_variant':1,
      'guide_blocks_preview_only':True,'fox_action':rig.animation_data.action.name,'default_scene_preserved':True}))

main()
