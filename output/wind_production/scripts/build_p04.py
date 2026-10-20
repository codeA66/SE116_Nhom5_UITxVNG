import bpy,bmesh,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    vals=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1.0,)

PAL={'stone_main':lin('#3C4543'),'stone_edge':lin('#4A5450'),'stone_dark':lin('#303735'),'stone_joint':lin('#59625C')}

class MB:
    def __init__(self): self.verts=[]; self.faces=[]; self.colors=[]; self.cache={}
    def v(self,p):
        p=tuple(float(x) for x in p); k=tuple(round(x,7) for x in p)
        if k not in self.cache: self.cache[k]=len(self.verts); self.verts.append(p)
        return self.cache[k]
    def face(self,pts,col='stone_main'):
        ids=[self.v(p) for p in pts]; out=[]
        for i in ids:
            if not out or i!=out[-1]: out.append(i)
        if len(out)>2 and out[0]==out[-1]: out.pop()
        if len(set(out))>=3: self.faces.append(tuple(out)); self.colors.append(col)

def material(name,color,roughness=.85,metallic=0.0,emission=None,strength=0.0,vertex_color=False):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=color; bs.inputs['Roughness'].default_value=roughness; bs.inputs['Metallic'].default_value=metallic
    if emission is not None:
        em=bs.inputs.get('Emission Color') or bs.inputs.get('Emission')
        st=bs.inputs.get('Emission Strength')
        if em: em.default_value=emission
        if st: st.default_value=strength
    if vertex_color:
        vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
        m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def mesh_data(mb,name,mats,use_colors=False):
    me=bpy.data.meshes.new(name); me.from_pydata(mb.verts,[],mb.faces); me.update()
    for mat in mats: me.materials.append(mat)
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    for poly in me.polygons: poly.use_smooth=False
    if use_colors:
        attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for poly,col in zip(me.polygons,mb.colors):
            for li in poly.loop_indices: attr.data[li].color=PAL[col]
    return me

def stone_ring_module():
    mb=MB(); half=math.radians(59); n=6; ang=[-half+2*half*i/n for i in range(n+1)]
    ib=[]; ob=[]; it=[]; ot=[]
    for a in ang:
        ca,sa=math.cos(a),math.sin(a)
        ib.append((1.20*ca,1.20*sa,0.0)); ob.append((1.72*ca,1.72*sa,0.0))
        it.append((1.15*ca,1.15*sa,.18)); ot.append((1.80*ca,1.80*sa,.18))
    for i in range(n):
        mb.face([it[i],ot[i],ot[i+1],it[i+1]],'stone_main' if i%3 else 'stone_edge')
        mb.face([ib[i],ib[i+1],ob[i+1],ob[i]],'stone_dark')
        mb.face([ob[i],ob[i+1],ot[i+1],ot[i]],'stone_main')
        mb.face([ib[i],it[i],it[i+1],ib[i+1]],'stone_dark')
    mb.face([ib[0],ob[0],ot[0],it[0]],'stone_joint')
    mb.face([ib[-1],it[-1],ot[-1],ob[-1]],'stone_joint')
    return mb

def crystal_mesh():
    mb=MB(); n=6; rings=[]
    for z,r in [(-.45,.20),(.29,.38),(.45,.12)]:
        rings.append([(r*math.cos(2*math.pi*i/n),r*math.sin(2*math.pi*i/n),z) for i in range(n)])
    for level in range(2):
        for i in range(n): mb.face([rings[level][i],rings[level][(i+1)%n],rings[level+1][(i+1)%n],rings[level+1][i]])
    mb.face(rings[0][::-1]); mb.face(rings[-1])
    return mb

def empty(coll,name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); coll.objects.link(o); o.empty_display_type='PLAIN_AXES'
    if parent: o.parent=parent
    o.location=loc; return o

def add_object(coll,name,data,parent=None,part=None,rotation_z=0,loc=(0,0,0)):
    ob=bpy.data.objects.new(name,data); coll.objects.link(ob)
    if parent: ob.parent=parent
    ob.location=loc; ob.rotation_euler[2]=math.radians(rotation_z)
    if part: ob['part']=part
    return ob

def preview_setup(scene,prev):
    cd=bpy.data.cameras.new('P04_PreviewCamera_Data'); cam=bpy.data.objects.new('P04_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('P04_Key',(-5,-7,9),1450,5),('P04_Fill',(7,-4,6),800,4),('P04_Rim',(1,6,8),1200,4)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('P04_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=lin('#777B78'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('P04_PreviewGround_Mesh'); me.from_pydata([(-100,-100,-.01),(100,-100,-.01),(100,100,-.01),(-100,100,-.01)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('P04_PreviewGround',me); prev.objects.link(floor)
    world=bpy.data.worlds.new('P04_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.40,.42,.43,1); bg.inputs['Strength'].default_value=.52; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import fox scale reference')
    for ob in imported:
        original=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='P04_Fox_'+original.replace('.','_')
        if any(token in original.lower() for token in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-5.4,-.35,0)
    return cam,rig

def setup_scene():
    assert bpy.data.scenes.get('Scene') is not None,'Preserve original default scene'
    old=bpy.data.scenes.get('WindProduction_P04')
    if old:
        fallback=bpy.data.scenes.get('WindProduction_P03') or bpy.data.scenes.get('Scene')
        if fallback: bpy.context.window.scene=fallback
        bpy.data.scenes.remove(old,do_unlink=True)
    for ob in list(bpy.data.objects):
        if ob.name.startswith('P04_'): bpy.data.objects.remove(ob,do_unlink=True)
    for coll in list(bpy.data.collections):
        if coll.name.startswith('P04_'): bpy.data.collections.remove(coll,do_unlink=True)
    for db in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
        for x in list(db):
            if x.name.startswith('P04_') and x.users==0:
                try: db.remove(x,do_unlink=True)
                except TypeError: db.remove(x)
    scene=bpy.data.scenes.new('WindProduction_P04'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('P04_Export'); scene.collection.children.link(export)
    prev=bpy.data.collections.new('P04_Preview_ONLY'); scene.collection.children.link(prev)
    source=bpy.data.collections.new('P04_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    return scene,export,prev,source

def make_state(export,root,stone_data,crystal_data):
    for i,angle in enumerate((0,120,240),1):
        ob=add_object(export,root.name+f'_RingSegment_{i}',stone_data,root,'ThreePieceWalkableStoneRing',angle)
        ob['module_index']=i; ob['nominal_arc_degrees']=118.0
    center=empty(export,root.name+'_FloatingCrystalCenter',root,(0,0,1.8)); center['crystal_center_height_m']=1.8
    crystal=add_object(export,root.name+'_FacetedCrystal',crystal_data,center,'SeparateFloatingCrystal',0,(0,0,0))
    crystal['crystal_height_m']=.9; crystal['facets']=6
    root['state']='activated' if 'Activated' in root.name else 'off'
    root['pivot']='bottom center of ring at ground z=0'; root['outer_diameter_m']=3.6; root['base_height_m']=.18
    root['crystal_center_height_m']=1.8; root['crystal_height_m']=.9
    root['geometry_shared_off_on']=True
    return {'segments':[bpy.data.objects[root.name+f'_RingSegment_{i}'] for i in range(1,4)],'crystal':crystal}

def main():
    scene,export,prev,source=setup_scene()
    stone=material('P04_SharedNonEmissiveBasalt',(1,1,1,1),.92,.03,vertex_color=True)
    crystal_off_mat=material('P04_Crystal_Off_DarkTeal',(0.025,.105,.13,1),.27,.10)
    crystal_on_mat=material('P04_Crystal_Activated_WarmAmber',(1.0,.40,.08,1),.24,.05,(1.0,.28,.035,1),2.0)
    ring_data=mesh_data(stone_ring_module(),'P04_ThreeArcRingModule_Mesh',[stone],True)
    cbase=mesh_data(crystal_mesh(),'P04_SharedCrystalGeometry_Mesh',[crystal_off_mat],False)
    cactive=cbase.copy(); cactive.name='P04_ActivatedCrystalGeometry_Mesh'; cactive.materials.clear(); cactive.materials.append(crystal_on_mat)
    off=empty(export,'P04_Off_WindCheckpoint'); on=empty(export,'P04_Activated_WindCheckpoint')
    part_off=make_state(export,off,ring_data,cbase); part_on=make_state(export,on,ring_data,cactive)
    for name,loc in [('BottomPivot',(0,0,0)),('FloatingCrystalCenter',(0,0,1.8)),('ApproachZoneCenter',(0,-2.55,0))]:
        e=empty(source,'P04_Source_'+name,off,loc); e['local_coordinates_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    source['approach_clear_zone_m']=[2.0,1.5,2.1]
    cam,fox=preview_setup(scene,prev)
    off.location=(-2.4,0,0); on.location=(2.4,0,0)
    cam.location=(7,-14,8); cam.rotation_euler=(Vector((-.25,0,1.05))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=43
    scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=off
    assert all(part_off['segments'][i].data is part_on['segments'][i].data for i in range(3))
    off_coords=tuple(tuple(round(float(v.co[j]),8) for j in range(3)) for v in part_off['crystal'].data.vertices)
    on_coords=tuple(tuple(round(float(v.co[j]),8) for j in range(3)) for v in part_on['crystal'].data.vertices)
    off_faces=tuple(tuple(p.vertices) for p in part_off['crystal'].data.polygons)
    on_faces=tuple(tuple(p.vertices) for p in part_on['crystal'].data.polygons)
    assert off_coords==on_coords and off_faces==on_faces,'Off/on crystal geometry must match exactly'
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain present'
    print('P04_CREATED',scene.name,'asset_meshes',sum(o.type=='MESH' for o in export.objects),
          'states',off.name,on.name,'base_modules_per_state=3','crystal_center_z_m=1.8','crystal_height_m=0.9',
          'geometry_matches=True','original_scene_preserved=True',
          'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None)

if __name__=='__main__': main()
