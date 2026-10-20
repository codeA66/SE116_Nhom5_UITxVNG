import bpy,bmesh,os,json,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/p02';PRE=ROOT+'/output/wind_production/p02'
CONCEPT=ROOT+'/output/wind_production/concepts/p02_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/p02_prompt.txt'

def linhex(h):
    q=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in q)+(1,)
COLORS={'stone_dark':linhex('#3E3F3E'),'stone_base':linhex('#52524F'),'stone_light':linhex('#66645C'),'stone_outer':linhex('#5B5A54'),'fracture':linhex('#747167')}

def material():
    m=bpy.data.materials.new('P02_Shared_FlatWeatheredStone_VertexColor');m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.95
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color']);return m

def face_color(key,n):
    z=Vector(n).normalized().z
    if key=='fracture':
        if z>.7:return COLORS['stone_light']
        if z<-.7:return COLORS['stone_dark']
        return COLORS['fracture']
    if z>.7:return COLORS['stone_light'] if key in ('stone_base','cap') else COLORS['stone_outer']
    if z<-.7:return COLORS['stone_dark']
    if key=='stone_outer':return COLORS['stone_outer']
    return COLORS['stone_base'] if Vector(n).normalized().y>=0 else COLORS['stone_dark']

def make_mesh(collection,name,verts,faces,mat,color_key,role,props=None):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me)
    ngons=[f for f in bm.faces if len(f.verts)>4]
    if ngons:bmesh.ops.triangulate(bm,faces=ngons,quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    ob=bpy.data.objects.new(name,me);collection.objects.link(ob);ob['part_role']=role
    for p in me.polygons:
        col=face_color(color_key,p.normal)
        for li in p.loop_indices:ca.data[li].color=col
    for k,v in (props or {}).items():ob[k]=v
    return ob

def beveled_box(collection,name,center,size,mat,color_key,role,bevel=.012):
    cx,cy,cz=center;dx,dy,dz=[v/2 for v in size]
    vs=[(cx+sx*dx,cy+sy*dy,cz+sz*dz) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    fs=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(vs,[],fs);me.update();bm=bmesh.new();bm.from_mesh(me)
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.verts)+list(bm.edges),offset=bevel,segments=1,affect='EDGES',profile=.5)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER');ob=bpy.data.objects.new(name,me);collection.objects.link(ob);ob['part_role']=role;ob['bevel_width_m']=bevel
    for p in me.polygons:
        col=face_color(color_key,p.normal)
        for li in p.loop_indices:ca.data[li].color=col
    return ob

def parent(ob,root):ob.parent=root;ob.matrix_parent_inverse=type(ob.matrix_parent_inverse).Identity(4)

def prism_xz(collection,name,profile,ycenter,depth,mat,key,role,props=None):
    n=len(profile);y0=ycenter-depth/2;y1=ycenter+depth/2
    vs=[(x,y0,z) for x,z in profile]+[(x,y1,z) for x,z in profile]
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    for i in range(n):fs.append((i,(i+1)%n,n+(i+1)%n,n+i))
    return make_mesh(collection,name,vs,fs,mat,key,role,props)

def prism_yz(collection,name,profile,xcenter,depth,mat,key,role,props=None):
    n=len(profile);x0=xcenter-depth/2;x1=xcenter+depth/2
    vs=[(x0,y,z) for y,z in profile]+[(x1,y,z) for y,z in profile]
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    for i in range(n):fs.append((i,(i+1)%n,n+(i+1)%n,n+i))
    return make_mesh(collection,name,vs,fs,mat,key,role,props)

def prism_xy(collection,name,profile,z0,z1,mat,key,role,props=None):
    n=len(profile);vs=[(x,y,z0) for x,y in profile]+[(x,y,z1) for x,y in profile]
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    for i in range(n):fs.append((i,(i+1)%n,n+(i+1)%n,n+i))
    return make_mesh(collection,name,vs,fs,mat,key,role,props)

def wall_profile(a,b,hole_center,hole_half,bottom=.28,opening_top=.86,top=2.18,broken_outer=False):
    l=hole_center-hole_half;r=hole_center+hole_half
    p=[(a,bottom),(l,bottom),(l,opening_top),(r,opening_top),(r,bottom),(b,bottom),(b,top)]
    if broken_outer:
        # Three broad angular cuts remove only the outside face layer at the exposed top corner.
        p.extend([(1.86,1.88),(1.68,1.82),(1.53,2.18)])
    p.append((a,top));return p

def base_straight(root,c,mat,length=4.0):
    a=-length/2;b=length/2
    prof=[(-.45,0),(.45,0),(.22,.28),(-.22,.28)]
    parent(prism_yz(c,'P02_BaseFlare_'+root.name,prof,0,length,mat,'stone_base','subtly_flared_continuous_foot',{'base_flare_m':.23}),root)

def l_plan(hw,pad):
    # The two 2 m centreline legs receive equal end caps; this forms one continuous L outline.
    return [(-2-pad,-hw),(pad,-hw),(pad,2+pad),(-hw,2+pad),(-hw,hw),(-2-pad,hw)]

def l_foot(collection,root,mat):
    bottom=l_plan(.45,.45);top=l_plan(.22,.22);n=len(bottom);vs=[(x,y,0) for x,y in bottom]+[(x,y,.28) for x,y in top]
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    for i in range(n):fs.append((i,(i+1)%n,n+(i+1)%n,n+i))
    ob=make_mesh(collection,'P02_ContinuousCornerBase_'+root.name,vs,fs,mat,'stone_base','continuous_flared_L_foot',{'same_section_as_straight':True});parent(ob,root)

def wall_drain_leg(collection,root,mat,name,orientation,a,b,hole_center):
    p=wall_profile(a,b,hole_center,.47)
    if orientation=='x':
        body=prism_xz(collection,name+'_BroadWallAndBoundedOutlet',p,0,.42,mat,'stone_base','continuous_wall_with_bounded_drain',{'drain_width_m':.94,'drain_height_m':.58,'pond_side':'positive Y'})
        face=prism_xz(collection,name+'_OutsideFaceLayer',p,-.218,.016,mat,'stone_outer','single_broad_exterior_face')
        floor=beveled_box(collection,name+'_ShortChannelFloor',(hole_center,-.10,.315),(.90,.66,.07),mat,'stone_light','bounded_outlet_channel_floor',.006)
    else:
        # Coordinates in the profile are global Y/Z; the outer face is the positive-X side.
        body=prism_yz(collection,name+'_BroadWallAndBoundedOutlet',p,0,.42,mat,'stone_base','continuous_wall_with_bounded_drain',{'drain_width_m':.94,'drain_height_m':.58,'pond_side':'negative X'})
        face=prism_yz(collection,name+'_OutsideFaceLayer',p,.218,.016,mat,'stone_outer','single_broad_exterior_face')
        floor=beveled_box(collection,name+'_ShortChannelFloor',(.10,hole_center,.315),(.66,.90,.07),mat,'stone_light','bounded_outlet_channel_floor',.006)
    for ob in (body,face,floor):parent(ob,root)

def add_straight_wall(collection,root,mat,broken=False):
    base_straight(root,collection,mat)
    profile=wall_profile(-2,2,0,.47,broken_outer=False)
    body=prism_xz(collection,'P02_WallBody_'+root.name,profile,0,.42,mat,'stone_base','one_broad_retaining_wall_face',{'catalog_run_m':4.0,'straight_end_connectors_clear':True})
    parent(body,root)
    # One uninterrupted outside face; in the damaged state only its top outer corner layer is missing.
    faceprofile=wall_profile(-2,2,0,.47,broken_outer=broken)
    face=prism_xz(collection,'P02_WallExteriorFace_'+root.name,faceprofile,-.218,.016,mat,'fracture' if broken else 'stone_outer','one_outer_corner_layer' if broken else 'single_broad_exterior_face',{'broken_outside_corner':broken,'broad_fracture_planes':3 if broken else 0})
    parent(face,root)
    if broken:
        # Three broad angled cuts clip only the outside cap corner; the water-facing edge stays continuous.
        outline=[(-2,-.50),(1.62,-.50),(1.78,-.40),(1.72,-.29),(1.86,-.20),(2,-.08),(2,.50),(-2,.50)]
        cap=prism_xy(collection,'P02_Broken_OutsideCorner_Cap_'+root.name,outline,2.18,2.40,mat,'fracture','outer_cap_corner_chipped_with_three_planes',{'broad_fracture_planes':3,'pond_facing_edge_continuous':True})
    else:
        cap=beveled_box(collection,'P02_WideContinuousCap_'+root.name,(0,0,2.29),(4.0,1.0,.22),mat,'cap','one_wide_pond_rim_cap',.018)
    parent(cap,root)
    # Large bounded rectangular outlet: the broad face stays solid above and around it; the continuous foot is its sill.
    channel=beveled_box(collection,'P02_OutletChannelFloor_'+root.name,(0,-.10,.315),(.94,.66,.07),mat,'stone_light','short_bounded_drain_channel_floor',.006);parent(channel,root)
    root['drain_count']=1

def add_corner_wall(collection,root,mat):
    l_foot(collection,root,mat)
    # Both legs use the straight section and overlap inside the corner; one continuous L-shaped cap closes the junction.
    wall_drain_leg(collection,root,mat,'P02_Corner_XLeg','x',-2,.21,-1.0)
    wall_drain_leg(collection,root,mat,'P02_Corner_YLeg','y',-.21,2,1.0)
    cap=prism_xy(collection,'P02_ContinuousL_Cap_'+root.name,l_plan(.50,.50),2.18,2.40,mat,'cap','single_continuous_L_pond_rim_cap',{'inner_cap_skin_continuous':True,'corner_angle_degrees':90})
    parent(cap,root);root['drain_count']=2;root['centerline_run_total_m']=4.0;root['inner_skin_continuous']=True

def area_light(collection,name,loc,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);collection.objects.link(o)
    o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o

def measure(root):
    obs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in obs for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
    health=[];tris=0
    for ob in obs:
        ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles);tris+=n;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':n,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],
      'mesh_parts':len(obs),'triangles':tris,'non_manifold_edges':sum(x['non_manifold_edges'] for x in health),'boundary_edges':sum(x['boundary_edges'] for x in health),'loose_edges':sum(x['loose_edges'] for x in health),'loose_vertices':sum(x['loose_vertices'] for x in health),'mesh_health':health}

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    assert not os.path.isfile(OUT+'/p02_pond_retaining_wall.glb'),'Refusing to overwrite existing P02 GLB'
    previous=bpy.data.scenes.get('WindProduction_P02')
    if previous:
        bpy.context.window.scene=default;old=list(previous.objects);bpy.data.scenes.remove(previous)
        for ob in old:
            if bpy.data.objects.get(ob.name):bpy.data.objects.remove(ob,do_unlink=True)
        for blocks in (bpy.data.meshes,bpy.data.curves,bpy.data.cameras,bpy.data.lights,bpy.data.materials,bpy.data.worlds):
            for block in list(blocks):
                if block.name.startswith('P02_') and block.users==0:blocks.remove(block)
        for c in list(bpy.data.collections):
            if c.name.startswith('P02_') and c.users==0:bpy.data.collections.remove(c)
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'P02 concept and prompt must be saved before modeling'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_P02');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('P02_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('P02_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('P02_Source_NOT_EXPORTED');scene.collection.children.link(source);mat=material()
    roots=[]
    for name,loc,kind in [('P02_Wall_Straight',(-6,0,0),'straight'),('P02_Wall_Corner90',(0,0,0),'corner'),('P02_Wall_BrokenOutside',(6,0,0),'broken')]:
        root=bpy.data.objects.new(name,None);export.objects.link(root);root.location=loc;root['variant']=kind;root['pivot']='centerline base anchor at local Z=0';root['pond_facing_side']='positive Y for straight/broken';root['catalog_straight_envelope_m']=[4,1,2.4]
        if kind=='straight':add_straight_wall(export,root,mat,False)
        elif kind=='broken':add_straight_wall(export,root,mat,True)
        else:add_corner_wall(export,root,mat)
        roots.append(root)
    measures={r.name:measure(r) for r in roots}
    for r in roots:
        m=measures[r.name];assert m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0,(r.name,m)
        assert m['triangles']<2000 and r.get('drain_count') in (1,2)
    for r in (roots[0],roots[2]):
        d=measures[r.name]['dimensions_blender_xyz_m']
        assert all(abs(d[i]-[4,1,2.4][i])<.002 for i in range(3)),(r.name,d)
        assert abs(measures[r.name]['bounds_min_blender_m'][0]+2)<.002 and abs(measures[r.name]['bounds_max_blender_m'][0]-2)<.002
        assert abs(measures[r.name]['bounds_min_blender_m'][2])<.002
    cornerdims=measures[roots[1].name]['dimensions_blender_xyz_m'];assert all(abs(cornerdims[i]-[3,3,2.4][i])<.002 for i in range(3)),cornerdims
    assert len([o for o in roots[1].children_recursive if o.get('part_role')=='continuous_wall_with_bounded_drain'])==2
    assert len([o for o in roots[1].children_recursive if o.get('part_role')=='single_continuous_L_pond_rim_cap'])==1
    broken_face=next(o for o in roots[2].children_recursive if o.get('part_role')=='one_outer_corner_layer')
    assert broken_face.get('broad_fracture_planes')==3
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    meshes=[o for o in export.objects if o.type=='MESH'];assert len(meshes)>0
    assert len({m.name for o in meshes for m in o.data.materials})==1 and all(o.data.color_attributes.get('Color') for o in meshes)
    groundmat=bpy.data.materials.new('P02_PreviewGround_Material');groundmat.use_nodes=True;bs=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.065,.066,.068,1);bs.inputs['Roughness'].default_value=.96
    gm=bpy.data.meshes.new('P02_PreviewGround_Mesh');gm.from_pydata([(-80,-80,-.02),(80,-80,-.02),(80,80,-.02),(-80,80,-.02)],[],[(0,1,2,3)]);gm.materials.append(groundmat)
    ground=bpy.data.objects.new('P02_PreviewGround',gm);preview.objects.link(ground)
    world=bpy.data.worlds.new('P02_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.08,.085,.09,1);bg.inputs['Strength'].default_value=.55;scene.world=world
    for name,loc,power,size in [('P02_Key',(-7,-10,12),3000,10),('P02_Fill',(8,-7,7),1800,9),('P02_Rim',(0,9,11),2400,10)]:area_light(preview,name,loc,power,size,(0,0,1.2))
    cd=bpy.data.cameras.new('P02_PreviewCamera_Data');cam=bpy.data.objects.new('P02_PreviewCamera',cd);preview.objects.link(cam);scene.camera=cam
    cam.location=(7,-20,11);cam.rotation_euler=(Vector((0,.2,1.15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');imported=list(set(bpy.data.objects)-before)
    rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox preview import failed'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='P02_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None);assert idle,'Idle action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(-9,-.8,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    for r in roots:
        note=bpy.data.objects.new('P02_PivotNote_'+r.name,None);source.objects.link(note);note.parent=r;note.hide_render=True;note.hide_set(True);note['source_only']=True
    source['source_only']=True;source['excluded_from_glb']=True
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    print('P02_BUILD_READY',json.dumps({'scene':scene.name,'variants':{r.name:measures[r.name] for r in roots},'single_shared_material':mat.name,'straight_envelope_m':[4,1,2.4],'corner_centerline_run_m':4,'continuous_L_cap':True,'bounded_drains':[1,2,1],'broken_outer_layer_planes':3,'fox_action':rig.animation_data.action.name,'default_scene_preserved':True}))

main()
