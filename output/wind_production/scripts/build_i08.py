import bpy,bmesh,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    vals=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1.0,)

PAL={'wood':lin('#57493A'),'wood_light':lin('#7C684F'),'wood_high':lin('#A28A68'),
     'wood_dark':lin('#38312A'),'fracture':lin('#2D2822'),'stone':lin('#626761'),
     'stone_light':lin('#868982'),'iron':lin('#59615D'),'iron_light':lin('#7B8078'),
     'rope':lin('#A48D6A'),'rope_light':lin('#C0A67B')}

class MB:
    def __init__(self): self.verts=[]; self.faces=[]; self.colors=[]; self.cache={}
    def v(self,p):
        p=tuple(float(x) for x in p); k=tuple(round(x,7) for x in p)
        if k not in self.cache: self.cache[k]=len(self.verts); self.verts.append(p)
        return self.cache[k]
    def face(self,pts,col='wood'):
        ids=[self.v(p) for p in pts]; out=[]
        for i in ids:
            if not out or i!=out[-1]: out.append(i)
        if len(out)>2 and out[0]==out[-1]: out.pop()
        if len(set(out))>=3: self.faces.append(tuple(out)); self.colors.append(col)

def material():
    m=bpy.data.materials.new('I08_OneSharedWindCranePalette'); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1); bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def make_mesh(coll,name,mb,mat,parent=None,part=None):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(mb.verts,[],mb.faces); me.update(); me.materials.append(mat)
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,mb.colors):
        for li in poly.loop_indices: attr.data[li].color=PAL[col]
    for poly in me.polygons: poly.use_smooth=False
    ob=bpy.data.objects.new(name,me); coll.objects.link(ob)
    if parent: ob.parent=parent
    if part: ob['part']=part
    return ob

def empty(coll,name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); coll.objects.link(o); o.empty_display_type='PLAIN_AXES'
    if parent: o.parent=parent
    o.location=loc; return o

def add_bevel_box(mb,center,size,col='wood',ch=.035):
    x,y,z=center; sx,sy,sz=[v*.5 for v in size]; c=min(ch,sx*.4,sy*.4)
    ringxy=[(-sx+c,-sy),(sx-c,-sy),(sx,-sy+c),(sx,sy-c),(sx-c,sy),(-sx+c,sy),(-sx,sy-c),(-sx,-sy+c)]
    bot=[(x+u,y+v,z-sz) for u,v in ringxy]; top=[(x+u,y+v,z+sz) for u,v in ringxy]
    mb.face(bot[::-1],col)
    for i in range(8): mb.face([bot[i],bot[(i+1)%8],top[(i+1)%8],top[i]],'wood_light' if col in ('wood','wood_dark') and i in (1,5) else col)
    mb.face(top,col)

def box_obj(coll,name,center,size,mat,parent=None,col='wood',ch=.035,part=None):
    mb=MB(); add_bevel_box(mb,center,size,col,ch); return make_mesh(coll,name,mb,mat,parent,part)

def beam_mesh(a,b,width=.24,depth=.28,col='wood',cut_start=False,cut_end=False):
    a=Vector(a); b=Vector(b); axis=(b-a).normalized(); u=Vector((-axis.z,0,axis.x)).normalized(); v=Vector((0,1,0))
    c=min(width*.22,depth*.22,.045)
    profile=[(-width/2+c,-depth/2),(width/2-c,-depth/2),(width/2,-depth/2+c),(width/2,depth/2-c),
             (width/2-c,depth/2),(-width/2+c,depth/2),(-width/2,depth/2-c),(-width/2,-depth/2+c)]
    jag=[-.055,.045,.035,-.04,.05,-.035,-.05,.035]
    def ring(center,enabled):
        return [tuple(center+axis*(jag[i] if enabled else 0)+u*s+v*y) for i,(s,y) in enumerate(profile)]
    ra=ring(a,cut_start); rb=ring(b,cut_end); mb=MB()
    for i in range(8): mb.face([ra[i],ra[(i+1)%8],rb[(i+1)%8],rb[i]],'wood_light' if i in (1,5) else col)
    if cut_start:
        for ids in ((0,1,2,3),(0,3,4,5),(0,5,6,7)): mb.face([ra[i] for i in ids],'fracture')
    else: mb.face(ra[::-1],col)
    if cut_end:
        for ids in ((0,1,2,3),(0,3,4,5),(0,5,6,7)): mb.face([rb[i] for i in ids],'fracture')
    else: mb.face(rb,col)
    return mb

def tube_mesh(paths,r=.035,sides=8,col='rope'):
    mb=MB()
    for points in paths:
        ps=[Vector(p) for p in points]
        rings=[]
        for i,p in enumerate(ps):
            tangent=(ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)]).normalized()
            ref=Vector((0,1,0)); u=tangent.cross(ref)
            if u.length<1e-5: u=tangent.cross(Vector((1,0,0)))
            u.normalize(); v=tangent.cross(u).normalized()
            rings.append([tuple(p+r*(math.cos(j*2*math.pi/sides)*u+math.sin(j*2*math.pi/sides)*v)) for j in range(sides)])
        mb.face(rings[0][::-1],col); mb.face(rings[-1],col)
        for i in range(len(rings)-1):
            for j in range(sides):
                mb.face([rings[i][j],rings[i][(j+1)%sides],rings[i+1][(j+1)%sides],rings[i+1][j]],'rope_light' if j in (1,2) else col)
    return mb

def mast_mesh():
    mb=MB(); prof=[(-.155,-.18),(.155,-.18),(.20,-.135),(.20,.135),(.155,.18),(-.155,.18),(-.20,.135),(-.20,-.135)]
    rings=[]
    for z,scale in ((.3,1.0),(.48,1.04),(3.55,.94),(3.78,1.0)):
        rings.append([(x*scale,y*scale,z) for x,y in prof])
    mb.face(rings[0][::-1],'wood_dark')
    for k in range(len(rings)-1):
        for i in range(8): mb.face([rings[k][i],rings[k][(i+1)%8],rings[k+1][(i+1)%8],rings[k+1][i]],'wood_light' if i in (1,5) else 'wood')
    mb.face(rings[-1],'wood_high'); return mb

def wheel_rim_mesh(n=16,outer=.35,inner=.275,depth=.12):
    mb=MB(); loops=[]
    for y,r in ((-depth/2,outer),(-depth/2,inner),(depth/2,outer),(depth/2,inner)):
        loops.append([(r*math.cos(2*math.pi*i/n),y,r*math.sin(2*math.pi*i/n)) for i in range(n)])
    fo,fi,bo,bi=loops
    for i in range(n):
        j=(i+1)%n
        mb.face([fo[i],fo[j],fi[j],fi[i]],'wood_high')
        mb.face([bo[j],bo[i],bi[i],bi[j]],'wood_light')
        mb.face([fo[i],bo[i],bo[j],fo[j]],'wood')
        mb.face([fi[j],bi[j],bi[i],fi[i]],'wood_dark')
    return mb

def cylinder_y_mesh(radius=.105,depth=.15,n=10,col='iron'):
    mb=MB(); lo=[(radius*math.cos(2*math.pi*i/n),-depth/2,radius*math.sin(2*math.pi*i/n)) for i in range(n)]
    hi=[(x,depth/2,z) for x,y,z in lo]
    mb.face(lo[::-1],col); mb.face(hi,'iron_light')
    for i in range(n): mb.face([lo[i],lo[(i+1)%n],hi[(i+1)%n],hi[i]],'iron_light' if i%3==0 else col)
    return mb

def pulley(coll,root,mat,name,center):
    group=empty(coll,name,root,center); group['axis']='Y'; group['diameter_m']=.70
    make_mesh(coll,name+'_WheelRim',wheel_rim_mesh(),mat,group,'16SegmentClosedRim')
    for i in range(5):
        ang=2*math.pi*i/5
        aa=(.07*math.cos(ang),0,.07*math.sin(ang)); bb=(.279*math.cos(ang),0,.279*math.sin(ang))
        make_mesh(coll,name+'_BroadSpoke_%02d'%(i+1),beam_mesh(aa,bb,.065,.10,'wood_light'),mat,group,'OneOfFiveBroadSpokes')
    make_mesh(coll,name+'_AxleHub',cylinder_y_mesh(),mat,group,'SingleAxleHub')
    return group

def basket_mesh():
    mb=MB()
    # compact empty frame, open on top and between the broad lower side rails
    add_bevel_box(mb,(0,0,-.17),(.54,.42,.06),'wood_dark',.018)
    for sx in (-1,1):
        for sy in (-1,1): add_bevel_box(mb,(sx*.235,sy*.175,0),(.07,.07,.36),'wood',.018)
    for sy in (-1,1): add_bevel_box(mb,(0,sy*.175,.15),(.48,.07,.07),'wood_light',.018)
    for sx in (-1,1): add_bevel_box(mb,(sx*.235,0,.15),(.07,.34,.07),'wood_high',.018)
    return mb

def rope_paths_intact():
    main=[(2.58,-.20,4.12),(2.62,-.28,3.45),(2.50,-.30,2.55),(2.30,-.30,1.50),(2.25,-.30,1.20)]
    slings=[[(2.25,-.30,1.20),(2.05,-.38,1.02),(2.00,-.38,.98)],
            [(2.25,-.30,1.20),(2.45,-.38,1.02),(2.50,-.38,.98)]]
    return [main]+slings

def source_scene_setup():
    assert bpy.data.scenes.get('Scene') is not None,'Preserve original default scene'
    old=bpy.data.scenes.get('WindProduction_I08')
    if old:
        fallback=bpy.data.scenes.get('WindProduction_I07') or bpy.data.scenes.get('Scene')
        if fallback: bpy.context.window.scene=fallback
        bpy.data.scenes.remove(old,do_unlink=True)
    for db in (bpy.data.collections,bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
        for x in list(db):
            if x.name.startswith('I08_') and x.users==0:
                try: db.remove(x,do_unlink=True)
                except TypeError: db.remove(x)
    scene=bpy.data.scenes.new('WindProduction_I08'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('I08_Export'); scene.collection.children.link(export)
    prev=bpy.data.collections.new('I08_Preview_ONLY'); scene.collection.children.link(prev)
    source=bpy.data.collections.new('I08_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    return scene,export,prev,source

def preview_setup(scene,prev):
    cd=bpy.data.cameras.new('I08_PreviewCamera_Data'); cam=bpy.data.objects.new('I08_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('I08_Key',(-6,-8,8),1400,6),('I08_Fill',(7,-5,5),900,5),('I08_Rim',(1,6,7),1200,5)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,2.0))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('I08_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=lin('#777B78'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('I08_PreviewGround_Mesh'); me.from_pydata([(-100,-100,-.01),(100,-100,-.01),(100,100,-.01),(-100,100,-.01)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('I08_PreviewGround',me); prev.objects.link(floor)
    world=bpy.data.worlds.new('I08_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.40,.42,.43,1); bg.inputs['Strength'].default_value=.52; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import fox scale reference')
    for ob in imported:
        orig=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='I08_Fox_'+orig.replace('.','_')
        if any(token in orig.lower() for token in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-7.2,-.25,0)
    return cam,rig

def build_state(export,root,mat,broken=False):
    # Shared compact footing, upright mast, and diagonal support brace.
    box_obj(export,root.name+('_StonePlinth' if not broken else '_StonePlinth'),(0,0,.15),(1.1,1.8,.30),mat,root,'stone',.045,'CompactStoneFooting')
    make_mesh(export,root.name+'_UprightMast',mast_mesh(),mat,root,'SingleTaperedTimberMast')
    A=Vector((0,0,2.30)); B=Vector((2.60,0,4.15))
    brace_a=(0,0,.37); brace_b=tuple(A.lerp(B,.12)) if broken else (1.15,0,3.28)
    make_mesh(export,root.name+'_MainSupportBrace',beam_mesh(brace_a,brace_b,.19,.24,'wood_dark'),mat,root,'OneBroadTriangularBrace')
    if not broken:
        make_mesh(export,'I08_Intact_MainDiagonalBoom',beam_mesh(A,B,.28,.34,'wood'),mat,root,'SingleLongBoom')
        box_obj(export,'I08_Intact_PulleyBracket',(2.49,0,4.08),(.26,.22,.25),mat,root,'iron',.035,'SimpleWheelMount')
        wh=pulley(export,root,mat,'I08_Intact_Pulley',(2.60,-.12,4.15))
        basket=empty(export,'I08_Intact_CompactHangingBasket',root,(2.25,0,1.12)); basket['part']='small open cargo frame'
        make_mesh(export,'I08_Intact_EmptyBasketFrame',basket_mesh(),mat,basket,'CompactOpenBasket')
        make_mesh(export,'I08_Intact_SlackHoistAndSlings',tube_mesh(rope_paths_intact(),.032,8),mat,root,'FewThickSlackRopes')
    else:
        t=.15; D=A.lerp(B,t)
        make_mesh(export,'I08_Broken_BoomStump',beam_mesh(A,D,.28,.34,'wood',False,True),mat,root,'LowerBeamWithThreeBroadCutPlanes')
        # Preserve the same remaining beam length and profile, rotated down-right from its fracture.
        remaining=B-D; desired=math.radians(-43); original=math.atan2(remaining.z,remaining.x); delta=original-desired
        E=D+Vector((remaining.length*math.cos(desired),0,remaining.length*math.sin(desired)))
        upper_group=empty(export,'I08_Broken_FallenBoomAndPulley',root,tuple(D)); upper_group.rotation_euler[1]=delta
        upper_local_end=Vector((remaining.x,0,remaining.z))
        make_mesh(export,'I08_Broken_FallenUpperBoom',beam_mesh((0,0,0),upper_local_end,.28,.34,'wood',True,False),mat,upper_group,'MatchingFracturedUpperBeam')
        # Wheel is kept upright and seated at the dropped beam tip, making the fallen state read clearly.
        bracket=empty(export,'I08_Broken_FallenPulleyBracket',root,tuple(E));
        box_obj(export,'I08_Broken_PulleyBracket',(0,0,0),(.24,.22,.22),mat,bracket,'iron',.03,'SimpleWheelMount')
        pulley(export,bracket,mat,'I08_Broken_Pulley',(0,-.12,.07))
        basket=empty(export,'I08_Broken_FallenBasket',root,(2.67,0,.31)); basket.rotation_euler[1]=math.radians(-26); basket['part']='fallen, tilted empty cargo frame'
        make_mesh(export,'I08_Broken_EmptyBasketFrame',basket_mesh(),mat,basket,'CompactOpenBasket')
        fallen_rope=[[(E.x,-.28,E.z),(E.x+.22,-.34,.50),(2.28,-.38,.22),(2.43,-.38,.28)],
                     [(2.43,-.38,.28),(2.53,-.38,.35),(2.62,-.38,.43)]]
        make_mesh(export,'I08_Broken_SlackFallenRopes',tube_mesh(fallen_rope,.032,8),mat,root,'A FewLooseGroundedRopeLines')
    root['variant']='broken boom and fallen basket' if broken else 'intact abandoned decorative cargo lift'
    root['pivot']='bottom-center of compact footing at mast base'; root['catalog_envelope_m']=[3.6,1.8,4.5]
    root['pulley_diameter_m']=.70; root['accessory_not_interactive']=True

def main():
    scene,export,prev,source=source_scene_setup(); mat=material()
    intact=empty(export,'I08_Intact_AbandonedCargoCrane'); build_state(export,intact,mat,False)
    broken=empty(export,'I08_Broken_AbandonedCargoCrane'); build_state(export,broken,mat,True)
    for name,loc in [('MastBasePivot',(0,0,0)),('IntactPulleyAxle',(2.6,-.12,4.15)),('HangingBasketCenter',(2.25,0,1.12)),('DockSurface',(0,0,0))]:
        e=empty(source,'I08_Source_'+name,intact,loc); e['local_coordinates_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    cam,fox=preview_setup(scene,prev)
    intact.location=(-2.3,0,0); broken.location=(2.7,0,0)
    cam.location=(6,-24,11); cam.rotation_euler=(Vector((-.9,0,2.0))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=55
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain present'
    print('I08_CREATED',scene.name,'asset_meshes',sum(o.type=='MESH' for o in export.objects),
          'states',intact.name,broken.name,'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,
          'pulley_diameter_m=.70','default_scene_preserved=True')

if __name__=='__main__': main()
