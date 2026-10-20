import bpy, bmesh, math, json
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(h):
    vals = [int(h[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in vals) + (1.0,)

PAL = {
    'stone': lin('#565D59'), 'stone_light': lin('#707671'),
    'stone_dark': lin('#3D4542'), 'stone_mid': lin('#4C5450'),
    'fracture': lin('#858B83'), 'fracture_shadow': lin('#656B65'),
    'cloth': lin('#E5E0D1'), 'cloth_fold': lin('#C9C5B8'),
    'emblem': lin('#354240'), 'timber': lin('#514A3D')
}

class MB:
    def __init__(self):
        self.verts, self.faces, self.colors, self.cache = [], [], [], {}
    def v(self, p):
        p = tuple(float(x) for x in p)
        key = tuple(round(x, 7) for x in p)
        if key not in self.cache:
            self.cache[key] = len(self.verts)
            self.verts.append(p)
        return self.cache[key]
    def face(self, points, color='stone'):
        ids = [self.v(p) for p in points]
        clean = []
        for i in ids:
            if not clean or clean[-1] != i: clean.append(i)
        if len(clean) > 2 and clean[0] == clean[-1]: clean.pop()
        if len(set(clean)) >= 3:
            self.faces.append(tuple(clean)); self.colors.append(color)

def material():
    m = bpy.data.materials.new('L01_SharedPalette_VertexColor')
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bs.inputs['Roughness'].default_value = .88
    vc = m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Color'
    m.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
    return m

MAT = material()

def add_mesh(coll, name, verts, faces, colors, parent, mat=MAT):
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(verts, [], faces); me.update()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(mat)
    attr = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, key in zip(me.polygons, colors):
        for li in poly.loop_indices: attr.data[li].color = PAL[key]
    ob = bpy.data.objects.new(name, me); coll.objects.link(ob)
    if parent: ob.parent = parent
    ob['part'] = name.rsplit('_', 1)[-1]
    return ob

def box_mesh(name, x0, x1, y0, y1, z0, z1, parent, top='stone_light', side='stone', bottom='stone_dark'):
    p = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
         (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return add_mesh(bpy.context.scene.collection.children.get('L01_Export'), name, p, faces,
                    [bottom,top,side,side,side,side], parent)

def loft(name, rings, parent, chip=False):
    n = 8; verts = []; faces = []; colors = []
    angle0 = math.pi / 8
    for ri, item in enumerate(rings):
        z, radius = item[0], item[1]
        center_x = item[2] if len(item) > 2 else 0.0
        center_y = item[3] if len(item) > 3 else 0.0
        for i in range(n):
            a = angle0 + i * 2 * math.pi / n
            rr = radius
            if chip and ri in (2, 3):
                if i == 6: rr *= .64
                elif i == 7: rr *= .48
                elif i == 5: rr *= .87
            verts.append((center_x + rr*math.cos(a), center_y + rr*math.sin(a), z))
    faces.append(tuple(reversed(range(n)))); colors.append('stone_dark')
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i, k*n+(i+1)%n, (k+1)*n+(i+1)%n, (k+1)*n+i))
            colors.append(('stone','stone_light','stone_mid','stone_dark')[i%4])
    faces.append(tuple((len(rings)-1)*n+i for i in range(n))); colors.append('stone_light')
    if chip:
        # The two recessed outer planes read as a single chipped corner.
        for k in (2,3):
            for i in (5,6,7):
                face_index = 1 + k*n + i
                if face_index < len(colors): colors[face_index] = 'fracture' if i == 6 else 'fracture_shadow'
    return add_mesh(bpy.data.collections['L01_Export'], name, verts, faces, colors, parent)

def prism_poly(name, poly, ztop_fn, thickness, parent, damage_edges=()):
    n = len(poly); verts = []
    for x,y in poly: verts.append((x,y,ztop_fn(x)-thickness))
    for x,y in poly: verts.append((x,y,ztop_fn(x)))
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    colors = ['stone_dark','stone_light']
    damage_edges = set(damage_edges)
    for i in range(n):
        faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
        colors.append(('fracture' if i%2 else 'fracture_shadow') if i in damage_edges else ('stone_mid' if i%2 else 'stone'))
    return add_mesh(bpy.data.collections['L01_Export'], name, verts, faces, colors, parent)

def empty(coll, name, description):
    ob = bpy.data.objects.new(name, None); coll.objects.link(ob)
    ob.empty_display_type = 'PLAIN_AXES'; ob['pivot'] = 'bottom center at ground z=0'; ob['design'] = description
    return ob

def col_part(root, side, part, rings, chip=False):
    return loft(f'L01_{side}_{part}', rings, root, chip)

def build_columns(root, damage=False):
    for side, cx in (('Left',-2.75),('Right',2.75)):
        col_part(root,side,'FootPlinth',[(0,.43,cx),(.12,.43,cx),(.20,.40,cx)])
        ped=[(.20,.40,cx),(.28,.39,cx),(.36,.38,cx),(.55,.37,cx),(.64,.35,cx),(.74,.33,cx)]
        col_part(root,side,'Pedestal',ped,chip=(damage and side=='Right'))
        col_part(root,side,'BaseShoulder',[(.70,.33,cx),(.78,.30,cx),(.86,.255,cx)])
        col_part(root,side,'OctagonalShaft',[(.82,.255,cx),(1.0,.25,cx),(2.0,.238,cx),(3.1,.226,cx),(4.28,.215,cx)])
        col_part(root,side,'UpperCollar',[(4.18,.225,cx),(4.24,.25,cx),(4.34,.25,cx),(4.40,.23,cx)])
        col_part(root,side,'FlaredCapital',[(4.28,.23,cx),(4.40,.28,cx),(4.55,.34,cx),(4.70,.38,cx),(4.82,.37,cx),(4.90,.33,cx)])

def roof(root, damaged=False):
    # One clean shallow roof: a central plane and two broad upturned ends.
    prism_poly('L01_Roof_Center', [(-2.8,-1.05),(2.8,-1.05),(2.8,1.05),(-2.8,1.05)], lambda x:5.48, .28, root)
    prism_poly('L01_Roof_Left_End', [(-3.5,-1.05),(-2.8,-1.05),(-2.8,1.05),(-3.5,1.05)], lambda x:5.48 + (abs(x)-2.8)*(.30/.70), .28, root)
    if damaged:
        # Three broad, zig-zag fracture faces shorten the full right roof tip.
        poly=[(2.8,-1.05),(3.05,-1.05),(2.86,-.55),(3.12,-.10),(2.88,.34),(3.08,.72),(2.8,1.05)]
        prism_poly('L01_Roof_Right_Corner_Broken',poly,lambda x:5.48+(x-2.8)*(.30/.70),.28,root,damage_edges=(1,3,5))
    else:
        prism_poly('L01_Roof_Right_Back', [(2.8,0),(3.5,0),(3.5,1.05),(2.8,1.05)], lambda x:5.48 + (x-2.8)*(.30/.70), .28, root)
        prism_poly('L01_Roof_Right_Front', [(2.8,-1.05),(3.5,-1.05),(3.5,0),(2.8,0)], lambda x:5.48 + (x-2.8)*(.30/.70), .28, root)

def flags(root):
    def flag_mesh(name,x0,x1):
        nx,nz=4,3; top=5.30; verts=[]
        def z_at(u,v):
            bottom=4.08 + .11*(1-abs(2*u-1))
            return top + (bottom-top)*v
        def y_at(u,v,back=False):
            fold=.065*math.sin(math.pi*u)+.025*math.sin(2*math.pi*u)*(1-v)
            return -.59-fold + (.045 if back else 0.0)
        front=[]; back=[]
        for j in range(nz+1):
            v=j/nz
            fr=[]; br=[]
            for i in range(nx+1):
                u=i/nx; x=x0+(x1-x0)*u; z=z_at(u,v)
                fr.append((x,y_at(u,v),z)); br.append((x,y_at(u,v,True),z))
            front.append(fr);back.append(br)
        verts=[p for row in front for p in row]+[p for row in back for p in row]
        stride=(nx+1)*(nz+1); faces=[]; colors=[]
        def fi(j,i): return j*(nx+1)+i
        def bi(j,i): return stride+fi(j,i)
        for j in range(nz):
            for i in range(nx):
                faces.append((fi(j,i),fi(j,i+1),fi(j+1,i+1),fi(j+1,i)))
                colors.append('cloth' if i%2 else 'cloth_fold')
                faces.append((bi(j,i),bi(j+1,i),bi(j+1,i+1),bi(j,i+1)))
                colors.append('cloth')
        # Closed perimeter, top bar edge, and softly scalloped lower edge.
        for i in range(nx):
            faces.append((fi(0,i),bi(0,i),bi(0,i+1),fi(0,i+1))); colors.append('cloth_fold')
            faces.append((fi(nz,i+1),bi(nz,i+1),bi(nz,i),fi(nz,i))); colors.append('cloth_fold')
        for j in range(nz):
            faces.append((fi(j,0),fi(j+1,0),bi(j+1,0),bi(j,0))); colors.append('cloth_fold')
            faces.append((fi(j,nx),bi(j,nx),bi(j+1,nx),fi(j+1,nx))); colors.append('cloth_fold')
        return add_mesh(bpy.data.collections['L01_Export'],name,verts,faces,colors,root)

    def tube_path(name, path, r=.013, n=6):
        mb=MB(); pts=[Vector(p) for p in path]; rings=[]
        for i,p in enumerate(pts):
            tangent=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
            u=tangent.cross(Vector((0,1,0))).normalized(); v=Vector((0,1,0)); ring=[]
            for j in range(n): ring.append(tuple(p+r*(math.cos(2*math.pi*j/n)*u+math.sin(2*math.pi*j/n)*v)))
            rings.append(ring)
        mb.face(list(reversed(rings[0])),'emblem')
        for i in range(len(rings)-1):
            for j in range(n): mb.face([rings[i][j],rings[i][(j+1)%n],rings[i+1][(j+1)%n],rings[i+1][j]],'emblem')
        mb.face(rings[-1],'emblem')
        ob=add_mesh(bpy.data.collections['L01_Export'],name,mb.verts,mb.faces,mb.colors,root)
        ob['design_reference']='F01 open ring and three same-direction wind strokes'

    # Two outboard banners; their combined outer width stays inside 7.2 m.
    for side, x0, x1, pole_x in (('Left',-3.56,-3.02,-3.02),('Right',3.02,3.56,3.02)):
        flag_mesh('L01_Banner_'+side,x0,x1)
        r=.045; n=8; verts=[]; faces=[]; colors=[]
        for z,rr in ((4.42,r),(5.67,r*.62)):
            for i in range(n):
                a=(i+.5)*2*math.pi/n
                verts.append((pole_x+rr*math.cos(a),-.54+rr*math.sin(a),z))
        faces.append(tuple(reversed(range(n))));colors.append('stone_dark')
        for i in range(n): faces.append((i,(i+1)%n,(i+1)%n+n,i+n));colors.append(('timber','stone_dark','stone_mid','stone_dark')[i%4])
        faces.append(tuple(n+i for i in range(n)));colors.append('stone_light')
        add_mesh(bpy.data.collections['L01_Export'],'L01_BannerPole_'+side,verts,faces,colors,root)
        # A plain horizontal staff carries the banner; no finials or ornament.
        lo,hi=sorted((x0,x1));box_mesh(f'L01_BannerStaff_{side}',lo,hi,-.59,-.49,5.25,5.32,root,'stone_light','stone_mid','stone_dark')
        # Reuse the F01 emblem's open loop and three right-sweeping paths, proportionally fitted.
        center_x=(x0+x1)/2; scale=.72; center_z=4.77
        def xf(x,z,side_offset):
            xa=center_x+(x+.345)*scale; za=center_z+(z-2.96)*scale
            u=(xa-x0)/(x1-x0); bottom=4.08+.11*(1-abs(2*u-1)); v=(5.30-za)/(5.30-bottom)
            surface_y=-.59-.065*math.sin(math.pi*u)+.025*math.sin(2*math.pi*u)*(1-v)
            if side_offset>0: surface_y+=.045
            return (xa,surface_y+side_offset,za)
        paths=[]
        paths.append([( -.345+.255*math.cos(math.radians(a)),2.96+.255*math.sin(math.radians(a))) for a in range(55,306,19)])
        paths.extend([
            [(-.43,2.86),(-.29,2.87),(-.15,2.91),(-.07,2.96)],
            [(-.41,2.96),(-.27,2.97),(-.12,3.01),(-.035,3.06)],
            [(-.39,3.06),(-.25,3.07),(-.11,3.11),(-.015,3.16)]
        ])
        for face_side, offset in (('Front',-.020),('Back',.020)):
            for i,path in enumerate(paths):
                tube_path(f'L01_F01_Emblem_{side}_{face_side}_{i+1}',[xf(x,z,offset) for x,z in path],.009,6)

def main():
    assert bpy.data.scenes.get('Scene') is not None, 'Original default scene must remain present'
    assert bpy.data.scenes.get('WindProduction_L01') is None, 'Refusing to replace an existing L01 scene'
    scene=bpy.data.scenes.new('WindProduction_L01'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('L01_Export'); scene.collection.children.link(export)
    prev=bpy.data.collections.new('L01_Preview_ONLY'); scene.collection.children.link(prev)
    source=bpy.data.collections.new('L01_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    intact=empty(export,'L01_Intact_RuinedGate','7.2 x 2.4 x 5.8 m wind-ruin portal; bottom-center ground pivot; clear opening 4.64 x 4.65 m.')
    broken=empty(export,'L01_Damaged_RuinedGate','Same gate with one clipped roof corner and one chipped right column pedestal; portal remains clear.')
    build_columns(intact,False)
    box_mesh('L01_Crossbeam',-2.95,2.95,-.21,.21,4.65,5.20,intact,'stone_light','stone','stone_dark')
    roof(intact,False); flags(intact)
    # Reuse the intact gate parts and mesh data; only the exposed roof corner and one pedestal differ.
    for ob in list(intact.children):
        if ob.name in ('L01_Roof_Right_Front','L01_Roof_Right_Back'): continue
        dup=ob.copy(); dup.data=ob.data
        dup.name=ob.name.replace('L01_','L01_Damaged_',1)
        export.objects.link(dup); dup.parent=broken; dup.location=ob.location.copy(); dup.rotation_euler=ob.rotation_euler.copy(); dup.scale=ob.scale.copy()
    # Replace the shared names for these exact damaged components with clean descriptive names.
    for name in ('L01_Damaged_Roof_Right_Front','L01_Damaged_Roof_Right_Back'):
        old_roof=bpy.data.objects.get(name)
        if old_roof: bpy.data.objects.remove(old_roof,do_unlink=True)
    # Build only the damaged roof corner prism and column pedestal.
    prism_poly('L01_Damaged_Roof_Right_Corner_Broken',[(2.8,-1.05),(3.05,-1.05),(2.86,-.55),(3.12,-.10),(2.88,.34),(3.08,.72),(2.8,1.05)],lambda x:5.48+(x-2.8)*(.30/.70),.28,broken,damage_edges=(1,3,5))
    old_ped=bpy.data.objects.get('L01_Damaged_Right_Pedestal')
    if old_ped: bpy.data.objects.remove(old_ped,do_unlink=True)
    loft('L01_Damaged_Right_Pedestal',[(.20,.40,2.75),(.28,.39,2.75),(.36,.38,2.75),(.55,.37,2.75),(.64,.35,2.75),(.74,.33,2.75)],broken,chip=True)
    intact['state']='intact'; broken['state']='damaged'
    intact['opening_clear_width_m']=4.64; intact['opening_clear_height_m']=4.65
    broken['opening_clear_width_m']=4.64; broken['opening_clear_height_m']=4.65
    intact['envelope_m']=[7.2,2.4,5.8]; broken['envelope_m']=[7.2,2.4,5.8]
    source_root=bpy.data.objects.new('L01_SourceLocatorRoot',None); source.objects.link(source_root); source_root.hide_render=True; source_root.hide_set(True)
    for name,loc in [('BottomPivot',(0,0,0)),('DoorwayCenter',(0,0,2.3)),('BannerAnchorLeft',(-3.02,-.54,5.25)),('BannerAnchorRight',(3.02,-.54,5.25))]:
        e=bpy.data.objects.new('L01_Source_'+name,None); source.objects.link(e); e.parent=source_root; e.location=loc
        e['local_coordinates_m']=[float(v) for v in loc]; e['source_only']=True; e.hide_render=True; e.hide_set(True)
    source['clear_opening_m']=[4.64,4.65]; source['all_locators_excluded_from_glb']=True
    # Compact stage with the actual fox GLB, Idle, palette, and hidden preview helpers.
    cd=bpy.data.cameras.new('L01_PreviewCamera_Data'); cam=bpy.data.objects.new('L01_PreviewCamera',cd); prev.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('L01_Key',(-7,-10,11),1900,7),('L01_Fill',(8,-5,7),950,6),('L01_Rim',(0,6,11),1500,6)]:
        ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        ob=bpy.data.objects.new(name,ld); prev.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,2.5))-ob.location).to_track_quat('-Z','Y').to_euler()
    gm=bpy.data.materials.new('L01_PreviewGround'); gm.use_nodes=True
    gbs=next(n for n in gm.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); gbs.inputs['Base Color'].default_value=lin('#656967'); gbs.inputs['Roughness'].default_value=.96
    floor_mesh=bpy.data.meshes.new('L01_PreviewGround_Mesh'); floor_mesh.from_pydata([(-200,-200,-.015),(200,-200,-.015),(200,200,-.015),(-200,200,-.015)],[],[(0,1,2,3)]); floor_mesh.materials.append(gm)
    floor=bpy.data.objects.new('L01_PreviewGround',floor_mesh); prev.objects.link(floor)
    world=bpy.data.worlds.new('L01_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.18,.20,.21,1); bg.inputs['Strength'].default_value=.48; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import fox scale reference')
    for ob in imported:
        original=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        prev.objects.link(ob); ob.name='L01_Fox_'+original.replace('.','_')
        if any(t in original.lower() for t in ('icosphere','sword')): ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(0,-1.45,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:
            try: im.pack()
            except Exception: pass
    cam.location=(0,-24,10); cam.rotation_euler=(Vector((0,0,2.6))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=40
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in scene.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    print('L01_CREATED',json.dumps({'scene':scene.name,'intact_children':len(intact.children),'damaged_children':len(broken.children),'mesh_parts':sum(o.type=='MESH' for o in export.objects),'fox_action':rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None,'default_scene_preserved':bpy.data.scenes.get('Scene') is not None}))

if __name__=='__main__': main()
