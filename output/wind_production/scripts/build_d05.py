import bpy,bmesh,math,os,json
from mathutils import Vector,Matrix
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/d05';PRE=ROOT+'/output/wind_production/d05'
CONCEPT=ROOT+'/output/wind_production/concepts/d05_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/d05_prompt.txt'
STONE={'stone':(.075,.089,.078,1),'stone_mid':(.105,.121,.107,1),'stone_light':(.185,.202,.176,1),'stone_dark':(.041,.052,.045,1),'field':(.12,.137,.12,1),'fracture':(.15,.168,.148,1),'edge':(.062,.075,.066,1)}

def mat_vertex(name):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color']);return m

def mesh(c,name,verts,faces,mat,colors,pal,props=None):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,colors):
        rgba=pal[col]
        for li in poly.loop_indices:ca.data[li].color=rgba
    ob=bpy.data.objects.new(name,me);c.objects.link(ob);ob['surface_style']='broad_clean_planes'
    if props:
        for k,v in props.items():ob[k]=v
    return ob

def create_empty(c,name,desc):
    o=bpy.data.objects.new(name,None);c.objects.link(o);o.empty_display_type='PLAIN_AXES';o['design']=desc;return o

def intact_outline(cut):
    return [(-1.2+cut,0),(1.2-cut,0),(1.2,cut),(1.2,2.8-cut),(1.2-cut,2.8),(-1.2+cut,2.8),(-1.2,2.8-cut),(-1.2,cut)]

def damaged_outline(bottom_x,left_z):
    return [(bottom_x,0),(1.08,0),(1.2,.12),(1.2,2.68),(1.08,2.8),(-1.08,2.8),(-1.2,2.68),(-1.2,left_z)]

def slab_mesh(c,name,mat,damaged=False):
    if not damaged:
        loops=[(-.075,intact_outline(.12)),(.175,intact_outline(.07))]
    else:
        loops=[(-.075,damaged_outline(-.78,.62)),(.05,damaged_outline(-.82,.56)),(.175,damaged_outline(-.76,.65))]
    n=8;verts=[]
    for y,outline in loops:verts.extend((x,y,z) for x,z in outline)
    faces=[tuple(reversed(range(n)))];colors=['stone']
    faces.append(tuple(range((len(loops)-1)*n,len(loops)*n)));colors.append('stone_dark')
    side_colors=['stone_mid','stone','stone_mid','stone','stone_mid','stone','stone_mid','fracture']
    for layer in range(len(loops)-1):
        for i in range(n):
            faces.append((layer*n+i,layer*n+(i+1)%n,(layer+1)*n+(i+1)%n,(layer+1)*n+i))
            colors.append(('fracture' if i==7 and layer==0 else 'stone_light' if i==7 and layer==1 else side_colors[i]) if damaged else side_colors[i])
    ob=mesh(c,name,verts,faces,mat,colors,STONE,{'missing_lower_left_corner':bool(damaged),'fracture_plane_count':2 if damaged else 0,'front_axis':'Blender -Y / Godot +Z'})
    return ob

def xz_plate(c,name,xmin,xmax,zmin,zmax,yback,yfront,mat,pal,front_color,side_color):
    hx=(xmax-xmin)/2;hz=(zmax-zmin)/2;cx=(xmax+xmin)/2;cz=(zmax+zmin)/2;cut=min(hx,hz)*.05
    outline=[(cx-hx+cut,cz-hz),(cx+hx-cut,cz),(cx+hx,cz-hz+cut),(cx+hx,cz+hz-cut),(cx+hx-cut,cz+hz),(cx-hx+cut,cz+hz),(cx-hx,cz+hz-cut),(cx-hx,cz-hz+cut)]
    verts=[(x,yfront,z) for x,z in outline]+[(x,yback,z) for x,z in outline];faces=[tuple(reversed(range(8))),tuple(range(8,16))];colors=[front_color,'stone_dark']
    for i in range(8):faces.append((i,(i+1)%8,8+(i+1)%8,8+i));colors.append(side_color)
    return mesh(c,name,verts,faces,mat,colors,pal,{'panel_role':'one_broad_inset_field'})

def ribbon(c,name,points,widths,mat):
    front_y=-.175;back_y=-.075;n=len(points);left=[];right=[]
    for k,(x,z) in enumerate(points):
        a=points[max(0,k-1)];b=points[min(n-1,k+1)];dx=b[0]-a[0];dz=b[1]-a[1];l=math.hypot(dx,dz);nx=-dz/l;nz=dx/l
        left.append((x+nx*widths[k]/2,z+nz*widths[k]/2));right.append((x-nx*widths[k]/2,z-nz*widths[k]/2))
    verts=[]
    for y in (front_y,back_y):
        for pair in (left,right):verts.extend((x,y,z) for x,z in pair)
    off=2*n;faces=[];colors=[]
    for k in range(n-1):faces.append((k,k+1,n+k+1,n+k));colors.append('stone_light')
    for k in range(n-1):faces.append((off+n+k,off+n+k+1,off+k+1,off+k));colors.append('stone_mid')
    for k in range(n-1):faces.append((k,off+k,off+k+1,k+1));colors.append('stone')
    for k in range(n-1):faces.append((n+k,n+k+1,off+n+k+1,off+n+k));colors.append('stone')
    faces.extend([(0,n,off+n,off),(n-1,2*n-1,off+2*n-1,off+n-1)]);colors.extend(['stone_mid','stone_mid'])
    ob=mesh(c,name,verts,faces,mat,colors,STONE,{'relief_depth_m':.10,'f01_emblem_derived':True});return ob

def build_emblem(c,root,stem,mat,scale=1.6,center_z=1.82):
    objs=[]
    pts=[(.365*math.cos(math.radians(28+304*k/64))*scale,center_z+.365*math.sin(math.radians(28+304*k/64))*scale) for k in range(65)]
    ring=ribbon(c,stem+'_Open_C_Ring',pts,[.12*scale]*65,mat);ring.parent=root;ring['emblem_component']='open C ring, right opening';objs.append(ring)
    for row in [-1,0,1]:
        pts=[];widths=[]
        for k in range(17):
            t=k/16;x=-.245+.49*t;z=center_z+row*.18+.057*math.sin((t-.5)*math.pi*1.5)
            pts.append((x*scale,center_z+(z-center_z)*scale));widths.append((.016+.092*math.sin(math.pi*t)**.55)*scale)
        ob=ribbon(c,stem+'_WindStroke_'+('Lower' if row==-1 else 'Middle' if row==0 else 'Upper'),pts,widths,mat);ob.parent=root;ob['emblem_component']='broad same-direction wind stroke';objs.append(ob)
    return objs

def measure(root):
    objs=[o for o in root.children_recursive if o.type=='MESH'];pts=[v.co for o in objs for v in o.data.vertices];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];health=[];tris=0
    for ob in objs:
        ob.data.calc_loop_triangles();tris+=len(ob.data.loop_triangles);bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'name':ob.name,'triangles':len(ob.data.loop_triangles),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(objs),'triangles':tris,'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

def area_light(c,name,loc,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);c.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o

def setup_preview(scene,c):
    cd=bpy.data.cameras.new('D05_PreviewCamera_Data');cam=bpy.data.objects.new('D05_PreviewCamera',cd);c.objects.link(cam);scene.camera=cam
    for name,loc,power,size in [('D05_Key',(-7,-9,8),3200,6),('D05_Fill',(7,-4,5),1500,5),('D05_Rim',(0,6,7),2400,5)]:area_light(c,name,loc,power,size,(0,0,1.2))
    gm=bpy.data.materials.new('D05_PreviewGround');gm.use_nodes=True;bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.12,.14,.14,1);bs.inputs['Roughness'].default_value=.96;me=bpy.data.meshes.new('D05_PreviewGround_Mesh');me.from_pydata([(-80,-80,-.02),(80,-80,-.02),(80,80,-.02),(-80,80,-.02)],[],[(0,1,2,3)]);me.materials.append(gm);floor=bpy.data.objects.new('D05_PreviewGround',me);c.objects.link(floor)
    world=bpy.data.worlds.new('D05_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.23,.25,.25,1);bg.inputs['Strength'].default_value=.7;scene.world=world
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');new=list(set(bpy.data.objects)-before);rig=next((o for o in new if o.type=='ARMATURE'),None)
    if rig is None:raise RuntimeError('Actual fox reference did not import as an armature')
    for ob in new:
        old=ob.name
        for oldcoll in list(ob.users_collection):oldcoll.objects.unlink(ob)
        c.objects.link(ob);ob.name='D05_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data:rig.animation_data_create()
        rig.animation_data.action=idle
    rig.location=(-4.0,-1.55,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    return cam,rig

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene not preserved'
    assert bpy.data.scenes.get('WindProduction_D05') is None,'Refusing to overwrite a previous D05 Blender scene'
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'D05 actual concept or prompt missing'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_D05');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('D05_Export');scene.collection.children.link(export);preview=bpy.data.collections.new('D05_Preview_ONLY');scene.collection.children.link(preview);source=bpy.data.collections.new('D05_SourceLocators_NOT_EXPORTED');scene.collection.children.link(source)
    mat=mat_vertex('D05_Shared_Stone_VertexColor')
    intact=create_empty(export,'D05_StoneRelief_Intact','Upright 2.4 x 0.35 x 2.8 m low-poly stone slab with exact F01 open C-ring and three-stroke wind emblem; 0.10 m raised relief; bottom-center pivot.')
    broken=create_empty(export,'D05_StoneRelief_MissingLowerLeftCorner','Same exact F01 emblem on the same stone slab; one genuine lower-left corner missing with two broad fracture planes and a stable flat base.')
    intact.location=(-1.55,0,0);broken.location=(1.55,0,0)
    a=slab_mesh(export,'D05_Intact_StoneSlab',mat,False);a.parent=intact
    ap=xz_plate(export,'D05_Intact_InsetField',-1.04,1.04,.62,2.68,-.055,-.08,mat,STONE,'field','stone_mid');ap.parent=intact
    aemb=build_emblem(export,intact,'D05_Intact',mat)
    b=slab_mesh(export,'D05_Broken_StoneSlab',mat,True);b.parent=broken
    bp=xz_plate(export,'D05_Broken_InsetField',-1.04,1.04,.62,2.68,-.055,-.08,mat,STONE,'field','stone_mid');bp.parent=broken
    for ob in aemb:
        dup=bpy.data.objects.new(ob.name.replace('D05_Intact','D05_Broken'),ob.data);export.objects.link(dup);dup.parent=broken;dup.location=(0,0,0);dup['derived_from']=ob.name;dup['emblem_component']=ob['emblem_component'];dup['relief_depth_m']=.10;dup['f01_emblem_derived']=True
    intact['catalog_dimensions_m']=[2.4,.35,2.8];intact['front_axis']='Godot +Z';intact['relief_depth_m']=.10;intact['emblem_source']='exact F01 build_f01.py curves, scaled uniformly 1.6x';intact['states']='intact'
    broken['catalog_dimensions_m']=[2.4,.35,2.8];broken['front_axis']='Godot +Z';broken['relief_depth_m']=.10;broken['emblem_source']='shared exact F01 emblem meshes';broken['states']='missing_lower_left_corner';broken['missing_area']='lower-left corner, chip ends below emblem and retains 1.84 m flat base'
    cam,fox=setup_preview(scene,preview);cam.location=(0,-9.4,5.6);cam.rotation_euler=(Vector((0,0,1.25))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    for root in (intact,broken):
        loc=bpy.data.objects.new('D05_Pivot_'+root.name,None);source.objects.link(loc);loc.empty_display_type='CIRCLE';loc.parent=root;loc.location=(0,0,0);loc.hide_render=True;loc.hide_set(True);loc['source_only']=True;loc['pivot']='local bottom-center (0,0,0); front normal points Blender -Y / Godot +Z'
    source['source_only']=True;source['excluded_from_glb']=True
    roots=[intact,broken];measurements={r.name:measure(r) for r in roots}
    for r in roots:
        q=measurements[r.name];assert all(abs(q['dimensions_blender_xyz_m'][i]-[2.4,.35,2.8][i])<.005 for i in range(3)),(r.name,q)
        assert abs(q['bounds_min_blender_m'][0]+q['bounds_max_blender_m'][0])<.005 and abs(q['bounds_min_blender_m'][1]+q['bounds_max_blender_m'][1])<.005 and abs(q['bounds_min_blender_m'][2])<.005,(r.name,q)
        assert q['non_manifold_edges']==0 and q['boundary_edges']==0 and q['loose_edges']==0 and q['loose_vertices']==0,(r.name,q)
    for r in roots:
        em=[o for o in r.children_recursive if o.type=='MESH' and o.get('emblem_component')]
        assert len(em)==4,(r.name,[o.name for o in em])
    assert all(o.data.color_attributes.get('Color') is not None for r in roots for o in r.children_recursive if o.type=='MESH')
    assert fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle'
    assert bpy.data.scenes['Scene'] and all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    print('D05_BUILD_READY',json.dumps({'scene':scene.name,'states':{k:{'dimensions_blender_xyz_m':v['dimensions_blender_xyz_m'],'dimensions_godot_xyz_m':v['dimensions_godot_xyz_m'],'triangles':v['triangles'],'parts':v['mesh_parts'],'manifold':v['non_manifold_edges']==0 and v['boundary_edges']==0} for k,v in measurements.items()},'emblem_components':{r.name:[o.name for o in r.children_recursive if o.type=='MESH' and o.get('emblem_component')] for r in roots},'fox_action':fox.animation_data.action.name,'default_scene_preserved':True}))

main()
