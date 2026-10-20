import bpy, bmesh, math
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    values=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)+(1.0,)

PAL={
 'hull':lin('#403B34'),'hull_light':lin('#585047'),'hull_dark':lin('#302C27'),
 'deck':lin('#766650'),'deck_light':lin('#927D5F'),'deck_edge':lin('#594A3A'),
 'linen':lin('#D5C6A1'),'linen_light':lin('#E4D7B8'),'linen_fold':lin('#B3A17C'),
 'emblem':lin('#263A3A'),'rope':lin('#A18B68')
}

class MB:
    def __init__(self): self.verts=[]; self.faces=[]; self.colors=[]; self.cache={}
    def v(self,p):
        p=tuple(float(x) for x in p); k=tuple(round(x,7) for x in p)
        if k not in self.cache: self.cache[k]=len(self.verts); self.verts.append(p)
        return self.cache[k]
    def face(self,pts,color='hull',reverse=False):
        ids=[self.v(p) for p in pts]
        clean=[]
        for i in ids:
            if not clean or i!=clean[-1]: clean.append(i)
        if len(clean)>2 and clean[0]==clean[-1]: clean.pop()
        if len(set(clean))>=3:
            self.faces.append(tuple(reversed(clean)) if reverse else tuple(clean)); self.colors.append(color)

def material():
    m=bpy.data.materials.new('I06_OneSharedPalette'); m.use_nodes=True
    b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value=(1,1,1,1); b.inputs['Roughness'].default_value=.88
    a=m.node_tree.nodes.new('ShaderNodeVertexColor'); a.layer_name='Color'
    m.node_tree.links.new(a.outputs['Color'],b.inputs['Base Color'])
    return m

def mesh_obj(coll,name,mb,mat,parent=None,part=None,shared=None):
    if shared is None:
        me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(mb.verts,[],mb.faces); me.update()
        me.materials.append(mat)
        attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for poly,col in zip(me.polygons,mb.colors):
            for li in poly.loop_indices: attr.data[li].color=PAL[col]
        bm=bmesh.new(); bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        for p in me.polygons: p.use_smooth=False
    else: me=shared
    ob=bpy.data.objects.new(name,me); coll.objects.link(ob)
    if parent: ob.parent=parent
    if part: ob['part']=part
    return ob

def box(mb,x0,x1,y0,y1,z0,z1,top='deck_light',side='deck_edge',bottom='hull_dark'):
    p=[(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
       (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    mb.face([p[i] for i in (0,3,2,1)],bottom)
    mb.face([p[i] for i in (4,5,6,7)],top)
    for a,b in ((0,1),(1,2),(2,3),(3,0)):
        mb.face([p[a],p[b],p[b+4],p[a+4]],side)

def hull_mesh():
    # Cross-sections are broad, faceted boat-building planes; the final two stations lift the bow.
    st=[(-2.70,.18,.82,1.00),(-2.45,.92,.46,.98),(-2.00,1.27,.18,.93),
        (-1.30,1.34,.02,.91),(0.00,1.35,0.00,.91),(1.30,1.34,.06,.94),
        (2.00,1.27,.32,1.02),(2.42,.78,.68,1.40),(2.70,.15,1.02,1.76)]
    rings=[]
    for y,w,k,r in st:
        sidez=k+(r-k)*.43
        rings.append([(0,y,k),(.70*w,y,sidez),(w,y,r),(0,y,r),(-w,y,r),(-.70*w,y,sidez)])
    mb=MB()
    for i in range(len(rings)-1):
        for j in range(6):
            a=rings[i][j]; b=rings[i][(j+1)%6]; c=rings[i+1][(j+1)%6]; d=rings[i+1][j]
            col='hull_light' if j in (1,4) else ('hull_dark' if j in (0,5) else 'hull')
            mb.face([a,b,c,d],col)
    mb.face(rings[0], 'hull_dark', reverse=True); mb.face(rings[-1], 'hull_light')
    return mb

def flat_deck_parts(coll,root,mat):
    deck=empty(coll,'I06_Intact_Deck',root); deck['part']='Deck'; deck['surface_height_m']=1.0
    # Six broad longitudinal boards form an exact 4.0 x 2.2 m clear deck, with fine seams.
    half=1.10; gap=.018; each=(2*half-5*gap)/6
    for i in range(6):
        x0=-half+i*(each+gap); x1=x0+each
        group=empty(coll,f'I06_Intact_DeckPlank_{i+1:02d}',deck)
        group['part']='DeckPlank'; group['adjustable_in_source']=True
        mb=MB(); box(mb,x0,x1,-2.0,2.0,.84,1.0,'deck_light' if i%2==0 else 'deck','deck_edge','hull_dark')
        mesh_obj(coll,f'I06_Intact_DeckPlank_{i+1:02d}_Wood',mb,mat,group,'DeckPlankMesh')
    # Three low transverse beams stay below the open walking area.
    for i,y in enumerate((-1.42,0,1.42),1):
        group=empty(coll,f'I06_Intact_DeckBeam_{i:02d}',deck); group['part']='DeckBeam'
        mb=MB(); box(mb,-1.18,1.18,y-.11,y+.11,.70,.86,'hull_light','hull_dark','hull_dark')
        mesh_obj(coll,f'I06_Intact_DeckBeam_{i:02d}_Wood',mb,mat,group,'DeckBeamMesh')
    return deck

def make_sail(mast_x,front_y=-.13):
    # One triangular cloth, divided into three broad faceted folds with a closed back and edge.
    z0,z1,z2,z3=1.16,2.30,3.55,4.56
    outer_x=1.18; mastx=mast_x
    # The outer leech runs from the low boom tip back to the masthead, forming a true triangle.
    def edge_x(z):
        z_tip=1.30
        return mastx+(outer_x-mastx)*max(0.0,min(1.0,(z3-z)/(z3-z_tip)))
    levels=[z0,z1,z2,z3]
    y_m=[front_y,front_y-.035,front_y-.018,front_y]
    y_o=[front_y,front_y-.085,front_y-.055,front_y]
    front=[]; back=[]
    for z,ym,yo in zip(levels,y_m,y_o):
        xo=edge_x(z); front.append([(mastx,ym,z),(xo,yo,z)]); back.append([(mastx,ym+.085,z),(xo,yo+.085,z)])
    mb=MB(); col=['linen','linen_light','linen_fold']
    for i in range(3):
        a,b=front[i]; c,d=front[i+1]
        mb.face([a,b,d,c],col[i])
        ar,br=back[i]; cr,dr=back[i+1]
        mb.face([ar,cr,dr,br],col[i],reverse=True)
    # Keep every mast-side fold vertex in the boundary loop to avoid long-edge T-junctions.
    outline=[front[i][0] for i in range(4)]+[front[3][1],front[2][1],front[1][1],front[0][1]]
    backoutline=[back[i][0] for i in range(4)]+[back[3][1],back[2][1],back[1][1],back[0][1]]
    for i in range(len(outline)):
        j=(i+1)%len(outline); mb.face([outline[i],outline[j],backoutline[j],backoutline[i]],'linen_fold')
    return mb

def copy_f01_emblem(coll,mat,parent,mastx):
    mb=MB(); center=(-.42,2.96); y=-.175; radius=.255; tube=.018
    # Match the F01 mark's open ring and three parallel, flowing strokes.
    paths=[]
    paths.append([(center[0]+radius*math.cos(math.radians(a)),y,center[1]+radius*math.sin(math.radians(a)))
                  for a in range(55,306,19)])
    paths.extend([
      [(-.43,y,2.86),(-.29,y,2.87),(-.15,y,2.91),(-.07,y,2.96)],
      [(-.41,y,2.96),(-.27,y,2.97),(-.12,y,3.01),(-.035,y,3.06)],
      [(-.39,y,3.06),(-.25,y,3.07),(-.11,y,3.11),(-.015,y,3.16)]
    ])
    for path in paths: tube_path(mb,path,tube,8)
    ob=mesh_obj(coll,'I06_Intact_Sail_F01_WindEmblem',mb,mat,parent,'F01ExactOpenRingThreeStrokes')
    ob['design_reference']='F01 open ring and three same-direction wind strokes, matched to the shared banner emblem'
    return ob

def tube_path(mb,path,r=.018,n=8):
    pts=[Vector(p) for p in path]; rings=[]
    for i,p in enumerate(pts):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
        u=tangent.cross(Vector((0,1,0))).normalized(); v=Vector((0,1,0))
        rings.append([tuple(p+r*(math.cos(2*math.pi*j/n)*u+math.sin(2*math.pi*j/n)*v)) for j in range(n)])
    mb.face(list(reversed(rings[0])),'emblem')
    for i in range(len(rings)-1):
        for j in range(n): mb.face([rings[i][j],rings[i][(j+1)%n],rings[i+1][(j+1)%n],rings[i+1][j]],'emblem')
    mb.face(rings[-1],'emblem')

def empty(coll,name,parent=None,loc=(0,0,0)):
    ob=bpy.data.objects.new(name,None); coll.objects.link(ob); ob.empty_display_type='PLAIN_AXES'
    if parent: ob.parent=parent
    ob.location=loc
    return ob

def octagonal_mast(mb,x,y,z0,z1,r0=.085,r1=.042,n=8):
    low=[]; high=[]
    for i in range(n):
        a=(i+.5)*2*math.pi/n
        low.append((x+r0*math.cos(a),y+r0*math.sin(a),z0))
        high.append((x+r1*math.cos(a),y+r1*math.sin(a),z1))
    mb.face(list(reversed(low)),'hull_dark')
    for i in range(n): mb.face([low[i],low[(i+1)%n],high[(i+1)%n],high[i]],'deck_edge' if i%3 else 'deck_light')
    mb.face(high,'deck_light')

def scene_setup():
    old=bpy.data.scenes.get('WindProduction_I06')
    if old:
        fallback=bpy.data.scenes.get('WindProduction_I05') or bpy.data.scenes.get('Scene')
        if fallback: bpy.context.window.scene=fallback
        bpy.data.scenes.remove(old,do_unlink=True)
    for db in (bpy.data.collections,bpy.data.objects,bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
        for x in list(db):
            if x.name.startswith('I06_') and x.users==0:
                try: db.remove(x,do_unlink=True)
                except TypeError: db.remove(x)
    scene=bpy.data.scenes.new('WindProduction_I06'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('I06_Export'); scene.collection.children.link(export)
    preview=bpy.data.collections.new('I06_Preview_ONLY'); scene.collection.children.link(preview)
    return scene,export,preview

def add_preview(scene,preview):
    camera_data=bpy.data.cameras.new('I06_PreviewCamera_Data'); camera=bpy.data.objects.new('I06_PreviewCamera',camera_data); preview.objects.link(camera); scene.camera=camera
    for name,loc,power,size in [('I06_Key',(-8,-10,12),1900,8),('I06_Fill',(8,-5,8),1100,7),('I06_Rim',(0,9,10),1300,6)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); preview.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,1.0))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('I06_Preview_Ground'); gm.use_nodes=True; bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=lin('#717775'); bs.inputs['Roughness'].default_value=.96
    floor_me=bpy.data.meshes.new('I06_PreviewFloor_Mesh'); floor_me.from_pydata([(-250,-250,-.015),(250,-250,-.015),(250,250,-.015),(-250,250,-.015)],[],[(0,1,2,3)]); floor_me.materials.append(gm)
    floor=bpy.data.objects.new('I06_PreviewFloor',floor_me); preview.objects.link(floor)
    world=bpy.data.worlds.new('I06_PreviewWorld'); world.use_nodes=True; bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.40,.42,.43,1); bg.inputs['Strength'].default_value=.52; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Unable to import current fox scale-reference GLB')
    names={o:o.name for o in imported}
    for ob in imported:
        for c in list(ob.users_collection): c.objects.unlink(ob)
        preview.objects.link(ob); ob.name='I06_Fox_'+names[ob].replace('.','_')
        if any(k in names[ob].lower() for k in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-8.1,-.25,0)
    return camera,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain intact'
    scene,export,preview=scene_setup(); mat=material()
    intact=empty(export,'I06_Intact_WindSailBoat'); intact['variant']='intact / functional'; intact['nominal_dimensions_blender_xyz_m']=[2.7,5.4,4.8]; intact['pivot']='keel center at ground plane (0,0,0)'
    hull_group=empty(export,'I06_Intact_Hull',intact); hull_group['part']='Hull'; hull_group['dimensions_m']=[2.7,5.4,1.76]
    hm=hull_mesh(); hull=mesh_obj(export,'I06_Intact_Hull_ClosedFaceted',hm,mat,hull_group,'Hull'); shared_hull=hull.data
    deck=flat_deck_parts(export,intact,mat)
    mx=-.72
    mast=empty(export,'I06_Intact_Mast',intact); mast['part']='Mast'; mast['pivot_local_m']=[mx,0,1.0]
    mm=MB(); octagonal_mast(mm,mx,0,1.0,4.8)
    mesh_obj(export,'I06_Intact_Mast_Octagonal',mm,mat,mast,'MastMesh')
    sail=empty(export,'I06_Intact_Sail',intact); sail['part']='Sail'; sail['folds']='three broad cloth planes';
    sm=make_sail(mx); mesh_obj(export,'I06_Intact_Sail_TriangularThreeFold',sm,mat,sail,'SailMesh')
    copy_f01_emblem(export,mat,sail,mx)
    boom=empty(export,'I06_Intact_Boom',intact); boom['part']='Boom'; bm=MB()
    # A single clean low-poly spar follows the triangular sail's lower edge.
    def beam_between(mb,a,b,r=.035,n=6):
        A=Vector(a); B=Vector(b); axis=(B-A).normalized(); u=axis.cross(Vector((0,1,0))).normalized(); v=axis.cross(u).normalized(); lo=[]; hi=[]
        for i in range(n):
            q=math.cos(i*2*math.pi/n)*u+math.sin(i*2*math.pi/n)*v
            lo.append(tuple(A+q*r)); hi.append(tuple(B+q*r))
        mb.face(list(reversed(lo)),'hull_dark')
        for i in range(n): mb.face([lo[i],lo[(i+1)%n],hi[(i+1)%n],hi[i]],'deck_edge')
        mb.face(hi,'deck_light')
    beam_between(bm,(mx,-.17,1.16),(1.18,-.17,1.30),.034,6)
    mesh_obj(export,'I06_Intact_Boom_SingleFacetedSpar',bm,mat,boom,'BoomMesh')
    # Source-only deck surface, boarding and mooring locators: editable positions, omitted from GLB.
    loccol=bpy.data.collections.new('I06_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(loccol)
    loc_specs=[('DeckCenter',(0,0,1.0)),('BoardingPort',(-1.0,0,1.0)),('BoardingStarboard',(1.0,0,1.0)),
               ('BowMooringPort',(-.58,2.36,1.22)),('BowMooringStarboard',(.58,2.36,1.22)),
               ('SternMooringPort',(-.52,-2.36,.98)),('SternMooringStarboard',(.52,-2.36,.98))]
    for name,loc in loc_specs:
        e=empty(loccol,'I06_Source_'+name,intact,loc); e['local_coordinates_m']=list(loc); e['source_only']=True; e.hide_render=True; e.hide_set(True)
    # Capsized state reuses the exact hull mesh, inverted so the keel faces upward. No mast or sail.
    cap=empty(export,'I06_Capsized_HullOnly'); cap['variant']='capsized, inverted hull only'; cap['mast_present']=False; cap['sail_present']=False
    tilt=empty(export,'I06_Capsized_InversionPivot',cap); tilt.rotation_euler[1]=math.pi
    tilt.location=(0,0,1.76)
    cg=empty(export,'I06_Capsized_Hull',tilt); cg['part']='Hull'; mesh_obj(export,'I06_Capsized_Hull_ExactIntactMesh',MB(),mat,cg,'Hull',shared=shared_hull)
    # Three broad underside keel planes add readable structure without busy ribs.
    keel=empty(export,'I06_Capsized_KeelPlanes',tilt); keel['part']='KeelReinforcement'; keel['structural_planes']=3
    for i,x in enumerate((-.35,0,.35),1):
        mb=MB(); box(mb,x-.08,x+.08,-1.70,1.70,-.028,-.005,'hull_light','hull','hull_light')
        mesh_obj(export,f'I06_Capsized_KeelPlane_{i:02d}',mb,mat,keel,'BroadKeelPlane')
    camera,fox=add_preview(scene,preview)
    intact.location=(-4.2,0,0); cap.location=(4.2,0,0)
    camera.location=(7,-25,16); camera.rotation_euler=(Vector((0,0,1.35))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24; camera.data.lens=60
    scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for o in bpy.context.view_layer.objects: o.select_set(False)
    for o in export.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=intact
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene was lost'
    print('I06_CREATED',scene.name,'export_meshes',sum(o.type=='MESH' for o in export.objects),
          'states',intact.name,cap.name,'shared_capsized_hull_mesh',hull.data==bpy.data.objects['I06_Capsized_Hull_ExactIntactMesh'].data,
          'source_locators',len(loc_specs),'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,
          'default_scene_preserved=True')

main()
