import bpy,bmesh,math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    vals=[int(h[i:i+2],16)/255.0 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1.0,)

PAL={'stone':lin('#515957'),'stone_mid':lin('#454D4A'),'stone_light':lin('#69716C'),
     'stone_dark':lin('#343B39'),'fracture':lin('#858B81'),'cloth':lin('#E6E0D0'),
     'cloth_shadow':lin('#CEC9BA'),'emblem':lin('#39433F'),'book':lin('#D8D0BF'),
     'book_edge':lin('#AAA496')}

def material():
    m=bpy.data.materials.new('L03_Shared_StoneAndCloth_VertexColor'); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1); bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def mesh_obj(name,verts,faces,colors,parent,mat):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(mat); attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,c in zip(me.polygons,colors):
        for li in poly.loop_indices: attr.data[li].color=PAL[c]
    ob=bpy.data.objects.new(name,me); bpy.context.scene.collection.children.get('L03_Export').objects.link(ob)
    ob.parent=parent; return ob

def empty(coll,name,parent=None):
    ob=bpy.data.objects.new(name,None); coll.objects.link(ob)
    if parent: ob.parent=parent
    ob.empty_display_type='PLAIN_AXES'; return ob

def box(name,bounds,parent,mat,top='stone_light',side='stone',bottom='stone_dark'):
    x0,x1,y0,y1,z0,z1=bounds
    v=[(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    f=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return mesh_obj(name,v,f,[bottom,top,side,side,side,side],parent,mat)

def loft(name,x,y,rings,parent,mat,n=8):
    v=[]; f=[]; c=[]
    for z,r in rings:
        for i in range(n):
            a=(i+.5)*2*math.pi/n; v.append((x+r*math.cos(a),y+r*math.sin(a),z))
    f.append(tuple(reversed(range(n)))); c.append('stone_dark')
    for k in range(len(rings)-1):
        for i in range(n):
            f.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i)); c.append(('stone','stone_light','stone_mid','stone_dark')[i%4])
    f.append(tuple((len(rings)-1)*n+i for i in range(n))); c.append('stone_light')
    return mesh_obj(name,v,f,c,parent,mat)

def roof_z(x,s):
    return 5.8-.65*s+.025*s*s+.12*(abs(x)/3.0)**4*(s/2.0)

def roof_band(name,side,s0,s1,x0,x1,parent,mat):
    # A broad full-width strip, given a shallow upturn at both eaves and closed lower faces.
    gap=.012 if s0>0 else 0.0; a=s0+gap; b=s1-gap
    pts=[]
    for x,s in ((x0,a),(x1,a),(x1,b),(x0,b)):
        pts.append((x,side*s,roof_z(x,s)))
    bottom=[(x,y,z-.20) for x,y,z in pts]
    v=pts+bottom
    f=[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    color='stone_light' if int((s0+s1)*3)%2==0 else 'stone'
    return mesh_obj(name,v,f,['stone_light','stone_dark',color,color,'stone_mid','stone_mid'],parent,mat)

def beam_between(name,p0,p1,width,height,parent,mat,color='stone_mid'):
    a=Vector(p0); b=Vector(p1); d=b-a
    side=Vector((1,0,0)) if abs(d.x)<.9*d.length else Vector((0,1,0))
    u=d.cross(side).normalized()*width/2; v=d.cross(u).normalized()*height/2
    verts=[]
    for p in (a,b): verts.extend([tuple(p-u-v),tuple(p+u-v),tuple(p+u+v),tuple(p-u+v)])
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return mesh_obj(name,verts,faces,['stone_dark',color,'stone_mid',color,color,'stone_mid'],parent,mat)

def banner(name,cx,parent,mat):
    y=-1.92; top=4.34; bot=3.63; half=.22
    # Single broad ivory standard with a gentle shallow swallow-tail.
    v=[(cx-half,y,top),(cx+half,y,top),(cx+half,y,bot+.08),(cx,y,bot),(cx-half,y,bot+.08),
       (cx-half,y+.035,top),(cx+half,y+.035,top),(cx+half,y+.035,bot+.08),(cx,y+.035,bot),(cx-half,y+.035,bot+.08)]
    f=[(0,1,2,3,4),(9,8,7,6,5),(0,5,6,1),(1,6,7,2),(2,7,8,3),(3,8,9,4),(4,9,5,0)]
    mesh_obj(name,v,f,['cloth','cloth_shadow','cloth_shadow','cloth_shadow','cloth_shadow','cloth_shadow','cloth_shadow'],parent,mat)
    def tube(line_name,path,r=.009):
        pts=[Vector(p) for p in path]; n=6; rings=[]
        for i,p in enumerate(pts):
            tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
            u=Vector((0,1,0)); vv=tangent.cross(u).normalized(); ring=[]
            for j in range(n): ring.append(tuple(p+r*(math.cos(2*math.pi*j/n)*u+math.sin(2*math.pi*j/n)*vv)))
            rings.append(ring)
        vvtx=[q for rr in rings for q in rr]; faces=[tuple(reversed(range(n)))]; cols=['emblem']
        for i in range(len(rings)-1):
            for j in range(n): faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j)); cols.append('emblem')
        faces.append(tuple((len(rings)-1)*n+j for j in range(n))); cols.append('emblem')
        mesh_obj(line_name,vvtx,faces,cols,parent,mat)
    # F01's open ring and three parallel, same-direction wind strokes.
    center=(cx-.045,3.98)
    arc=[(center[0]+.115*math.cos(math.radians(a)),y-.018,center[1]+.115*math.sin(math.radians(a))) for a in range(48,313,22)]
    tube(name+'_F01_OpenRing',arc,.009)
    for j,z in enumerate((3.94,4.00,4.06),1):
        tube(name+f'_F01_WindStroke_{j}',[(cx+.015,y-.019,z-.018),(cx+.085,y-.019,z),(cx+.155,y-.019,z+.012)],.008)

def book_pedestal(root,mat):
    # Compact P03-like stand with one readable book, located at the back of the room.
    cx=0; cy=2.12
    box('L03_BookStand_Base',(-.72,.72,cy-.48,cy+.48,.40,.65),root,mat,'stone_light','stone_mid','stone_dark')
    loft('L03_BookStand_Taper',cx,cy,[(.65,.48),(.78,.43),(1.22,.29),(1.32,.29)],root,mat)
    box('L03_BookStand_Top',(-.53,.53,cy-.40,cy+.40,1.30,1.43),root,mat,'stone_light','stone','stone_dark')
    box('L03_OpenBook_CreamPages',(-.38,.38,cy-.24,cy+.19,1.44,1.51),root,mat,'book','book_edge','book_edge')
    # Two quiet page leaves with a visible center fold.
    box('L03_Book_Left_Page',(-.38,-.012,cy-.24,cy+.19,1.51,1.535),root,mat,'book','book_edge','book_edge')
    box('L03_Book_Right_Page',(.012,.38,cy-.24,cy+.19,1.51,1.535),root,mat,'book','book_edge','book_edge')
    root['book_interaction_center_blender_m']=[0.0,cy,1.55]
    root['clear_approach_to_book_min_m']=1.5

def build_state(export,root,mat,damaged=False):
    root['state']='damaged' if damaged else 'intact'; root['pivot']='center of platform at ground z=0'
    root['nominal_envelope_m']=[7.2,6.0,5.8]
    # The platform spans 7.2 x 6 m, with a centered front notch for two shallow entry steps.
    tag='L03_Damaged' if damaged else 'L03_Intact'
    box(tag+'_LowStonePlatform_Left',(-3.6,-1.35,-3.0,3.0,0,.40),root,mat,'stone_light','stone','stone_dark')
    box(tag+'_LowStonePlatform_Right',(1.35,3.6,-3.0,3.0,0,.40),root,mat,'stone_light','stone','stone_dark')
    box(tag+'_LowStonePlatform_Rear',(-1.35,1.35,-2.24,3.0,0,.40),root,mat,'stone_light','stone','stone_dark')
    box(tag+'_ApproachStep_Lower',(-1.30,1.30,-3.0,-2.70,0,.20),root,mat,'stone_light','stone_mid','stone_dark')
    box(tag+'_ApproachStep_Upper',(-1.16,1.16,-2.70,-2.24,.20,.40),root,mat,'stone_light','stone_mid','stone_dark')
    # Exactly four A01-style ritual corner columns (no intermediate supports).
    for idx,(x,y) in enumerate(((-2.62,-1.62),(2.62,-1.62),(-2.62,1.62),(2.62,1.62)),1):
        rings=[(.40,.43),(.55,.43),(.72,.33),(.82,.275),(1.0,.255),(2.0,.25),(3.15,.235),(4.18,.225),(4.28,.27),(4.42,.37),(4.56,.37),(4.62,.31)]
        loft(('L03_Damaged' if damaged else 'L03_Intact')+f'_A01_CornerColumn_{idx}',x,y,rings,root,mat)
    # A single clean A02-like perimeter beam supports the eaves without adding posts.
    for label,y in (('Front',-1.72),('Rear',1.72)):
        box(f'L03_{"Damaged" if damaged else "Intact"}_A02_{label}CrossBeam',(-2.86,2.86,y-.20,y+.20,4.38,4.62),root,mat,'stone_light','stone_mid','stone_dark')
    for side,x in (('Left',-2.62),('Right',2.62)):
        box(f'L03_{"Damaged" if damaged else "Intact"}_A02_{side}SideBeam',(x-.18,x+.18,-1.72,1.72,4.38,4.62),root,mat,'stone_light','stone_mid','stone_dark')
    # Roof is a separate hierarchy; the front 3-band plane is detachable for camera/occlusion.
    roofroot=empty(export,('L03_Damaged' if damaged else 'L03_Intact')+'_A04_RoofGroup',root)
    front=empty(export,('L03_Damaged' if damaged else 'L03_Intact')+'_A04_RoofFront_Removable',roofroot)
    front['camera_occlusion_part']=True; front['dimensions_m']=[6.0,2.0,1.4]
    rear=empty(export,('L03_Damaged' if damaged else 'L03_Intact')+'_A04_RoofRear',roofroot)
    roof_bands=[(0,.67),(.67,1.34),(1.34,2.0)]
    for i,(s0,s1) in enumerate(roof_bands,1): roof_band(f'L03_{"Damaged" if damaged else "Intact"}_A04_Front_BroadBand_{i}',-1,s0,s1,-3,3,front,mat)
    # The rear side has the same three broad bands; split only its outside corner so one corner can be lost cleanly.
    roof_band(f'L03_{"Damaged" if damaged else "Intact"}_A04_Rear_BroadBand_1',1,0,.67,-3,3,rear,mat)
    roof_band(f'L03_{"Damaged" if damaged else "Intact"}_A04_Rear_BroadBand_2_Left',1,.67,1.34,-3,0,rear,mat)
    if not damaged: roof_band('L03_Intact_A04_Rear_BroadBand_2_Right',1,.67,1.34,0,3,rear,mat)
    roof_band(f'L03_{"Damaged" if damaged else "Intact"}_A04_Rear_BroadBand_3_Left',1,1.34,2.0,-3,0,rear,mat)
    if not damaged: roof_band('L03_Intact_A04_Rear_BroadBand_3_Right',1,1.34,2.0,0,3,rear,mat)
    # Three stout rafters remain underneath; the same 3 become visible through the removed rear corner.
    for i,x in enumerate((.48,1.38,2.28),1):
        beam_between(f'L03_{"Damaged" if damaged else "Intact"}_A04_Rafter_{i}',(x,0,5.45),(x,1.92,4.66),.15,.18,roofroot,mat,'fracture' if damaged and i==3 else 'stone_mid')
    box(f'L03_{"Damaged" if damaged else "Intact"}_A04_RidgeBeam',(-2.92,2.92,-.12,.12,5.55,5.79),roofroot,mat,'stone_light','stone_mid','stone_dark')
    # Paired front standards use only the shared F01 wind emblem.
    for i,x in enumerate((-2.08,2.08),1): banner(f'L03_{"Damaged" if damaged else "Intact"}_F01_Banner_{i}',x,root,mat)
    # One broad rear wall panel in the intact state; same bay is open in damage state.
    box('L03_Intact_RearWallPanel',(.92,2.34,2.52,2.72,.48,2.62),root,mat,'stone_light','stone_mid','stone_dark') if not damaged else None
    if damaged:
        # The missing rear panel breaks into two broad slabs on the rear half of the platform, clear of the stair/approach.
        box('L03_Damaged_RearPanel_Rubble_Large',(2.12,2.88,2.04,2.48,.43,.59),root,mat,'fracture','stone_mid','stone_dark')
        box('L03_Damaged_RearPanel_Rubble_Small',(2.60,3.14,2.34,2.62,.43,.53),root,mat,'fracture','stone_mid','stone_dark')
    book_pedestal(root,mat)
    root['roof_front_removable']=True; root['front_approach_clear_m']=1.5; root['rear_wall_panel_bay_m']=[.92,2.34,2.52,2.72,.48,2.62]
    if damaged: root['damage']='Rear-right roof corner removed (~16.7% roof plan area); one rear panel removed into two broad slabs; three rafters visible.'
    return roofroot

def preview_setup(scene,prev):
    cd=bpy.data.cameras.new('L03_PreviewCamera_Data'); cam=bpy.data.objects.new('L03_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('L03_Key',(-9,-13,13),2100,8),('L03_Fill',(8,-8,9),1050,7),('L03_Rim',(0,8,13),1700,8)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,2.0))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('L03_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=lin('#737875'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('L03_PreviewGround_Mesh'); me.from_pydata([(-100,-100,-.015),(100,-100,-.015),(100,100,-.015),(-100,100,-.015)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('L03_PreviewGround',me); prev.objects.link(floor)
    world=bpy.data.worlds.new('L03_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.29,.31,.31,1); bg.inputs['Strength'].default_value=.55; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import the actual fox scale reference')
    for ob in imported:
        original=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='L03_Fox_'+original.replace('.','_')
        if any(k in original.lower() for k in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(0,-4.25,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:
            try: im.pack()
            except Exception: pass
    return cam,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None,'Preserve the original default scene'
    assert bpy.data.scenes.get('WindProduction_L03') is None,'L03 scene already exists; refusing duplicate build'
    scene=bpy.data.scenes.new('WindProduction_L03'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('L03_Export'); scene.collection.children.link(export)
    prev=bpy.data.collections.new('L03_Preview_ONLY'); scene.collection.children.link(prev)
    source=bpy.data.collections.new('L03_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    mat=material(); intact=empty(export,'L03_Intact_WindArchivePavilion'); damaged=empty(export,'L03_Damaged_WindArchivePavilion')
    build_state(export,intact,mat,False); build_state(export,damaged,mat,True)
    for name,loc in [('BottomCenterPivot',(0,0,0)),('FrontEntranceCenter',(0,-2.5,.4)),('BookInteractionPoint',(0,2.12,1.55)),('FrontRoofRemovable',(0,-1,5.1)),('RearWallPanelBay',(1.63,2.62,1.55)),('RearRoofDamageCorner',(1.5,1.5,4.95))]:
        e=empty(source,'L03_Source_'+name); e.location=loc; e['local_coordinates_blender_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    source['book_approach_clear_m']=1.5; source['roof_front_removable']=True
    cam,fox=preview_setup(scene,prev)
    intact.location=(-4.1,0,0); damaged.location=(4.1,0,0)
    cam.location=(13,-26,14); cam.rotation_euler=(Vector((0,0,2.2))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=42
    scene.render.engine='CYCLES'; scene.cycles.samples=18; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for o in bpy.context.view_layer.objects: o.select_set(False)
    for o in export.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=intact
    print('L03_CREATED',{'scene':scene.name,'export_objects':len(export.objects),'intact_meshes':len([o for o in intact.children_recursive if o.type=='MESH']),'damaged_meshes':len([o for o in damaged.children_recursive if o.type=='MESH']),'fox_action':fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,'default_scene_preserved':bpy.data.scenes.get('Scene') is not None})

main()
