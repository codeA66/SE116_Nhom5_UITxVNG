import bpy, math
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb) + (1.0,)

COLORS = {
    'stone': lin('#62645F'), 'stone_light': lin('#777972'), 'stone_dark': lin('#4E514D'),
    'stone_band': lin('#6F706A'), 'wood': lin('#493627'), 'wood_light': lin('#68503A'),
    'wood_dark': lin('#35291F'), 'iron': lin('#464A48'), 'iron_light': lin('#777A74'),
    'cloth': lin('#D0C9B6'), 'cloth_back': lin('#A9A391'), 'cloth_edge': lin('#777263')
}

class MeshBuilder:
    def __init__(self):
        self.vertices, self.faces, self.keys, self.cache = [], [], [], {}
    def vertex(self, p):
        p = tuple(float(v) for v in p)
        k = tuple(round(v, 7) for v in p)
        if k not in self.cache:
            self.cache[k] = len(self.vertices)
            self.vertices.append(p)
        return self.cache[k]
    def face(self, pts, key):
        ids = [self.vertex(p) for p in pts]
        clean = []
        for i in ids:
            if not clean or clean[-1] != i: clean.append(i)
        if len(clean) > 2 and clean[0] == clean[-1]: clean.pop()
        if len(set(clean)) >= 3:
            self.faces.append(tuple(clean)); self.keys.append(key)

def shared_material():
    mat = bpy.data.materials.new('I03_WindMachine_SharedPalette')
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bsdf.inputs['Roughness'].default_value = .86
    attr = mat.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'Color'
    mat.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

def make_object(collection, name, builder, mat, parent=None, tags=None):
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(builder.vertices, [], builder.faces); me.update(); me.materials.append(mat)
    attr = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, key in zip(me.polygons, builder.keys):
        for li in poly.loop_indices: attr.data[li].color = COLORS[key]
    obj = bpy.data.objects.new(name, me); collection.objects.link(obj)
    if parent: obj.parent = parent; obj.location = (0, 0, 0)
    if tags:
        for k, v in tags.items(): obj[k] = v
    return obj

def empty(collection, name, parent=None, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None); collection.objects.link(obj)
    if parent: obj.parent = parent
    obj.location = loc; obj.empty_display_type = 'PLAIN_AXES'
    return obj

def box_beam(builder, a, b, width, depth, key='wood'):
    a, b = Vector(a), Vector(b); axis = (b - a).normalized()
    dep = Vector((0, 1, 0))
    if abs(axis.dot(dep)) > .95: dep = Vector((0, 0, 1))
    side = dep.cross(axis).normalized(); dep = axis.cross(side).normalized()
    verts = []
    for p in (a, b):
        verts.extend([tuple(p - side*width/2 - dep*depth/2), tuple(p + side*width/2 - dep*depth/2),
                      tuple(p + side*width/2 + dep*depth/2), tuple(p - side*width/2 + dep*depth/2)])
    for f in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
        builder.face([verts[i] for i in f], key)

def cylinder_y(builder, radius, y0, y1, sides=10, key='iron', cap='iron_light', center=(0,0,0)):
    cx, cy, cz = center
    lo = [(cx + radius*math.cos(2*math.pi*i/sides), cy+y0, cz + radius*math.sin(2*math.pi*i/sides)) for i in range(sides)]
    hi = [(cx + radius*math.cos(2*math.pi*i/sides), cy+y1, cz + radius*math.sin(2*math.pi*i/sides)) for i in range(sides)]
    builder.face(list(reversed(lo)), cap); builder.face(hi, cap)
    for i in range(sides): builder.face([lo[i], hi[i], hi[(i+1)%sides], lo[(i+1)%sides]], key)

def base_plinth(builder):
    # One tapered octagonal stone mass with three broad bands; total height exactly 1.5 m.
    rings = [(0.00,1.10,1.00),(.22,1.10,1.00),(.32,1.03,.92),
             (.78,1.03,.92),(.88,.95,.84),(1.38,.95,.84),(1.50,.86,.76)]
    sides = 8; loops=[]
    depth_scale = 1.0 / math.cos(math.pi / 8.0)
    for z,rx,ry in rings:
        ry *= depth_scale
        loops.append([(rx*math.cos(2*math.pi*i/sides+math.pi/8),
                       ry*math.sin(2*math.pi*i/sides+math.pi/8),z) for i in range(sides)])
    builder.face(list(reversed(loops[0])), 'stone_dark')
    transitions=('stone_dark','stone_band','stone','stone_band','stone','stone_light')
    for j in range(len(loops)-1):
        for i in range(sides):
            key = transitions[j]
            if i in (1,4,6) and key=='stone': key='stone_light'
            builder.face([loops[j][i],loops[j][(i+1)%sides],loops[j+1][(i+1)%sides],loops[j+1][i]],key)
    builder.face(loops[-1], 'stone_light')

def clip_half(poly, nx, ny, limit):
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=a[0]*nx+a[1]*ny-limit; db=b[0]*nx+b[1]*ny-limit
        ina=da<=1e-8; inb=db<=1e-8
        if ina: result.append(a)
        if ina != inb:
            t=da/(da-db); result.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
    return result

def plane_point(u,v,angle,y):
    c,s=math.cos(angle),math.sin(angle)
    return (c*u-s*v, y, s*u+c*v)

def prism_panel(builder, poly, angle):
    front=[plane_point(u,v,angle,-.085) for u,v in poly]
    back=[plane_point(u,v,angle,-.045) for u,v in poly]
    builder.face(front,'cloth')
    builder.face(list(reversed(back)),'cloth_back')
    for i in range(len(poly)):
        j=(i+1)%len(poly); builder.face([front[i],back[i],back[j],front[j]],'cloth_edge')

def plane_beam(builder, angle, a, b, width=.06, depth=.045, y=-.105, key='wood_light'):
    dx=b[0]-a[0]; dy=b[1]-a[1]; L=math.hypot(dx,dy)
    if L<1e-8:return
    sx=-dy/L*width/2; sy=dx/L*width/2
    poly=[(a[0]+sx,a[1]+sy),(b[0]+sx,b[1]+sy),(b[0]-sx,b[1]-sy),(a[0]-sx,a[1]-sy)]
    lo=[plane_point(u,v,angle,y-depth/2) for u,v in poly]
    hi=[plane_point(u,v,angle,y+depth/2) for u,v in poly]
    builder.face(list(reversed(lo)),key); builder.face(hi,key)
    for i in range(4): builder.face([lo[i],lo[(i+1)%4],hi[(i+1)%4],hi[i]],key)

def build_frame(scene_collection, export, root, mat, state):
    frame = empty(export, 'I03_'+state+'_Frame', root); frame['part']='Frame'; frame['fixed']=True
    base=MeshBuilder(); base_plinth(base)
    make_object(export,'I03_'+state+'_Stone_Plinth',base,mat,frame,{'part':'Frame','collider':'fixed base only'})
    # Lower tie arms reach the nominal 4.8 m width. They sit behind the rotor and below its 1.75 m sweep.
    for side in (-1,1):
        b=MeshBuilder(); box_beam(b,(side*.55,.60,1.48),(side*2.40,.60,1.48),.12,.14,'wood')
        make_object(export,f'I03_{state}_Lower_Tie_{"L" if side<0 else "R"}',b,mat,frame,{'part':'Frame'})
    if state == 'Collapsed':
        for side,top in [(-1,1.92),(1,2.18)]:
            b=MeshBuilder(); box_beam(b,(side*.52,.55,1.46),(side*.43,.55,top),.14,.15,'wood')
            make_object(export,f'I03_{state}_Broken_Stump_{"L" if side<0 else "R"}',b,mat,frame,{'part':'Frame','state':'snapped'})
    else:
        for side in (-1,1):
            b=MeshBuilder(); box_beam(b,(side*.52,.56,1.46),(side*.18,.62,3.95),.14,.15,'wood')
            make_object(export,f'I03_{state}_Support_{"L" if side<0 else "R"}',b,mat,frame,{'part':'Frame'})
        b=MeshBuilder(); box_beam(b,(-.36,.63,3.93),(.36,.63,3.93),.16,.15,'wood_light')
        make_object(export,'I03_'+state+'_Cradle_Crossbar',b,mat,frame,{'part':'Frame'})
        axle=MeshBuilder(); cylinder_y(axle,.075,.08,.80,10,'iron','iron_light',(0,0,4.0))
        make_object(export,'I03_'+state+'_Fixed_Axle',axle,mat,frame,{'part':'Frame','clearance':'behind rotor plane'})
    return frame

def build_rotor(export, root, mat, state, collapsed=False):
    rotor=empty(export,'I03_'+state+'_Rotor',root,
                (2.62,.06,.50) if collapsed else (0,0,4.0))
    rotor['part']='Rotor'; rotor['pivot']='center of axle'; rotor['diameter_m']=4.5
    if collapsed:
        rotor.rotation_euler=(math.radians(90),0,math.radians(-7))
        rotor['state']='fallen; origin remains at dropped axle center'
    else:
        rotor['state']='operable pivot at z=4.0 m; axle along local Y'
    hub=MeshBuilder(); cylinder_y(hub,.255,-.18,.18,12,'iron','iron_light')
    cylinder_y(hub,.145,-.225,-.18,10,'wood_light','iron_light')
    make_object(export,'I03_'+state+'_Rotor_Hub',hub,mat,rotor,{'part':'Rotor'})
    for i in range(4):
        angle=i*math.pi/2
        d=Vector((math.cos(angle),0,math.sin(angle)))
        tip=math.sqrt(2.25**2-(.105/2)**2)
        start=tuple(d*.16); end=tuple(d*tip)
        b=MeshBuilder(); box_beam(b,start,end,.105,.105,'wood_light')
        make_object(export,f'I03_{state}_Rotor_Spoke_{i+1:02d}',b,mat,rotor,{'part':'Rotor','tip_radius_m':2.25})
    for i in range(4):
        missing=(state in ('Damaged','Collapsed') and i==1)
        if missing: continue
        torn=(state in ('Damaged','Collapsed') and i==2)
        sail=empty(export,f'I03_{state}_Sail_{i+1:02d}'+('_Torn' if torn else ''),rotor)
        sail['part']='Sail'; sail['state']='torn' if torn else 'intact'; sail['index']=i+1
        angle=i*math.pi/2
        ri,ro=.43,1.94; wi,wo=.22,.47
        quad=[(ri,-wi),(ro,-wo),(ro,wo),(ri,wi)]
        polys=[quad]
        if torn:
            a=(1.14,-.34); b=(1.42,.34); dx=b[0]-a[0]; dy=b[1]-a[1]; L=math.hypot(dx,dy)
            nx=-dy/L; ny=dx/L; d0=a[0]*nx+a[1]*ny; gap=.055
            polys=[clip_half(quad,nx,ny,d0-gap),clip_half(quad,-nx,-ny,-d0-gap)]
        for j,poly in enumerate(polys):
            if len(poly)>=3:
                panel=MeshBuilder(); prism_panel(panel,poly,angle)
                make_object(export,f'I03_{state}_Sail_{i+1:02d}_Cloth_{j+1:02d}',panel,mat,sail,{'part':'Sail','cloth_piece':j+1})
        # One clear center spar and two edge rails define the trapezoid; a tear interrupts the center spar.
        beam_segments=[(ri,ro)]
        if torn: beam_segments=[(ri,1.10),(1.48,ro)]
        for j,(u0,u1) in enumerate(beam_segments):
            b=MeshBuilder(); plane_beam(b,angle,(u0,0),(u1,0),.060,.055,-.115,'wood_light')
            make_object(export,f'I03_{state}_Sail_{i+1:02d}_Spar_{j+1:02d}',b,mat,sail,{'part':'Sail'})
        for r,w,lab in ((ri,wi,'Inner'),(ro,wo,'Outer')):
            b=MeshBuilder(); plane_beam(b,angle,(r,-w),(r,w),.055,.050,-.112,'wood')
            make_object(export,f'I03_{state}_Sail_{i+1:02d}_{lab}_Rail',b,mat,sail,{'part':'Sail'})
    return rotor

def setup_preview(scene, preview):
    # Camera, neutral ground, and real imported fox are preview-only and never enter the export collection.
    cam_data=bpy.data.cameras.new('I03_PreviewCamera_Data'); cam=bpy.data.objects.new('I03_PreviewCamera',cam_data); preview.objects.link(cam); scene.camera=cam
    for name,loc,power,size in [('I03_Key',(-7,-8,13),1800,7),('I03_Fill',(8,-2,8),950,6),('I03_Rim',(0,8,11),1300,5)]:
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
        obj=bpy.data.objects.new(name,data); preview.objects.link(obj); obj.location=loc
        obj.rotation_euler=(Vector((0,0,2.5))-obj.location).to_track_quat('-Z','Y').to_euler()
    groundmat=bpy.data.materials.new('I03_Preview_Ground'); groundmat.diffuse_color=lin('#777A78'); groundmat.use_nodes=True
    bsdf=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); bsdf.inputs['Base Color'].default_value=lin('#777A78'); bsdf.inputs['Roughness'].default_value=.95
    me=bpy.data.meshes.new('I03_PreviewFloor_Mesh'); me.from_pydata([(-250,-250,-.012),(250,-250,-.012),(250,250,-.012),(-250,250,-.012)],[],[(0,1,2,3)]); me.materials.append(groundmat)
    floor=bpy.data.objects.new('I03_PreviewFloor',me); preview.objects.link(floor)
    world=bpy.data.worlds.new('I03_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.40,.42,.43,1); bg.inputs['Strength'].default_value=.55; scene.world=world
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before)
    rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not locate the imported fox armature for preview scale.')
    original_names={o:o.name for o in imported}
    for obj in imported:
        for col in list(obj.users_collection): col.objects.unlink(obj)
        preview.objects.link(obj)
        obj.name='I03_Fox_'+original_names[obj].replace('.','_')
        if any(k in original_names[obj].lower() for k in ('icosphere','sword')): obj.hide_render=True
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1)
    rig.location=(-4.8,-.15,0)
    return cam,rig

# Replace only this generated scene on iteration; all default and earlier asset scenes are preserved.
old=bpy.data.scenes.get('WindProduction_I03')
if old:
    fallback=bpy.data.scenes.get('WindProduction_T03') or bpy.data.scenes.get('Scene')
    if fallback: bpy.context.window.scene=fallback
    bpy.data.scenes.remove(old,do_unlink=True)
for col in list(bpy.data.collections):
    if col.name.startswith('I03_') and col.users==0: bpy.data.collections.remove(col)
for obj in list(bpy.data.objects):
    if obj.name.startswith('I03_') and obj.users==0: bpy.data.objects.remove(obj,do_unlink=True)
for datablocks in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
    for data in list(datablocks):
        if data.name.startswith('I03_') and data.users==0: datablocks.remove(data)

scene=bpy.data.scenes.new('WindProduction_I03'); bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
export=bpy.data.collections.new('I03_Export'); scene.collection.children.link(export)
preview=bpy.data.collections.new('I03_Preview_ONLY'); scene.collection.children.link(preview)
mat=shared_material()
states=[('Intact',-8.0),('Damaged',0.0),('Collapsed',9.0)]
for state,x in states:
    root=empty(export,'I03_'+state+'_WindMachine',None,(x,0,0))
    root['variant']=state; root['nominal_dimensions_blender_xyz_m']=[4.8,2.0,6.3]
    root['design']='Ruined East Asian wind catcher; broad four-sail rotor; low-poly shared palette.'
    root['fixed_collider']='simple stable base; rotor and sails remain separate'
    build_frame(scene,export,root,mat,state)
    build_rotor(export,root,mat,state,collapsed=(state=='Collapsed'))
    if state=='Collapsed':
        fallen=empty(export,'I03_Collapsed_FallenFrame',root,(1.2,.2,.18)); fallen['part']='Frame'; fallen['state']='fallen upper supports'
        for i,(a,b) in enumerate([((.05,-.52,.04),(2.48,-.52,.10)),((.15,.70,.03),(2.72,.70,.08)),((1.10,-.52,.10),(1.52,.70,.08))]):
            beam=MeshBuilder(); box_beam(beam,a,b,.14,.13,'wood')
            make_object(export,f'I03_Collapsed_Fallen_Support_{i+1:02d}',beam,mat,fallen,{'part':'Frame','state':'fallen'})

cam,fox=setup_preview(scene,preview)
cam.location=(1.0,-26.0,23.0); cam.rotation_euler=(Vector((1.0,0,2.8))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=40
scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in export.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['I03_Intact_WindMachine']
print('I03_CREATED',scene.name,'roots',len(states),'export_objects',len(export.objects),'mesh_parts',sum(o.type=='MESH' for o in export.objects),'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,'default_scene_preserved',bpy.data.scenes.get('Scene') is not None)
