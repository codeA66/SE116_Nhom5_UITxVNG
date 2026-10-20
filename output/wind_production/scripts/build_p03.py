import bpy,bmesh,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    vals=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1.0,)

PAL={'stone':lin('#737873'),'stone_light':lin('#9A9B91'),'stone_dark':lin('#555B56'),
     'fracture':lin('#414743'),'book_cover':lin('#534238'),'book_spine':lin('#6F5944'),
     'paper':lin('#E8E2D2'),'paper_edge':lin('#C8C2B2'),'page_shadow':lin('#AAA596')}

class MB:
    def __init__(self): self.verts=[]; self.faces=[]; self.colors=[]; self.cache={}
    def v(self,p):
        p=tuple(float(x) for x in p); k=tuple(round(x,7) for x in p)
        if k not in self.cache: self.cache[k]=len(self.verts); self.verts.append(p)
        return self.cache[k]
    def face(self,pts,col='stone'):
        ids=[self.v(p) for p in pts]; out=[]
        for i in ids:
            if not out or i!=out[-1]: out.append(i)
        if len(out)>2 and out[0]==out[-1]: out.pop()
        if len(set(out))>=3: self.faces.append(tuple(out)); self.colors.append(col)

def material():
    m=bpy.data.materials.new('P03_OneSharedWindReadingPalette'); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1); bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def make_mesh(coll,name,mb,mat,parent=None,part=None):
    if isinstance(mb,bpy.types.Mesh):
        me=mb
    else:
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

def add_beveled_box(mb,center,size,col='stone',ch=.035):
    x,y,z=center; sx,sy,sz=[v*.5 for v in size]; c=min(ch,sx*.38,sy*.38)
    xy=[(-sx+c,-sy),(sx-c,-sy),(sx,-sy+c),(sx,sy-c),(sx-c,sy),(-sx+c,sy),(-sx,sy-c),(-sx,-sy+c)]
    bot=[(x+u,y+v,z-sz) for u,v in xy]; top=[(x+u,y+v,z+sz) for u,v in xy]
    mb.face(bot[::-1],col)
    for i in range(8): mb.face([bot[i],bot[(i+1)%8],top[(i+1)%8],top[i]],'stone_light' if col=='stone' and i in (1,5) else col)
    mb.face(top,col)

def base_mesh(chipped=False):
    mb=MB(); sx=.50; sy=.60; c=.055
    if not chipped:
        outline=[(-sx+c,-sy),(sx-c,-sy),(sx,-sy+c),(sx,sy-c),(sx-c,sy),(-sx+c,sy),(-sx,sy-c),(-sx,-sy+c)]
    else:
        # One broad clean diagonal cut removes only the camera-right front corner.
        cut=.18
        outline=[(-sx+c,-sy),(sx-cut,-sy),(sx,-sy+cut),(sx,sy-c),(sx-c,sy),(-sx+c,sy),(-sx,sy-c),(-sx,-sy+c)]
    lo=[(x,y,0) for x,y in outline]; hi=[(x,y,.18) for x,y in outline]
    mb.face(lo[::-1],'stone_dark')
    for i in range(8): mb.face([lo[i],lo[(i+1)%8],hi[(i+1)%8],hi[i]],'fracture' if chipped and i==1 else 'stone_light' if i in (1,5) else 'stone')
    mb.face(hi,'stone'); return mb

def pedestal_mesh():
    mb=MB(); profiles=[(.18,.84,.76),(.35,.68,.62),(.60,.45,.42),(.92,.42,.40),(1.08,.54,.50),(1.16,.67,.60)]
    rings=[]
    for z,w,d in profiles:
        c=min(.075,w*.17,d*.17)
        xy=[(-w/2+c,-d/2),(w/2-c,-d/2),(w/2,-d/2+c),(w/2,d/2-c),(w/2-c,d/2),(-w/2+c,d/2),(-w/2,d/2-c),(-w/2,-d/2+c)]
        rings.append([(x,y,z) for x,y in xy])
    mb.face(rings[0][::-1],'stone_dark')
    for k in range(len(rings)-1):
        for i in range(8): mb.face([rings[k][i],rings[k][(i+1)%8],rings[k+1][(i+1)%8],rings[k+1][i]],'stone_light' if i in (1,5) else 'stone')
    mb.face(rings[-1],'stone'); return mb

def wind_ribbon_mesh():
    # One subdued broad curve follows the tapered stand's front face from the foot to the desk.
    path=[(-.29,.22),(-.27,.35),(-.20,.52),(-.10,.72),(.015,.91),(.12,1.09)]
    dep=[(.18,.76),(.35,.62),(.60,.42),(.92,.40),(1.08,.50),(1.16,.60)]
    def depth(z):
        for i in range(len(dep)-1):
            z0,d0=dep[i]; z1,d1=dep[i+1]
            if z<=z1:
                t=max(0,min(1,(z-z0)/(z1-z0))); return d0+(d1-d0)*t
        return dep[-1][1]
    mb=MB(); half=.042; thickness=.022; rings=[]
    pts=[Vector((x,0,z)) for x,z in path]
    for i,p in enumerate(pts):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized(); side=Vector((tangent.z,0,-tangent.x)).normalized()
        yfront=-depth(p.z)*.5-.002
        left=p+side*half; right=p-side*half
        rings.append([(left.x,yfront,left.z),(right.x,yfront,right.z),(right.x,yfront+thickness,right.z),(left.x,yfront+thickness,left.z)])
    mb.face(rings[0][::-1],'stone_dark'); mb.face(rings[-1],'stone_dark')
    for i in range(len(rings)-1):
        for j in range(4): mb.face([rings[i][j],rings[i][(j+1)%4],rings[i+1][(j+1)%4],rings[i+1][j]],'stone_light' if j==0 else 'stone_dark')
    return mb

def book_mesh():
    mb=MB()
    add_beveled_box(mb,(0,0,.02),(.70,.50,.04),'book_cover',.018)
    add_beveled_box(mb,(0,0,.052),(.055,.50,.055),'book_spine',.012)
    # Two broad page leaves with a lowered central gutter and a softly lifted outer edge.
    for side in (-1,1):
        xi=side*.018; xo=side*.337; yn=-.228; yp=.228; zb=.043; zi=.090; zo=.1655
        bot=[(xi,yn,zb),(xo,yn,zb),(xo,yp,zb),(xi,yp,zb)]
        top=[(xi,yn,zi),(xo,yn,zo),(xo,yp,zo),(xi,yp,zi)]
        mb.face(bot[::-1],'page_shadow')
        mb.face(top,'paper')
        for j in range(4): mb.face([bot[j],bot[(j+1)%4],top[(j+1)%4],top[j]],'paper_edge' if j in (1,3) else 'paper')
    return mb

def preview_setup(scene,prev):
    cd=bpy.data.cameras.new('P03_PreviewCamera_Data'); cam=bpy.data.objects.new('P03_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('P03_Key',(-5,-6,5),1000,4),('P03_Fill',(6,-4,4),650,3),('P03_Rim',(0,5,5),800,4)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,.7))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('P03_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=lin('#777B78'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('P03_PreviewGround_Mesh'); me.from_pydata([(-80,-80,-.01),(80,-80,-.01),(80,80,-.01),(-80,80,-.01)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('P03_PreviewGround',me); prev.objects.link(floor)
    world=bpy.data.worlds.new('P03_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.40,.42,.43,1); bg.inputs['Strength'].default_value=.52; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import fox scale reference')
    for ob in imported:
        orig=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='P03_Fox_'+orig.replace('.','_')
        if any(token in orig.lower() for token in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-4.2,-.25,0)
    return cam,rig

def source_scene_setup():
    assert bpy.data.scenes.get('Scene') is not None,'Preserve original default scene'
    old=bpy.data.scenes.get('WindProduction_P03')
    if old:
        fallback=bpy.data.scenes.get('WindProduction_I08') or bpy.data.scenes.get('Scene')
        if fallback: bpy.context.window.scene=fallback
        bpy.data.scenes.remove(old,do_unlink=True)
    for ob in list(bpy.data.objects):
        if ob.name.startswith('P03_'): bpy.data.objects.remove(ob,do_unlink=True)
    for coll in list(bpy.data.collections):
        if coll.name.startswith('P03_') and coll.users==0:
            bpy.data.collections.remove(coll)
    for db in (bpy.data.collections,bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
        for x in list(db):
            if x.name.startswith('P03_') and x.users==0:
                try: db.remove(x,do_unlink=True)
                except TypeError: db.remove(x)
    scene=bpy.data.scenes.new('WindProduction_P03'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('P03_Export'); scene.collection.children.link(export)
    prev=bpy.data.collections.new('P03_Preview_ONLY'); scene.collection.children.link(prev)
    source=bpy.data.collections.new('P03_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    return scene,export,prev,source

def build_state(export,root,mat,shared_stand,book_data,chipped=False):
    base=make_mesh(export,root.name+('_ChippedBase' if chipped else '_IntactBase'),base_mesh(chipped),mat,root,'OneBroadCornerChip' if chipped else 'CleanFooting')
    shaft=make_mesh(export,root.name+'_TaperedStoneStand',pedestal_mesh(),mat,root,'SingleTaperedStoneBody')
    surface=empty(export,root.name+'_InclinedReadingSurface',root,(0,0,1.22)); surface.rotation_euler[0]=math.radians(16)
    slab=make_mesh(export,root.name+'_OnePieceReadingSlab',shared_stand['slab'],mat,surface,'SingleSlightlyTiltedSurface')
    curve=make_mesh(export,root.name+'_SingleShallowWindCurve',shared_stand['curve'],mat,root,'OneSubduedNonEmissiveInset')
    book=empty(export,root.name+'_SeparateBook',surface,(0,0,.06)); book['separate_object']=True; book['book_size_m']=[.70,.50]
    pages=make_mesh(export,root.name+'_OpenBook_PagesAndCover',book_data,mat,book,'SeparateSharedUnchangedBook')
    root['variant']='one broad chipped base corner; book intact' if chipped else 'intact wind-reading pedestal'
    root['pivot']='center of bottom plinth, ground at z=0'; root['approach_side']='negative Y; maintain 1.5 m clear'
    root['catalog_envelope_m']=[1.5,1.2,1.5]; root['book_dimensions_m']=[.70,.50]
    return {'base':base,'shaft':shaft,'surface':surface,'slab':slab,'curve':curve,'book':book,'book_mesh':pages}

def main():
    scene,export,prev,source=source_scene_setup(); mat=material()
    intact=empty(export,'P03_Intact_WindReadingPedestal'); broken=empty(export,'P03_Chipped_WindReadingPedestal')
    # Keep shared source mesh datablocks out of the export collection; each variant gets its own
    # object but reuses these exact geometries, so the selected state trees stay self-contained.
    slab_data=bpy.data.meshes.new('P03_SharedInclinedSlab_Mesh'); temp=MB(); add_beveled_box(temp,(0,0,0),(1.5,1.2,.12),'stone_light',.05); slab_data.from_pydata(temp.verts,[],temp.faces); slab_data.update(); slab_data.materials.append(mat)
    attr=slab_data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(slab_data.polygons,temp.colors):
        for li in poly.loop_indices: attr.data[li].color=PAL[col]
    curve_mb=wind_ribbon_mesh(); curve_data=bpy.data.meshes.new('P03_SharedWindCurve_Mesh'); curve_data.from_pydata(curve_mb.verts,[],curve_mb.faces); curve_data.update(); curve_data.materials.append(mat)
    cattr=curve_data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(curve_data.polygons,curve_mb.colors):
        for li in poly.loop_indices: cattr.data[li].color=PAL[col]
    shared_stand={'slab':slab_data,'curve':curve_data}
    book_mb=book_mesh(); book_temp=make_mesh(export,'P03_BookDataTemp',book_mb,mat); book_data=book_temp.data; bpy.data.objects.remove(book_temp,do_unlink=True)
    a=build_state(export,intact,mat,shared_stand,book_data,False)
    b=build_state(export,broken,mat,shared_stand,book_data,True)
    for name,loc in [('PedestalBottomPivot',(0,0,0)),('ReadingSurfaceCenter',(0,0,1.22)),('BookPlacement',(0,0,1.28)),('ApproachZoneCenter',(0,-1.35,0))]:
        e=empty(source,'P03_Source_'+name,intact,loc); e['local_coordinates_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    source['approach_clear_zone_m']=[1.5,1.5,2.0]
    cam,fox=preview_setup(scene,prev)
    intact.location=(-1.8,0,0); broken.location=(1.9,0,0)
    cam.location=(5,-13,6); cam.rotation_euler=(Vector((-.25,0,.72))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=50
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    assert a['book_mesh'].data is b['book_mesh'].data,'The same intact book mesh must be reused'
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain present'
    print('P03_CREATED',scene.name,'asset_meshes',sum(o.type=='MESH' for o in export.objects),
          'roots',intact.name,broken.name,'book_mesh_reused=True','approach_clearance_m=1.5',
          'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,
          'default_scene_preserved=True')

if __name__=='__main__': main()
