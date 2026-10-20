import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/d02'
PRE=ROOT+'/output/wind_production/d02'
CONCEPT=ROOT+'/output/wind_production/concepts/d02_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/d02_prompt.txt'
PAL={
 'stone':(0.0908,0.1070,0.0976,1), 'stone_light':(0.1714,0.1946,0.1714,1),
 'stone_mid':(0.0612,0.0742,0.0670,1), 'stone_dark':(0.0296,0.0395,0.0343,1),
 'edge':(0.1301,0.1470,0.1332,1), 'fracture':(0.2502,0.2831,0.2720,1)
}

def octagon(hx,hy,cut):
    return [(-hx+cut,-hy),(hx-cut,-hy),(hx,-hy+cut),(hx,hy-cut),
            (hx-cut,hy),(-hx+cut,hy),(-hx,hy-cut),(-hx,-hy+cut)]

def make_stone(coll,root,name,cx,cy,w,d,h,material,style='block',lean=(0,0),role='auxiliary'):
    # Eight planar masonry sides and three broad, adjoining top fracture facets.
    cut=min(w,d)*(.17 if style=='slab' else .14)
    base=octagon(w*.5,d*.5,cut)
    if style=='wedge':
        ratios=[.91,1,.94,.80,.79,.85,.95,.91]
        top_h=[h*r for r in ratios]
        upper=[(x+lean[0],y+lean[1]) for x,y in base]
    elif style=='slab':
        ratios=[.88,.96,1,.79,.83,.93,.99,.91]
        top_h=[h*r for r in ratios]
        upper=[(x+lean[0],y+lean[1]) for x,y in base]
    else:
        ratios=[.88,.98,1,.84,.79,.90,.97,.89]
        top_h=[h*r for r in ratios]
        upper=[(x+lean[0],y+lean[1]) for x,y in base]
    verts=[(cx+x,cy+y,0.0) for x,y in base]
    verts += [(cx+x,cy+y,top_h[i]) for i,(x,y) in enumerate(upper)]
    faces=[tuple(reversed(range(8)))]; colors=['stone_dark']
    side_palette=['stone','stone_light','stone_mid','stone','edge','stone_mid','stone','stone_light']
    for i in range(8):
        faces.append((i,(i+1)%8,8+(i+1)%8,8+i))
        colors.append(side_palette[i])
    # Three broad co-planar regions split by two deliberate fracture seams.
    faces.extend([(8,9,10,11),(8,11,14,15),(11,12,13,14)])
    colors.extend(['fracture','stone_light','stone_mid'])
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(material)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,color in zip(me.polygons,colors):
        for li in poly.loop_indices: attr.data[li].color=PAL[color]
    ob=bpy.data.objects.new(name,me); coll.objects.link(ob); ob.parent=root
    ob['role']=role; ob['fracture_facets']=2; ob['broad_masonry_faces']=True
    ob['dimensions_local_m']=[float(w),float(d),float(max(top_h))]
    ob['shape_style']=style
    return ob

def empty(coll,name,description):
    ob=bpy.data.objects.new(name,None);coll.objects.link(ob);ob.empty_display_type='PLAIN_AXES';ob['design']=description
    return ob

def area_light(coll,name,loc,power,size,target):
    ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size
    ob=bpy.data.objects.new(name,ld);coll.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def setup_preview(scene,coll):
    camdata=bpy.data.cameras.new('D02_PreviewCamera_Data');cam=bpy.data.objects.new('D02_PreviewCamera',camdata);coll.objects.link(cam);scene.camera=cam
    for name,loc,power,size in [('D02_Key',(-8,-10,10),3600,7),('D02_Fill',(8,-4,6),1800,6),('D02_Rim',(0,7,8),2600,6)]:
        area_light(coll,name,loc,power,size,(0,0,.55))
    gm=bpy.data.materials.new('D02_PreviewGround');gm.diffuse_color=(.22,.24,.23,1);gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.22,.24,.23,1);bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('D02_PreviewGround_Mesh');me.from_pydata([(-80,-80,-.035),(80,-80,-.035),(80,80,-.035),(-80,80,-.035)],[],[(0,1,2,3)]);me.materials.append(gm)
    floor=bpy.data.objects.new('D02_PreviewGround',me);coll.objects.link(floor)
    world=bpy.data.worlds.new('D02_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.31,.33,.32,1);bg.inputs['Strength'].default_value=.75;scene.world=world
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before);rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if rig is None:raise RuntimeError('Actual fox reference did not import as an armature')
    for ob in imported:
        old=ob.name
        for c in list(ob.users_collection):c.objects.unlink(ob)
        coll.objects.link(ob);ob.name='D02_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data:rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1);rig.location=(5.45,-2.65,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    return cam,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None, 'Preserve original default Cube/Camera/Light scene'
    default=bpy.data.scenes['Scene']
    assert all(default.objects.get(n) is not None for n in ('Cube','Camera','Light')), 'Original default objects are missing'
    assert bpy.data.scenes.get('WindProduction_D02') is None, 'Refusing to duplicate existing D02 scene'
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
    source=bpy.data.objects.get('L04_Intact_RingArc_02')
    assert source and source.data.materials and source.data.materials[0].name=='L04_Shared_Stone_VertexColor'
    material=source.data.materials[0]
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_D02');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('D02_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('D02_Preview_ONLY');scene.collection.children.link(preview)
    layout_specs=[
      {'id':'compact_low_wedge','name':'D02_Compact_LowWedge','center':-3.5,'dims':[1.2,1.0,.5],
       'desc':'Low, compact five-stone rubble wedge; one hero stone plus four tucked auxiliaries. Exact local envelope 1.2 x 1.0 x 0.5 m.',
       'stones':[('Hero_Wedge',0,0,.62,.42,.50,'wedge',(0.035,0),'dominant'),('West_Block',-.45,0,.30,.44,.20,'block',(0,0),'auxiliary'),('East_Block',.45,0,.30,.44,.23,'block',(0,0),'auxiliary'),('Near_Block',0,-.35,.38,.26,.17,'block',(0,0),'auxiliary'),('Far_Block',0,.35,.38,.26,.18,'block',(0,0),'auxiliary')]},
      {'id':'medium_sideways_spread','name':'D02_Medium_SidewaysSpread','center':0.0,'dims':[2.0,1.5,.8],
       'desc':'Sideways-spread five-stone masonry rubble; one strong horizontal slab and four tucked auxiliaries. Exact local envelope 2.0 x 1.5 x 0.8 m.',
       'stones':[('Hero_SidewaysSlab',0,0,1.18,.58,.80,'block',(0.025,0),'dominant'),('West_Block',-.82,0,.36,.54,.39,'block',(0,0),'auxiliary'),('East_Block',.82,0,.36,.54,.43,'block',(0,0),'auxiliary'),('Near_Block',-.24,-.51,.62,.40,.29,'block',(0,0),'auxiliary'),('Far_Block',.24,.51,.62,.40,.34,'block',(0,0),'auxiliary')]},
      {'id':'large_upright_leaning_slab','name':'D02_Large_UprightLeaningSlab','center':3.5,'dims':[3.0,2.0,1.2],
       'desc':'Large upright-leaning slab with four closely tucked companion blocks, one dominant stone and two strong shadow gaps. Exact local envelope 3.0 x 2.0 x 1.2 m.',
       'stones':[('Hero_LeaningSlab',0,0,1.24,.72,1.20,'slab',(.18,0),'dominant'),('West_Block',-1.20,-.22,.60,.66,.58,'block',(0,0),'auxiliary'),('East_Block',1.20,.22,.60,.66,.53,'block',(0,0),'auxiliary'),('Near_Block',-.12,-.77,.68,.44,.42,'block',(0,0),'auxiliary'),('Far_Block',.12,.77,.68,.44,.49,'block',(0,0),'auxiliary')]}
    ]
    roots=[]
    for spec in layout_specs:
        root=empty(export,spec['name'],spec['desc']);root.location=(spec['center'],0,0)
        root['variant']=spec['id'];root['catalog_envelope_local_m']=spec['dims'];root['stone_count']=5
        root['dominant_count']=1;root['auxiliary_count']=4;root['shadow_gaps']=2
        for entry in spec['stones']:
            name,cx,cy,w,d,h,style,lean,role=entry
            make_stone(export,root,spec['name']+'_'+name,cx,cy,w,d,h,material,style,lean,role)
        roots.append(root)
    cam,fox=setup_preview(scene,preview)
    cam.location=(1.3,-11.4,6.6);target=Vector((0,0,.48));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.25
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects:ob.select_set(False)
    for ob in export.objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=roots[2]
    print('D02_CREATED',json.dumps({'scene':scene.name,'variants':[(r.name,list(r['catalog_envelope_local_m'])) for r in roots],
         'stone_counts':[r['stone_count'] for r in roots],'shared_material':material.name,
         'default_scene_preserved':all(default.objects.get(n) is not None for n in ('Cube','Camera','Light')),
         'actual_fox_idle':bool(fox.animation_data and fox.animation_data.action and fox.animation_data.action.name=='Idle')}))

main()
