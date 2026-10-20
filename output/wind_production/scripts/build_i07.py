import bpy,bmesh,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    vals=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1.0,)

PAL={'wood':lin('#50453A'),'wood_light':lin('#71604C'),'wood_dark':lin('#39332D'),
     'fracture':lin('#302B26'),'rope':lin('#A58E6B'),'rope_light':lin('#C0A57B')}

PROFILE=[(-.135,-.225),(.135,-.225),(.225,-.135),(.225,.135),(.135,.225),(-.135,.225),(-.225,.135),(-.225,-.135)]
FRACTURE_Z=[.205,.22,.265,.28,.25,.235,.215,.19]
CUT=.24

class MB:
    def __init__(self): self.verts=[]; self.faces=[]; self.colors=[]; self.cache={}
    def v(self,p):
        p=tuple(float(x) for x in p); k=tuple(round(x,7) for x in p)
        if k not in self.cache: self.cache[k]=len(self.verts); self.verts.append(p)
        return self.cache[k]
    def face(self,pts,col='wood',reverse=False):
        ids=[self.v(p) for p in pts]; out=[]
        for i in ids:
            if not out or i!=out[-1]: out.append(i)
        if len(out)>2 and out[0]==out[-1]: out.pop()
        if len(set(out))>=3:
            self.faces.append(tuple(reversed(out)) if reverse else tuple(out)); self.colors.append(col)

def material():
    m=bpy.data.materials.new('I07_OneSharedTimberAndRopePalette'); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1); bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def make_mesh(coll,name,mb,mat,parent=None,part=None):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(mb.verts,[],mb.faces); me.update(); me.materials.append(mat)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,mb.colors):
        for li in poly.loop_indices: attr.data[li].color=PAL[col]
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth=False
    ob=bpy.data.objects.new(name,me); coll.objects.link(ob)
    if parent: ob.parent=parent
    if part: ob['part']=part
    return ob

def empty(coll,name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); coll.objects.link(o); o.empty_display_type='PLAIN_AXES'
    if parent: o.parent=parent
    o.location=loc; return o

def profile_ring(z,scale=1.0): return [(x*scale,y*scale,z) for x,y in PROFILE]

def connect_rings(mb,a,b,which='wood'):
    for i in range(8):
        col=which
        if i in (1,4): col='wood_light'
        mb.face([a[i],a[(i+1)%8],b[(i+1)%8],b[i]],col)

def cap_faces(mb,ring,col='wood_dark',reverse=False): mb.face(ring,col,reverse)

def whole_post_mesh():
    mb=MB(); rings=[profile_ring(-.12,1.0),profile_ring(0,1.0),profile_ring(.75,1.0),
                    profile_ring(.80,1.0),profile_ring(.96,1.22),profile_ring(1.08,1.08)]
    cap_faces(mb,rings[0],'wood_dark',True)
    for i in range(len(rings)-1):
        shade='wood_light' if i>=3 else 'wood'
        connect_rings(mb,rings[i],rings[i+1],shade)
    cap_faces(mb,rings[-1],'wood_light')
    return mb

def fracture_ring(stump=True,local=False):
    return [(x,y,(FRACTURE_Z[i]-CUT if local else FRACTURE_Z[i])) for i,(x,y) in enumerate(PROFILE)]

def fractured_cap(mb,ring,reverse=False):
    # Three large facets tile the same irregular eight-sided split face on both broken pieces.
    regions=[[0,1,2,3],[0,3,4,5],[0,5,6,7]]
    for ids in regions: mb.face([ring[i] for i in ids],'fracture',reverse)

def stump_mesh():
    mb=MB(); low=profile_ring(-.12); base=profile_ring(0); top=fracture_ring()
    cap_faces(mb,low,'wood_dark',True); connect_rings(mb,low,base); connect_rings(mb,base,top,'wood')
    fractured_cap(mb,top,False)
    return mb

def upper_mesh():
    mb=MB(); bottom=fracture_ring(local=True)
    rings=[bottom,profile_ring(.75-CUT),profile_ring(.80-CUT),profile_ring(.96-CUT,1.22),profile_ring(1.08-CUT,1.08)]
    fractured_cap(mb,bottom,True)
    for i in range(len(rings)-1): connect_rings(mb,rings[i],rings[i+1],'wood_light' if i>=2 else 'wood')
    cap_faces(mb,rings[-1],'wood_light')
    return mb

def rope_loop(mb,z,r=.031,sides=8):
    # One chunky closed octagonal cord, no strand texture or secondary coils.
    center=[(x*1.10,y*1.10,z) for x,y in PROFILE]; rings=[]
    up=Vector((0,0,1))
    for i,p in enumerate(center):
        prev=Vector(center[(i-1)%8]); nxt=Vector(center[(i+1)%8]); tangent=(nxt-prev).normalized()
        u=tangent.cross(up).normalized(); v=up.copy(); c=Vector(p)
        rings.append([tuple(c+r*(math.cos(j*2*math.pi/sides)*u+math.sin(j*2*math.pi/sides)*v)) for j in range(sides)])
    for i in range(8):
        ni=(i+1)%8
        for j in range(sides):
            col='rope_light' if j in (1,2) else 'rope'
            mb.face([rings[i][j],rings[i][(j+1)%sides],rings[ni][(j+1)%sides],rings[ni][j]],col)

def rope_obj(coll,name,mat,parent,z_local):
    mb=MB(); rope_loop(mb,z_local)
    return make_mesh(coll,name,mb,mat,parent,'SingleChunkyRopeLoop')

def preview_setup(scene,prev):
    cd=bpy.data.cameras.new('I07_PreviewCamera_Data'); cam=bpy.data.objects.new('I07_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('I07_Key',(-5,-7,6),1200,5),('I07_Fill',(6,-4,4),750,4),('I07_Rim',(0,5,5),900,4)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,.45))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('I07_PreviewGround'); gm.use_nodes=True; bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=lin('#777B78'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('I07_PreviewGround_Mesh'); me.from_pydata([(-80,-80,-.01),(80,-80,-.01),(80,80,-.01),(-80,80,-.01)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('I07_PreviewGround',me); prev.objects.link(floor)
    world=bpy.data.worlds.new('I07_PreviewWorld'); world.use_nodes=True; bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.40,.42,.43,1); bg.inputs['Strength'].default_value=.52; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import fox scale reference')
    originals={o:o.name for o in imported}
    for ob in imported:
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='I07_Fox_'+originals[ob].replace('.','_')
        if any(token in originals[ob].lower() for token in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-4.0,-.18,0)
    return cam,rig

def setup_scene():
    old=bpy.data.scenes.get('WindProduction_I07')
    if old:
        fallback=bpy.data.scenes.get('WindProduction_I06') or bpy.data.scenes.get('Scene')
        if fallback: bpy.context.window.scene=fallback
        bpy.data.scenes.remove(old,do_unlink=True)
    for db in (bpy.data.collections,bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
        for x in list(db):
            if x.name.startswith('I07_') and x.users==0:
                try: db.remove(x,do_unlink=True)
                except TypeError: db.remove(x)
    scene=bpy.data.scenes.new('WindProduction_I07'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('I07_Export'); scene.collection.children.link(export)
    prev=bpy.data.collections.new('I07_Preview_ONLY'); scene.collection.children.link(prev)
    return scene,export,prev

def main():
    assert bpy.data.scenes.get('Scene') is not None,'Preserve original default scene'
    scene,export,prev=setup_scene(); mat=material()
    upright=empty(export,'I07_Upright_MooringPost'); upright['variant']='upright'; upright['pivot']='embedded dock surface at (0,0,0)'; upright['embed_depth_m']=.12
    pg=empty(export,'I07_Upright_WoodPost',upright); pg['part']='MainOctagonalPost'; pg['shaft_width_m']=.45; pg['cap_width_m']=.55
    make_mesh(export,'I07_Upright_Post_OctagonalFlaredCap',whole_post_mesh(),mat,pg,'PostAndSingleShallowFlare')
    rg=empty(export,'I07_Upright_Rope',upright); rope_obj(export,'I07_Upright_SingleLowRopeLoop',mat,rg,.39)
    broken=empty(export,'I07_LeaningBroken_MooringPost'); broken['variant']='one structural split; upper section leans 20 degrees'; broken['pivot']='embedded dock surface at (0,0,0)'; broken['embed_depth_m']=.12
    stump=empty(export,'I07_Broken_AnchoredStump',broken); stump['part']='lower piece from same upright post'
    make_mesh(export,'I07_Broken_Post_Stump',stump_mesh(),mat,stump,'LowerCutPiece')
    upper=empty(export,'I07_Broken_LeaningUpper',broken,(0,0,CUT)); upper.rotation_euler[1]=math.radians(20); upper['part']='matching upper piece from same post'; upper['fracture_facets']=3
    make_mesh(export,'I07_Broken_Post_LeaningUpper',upper_mesh(),mat,upper,'UpperCutPiece')
    rope=empty(export,'I07_Broken_Upper_Rope',upper); rope_obj(export,'I07_Broken_SingleLowRopeLoop',mat,rope,.39-CUT)
    # Source-only placement locators preserve the base pivot and dock surface without entering the GLB.
    source=bpy.data.collections.new('I07_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    for name,loc in [('EmbeddedBasePivot',(0,0,0)),('DockSurface',(0,0,0)),('RopeLoopCenter',(0,0,.39))]:
        e=empty(source,'I07_Source_'+name,upright,loc); e['local_coordinates_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    cam,fox=preview_setup(scene,prev)
    upright.location=(-2.2,0,0); broken.location=(2.2,0,0)
    cam.location=(5.4,-13.5,6.2); cam.rotation_euler=(Vector((0,0,.48))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=65
    scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for o in bpy.context.view_layer.objects: o.select_set(False)
    for o in export.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=upright
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain present'
    print('I07_CREATED',scene.name,'asset_meshes',sum(o.type=='MESH' for o in export.objects),
          'states',upright.name,broken.name,'source_locators',3,
          'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,
          'default_scene_preserved=True')

main()
