import bpy, bmesh, math, os
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
CODE = 'L05'
OUT = ROOT + '/assets/generated/wind_ruins/l05'
PRE = ROOT + '/output/wind_production/l05'

def lin(h):
    rgb=[int(h[i:i+2],16)/255.0 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1.0,)

PAL={'stone':lin('#626961'),'stone_light':lin('#85877D'),'stone_mid':lin('#555B56'),
     'stone_dark':lin('#353B39'),'edge':lin('#72786F'),'fracture':lin('#A29B87'),
     'teal':lin('#416B68'),'teal_light':lin('#5B8881'),'teal_dark':lin('#345653'),
     'foundation':lin('#4B524E')}

def shared_material():
    m=bpy.data.materials.new('L05_Shared_Stone_and_Windframe_VertexColor')
    m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1); bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def mesh_obj(coll,name,verts,faces,colors,mat,parent=None):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(mat)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,c in zip(me.polygons,colors):
        for li in poly.loop_indices: attr.data[li].color=PAL[c]
    ob=bpy.data.objects.new(name,me); coll.objects.link(ob)
    if parent: ob.parent=parent
    return ob

def empty(coll,name,parent=None,description=''):
    ob=bpy.data.objects.new(name,None); coll.objects.link(ob); ob.empty_display_type='PLAIN_AXES'
    if parent: ob.parent=parent
    if description: ob['design']=description
    return ob

def octagon(hx,hy,cut):
    return [(-hx+cut,-hy),(hx-cut,-hy),(hx,-hy+cut),(hx,hy-cut),
            (hx-cut,hy),(-hx+cut,hy),(-hx,hy-cut),(-hx,-hy+cut)]

def prism(coll,name,parent,mat,center,levels,side_colors=None,top='stone_light',bottom='stone_dark'):
    # Levels are (z, half-x, half-y, corner-cut); broad, closed eight-sided masonry.
    x0,y0=center; verts=[]
    for z,hx,hy,cut in levels: verts.extend((x0+x,y0+y,z) for x,y in octagon(hx,hy,cut))
    faces=[tuple(reversed(range(8)))]; colors=[bottom]
    sc=side_colors or ['stone','stone_light','stone_mid','stone','stone_light','stone_mid','stone','stone_mid']
    for layer in range(len(levels)-1):
        for i in range(8):
            faces.append((layer*8+i,layer*8+(i+1)%8,(layer+1)*8+(i+1)%8,(layer+1)*8+i))
            colors.append(sc[i%len(sc)])
    off=(len(levels)-1)*8; faces.append(tuple(off+i for i in range(8))); colors.append(top)
    return mesh_obj(coll,name,verts,faces,colors,mat,parent)

def beam(coll,name,parent,mat,a,b,width,depth=None,palette='stone'):
    a=Vector(a); b=Vector(b); axis=(b-a).normalized(); depth=depth or width
    side=Vector((0,1,0))
    if abs(axis.dot(side))>.94: side=Vector((1,0,0))
    side=(side-axis*axis.dot(side)).normalized(); other=axis.cross(side).normalized()
    verts=[]
    for p in (a,b):
        for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            v=p+side*s*width/2+other*t*depth/2; verts.append(tuple(v))
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    if palette=='teal': colors=['teal_dark','teal_light','teal','teal_light','teal','teal_light']
    else: colors=['fracture','stone_light','stone','stone_mid','stone_light','stone_mid']
    ob=mesh_obj(coll,name,verts,faces,colors,mat,parent)
    return ob

def add_lower(coll,root,mat,prefix):
    # Exactly 6 m from a stable 3 m square base to the designed crown fracture.
    prism(coll,prefix+'_FoundationMass',root,mat,(0,0),
          [(0,1.5,1.5,.18),(.26,1.42,1.42,.16),(.64,1.22,1.22,.14)],
          ['foundation','stone_mid','stone_dark','stone_mid']*2,'stone_light','stone_dark')
    prism(coll,prefix+'_BaseCap',root,mat,(0,0),
          [(.64,1.28,1.28,.14),(.82,1.13,1.13,.13)],
          ['stone_mid','stone_light','stone','stone_mid']*2,'stone_light','stone_dark')
    # Three major projecting tier masses, with clean voids between them.
    tiers=[(1.60,1.34),(3.47,1.17),(5.27,1.02)]
    for ti,(z,half) in enumerate(tiers,1):
        prism(coll,f'{prefix}_Tier{ti}_BroadMass',root,mat,(0,0),
              [(z-.27,half-.09,half-.09,.13),(z-.06,half,half,.14),
               (z+.24,half-.11,half-.11,.13),(z+.35,half-.20,half-.20,.11)],
              ['stone_mid','stone_light','stone','stone_mid']*2,'stone_light','stone_dark')
    # Four broad-beveled corner pillars in each open bay; slight taper gives a tall, elegant read.
    bays=[(.80,.82,1.33,.24),(.68,1.97,3.44,.21),(.57,3.82,5.00,.19)]
    for bi,(off,z0,z1,w) in enumerate(bays,1):
        for sx in (-1,1):
            for sy in (-1,1):
                c=(sx*off,sy*off)
                prism(coll,f'{prefix}_Bay{bi}_CornerPier_{sx}_{sy}',root,mat,c,
                      [(z0,w/2,w/2,.045),(z0+.10,w*.53/2,w*.53/2,.045),
                       (z1-.10,w*.44/2,w*.44/2,.035),(z1,w*.48/2,w*.48/2,.035)],
                      ['stone_mid','stone_light','stone','stone_dark']*2,'fracture','stone_dark')
    # A quiet neck closes the lower section at a precise 6 m fracture datum.
    prism(coll,prefix+'_BreakNeck',root,mat,(0,0),
          [(5.62,.52,.52,.10),(5.84,.46,.46,.09),(6.0,.39,.39,.08)],
          ['stone_mid','stone_light','stone','stone_dark']*2,'fracture','stone_dark')
    # Four small closed fracture stubs make the 6 m cut read as broad planes.
    for sx in (-1,1):
        for sy in (-1,1):
            prism(coll,f'{prefix}_BreakStub_{sx}_{sy}',root,mat,(sx*.43,sy*.43),
                  [(5.82,.10,.10,.025),(5.94,.14,.14,.03),(6.0,.13,.11,.025)],
                  ['stone_mid','stone_light','stone','stone_dark']*2,'fracture','stone_dark')
    root['lower_body_height_m']=6.0; root['base_width_depth_m']=[3.0,3.0]
    root['tier_heights_blender_m']=[1.6,3.47,5.27]

def add_top(coll,top,mat,prefix):
    # Authored in local coordinates z=0..3. Its intact world transform starts at z=6.
    prism(coll,prefix+'_CrownSeat',top,mat,(0,0),
          [(0,.92,.92,.12),(.23,.83,.83,.11),(.34,.72,.72,.10)],
          ['stone_mid','stone_light','stone','stone_dark']*2,'stone_light','fracture')
    for sx in (-1,1):
        for sy in (-1,1):
            prism(coll,f'{prefix}_CrownPier_{sx}_{sy}',top,mat,(sx*.55,sy*.55),
                  [(.34,.13,.13,.025),(.47,.15,.15,.03),(.92,.10,.10,.02),(1.00,.12,.12,.02)],
                  ['stone_mid','stone_light','stone','stone_dark']*2,'fracture','fracture')
    prism(coll,prefix+'_UpperCollar',top,mat,(0,0),
          [(.92,.84,.84,.12),(1.12,.89,.89,.12),(1.28,.70,.70,.10)],
          ['stone_mid','stone_light','stone','stone_dark']*2,'stone_light','stone_dark')
    # Sparse wind-frame: one square lower ring, four strong diagonals and a compact apex.
    r= .80; z0=1.26; z1=1.48
    pts=[(-r,-r,z0),(r,-r,z0),(r,r,z0),(-r,r,z0)]
    for i in range(4): beam(coll,f'{prefix}_FrameBaseBeam_{i+1}',top,mat,pts[i],pts[(i+1)%4],.12,.12,'teal')
    # Horizontal cross ties at the crown shoulder retain broad open voids.
    beam(coll,prefix+'_FrameCrossbar_X',top,mat,(-.78,0,1.55),(.78,0,1.55),.10,.10,'teal')
    beam(coll,prefix+'_FrameCrossbar_Y',top,mat,(0,-.78,1.55),(0,.78,1.55),.10,.10,'teal')
    apex=(0,0,2.94)
    for i,p in enumerate(pts,1): beam(coll,f'{prefix}_PyramidSailFrame_{i}',top,mat,p,apex,.16,.14,'teal')
    prism(coll,prefix+'_ApexCap',top,mat,(0,0),
          [(2.87,.17,.17,.04),(2.96,.12,.12,.035),(3.0,.07,.07,.02)],
          ['teal_dark','teal_light','teal','teal_dark']*2,'teal_light','teal_dark')
    top['designed_section_height_m']=3.0; top['section_origin_blender_m']=[0,0,0]

def duplicate_top(coll,source_top,target_top,prefix):
    clones=[]
    for ob in list(source_top.children):
        if ob.type!='MESH': continue
        cp=bpy.data.objects.new(prefix+ob.name.split('_',1)[-1],ob.data)
        coll.objects.link(cp); cp.parent=target_top
        cp.location=ob.location.copy(); cp.rotation_euler=ob.rotation_euler.copy(); cp.scale=ob.scale.copy()
        cp['reuses_intact_mesh']=ob.name
        clones.append(cp)
    return clones

def locator(coll,name,loc,description):
    ob=empty(coll,'L05_Source_'+name,description=description); ob.location=loc
    ob.hide_render=True; ob.hide_set(True); ob['source_only']=True
    ob['local_coordinates_blender_m']=[float(v) for v in loc]
    return ob

def preview_setup(scene,preview):
    cd=bpy.data.cameras.new('L05_PreviewCamera_Data'); cam=bpy.data.objects.new('L05_PreviewCamera',cd); preview.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('L05_Key',(-12,-18,18),5200,11),('L05_Fill',(13,-8,11),2600,10),('L05_Rim',(1,15,17),4300,9)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        o=bpy.data.objects.new(name,ld); preview.objects.link(o); o.location=loc
        o.rotation_euler=(Vector((0,0,4))-o.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('L05_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=lin('#858A85'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('L05_PreviewGround_Mesh'); me.from_pydata([(-100,-100,-.08),(100,-100,-.08),(100,100,-.08),(-100,100,-.08)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('L05_PreviewGround',me); preview.objects.link(floor)
    world=bpy.data.worlds.new('L05_PreviewWorld'); world.use_nodes=True; bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.42,.44,.43,1); bg.inputs['Strength'].default_value=.8; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Actual fox reference import did not include an armature')
    for ob in imported:
        old=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        preview.objects.link(ob); ob.name='L05_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(0,-4.0,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file: im.pack()
    return cam,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain preserved'
    assert bpy.data.scenes.get('WindProduction_L05') is None,'Refusing to overwrite an existing L05 scene'
    os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True); open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_L05'); bpy.context.window.scene=scene; scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('L05_Export'); scene.collection.children.link(export)
    preview=bpy.data.collections.new('L05_Preview_ONLY'); scene.collection.children.link(preview)
    source=bpy.data.collections.new('L05_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    mat=shared_material()
    intact=empty(export,'L05_Intact_ObservatoryTower',description='3 x 3 m base; three broad tier masses; exact 9 m sail-frame tip.')
    broken=empty(export,'L05_Broken_ObservatoryTower',description='Exact 6 m retained lower body and the same 3 m top section fallen beside it.')
    add_lower(export,intact,mat,'L05_Intact'); add_lower(export,broken,mat,'L05_Broken')
    top_i=empty(export,'L05_Intact_ExactTopSection_3m',intact,'Reusable crown geometry, local z=0..3 m.')
    top_i.location=(0,0,6); add_top(export,top_i,mat,'L05_ExactTop')
    top_f=empty(export,'L05_Broken_FallenExactTopSection',broken,'Same crown mesh data, rotated as one 3 m section; no scaling.')
    top_f.location=(1.90,0,.90); top_f.rotation_euler=(0,math.radians(76),0)
    clone_meshes=duplicate_top(export,top_i,top_f,'L05_FallenReuse_')
    intact['overall_dimensions_blender_xyz_m']=[3,3,9]; intact['full_height_m']=9
    broken['remaining_body_height_m']=6; broken['fallen_section_height_before_rotation_m']=3
    broken['fallen_top_anchor_blender_m']=[1.90,0,.90]; broken['fallen_rotation_degrees']=[0,76,0]
    locator(source,'BottomCenterPivot',(0,0,0),'Bottom-center ground pivot for both state roots.')
    locator(source,'SixMeterBreakPlane',(0,0,6),'Designed top-of-retained-body datum; broad fracture planes meet z=6.')
    locator(source,'IntactSailFrameTip',(0,0,9),'Highest point of the intact frame, exactly 9 m above ground.')
    locator(source,'FallenCrownAnchor',(1.90,0,.90),'Reuse of exact 3 m crown geometry beside broken lower body.')
    source['design_dimensions_m']={'base':[3,3],'intact_height':9,'break_height':6,'top_section_height':3}
    cam,fox=preview_setup(scene,preview); intact.location=(-4.05,0,0); broken.location=(4.05,0,0)
    cam.location=(0,-26,17); target=Vector((0,0,4.25)); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=40
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    print('L05_CREATED',{'scene':scene.name,'export_meshes':sum(o.type=='MESH' for o in export.objects),
       'intact_top_meshes':len(list(top_i.children)),'fallen_reused_meshes':len(clone_meshes),
       'all_fallen_mesh_data_reused':all(any(x.data is y.data for y in top_i.children if y.type=='MESH') for x in clone_meshes),
       'fox_action':fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,
       'default_scene_preserved':bpy.data.scenes.get('Scene') is not None})

main()
