import bpy,bmesh,math,os,json
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/n01';PRE=ROOT+'/output/wind_production/n01'
CONCEPT=ROOT+'/output/wind_production/concepts/n01_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/n01_prompt.txt'

def lin8(h):
    q=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in q)+(1,)
PAL={'bark':lin8('#49433C'),'bark_mid':lin8('#62594F'),'bark_light':lin8('#766A5E'),'bark_dark':lin8('#353431'),'bark_cut':lin8('#867A6B'),'leaf':lin8('#626D59'),'leaf_mid':lin8('#748168'),'leaf_light':lin8('#87937A'),'leaf_dark':lin8('#4C5849'),'leaf_edge':lin8('#3D463C')}

def make_mat(name):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.92
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color']);return m

def mesh(c,name,verts,faces,mat,face_colors,props=None):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,face_colors):
        color=PAL[col]
        for li in poly.loop_indices:ca.data[li].color=color
    ob=bpy.data.objects.new(name,me);c.objects.link(ob);ob['surface_style']='broad_clean_low_poly_planes'
    if props:
        for k,v in props.items():ob[k]=v
    return ob

def tube(c,name,pts,radii,mat,fractured_tip=False,role='branch'):
    P=[Vector(p) for p in pts];nside=8;verts=[];faces=[];colors=[]
    for k,center in enumerate(P):
        tangent=(P[min(k+1,len(P)-1)]-P[max(k-1,0)]).normalized()
        ref=Vector((0,1,0))
        if abs(tangent.dot(ref))>.95:ref=Vector((1,0,0))
        u=tangent.cross(ref).normalized();v=tangent.cross(u).normalized()
        for j in range(nside):
            a=2*math.pi*j/nside;rad=radii[k];q=center+rad*(math.cos(a)*u+math.sin(a)*v)
            if fractured_tip and k==len(P)-1:q+=tangent*(.045*math.cos(2*a+.35))
            verts.append(tuple(q))
    faces.append(tuple(reversed(range(nside))));colors.append('bark_dark')
    for k in range(len(P)-1):
        for j in range(nside):
            faces.append((k*nside+j,k*nside+(j+1)%nside,(k+1)*nside+(j+1)%nside,(k+1)*nside+j))
            colors.append(('bark_mid','bark','bark_mid','bark_light','bark_mid','bark','bark_mid','bark')[j])
    last=(len(P)-1)*nside
    if fractured_tip:
        center=Vector(P[-1]);tangent=(P[-1]-P[-2]).normalized();center+=tangent*.005;ci=len(verts);verts.append(tuple(center))
        groups=[(0,3),(3,6),(6,8)]
        for idx,(a,b) in enumerate(groups):faces.append(tuple([ci]+[last+j%nside for j in range(a,b+1)]));colors.append(('bark_cut','bark_mid','bark_light')[idx])
    else:faces.append(tuple(last+j for j in range(nside)));colors.append('bark_dark')
    return mesh(c,name,verts,faces,mat,colors,{'part_role':role,'fractured_tip':bool(fractured_tip),'cross_section_sides':nside})

def leaf_mass(c,name,cx,cy,cz,width,height,depth,mat):
    # Flattened low-poly crown pillow in the horizontal plane, with a right-swept plan silhouette.
    outline=[(-1,-.04),(-.78,-.64),(-.30,-1),(.45,-.82),(1,0),(.62,.59),(.06,1),(-.66,.68)]
    n=len(outline);verts=[]
    for x,y in outline:verts.append((cx+x*width/2,cy+y*depth/2,cz))
    topoff=len(verts)
    for x,y in outline:verts.append((cx+x*width*.34,cy+y*depth*.34,cz+height/2))
    botoff=len(verts)
    for x,y in outline:verts.append((cx+x*width*.34,cy+y*depth*.34,cz-height/2))
    tc=len(verts);verts.append((cx,cy,cz+height/2));bc=len(verts);verts.append((cx,cy,cz-height/2))
    faces=[];colors=[]
    for j in range(n):
        q=(j+1)%n
        faces.append((j,q,topoff+q,topoff+j));colors.append(('leaf_mid','leaf','leaf_light','leaf_mid','leaf','leaf_mid','leaf_light','leaf')[j])
        faces.append((topoff+j,topoff+q,tc));colors.append(('leaf_light','leaf_mid','leaf_light','leaf','leaf_mid','leaf_light','leaf_mid','leaf')[j])
        faces.append((q,j,botoff+j,botoff+q));colors.append('leaf_dark' if j%2 else 'leaf_edge')
        faces.append((botoff+q,botoff+j,bc));colors.append('leaf_mid' if j%2 else 'leaf_dark')
    ob=mesh(c,name,verts,faces,mat,colors,{'part_role':'broad_foliage_mass','wind_direction_local_x':1.0,'individual_leaves':False})
    return ob

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH'];points=[v.co for o in objs for v in o.data.vertices]
    lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)];health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();t=len(ob.data.loop_triangles);tris+=t;bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':t,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(objs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

def area_light(c,name,loc,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);c.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene not preserved'
    assert bpy.data.scenes.get('WindProduction_N01') is None,'Refusing to overwrite previous N01 Blender scene'
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'N01 concept/prompt missing'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_N01');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('N01_Export');scene.collection.children.link(export);preview=bpy.data.collections.new('N01_Preview_ONLY');scene.collection.children.link(preview);source=bpy.data.collections.new('N01_Source_NOT_EXPORTED');scene.collection.children.link(source)
    mat=make_mat('N01_Shared_WoodAndFoliage_VertexColor')
    living=bpy.data.objects.new('N01_WindBentTree_Living',None);export.objects.link(living);living.location=(-3.1,0,0);living['catalog_height_m']=4.8;living['canopy_envelope_xz_m']=[4.5,3.0];living['primary_branches']=3;living['leaf_masses']=5;living['pivot']='bottom-center at ground; Godot +Z / Blender -Y front'
    dead=bpy.data.objects.new('N01_WindBentTree_Dry_TwoLargeBranches',None);export.objects.link(dead);dead.location=(3.1,0,0);dead['catalog_height_m']=4.8;dead['primary_branches']=2;dead['leaf_masses']=0;dead['derived_from']='same exact S-curved trunk mesh as living tree';dead['pivot']='bottom-center at ground; Godot +Z / Blender -Y front'
    trunk_pts=[(0,0,0),(0,0,.68),(-.23,.02,1.42),(-.16,.05,2.16),(.14,.07,2.88),(.48,.08,3.58),(.66,.08,4.25),(.59,.08,4.60)]
    trunk_r=[.27,.235,.205,.17,.14,.11,.085,.06]
    trunk=tube(export,'N01_Shared_SCurved_Trunk',trunk_pts,trunk_r,mat,False,'shared_s_curved_trunk');trunk.parent=living;trunk['s_curve_direction']='lower left then upper right with prevailing wind'
    # The dead tree reuses the same lower S-curve, with a broad broken termination
    # where its two large branches split away, so no third upright leader remains.
    dry_trunk=tube(export,'N01_Dry_SameTrunk',trunk_pts[:5],trunk_r[:5],mat,True,'shared_s_curved_trunk');dry_trunk.parent=dead;dry_trunk['derived_from']='same lower S-curved trunk control points, truncated at the two-branch crown'
    branches=[
      ('N01_Living_PrimaryBranch_Left', [(-.14,.04,2.20),(-.52,-.04,2.57),(-.83,-.13,3.05),(-.50,-.18,3.38)],[.145,.118,.082,.050]),
      ('N01_Living_PrimaryBranch_MidRight',[(.06,.06,2.76),(.52,-.14,3.11),(1.02,-.24,3.48),(1.78,-.28,3.72)],[.15,.125,.085,.052]),
      ('N01_Living_PrimaryBranch_Crown',[(.44,.07,3.46),(.47,.02,3.86),(.64,-.12,4.22),(.93,-.22,4.48)],[.12,.095,.068,.042])]
    live_branches=[]
    for name,pts,rr in branches:
        ob=tube(export,name,pts,rr,mat,False,'primary_branch');ob.parent=living;live_branches.append(ob)
    # Dry tree retains two broad branches and fractures their ends into three large planes.
    dead_branches=[
      ('N01_Dry_BrokenBranch_Left',[(-.14,.04,2.20),(-.62,-.02,2.60),(-1.10,-.10,3.04),(-1.52,-.16,3.42)],[.15,.125,.09,.055]),
      ('N01_Dry_BrokenBranch_Windward',[(.06,.06,2.76),(.54,-.12,3.16),(1.18,-.20,3.62),(2.00,-.26,4.736)],[.16,.13,.092,.052])]
    dead_meshes=[]
    for name,pts,rr in dead_branches:
        ob=tube(export,name,pts,rr,mat,True,'primary_broken_branch');ob.parent=dead;dead_meshes.append(ob)
    leaf_specs=[
      ('LeftLow',-1.30,-.90,3.35,1.90,.50,1.20),
      ('LeftUpper',-.75,-.35,4.00,1.50,.45,2.30),
      ('Crown',.25,0.0,4.55,1.60,.50,1.40),
      ('RightMid',.95,-.20,3.82,1.60,.45,1.60),
      ('RightLow',1.40,.75,3.30,1.70,.45,1.50)]
    foliage=[]
    for label,x,y,z,w,h,d in leaf_specs:
        ob=leaf_mass(export,'N01_Living_BroadLeafMass_'+label,x,y,z,w,h,d,mat);ob.parent=living;foliage.append(ob)
    # Keep source-only placement notes out of the runtime GLB.
    for root in (living,dead):
        loc=bpy.data.objects.new('N01_Pivot_'+root.name,None);source.objects.link(loc);loc.parent=root;loc.empty_display_type='CIRCLE';loc.hide_render=True;loc.hide_set(True);loc['source_only']=True;loc['pivot']='local bottom-center (0,0,0)'
    source['excluded_from_glb']=True;source['source_only']=True
    groundmat=bpy.data.materials.new('N01_PreviewGround_Material');groundmat.use_nodes=True;bs=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.10,.11,.12,1);bs.inputs['Roughness'].default_value=.95
    gm=bpy.data.meshes.new('N01_PreviewGround_Mesh');gm.from_pydata([(-80,-80,-.02),(80,-80,-.02),(80,80,-.02),(-80,80,-.02)],[],[(0,1,2,3)]);gm.materials.append(groundmat);g=bpy.data.objects.new('N01_PreviewGround',gm);preview.objects.link(g)
    world=bpy.data.worlds.new('N01_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.18,.19,.20,1);bg.inputs['Strength'].default_value=.6;scene.world=world
    for name,loc,power,size in [('N01_Key',(-5,-8,7),2300,8),('N01_Fill',(6,-5,4),1400,7),('N01_Rim',(0,7,6),1800,7)]:area_light(preview,name,loc,power,size,(0,0,2.3))
    cd=bpy.data.cameras.new('N01_PreviewCamera_Data');cam=bpy.data.objects.new('N01_PreviewCamera',cd);preview.objects.link(cam);scene.camera=cam;cam.location=(0,-15,8.5);cam.rotation_euler=(Vector((0,0,2.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');imported=list(set(bpy.data.objects)-before);rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox reference import did not produce an armature'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='N01_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None);assert idle,'Fox Idle action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(-6.1,-2.1,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    for root in (living,dead):
        measurements=measure(root);root['dimensions_blender_xyz_m']=measurements['dimensions_blender_xyz_m'];root['triangles']=measurements['triangles']
        assert abs(measurements['dimensions_blender_xyz_m'][2]-4.8)<.005,(root.name,measurements['dimensions_blender_xyz_m'])
        assert measurements['non_manifold_edges']==0 and measurements['boundary_edges']==0 and measurements['loose_edges']==0 and measurements['loose_vertices']==0,(root.name,measurements)
    live_measure=measure(living);assert all(abs(live_measure['dimensions_blender_xyz_m'][i]-[4.5,3.0,4.8][i])<.005 for i in range(3)),live_measure['dimensions_blender_xyz_m']
    assert len([o for o in living.children_recursive if o.type=='MESH' and o.get('part_role')=='broad_foliage_mass'])==5
    assert len([o for o in living.children_recursive if o.type=='MESH' and o.get('part_role')=='primary_branch'])==3
    assert len([o for o in dead.children_recursive if o.type=='MESH' and o.get('part_role')=='primary_broken_branch'])==2
    assert dry_trunk.get('part_role')=='shared_s_curved_trunk' and dry_trunk.get('fractured_tip')
    assert rig.animation_data.action.name=='Idle'
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    print('N01_BUILD_READY',json.dumps({'scene':scene.name,'dimensions':{r.name:measure(r)['dimensions_blender_xyz_m'] for r in (living,dead)},'triangles':{r.name:measure(r)['triangles'] for r in (living,dead)},'mesh_parts':{r.name:measure(r)['mesh_parts'] for r in (living,dead)},'living_leaf_masses':len(foliage),'living_primary_branches':len(live_branches),'dead_primary_branches':len(dead_meshes),'shared_trunk_mesh':dry_trunk.data is trunk.data,'fox_action':rig.animation_data.action.name,'default_scene_preserved':True}))

main()
