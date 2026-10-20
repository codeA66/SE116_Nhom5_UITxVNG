import bpy,bmesh,math,os,json
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d03'
PRE=ROOT+'/output/wind_production/d03'
CONCEPT=ROOT+'/output/wind_production/concepts/d03_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/d03_prompt.txt'
YUP=.30

def lin(h):
    rgb=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb)+(1.0,)
WOOD={'wood':lin('#49372D'),'wood_light':lin('#66503D'),'wood_mid':lin('#554333'),'wood_dark':lin('#30261F'),'cut':lin('#806548')}
METAL={'bronze':lin('#525950'),'bronze_light':lin('#6A7164'),'bronze_dark':lin('#3A413B')}

def palette_material(name,palette):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.88
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def rect_oct(hx,hy,cut):
    cut=max(0,min(cut,hx*.45,hy*.45))
    return [(-hx+cut,-hy),(hx-cut,-hy),(hx,-hy+cut),(hx,hy-cut),
            (hx-cut,hy),(-hx+cut,hy),(-hx,hy-cut),(-hx,-hy+cut)]

def build_mesh(coll,name,verts,faces,material,palette,face_colors):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
    me.materials.append(material)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,face_colors):
        rgba=palette[col]
        for li in poly.loop_indices:attr.data[li].color=rgba
    ob=bpy.data.objects.new(name,me);coll.objects.link(ob)
    ob['surface_style']='broad_clean_planes';return ob

def box(coll,name,center,dims,material,palette,body='wood',shift_y=True):
    x,y,z=center;dx,dy,dz=dims
    oct2=rect_oct(dx/2,dy/2,min(dx,dy)*.09)
    yoff=YUP if shift_y else 0.0
    verts=[(x+a,yoff+y+b,z-dz/2) for a,b in oct2]+[(x+a,yoff+y+b,z+dz/2) for a,b in oct2]
    faces=[tuple(reversed(range(8)))]
    colors=['wood_dark']
    for i in range(8):faces.append((i,(i+1)%8,8+(i+1)%8,8+i));colors.append(['wood','wood_light','wood_mid','wood','wood_mid','wood_light','wood','wood_mid'][i%8])
    faces.append(tuple(range(8,16)));colors.append(body if body in palette else 'wood_light')
    if material==None:raise ValueError('Material must be supplied')
    ob=build_mesh(coll,name,verts,faces,material,palette,colors)
    ob['dimensions_m']=[float(dx),float(dy),float(dz)]
    return ob

def beam_between(coll,name,a,b,width,thick,material,palette,body='wood'):
    va=Vector(a);vb=Vector(b);direction=vb-va;length=direction.length
    quat=direction.to_track_quat('Z','Y');cut=min(width,thick)*.12
    section=rect_oct(width/2,thick/2,cut)
    verts=[]
    for z in (-length/2,length/2):
        for sx,sy in section:
            p=quat@Vector((sx,sy,z))+((va+vb)*.5);verts.append((p.x,p.y+YUP,p.z))
    faces=[tuple(reversed(range(8)))];colors=['wood_dark']
    for i in range(8):faces.append((i,(i+1)%8,8+(i+1)%8,8+i));colors.append(['wood','wood_light','wood_mid','wood','wood_mid','wood_light','wood','wood_mid'][i])
    faces.append(tuple(range(8,16)));colors.append(body if body in palette else 'wood_light')
    return build_mesh(coll,name,verts,faces,material,palette,colors)

def cylinder_x(coll,name,cx,cy,cz,radius,depth,material,palette,n=12,body='wood'):
    verts=[]
    for x in (cx-depth/2,cx+depth/2):
        for i in range(n):
            a=2*math.pi*i/n;verts.append((x,YUP+cy+radius*math.cos(a),cz+radius*math.sin(a)))
    faces=[tuple(reversed(range(n)))];colors=['wood_dark']
    for i in range(n):faces.append((i,(i+1)%n,n+(i+1)%n,n+i));colors.append('wood_mid' if i%4==0 else 'wood')
    faces.append(tuple(n+i for i in range(n)));colors.append(body if body in palette else 'wood_light')
    ob=build_mesh(coll,name,verts,faces,material,palette,colors);ob['disk_wheel']=True
    return ob

def metal_band(coll,name,ycenter,xouter,zlo,zhi,thickness,material):
    # A single closed octagonal-section hoop, one of exactly two broad body straps.
    xo=xouter;xi=xo-.045;zi0=zlo+.045;zi1=zhi-.045
    outer=[(-xo,zlo),(xo,zlo),(xo,zhi),(-xo,zhi)]
    inner=[(-xi,zi0),(xi,zi0),(xi,zi1),(-xi,zi1)]
    loops=[outer+inner,outer+inner];ys=(ycenter-thickness/2+YUP,ycenter+thickness/2+YUP)
    verts=[]
    for loop,y in zip(loops,ys):verts.extend((x,y,z) for x,z in loop)
    faces=[];colors=[]
    # Outside and inside perimeter surfaces.
    for i in range(4):
        j=(i+1)%4
        faces.append((i,j,8+j,8+i));colors.append('bronze_dark' if i==0 else 'bronze')
        faces.append((4+i,4+j,12+j,12+i));colors.append('bronze_dark')
    # Four broad front and back strips close the hoop.
    for base in (0,8):
        for i in range(4):
            j=(i+1)%4;faces.append((base+i,base+j,base+4+j,base+4+i));colors.append('bronze_light' if i==2 else 'bronze')
    ob=build_mesh(coll,name,verts,faces,material,METAL,colors)
    ob['broad_body_band']=True;return ob

def add_cart(export,root,wood,metal):
    parts=[]
    # Floor, three broad boards; box remains narrow and open at the top.
    for i,x in enumerate((-.30,0,.30),1):
        parts.append(box(export,f'D03_Intact_FloorBoard_{i}',(x,.225,.625),(.29,1.13,.11),wood,WOOD))
    # Three broad horizontal planks on each long and short side.
    zlevels=(.705,.875,1.045)
    for side,x in (('Left',-.455),('Right',.455)):
        for i,z in enumerate(zlevels,1):
            parts.append(box(export,f'D03_Intact_{side}_WallBoard_{i}',(x,.225,z),(.065,1.12,.15),wood,WOOD))
    for end,y in (('Front',-.32),('Rear',.77)):
        for i,z in enumerate(zlevels,1):
            parts.append(box(export,f'D03_Intact_{end}_WallBoard_{i}',(0,y,z),(.88,.065,.15),wood,WOOD))
    # Four substantial corner posts hold the board walls without decorative bracket clutter.
    for sx,side in ((-1,'Left'),(1,'Right')):
        for sy,end in ((-1,'Front'),(1,'Rear')):
            parts.append(box(export,f'D03_Intact_CornerPost_{side}_{end}',(sx*.43,.225+sy*.545,.87),(.09,.09,.54),wood,WOOD,body='wood_mid'))
    # Precisely two broad bronze hoops around the body.
    parts.append(metal_band(export,'D03_Intact_BroadBronzeBand_01',-.075,.505,.555,1.18,.085,metal))
    parts.append(metal_band(export,'D03_Intact_BroadBronzeBand_02',.525,.505,.555,1.18,.085,metal))
    # Wooden axle remains exposed at the missing-wheel end of the tipped state.
    parts.append(box(export,'D03_Intact_WoodAxle',(0,.20,.46),(1.23,.10,.10),wood,WOOD,body='wood_dark'))
    # Quiet solid disk wheels on a shared axle; no spokes or extra hardware.
    for side,label in ((-1,'NegX'),(1,'PosX')):
        cx=side*.565
        parts.append(cylinder_x(export,f'D03_Intact_Wheel_{label}_Disk',cx,.20,.46,.46,.13,wood,WOOD,n=12,body='wood_mid'))
        hubx=side*.66
        parts.append(cylinder_x(export,f'D03_Intact_Wheel_{label}_Hub',hubx,.20,.46,.115,.08,wood,WOOD,n=10,body='wood_light'))
    # Long paired wooden pull rails make the diagonal silhouette; one wood crosspiece joins their tips.
    for side,label in ((-1,'Left'),(1,'Right')):
        parts.append(beam_between(export,f'D03_Intact_{label}_DiagonalHandle', (side*.27,-.30,.95),(side*.27,-1.37,1.245),.075,.075,wood,WOOD))
    parts.append(beam_between(export,'D03_Intact_HandleTipCrossbar',(-.27,-1.355,1.24),(.27,-1.355,1.24),.075,.075,wood,WOOD))
    for ob in parts:
        ob.parent=root;ob['state']='upright_intact'
    root['variant']='upright_abandoned_cart';root['catalog_envelope_m']=[1.4,2.2,1.3]
    root['body_band_count']=2;root['wood_boards_per_side']=3;root['wheel_count']=2;root['pull_handle']='paired long diagonal wood rails'
    return parts

def make_empty(coll,name,description):
    ob=bpy.data.objects.new(name,None);coll.objects.link(ob);ob.empty_display_type='PLAIN_AXES';ob['design']=description;return ob

def area_light(coll,name,loc,power,size,target):
    ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size
    ob=bpy.data.objects.new(name,ld);coll.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def setup_preview(scene,coll):
    cd=bpy.data.cameras.new('D03_PreviewCamera_Data');cam=bpy.data.objects.new('D03_PreviewCamera',cd);coll.objects.link(cam);scene.camera=cam
    for name,loc,power,size in [('D03_Key',(-8,-9,9),3200,7),('D03_Fill',(8,-4,6),1700,6),('D03_Rim',(0,7,8),2600,6)]:area_light(coll,name,loc,power,size,(0,0,.6))
    gm=bpy.data.materials.new('D03_PreviewGround');gm.use_nodes=True;bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(.19,.21,.20,1);bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('D03_PreviewGround_Mesh');me.from_pydata([(-80,-80,-.04),(80,-80,-.04),(80,80,-.04),(-80,80,-.04)],[],[(0,1,2,3)]);me.materials.append(gm)
    floor=bpy.data.objects.new('D03_PreviewGround',me);coll.objects.link(floor)
    world=bpy.data.worlds.new('D03_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.30,.32,.31,1);bg.inputs['Strength'].default_value=.72;scene.world=world
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before);rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if rig is None:raise RuntimeError('Actual fox reference did not import as an armature')
    for ob in imported:
        old=ob.name
        for c in list(ob.users_collection):c.objects.unlink(ob)
        coll.objects.link(ob);ob.name='D03_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data:rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1);rig.location=(-4.6,-2.6,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    return cam,rig

def main():
    default=bpy.data.scenes.get('Scene')
    assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain preserved'
    assert bpy.data.scenes.get('WindProduction_D03') is None,'Refusing to duplicate existing D03 scene'
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_D03');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('D03_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('D03_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('D03_SourceLocators_NOT_EXPORTED');scene.collection.children.link(source)
    wood=palette_material('D03_Shared_Wood_VertexColor',WOOD);metal=palette_material('D03_Shared_MutedBronze_VertexColor',METAL)
    intact=make_empty(export,'D03_Upright_AbandonedCart','Narrow abandoned wood cargo cart, two solid disk wheels, long diagonal paired handles, two broad bronze body hoops; catalog envelope 1.4 x 2.2 x 1.3 m.')
    original_parts=add_cart(export,intact,wood,metal)
    # Fit measured wheel hubs and handle tips precisely within the catalog envelope and ground-centered pivot.
    pts=[v.co.copy() for ob in original_parts for v in ob.data.vertices]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    actual=hi-lo;target=Vector((1.4,2.2,1.3));center=(lo+hi)*.5
    assert min(actual)>0 and max(abs((actual[i]-target[i])/target[i]) for i in range(3))<.15,{'actual':list(actual),'expected':list(target)}
    scale=Vector((target.x/actual.x,target.y/actual.y,target.z/actual.z))
    for ob in original_parts:
        for v in ob.data.vertices:
            v.co.x=(v.co.x-center.x)*scale.x
            v.co.y=(v.co.y-center.y)*scale.y
            v.co.z=(v.co.z-center.z)*scale.z+target.z/2
        ob.data.update()
    intact.location=(-1.55,0,0)
    # Derive the fallen prop directly from the normalized intact meshes. Roll around the far-side lower body edge.
    tipped=make_empty(export,'D03_Tipped_MissingWheel_Cart','Same source cart rolled onto its positive-X side; one wheel is missing with exposed axle, and three compact cargo blocks lie beside the low side.')
    tipped.location=(1.55,0,0);tipped['variant']='tipped_one_wheel_missing_cargo_spilled';tipped['removed_wheels']=1;tipped['remaining_wheels']=1
    tipped['wheel_removed']='positive-X side';tipped['exposed_axle']=True;tipped['cargo_blocks_spilled']=3
    pivot=Vector((-.49,0,.48));rot=__import__('mathutils').Matrix.Rotation(math.radians(73),4,'Y')
    clones=[]
    for ob in original_parts:
        if ob.name in ('D03_Intact_Wheel_PosX_Disk','D03_Intact_Wheel_PosX_Hub'):continue
        dup=ob.copy();dup.data=ob.data.copy();dup.name=ob.name.replace('D03_Intact_','D03_Tipped_',1);export.objects.link(dup);dup.parent=tipped;dup.location=(0,0,0);dup.rotation_euler=(0,0,0);dup.scale=(1,1,1)
        for v in dup.data.vertices:
            p=pivot+rot@(v.co-pivot);v.co=p
        dup.data.update();dup['state']='tipped_derived_from_intact_cart';dup['source_mesh_object']=ob.name;clones.append(dup)
    bpy.context.view_layer.update()
    tippts=[o.matrix_world.inverted_safe()@ (o.matrix_world@v.co) for o in clones for v in o.data.vertices]
    # Clones are parented only to tipped; bake the local pivot transform into each source-derived mesh above.
    tippts=[v.co.copy() for o in clones for v in o.data.vertices]
    lo2=Vector(tuple(min(p[i] for p in tippts) for i in range(3)));hi2=Vector(tuple(max(p[i] for p in tippts) for i in range(3)))
    offset=Vector((-(lo2.x+hi2.x)/2,-(lo2.y+hi2.y)/2,-lo2.z))
    for ob in clones:
        for v in ob.data.vertices:v.co+=offset
        ob.data.update()
    # Cargo has fallen onto the low side after the cart is tipped; it does not prop up the body.
    for i,(x,y,w,d,h) in enumerate(((.86,-.30,.34,.30,.23),(.90,.10,.32,.30,.21),(.83,.40,.27,.25,.18)),1):
        box(export,f'D03_Tipped_SpilledCargoBlock_{i}',(x,y,h/2),(w,d,h),wood,WOOD,body='wood_light',shift_y=False).parent=tipped
    tipped['source_geometry']='rigidly rotated copies of the intact cart mesh parts';tipped['roll_degrees']=73.0;tipped['roll_axis']='Y'
    # Keep each variant root at bottom-center after adding the loose cargo blocks.
    tip_objects=[o for o in tipped.children_recursive if o.type=='MESH'];tipverts=[o.matrix_world.inverted_safe()@(o.matrix_world@v.co) for o in tip_objects for v in o.data.vertices]
    tlo=Vector(tuple(min(p[i] for p in tipverts) for i in range(3)));thi=Vector(tuple(max(p[i] for p in tipverts) for i in range(3)))
    # Recenter all tipped geometry with a shared translation.
    shift=Vector((-(tlo.x+thi.x)/2,-(tlo.y+thi.y)/2,-tlo.z))
    for ob in tip_objects:
        for v in ob.data.vertices:v.co+=shift
        ob.data.update()
    # The clone transforms are in mesh-local coordinates; root pivot locators document placement.
    for root in (intact,tipped):
        loc=bpy.data.objects.new('D03_SourcePivot_'+root.name,None);source.objects.link(loc);loc.parent=root;loc.empty_display_type='CIRCLE';loc.hide_render=True;loc.hide_set(True)
        loc['source_only']=True;loc['pivot']='Variant root origin at horizontal bounds center and ground contact.'
    source['excluded_from_glb']=True;source['source_only']=True
    cam,fox=setup_preview(scene,preview)
    cam.location=(5.2,-7.8,4.7);cam.rotation_euler=(Vector((0,0,.65))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=42
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.2
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects:ob.select_set(False)
    for ob in export.objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    print('D03_CREATED',json.dumps({'intact_original_dimensions_pre_normalization':list(actual),'fit_scale_xyz':list(scale),
        'intact_mesh_parts':len(original_parts),'tipped_derived_parts':len(clones),'wheel_removed':'positive-X','cargo_blocks':3,
        'default_scene_preserved':all(default.objects.get(n) for n in ('Cube','Camera','Light'))}))

main()
