import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d04'
PRE=ROOT+'/output/wind_production/d04'
CONCEPT=ROOT+'/output/wind_production/concepts/d04_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/d04_prompt.txt'
WOOD={'wood':(0.085,0.055,0.035,1),'wood_light':(0.115,0.077,0.050,1),'wood_mid':(0.067,0.045,0.030,1),'wood_dark':(0.035,0.026,0.020,1),'cut':(0.18,0.125,0.077,1)}
METAL={'bronze':(0.095,0.12,0.103,1),'bronze_light':(0.14,0.16,0.13,1),'bronze_dark':(0.052,0.068,0.058,1)}

def palette_mat(name):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.88
    vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color'
    mat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return mat

def oct_rect(hx,hy,cut):
    c=max(0,min(cut,hx*.45,hy*.45))
    return [(-hx+c,-hy),(hx-c,-hy),(hx,-hy+c),(hx,hy-c),(hx-c,hy),(-hx+c,hy),(-hx,hy-c),(-hx,-hy+c)]

def make_mesh(coll,name,verts,faces,mat,palette,face_colors):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.materials.append(mat)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,face_colors):
        rgba=palette[col]
        for li in poly.loop_indices:attr.data[li].color=rgba
    ob=bpy.data.objects.new(name,me);coll.objects.link(ob);ob['surface_style']='broad_clean_planes';return ob

def prism(coll,name,center,dims,mat,palette,body='wood',cut=None):
    cx,cy,cz=center;dx,dy,dz=dims
    if cut is None:cut=min(dx,dy)*.09
    ring=oct_rect(dx/2,dy/2,cut)
    verts=[(cx+x,cy+y,cz-dz/2) for x,y in ring]+[(cx+x,cy+y,cz+dz/2) for x,y in ring]
    faces=[tuple(reversed(range(8)))];colors=['wood_dark' if 'wood_dark' in palette else body]
    sides=['wood','wood_light','wood_mid','wood','wood_mid','wood_light','wood','wood_mid'] if 'wood' in palette else ['bronze','bronze_light','bronze','bronze_dark','bronze','bronze_light','bronze','bronze_dark']
    for i in range(8):faces.append((i,(i+1)%8,8+(i+1)%8,8+i));colors.append(sides[i])
    faces.append(tuple(range(8,16)));colors.append(body if body in palette else 'wood_light')
    ob=make_mesh(coll,name,verts,faces,mat,palette,colors);ob['dimensions_local_m']=[float(dx),float(dy),float(dz)];return ob

def make_chest_shell(coll,name,wood):
    outer=oct_rect(.45,.35,.025);inner=oct_rect(.38,.28,.022)
    levels=(.05,.20,.35,.49);verts=[]
    for z in levels:verts.extend((x,y,z) for x,y in outer)
    verts.extend((x,y,.49) for x,y in inner)
    verts.extend((x,y,.11) for x,y in inner)
    faces=[tuple(reversed(range(8)))];colors=['wood_dark']
    wall=['wood','wood_light','wood_mid','wood','wood_mid','wood_light','wood','wood_mid']
    for k in range(3):
        for i in range(8):faces.append((k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i));colors.append(wall[i] if k!=1 else (wall[i] if i%2 else 'wood_mid'))
    outertop=24;innertop=32;innerfloor=40
    for i in range(8):faces.append((outertop+i,outertop+(i+1)%8,innertop+(i+1)%8,innertop+i));colors.append('wood_light' if i%2 else 'wood')
    for i in range(8):faces.append((innertop+i,innertop+(i+1)%8,innerfloor+(i+1)%8,innerfloor+i));colors.append('wood_dark' if i%2 else 'wood_mid')
    faces.append(tuple(range(innerfloor,innerfloor+8)));colors.append('wood_dark')
    ob=make_mesh(coll,name,verts,faces,wood,WOOD,colors);ob['hollow_shell']=True;ob['internal_clear_width_m']=.76;ob['internal_clear_depth_m']=.56;return ob

def make_chest_parts(export,root,wood,metal,prefix,lid_open=False):
    parts=[];shell=make_chest_shell(export,prefix+'_HollowBody',wood);shell.parent=root;parts.append(shell)
    for sx,side in ((-1,'West'),(1,'East')):
      for sy,end in ((-1,'Front'),(1,'Back')):
        p=prism(export,prefix+'_CornerPost_'+side+'_'+end,(sx*.405,sy*.305,.25),(.09,.09,.50),wood,WOOD,'wood_mid',.012);p.parent=root;parts.append(p)
    bandz=.27;bandh=.15
    for sy,label in ((-1,'Front'),(1,'Back')):
        p=prism(export,prefix+'_SingleBand_'+label,(0,sy*.339,bandz),(.90,.022,bandh),metal,METAL,'bronze',.003);p.parent=root;p['one_broad_wrap_band']=True;parts.append(p)
    for sx,label in ((-1,'West'),(1,'East')):
        p=prism(export,prefix+'_SingleBand_'+label,(sx*.4375,0,bandz),(.025,.68,bandh),metal,METAL,'bronze',.003);p.parent=root;p['one_broad_wrap_band']=True;parts.append(p)
    lid=prism(export,prefix+'_FittedLid',(0,0,.57),(.90,.70,.16),wood,WOOD,'wood_light',.035);lid.parent=root;lid['lid']=True;parts.append(lid)
    if lid_open:
        pivot=Vector((0,.30,.49));rot=__import__('mathutils').Matrix.Rotation(math.radians(-62),4,'X')
        for v in lid.data.vertices:v.co=pivot+rot@(v.co-pivot)
        lid.data.update();lid['hinge_axis']='rear edge +Y';lid['open_degrees']=62
        hinge=prism(export,prefix+'_BroadRearHinge',(0,.312,.495),(.24,.026,.045),metal,METAL,'bronze',.004);hinge.parent=root;hinge['broad_hinge_no_small_fasteners']=True;parts.append(hinge)
    root['variant']='open_hollow_chest' if lid_open else 'closed_hollow_chest';root['catalog_dimensions_m']=[.9,.7,.65];root['broad_band_count']=1;root['same_shared_body_and_lid_geometry']=True
    return parts

def fracture_post(coll,name,cx,cy,zbottom,ztop,wood,palette,broken_top=False,broken_bottom=False):
    section=oct_rect(.045,.045,.008);n=8;verts=[]
    bottom=[zbottom]*n;top=[ztop]*n
    jitter=[-.012,.006,.020,-.006,.014,-.018,.004,-.008]
    if broken_bottom:bottom=[zbottom+v for v in jitter]
    if broken_top:top=[ztop+v for v in jitter]
    for i,(x,y) in enumerate(section):verts.append((cx+x,cy+y,bottom[i]))
    for i,(x,y) in enumerate(section):verts.append((cx+x,cy+y,top[i]))
    faces=[];colors=[]
    if broken_bottom:
        faces.extend([[0,1,2,3,4],[0,4,5,6],[0,6,7]]);colors.extend(['cut','wood_light','wood_mid'])
    else:
        faces.append(tuple(reversed(range(n))));colors.append('wood_dark')
    for i in range(n):faces.append((i,(i+1)%n,n+(i+1)%n,n+i));colors.append(['wood','wood_light','wood_mid','wood','wood_mid','wood_light','wood','wood_mid'][i])
    if broken_top:
        faces.extend([[n+0,n+1,n+2,n+3,n+4],[n+0,n+4,n+5,n+6],[n+0,n+6,n+7]]);colors.extend(['cut','wood_light','wood_mid'])
    else:
        faces.append(tuple(range(n,2*n)));colors.append('wood_light')
    ob=make_mesh(coll,name,verts,faces,wood,palette,colors);ob['fracture_planes']=3 if (broken_top or broken_bottom) else 0
    return ob

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in objs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();tris+=len(ob.data.loop_triangles);bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'name':ob.name,'triangles':len(ob.data.loop_triangles),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(objs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

def create_empty(coll,name,desc):
    o=bpy.data.objects.new(name,None);coll.objects.link(o);o.empty_display_type='PLAIN_AXES';o['design']=desc;return o

def area_light(coll,name,loc,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);coll.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o

def setup_preview(scene,coll):
    cd=bpy.data.cameras.new('D04_PreviewCamera_Data');cam=bpy.data.objects.new('D04_PreviewCamera',cd);coll.objects.link(cam);scene.camera=cam
    for name,loc,power,size in [('D04_Key',(-8,-10,10),3600,7),('D04_Fill',(8,-4,6),1800,6),('D04_Rim',(0,7,8),2600,6)]:area_light(coll,name,loc,power,size,(0,0,.8))
    gm=bpy.data.materials.new('D04_PreviewGround');gm.use_nodes=True;bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.13,.15,.15,1);bs.inputs['Roughness'].default_value=.97
    me=bpy.data.meshes.new('D04_PreviewGround_Mesh');me.from_pydata([(-80,-80,-.025),(80,-80,-.025),(80,80,-.025),(-80,80,-.025)],[],[(0,1,2,3)]);me.materials.append(gm);floor=bpy.data.objects.new('D04_PreviewGround',me);coll.objects.link(floor)
    world=bpy.data.worlds.new('D04_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.25,.27,.27,1);bg.inputs['Strength'].default_value=.72;scene.world=world
    old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');new=list(set(bpy.data.objects)-old);rig=next((o for o in new if o.type=='ARMATURE'),None)
    if rig is None:raise RuntimeError('Actual fox reference failed to import')
    for ob in new:
        oldname=ob.name
        for c in list(ob.users_collection):c.objects.unlink(ob)
        coll.objects.link(ob);ob.name='D04_Fox_'+oldname.replace('.','_')
        if any(k in oldname.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data:rig.animation_data_create()
        rig.animation_data.action=idle
    rig.location=(-5.6,-2.4,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    return cam,rig

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene is not intact'
    assert bpy.data.scenes.get('WindProduction_D04') is None,'Refusing to duplicate existing D04 scene'
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'D04 concept/prompt missing'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_D04');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('D04_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('D04_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('D04_SourceLocators_NOT_EXPORTED');scene.collection.children.link(source)
    wood=palette_mat('D04_Shared_Wood_VertexColor');metal=palette_mat('D04_Shared_MutedBronze_VertexColor')
    open_chest=create_empty(export,'D04_Open_HollowChest','Same .9 x .7 x .65 m hollow one-band chest, lid hinged at the rear and opened 62 degrees, dark visible cavity.')
    open_parts=make_chest_parts(export,open_chest,wood,metal,'D04_OpenChest',True);open_chest.location=(-3.45,0,0)
    closed=create_empty(export,'D04_Closed_Chest_Cluster','Closed .9 x .7 x .65 m hollow one-band chest; one of three matching storage crates clustered beside the broken rack.')
    closed_parts=make_chest_parts(export,closed,wood,metal,'D04_ClosedChest',False);closed.location=(3.25,.45,0)
    closed_by_name={o.name:o for o in closed_parts}
    for ob in open_parts:
        if ob.name.endswith('_FittedLid') or ob.name.endswith('_BroadRearHinge'):continue
        match=closed_by_name[ob.name.replace('D04_OpenChest_','D04_ClosedChest_',1)]
        ob.data=match.data;ob['shared_source_mesh']=match.name
    # Two additional matching closed chests complete one compact three-crate cluster.
    cluster_roots=[]
    for i,loc in enumerate(((4.20,.45,0),(3.25,1.25,0)),1):
        root=create_empty(export,'D04_Closed_CrateCluster_'+str(i),'Linked copy of the closed chest, kept in the compact 3-crate cluster beside the broken rack.')
        for ob in closed_parts:
            dup=bpy.data.objects.new(ob.name.replace('D04_ClosedChest','D04_Cluster'+str(i)),ob.data);export.objects.link(dup);dup.parent=root;dup.location=(0,0,0);dup['shared_source_mesh']=ob.name
            for key,value in ob.items():dup[key]=value
        root.location=loc;root['variant']='closed_chest_cluster_copy';root['catalog_dimensions_m']=[.9,.7,.65];root['broad_band_count']=1;cluster_roots.append(root)
    closed.location=(3.25,.45,0)
    intact=create_empty(export,'D04_TwoTierRack_Intact','Intact two-tier timber rack, exactly four slender corner posts and two single broad shelf planes; 1.8 x .7 x 1.6 m.')
    intact.location=(-.85,0,0);intact['variant']='intact_two_tier_rack';intact['catalog_dimensions_m']=[1.8,.7,1.6]
    intact_parts=[]
    for sx,side in ((-.855,'West'),(.855,'East')):
      for sy,end in ((-.305,'Front'),(.305,'Back')):
        p=prism(export,'D04_IntactRack_Post_'+side+'_'+end,(sx,sy,.8),(.09,.09,1.6),wood,WOOD,'wood_mid',.012);p.parent=intact;intact_parts.append(p);p['post_role']='one_of_exactly_four_supports'
    for tier,z in ((1,.56),(2,1.12)):
        p=prism(export,'D04_IntactRack_SingleShelfPlane_Tier'+str(tier),(0,0,z),(1.72,.62,.08),wood,WOOD,'wood_light',.025);p.parent=intact;intact_parts.append(p);p['single_broad_shelf_plane']=True
    broken=create_empty(export,'D04_TwoTierRack_BrokenLeg','Derived from the same rack: the +X/+Y post has one three-plane break and a detached foot; the upper frame leans subtly toward the broken corner.')
    broken.location=(1.50,0,0);broken['variant']='broken_leg_slight_lean';broken['catalog_dimensions_m']=[1.8,.7,1.6];broken['lean_degrees']=1.0;broken['broken_corner']='+X,+Y'
    broken_parts=[];slope=math.tan(math.radians(1.0))
    for ob in intact_parts:
        if ob.name=='D04_IntactRack_Post_East_Back':continue
        dup=bpy.data.objects.new(ob.name.replace('IntactRack','BrokenRack'),ob.data.copy());export.objects.link(dup);dup.parent=broken;dup.location=(0,0,0);dup['derived_from']=ob.name
        if ob.get('post_role'):dup['post_role']='one_of_three_unbroken_supports'
        if ob.get('single_broad_shelf_plane'):dup['single_broad_shelf_plane']=True
        for v in dup.data.vertices:v.co.x+=slope*v.co.z
        dup.data.update();broken_parts.append(dup)
    upper=fracture_post(export,'D04_BrokenRack_Post_East_Back_Upper',.855,.305,.335,1.6,wood,WOOD,broken_bottom=True);upper.parent=broken
    upper['post_role']='snapped_upper_fragment_of_fourth_support'
    for v in upper.data.vertices:v.co.x+=slope*v.co.z
    upper.data.update();upper['derived_from']='D04_IntactRack_Post_East_Back';broken_parts.append(upper)
    foot=fracture_post(export,'D04_BrokenRack_DetachedFoot_East_Back',.895,.305,0,.285,wood,WOOD,broken_top=True);foot.parent=broken
    pivot=Vector((.895,.305,0));tilt=__import__('mathutils').Matrix.Rotation(math.radians(12),4,'Y')
    for v in foot.data.vertices:v.co=pivot+tilt@(v.co-pivot)
    zmin=min(v.co.z for v in foot.data.vertices)
    for v in foot.data.vertices:v.co.z-=zmin;v.co.x+=slope*v.co.z
    foot.data.update();foot['detached_foot']=True;foot['matching_fracture_planes']=3;broken_parts.append(foot)
    # Normalize the small lean and detached foot back to the exact catalog footprint while preserving the ground pivot.
    allp=[v.co for ob in broken_parts for v in ob.data.vertices];xmin=min(p.x for p in allp);xmax=max(p.x for p in allp);mid=(xmin+xmax)/2;factor=1.8/(xmax-xmin)
    for ob in broken_parts:
        for v in ob.data.vertices:v.co.x=(v.co.x-mid)*factor
        ob.data.update()
    # Preview only: actual fox, muted stage, and camera framing.
    cam,fox=setup_preview(scene,preview)
    cam.location=(0,-14.5,8.1);cam.rotation_euler=(Vector((0,0,.78))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    # Source locators document bottom-center pivots and excluded cluster layout.
    for root in [open_chest,closed,*cluster_roots,intact,broken]:
        loc=bpy.data.objects.new('D04_Pivot_'+root.name,None);source.objects.link(loc);loc.empty_display_type='CIRCLE';loc.parent=root;loc.location=(0,0,0);loc.hide_render=True;loc.hide_set(True);loc['source_only']=True;loc['pivot']='bottom-center of each local model variant'
    source['source_only']=True;source['excluded_from_glb']=True
    # Check all catalog envelopes and individual closed mesh topology before rendering.
    roots=[open_chest,closed,*cluster_roots,intact,broken]
    measurements={r.name:measure(r) for r in roots}
    expected={'D04_Closed_Chest_Cluster':[.9,.7,.65],'D04_TwoTierRack_Intact':[1.8,.7,1.6],'D04_TwoTierRack_BrokenLeg':[1.8,.7,1.6]}
    for name,target in expected.items():
        dims=measurements[name]['dimensions_blender_xyz_m'];assert all(abs(dims[i]-target[i])<.004 for i in range(3)),(name,dims,target)
    assert all(measurements[r.name]['non_manifold_edges']==0 and measurements[r.name]['boundary_edges']==0 and measurements[r.name]['loose_edges']==0 and measurements[r.name]['loose_vertices']==0 for r in roots),measurements
    assert len([o for o in intact.children_recursive if o.type=='MESH' and o.get('post_role')])==4
    assert len([o for o in intact.children_recursive if o.type=='MESH' and o.get('single_broad_shelf_plane')])==2
    assert len([o for o in broken.children_recursive if o.type=='MESH' and o.get('post_role')])==4
    assert len([o for o in broken.children_recursive if o.type=='MESH' and o.get('single_broad_shelf_plane')])==2
    assert sum(1 for o in broken.children_recursive if o.type=='MESH' and o.get('detached_foot'))==1
    assert all(o.data.color_attributes.get('Color') for r in roots for o in r.children_recursive if o.type=='MESH')
    assert bpy.data.scenes.get('Scene') and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
    assert len(roots)==5 and len(cluster_roots)==2
    bpy.context.view_layer.objects.active=intact
    print('D04_BUILD_READY',json.dumps({'scene':scene.name,'roots':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'triangles':v['triangles'],'parts':v['mesh_parts'],'non_manifold':v['non_manifold_edges']} for k,v in measurements.items()},'materials':[wood.name,metal.name],'fox_action':fox.animation_data.action.name,'default_scene_preserved':True}))

main()

