import bpy, bmesh, math, os
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
CODE='L02'

def lin(h):
    vals=[int(h[i:i+2],16)/255.0 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1.0,)

PAL={
 'stone':lin('#525A56'), 'stone_light':lin('#69716B'), 'stone_edge':lin('#606963'),
 'stone_mid':lin('#444C48'), 'stone_dark':lin('#343B38'),
 'channel':lin('#78817B'), 'fracture':lin('#858B81'),
 'fracture_shadow':lin('#616962')
}

def shared_material():
    m=bpy.data.materials.new('L02_Shared_Stone_VertexColor'); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1); bs.inputs['Roughness'].default_value=.9
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

class MeshBuild:
    def __init__(self): self.verts=[]; self.faces=[]; self.cols=[]
    def face(self,ids,col):
        if len(set(ids))>=3: self.faces.append(tuple(ids)); self.cols.append(col)

def arc_mesh(name,r_profile,a0_deg,a1_deg,root,mat,damaged_outer=False,fracture=False):
    # Closed annular wedge with broad radial top planes, beveled inner/outer edges,
    # and solid low sides. Every ring section is a clean, individually exportable module.
    mb=MeshBuild(); angles=[math.radians(a0_deg+(a1_deg-a0_deg)*i/9) for i in range(10)]
    verts_top=[]; verts_bottom=[]
    for ai,a in enumerate(angles):
        top_row=[]; bottom_row=[]
        for r,z,col in r_profile:
            shift=0.0
            if damaged_outer:
                shift=math.radians(2.5)*max(0.0,min(1.0,(r-5.34)/.66))
            aa=a+shift
            top_row.append(len(mb.verts)); mb.verts.append((r*math.cos(aa),r*math.sin(aa),z))
            bottom_row.append(len(mb.verts)); mb.verts.append((r*math.cos(aa),r*math.sin(aa),0.0))
        verts_top.append(top_row); verts_bottom.append(bottom_row)
    # top and bottom radial bands
    for ai in range(len(angles)-1):
        for j in range(len(r_profile)-1):
            c=r_profile[j][2]
            if fracture and (ai in (3,4,5) and j in (1,3,4)):
                c='fracture' if (ai+j)%2 else 'fracture_shadow'
            mb.face((verts_top[ai][j],verts_top[ai+1][j],verts_top[ai+1][j+1],verts_top[ai][j+1]),c)
            mb.face((verts_bottom[ai][j+1],verts_bottom[ai+1][j+1],verts_bottom[ai+1][j],verts_bottom[ai][j]),'stone_dark')
    # inner and outer vertical walls
    for ai in range(len(angles)-1):
        for j,c in ((0,'stone_mid'),(len(r_profile)-1,'stone_dark')):
            mb.face((verts_bottom[ai][j],verts_bottom[ai+1][j],verts_top[ai+1][j],verts_top[ai][j]),c)
    # radial module end faces. The damage accent is only on the displaced outer part.
    for side,ai in (('start',0),('end',len(angles)-1)):
        for j in range(len(r_profile)-1):
            c='stone_mid'
            if fracture and j>=1: c='fracture' if j%2 else 'fracture_shadow'
            mb.face((verts_bottom[ai][j],verts_bottom[ai][j+1],verts_top[ai][j+1],verts_top[ai][j]),c)
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(mb.verts,[],mb.faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(mat)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,col in zip(me.polygons,mb.cols):
        for li in poly.loop_indices: attr.data[li].color=PAL[col]
    ob=bpy.data.objects.new(name,me); bpy.context.scene.collection.children.get('L02_Export').objects.link(ob); ob.parent=root
    ob['closed_module']=True; ob['arc_degrees']=36.0
    return ob

def empty(coll,name,description=''):
    o=bpy.data.objects.new(name,None); coll.objects.link(o); o.empty_display_type='PLAIN_AXES'
    if description: o['design']=description
    o['pivot']='center of ring at ground z=0'; return o

def post_mesh(name,center_angle,root,mat):
    n=8; a0=math.radians(center_angle); cx=5.42*math.cos(a0); cy=5.42*math.sin(a0)
    rings=[(1.13,.22),(1.20,.20),(1.68,.16),(1.76,.19),(1.82,.17)]
    verts=[]; faces=[]; colors=[]
    for z,r in rings:
        for i in range(n):
            a=2*math.pi*i/n+math.pi/8
            verts.append((cx+r*math.cos(a),cy+r*math.sin(a),z))
    faces.append(tuple(reversed(range(n)))); colors.append('stone_dark')
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
            colors.append(('stone','stone_light','stone_mid','stone_dark')[i%4])
    faces.append(tuple((len(rings)-1)*n+i for i in range(n))); colors.append('stone_light')
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update(); me.materials.append(mat)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for p,col in zip(me.polygons,colors):
        for li in p.loop_indices: attr.data[li].color=PAL[col]
    ob=bpy.data.objects.new(name,me); bpy.context.scene.collection.children.get('L02_Export').objects.link(ob); ob.parent=root
    ob['height_above_ring_m']=.55; ob['route_clear']=True
    return ob

def preview_setup(scene,prev):
    cd=bpy.data.cameras.new('L02_PreviewCamera_Data'); cam=bpy.data.objects.new('L02_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('L02_Key',(-9,-12,17),2100,9),('L02_Fill',(11,-6,10),1100,8),('L02_Rim',(0,9,14),1750,8)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,.8))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('L02_PreviewGround'); gm.use_nodes=True
    bs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=lin('#707572'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('L02_PreviewGround_Mesh'); me.from_pydata([(-100,-100,-.015),(100,-100,-.015),(100,100,-.015),(-100,100,-.015)],[],[(0,1,2,3)]); me.materials.append(gm)
    floor=bpy.data.objects.new('L02_PreviewGround',me); prev.objects.link(floor)
    world=bpy.data.worlds.new('L02_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.27,.29,.29,1); bg.inputs['Strength'].default_value=.58; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Fox scale reference did not import as an armature')
    for ob in imported:
        original=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='L02_Fox_'+original.replace('.','_')
        if any(k in original.lower() for k in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(0,-8.0,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:
            try: im.pack()
            except Exception: pass
    return cam,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None,'Original default scene must remain'
    assert bpy.data.scenes.get('WindProduction_L02') is None,'L02 scene already exists; refusing duplicate build'
    scene=bpy.data.scenes.new('WindProduction_L02'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('L02_Export'); scene.collection.children.link(export)
    preview=bpy.data.collections.new('L02_Preview_ONLY'); scene.collection.children.link(preview)
    source=bpy.data.collections.new('L02_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    mat=shared_material()
    intact=empty(export,'L02_Intact_WindWell','12 m OD / 8 m hollow center; eight broad stone arc modules, two opposite 2.472 m clear approaches, three low posts.')
    damaged=empty(export,'L02_Damaged_WindWell','Same well with one outer arc slid tangentially by 0.26 m; inner wind channel stays aligned.')
    inner_profile=[(4.0,1.08,'stone_dark'),(4.08,1.20,'stone_light'),(4.22,1.20,'stone'),(5.24,1.20,'stone'),(5.34,1.20,'stone_edge')]
    # Four 36-degree modules on either side; the two 36-degree route gaps are centered at 90/270 degrees.
    spans=[(108,144),(144,180),(180,216),(216,252),(288,324),(324,360),(0,36),(36,72)]
    outer_profile=[(5.34,1.20,'stone_light'),(5.39,1.16,'stone_mid'),(5.45,1.16,'channel'),(5.51,1.20,'stone_light'),(5.92,1.20,'stone'),(6.0,1.12,'stone_light')]
    for idx,(a0,a1) in enumerate(spans,1):
        arc_mesh(f'L02_Intact_InnerChannel_{idx:02d}',inner_profile,a0,a1,intact,mat)
        arc_mesh(f'L02_Intact_OuterArc_{idx:02d}',outer_profile,a0,a1,intact,mat)
        arc_mesh(f'L02_Damaged_InnerChannel_{idx:02d}',inner_profile,a0,a1,damaged,mat)
        arc_mesh(f'L02_Damaged_OuterArc_{idx:02d}',outer_profile,a0,a1,damaged,mat,damaged_outer=(idx==3),fracture=(idx==3))
    for idx,angle in enumerate((0,180,36),1):
        post_mesh(f'L02_Intact_LowMarkerPost_{idx}',angle,intact,mat)
        post_mesh(f'L02_Damaged_LowMarkerPost_{idx}',angle,damaged,mat)
    intact['state']='intact'; damaged['state']='outer_arc_shifted'
    for name,loc in [('BottomCenterPivot',(0,0,0)),('OpenCoreCenter',(0,0,0)),('FrontRouteCenter',(0,-5,0)),('RearRouteCenter',(0,5,0)),('FrontRouteClearWidth',(0,-4,0)),('RearRouteClearWidth',(0,4,0))]:
        e=empty(source,'L02_Source_'+name); e.location=loc; e['local_coordinates_blender_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    source['route_gap_chord_at_inner_radius_m']=round(2*4*math.sin(math.radians(18)),6)
    source['inner_channel_radius_m']=[4.0,5.34]
    cam,fox=preview_setup(scene,preview)
    intact.location=(-6.7,0,0); damaged.location=(6.7,0,0)
    cam.location=(20,-37,25); cam.rotation_euler=(Vector((0,0,.7))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=38
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    print('L02_CREATED',{'scene':scene.name,'objects':len(export.objects),'intact_modules':len([o for o in intact.children_recursive if o.type=='MESH']),'damaged_modules':len([o for o in damaged.children_recursive if o.type=='MESH']),'fox_action':fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,'original_default_scene_preserved':bpy.data.scenes.get('Scene') is not None})

main()
