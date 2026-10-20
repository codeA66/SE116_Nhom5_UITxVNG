import bpy, bmesh, math
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def linear(hex_color):
    values=[int(hex_color[i:i+2],16)/255.0 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)+(1.0,)

PALETTE={
  'wood':linear('#51473E'),'wood_light':linear('#62564A'),
  'wood_edge':linear('#443C35'),'wood_dark':linear('#35312D')
}

class MeshBuilder:
    def __init__(self): self.vertices=[]; self.faces=[]; self.keys=[]; self.cache={}
    def vertex(self,p):
        p=tuple(float(v) for v in p); key=tuple(round(v,7) for v in p)
        if key not in self.cache: self.cache[key]=len(self.vertices); self.vertices.append(p)
        return self.cache[key]
    def face(self,points,color):
        ids=[self.vertex(p) for p in points]; clean=[]
        for i in ids:
            if not clean or clean[-1]!=i: clean.append(i)
        if len(clean)>2 and clean[0]==clean[-1]: clean.pop()
        if len(set(clean))>=3: self.faces.append(tuple(clean)); self.keys.append(color)

def make_material():
    mat=bpy.data.materials.new('I05_Timber_SharedPalette'); mat.use_nodes=True
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=(1,1,1,1); bsdf.inputs['Roughness'].default_value=.92
    attr=mat.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name='Color'
    mat.node_tree.links.new(attr.outputs['Color'],bsdf.inputs['Base Color'])
    return mat

def make_object(collection,name,builder,mat,parent=None,part=None):
    mesh=bpy.data.meshes.new(name+'_Mesh'); mesh.from_pydata(builder.vertices,[],builder.faces); mesh.update(); mesh.materials.append(mat)
    attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,key in zip(mesh.polygons,builder.keys):
        for li in poly.loop_indices: attr.data[li].color=PALETTE[key]
    bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
    obj=bpy.data.objects.new(name,mesh); collection.objects.link(obj)
    if parent: obj.parent=parent; obj.location=(0,0,0)
    if part: obj['part']=part
    return obj

def empty(collection,name,loc=(0,0,0),parent=None):
    obj=bpy.data.objects.new(name,None); collection.objects.link(obj)
    if parent: obj.parent=parent
    obj.location=loc; obj.empty_display_type='PLAIN_AXES'
    return obj

def inset(points,amount):
    cx=sum(p[0] for p in points)/len(points); cy=sum(p[1] for p in points)/len(points)
    result=[]
    for x,y in points:
        d=Vector((cx-x,cy-y))
        if d.length: d.normalize(); x+=d.x*amount; y+=d.y*amount
        result.append((x,y))
    return result

def solid_prism(builder,polygon,z0,z1,top_color='wood_light',edge_color='wood_edge',bevel=.014,bottom_color='wood_dark'):
    low=[(x,y,z0) for x,y in polygon]
    top_xy=inset(polygon,bevel); high=[(x,y,z1) for x,y in top_xy]
    builder.face(list(reversed(low)),bottom_color)
    for i in range(len(low)):
        j=(i+1)%len(low); color=edge_color
        if i in (0,len(low)//2): color='wood'
        builder.face([low[i],low[j],high[j],high[i]],color)
    builder.face(high,top_color)

def deck_outline_x(y):
    # Straight central bow edge with two broad, shallow corner chamfers.
    return 2.25 if abs(y)<=1.55 else 3.80-abs(y)

def board_polygon(row,x_min=-2.25,x_override=None):
    pitch=4.0/6.0; gap=.024
    y0=-2.0+row*pitch+(0 if row==0 else gap/2)
    y1=-2.0+(row+1)*pitch-(0 if row==5 else gap/2)
    xmax0=deck_outline_x(y0); xmax1=deck_outline_x(y1)
    if x_override is not None: x_min,xmax0,xmax1=x_override
    return [(x_min,y0),(xmax0,y0),(xmax1,y1),(x_min,y1)]

def add_plank(collection,root,mat,name,row,polygon,z_bottom=.46,z_top=.60,top_color='wood_light',part_parent=None):
    group=empty(collection,name, parent=part_parent or root); group['part']='DeckPlank'; group['index']=row+1
    group['state']='same docking edge / separate board'
    builder=MeshBuilder(); solid_prism(builder,polygon,z_bottom,z_top,top_color=top_color)
    make_object(collection,name+'_Board',builder,mat,group,'DeckPlankMesh')
    return group

def post_polygon(half,cut):
    return [(-half+cut,-half),(half-cut,-half),(half,-half+cut),(half,half-cut),
            (half-cut,half),(-half+cut,half),(-half,half-cut),(-half,-half+cut)]

def make_post(builder,height=.46,broken=False):
    bottom=[(x,y,0) for x,y in post_polygon(.15,.055)]
    top_profile=[.27,.23,.28,.24,.27,.22,.28,.25] if broken else [height]*8
    top=[(x*.88,y*.88,z) for (x,y),z in zip(post_polygon(.15,.055),top_profile)]
    builder.face(list(reversed(bottom)),'wood_dark')
    for i in range(8):
        shade='wood_light' if i in (1,4,6) else 'wood'
        builder.face([bottom[i],bottom[(i+1)%8],top[(i+1)%8],top[i]],shade)
    builder.face(top,'wood_edge' if broken else 'wood_light')

def add_support_posts(collection,root,mat,state,collapsed=False):
    locations=[('BackLeft',-1.82,-1.55),('BackRight',-1.82,1.55),('BowLeft',1.82,-1.45),('BowRight',1.82,1.45)]
    for label,x,y in locations:
        broken=collapsed and label=='BackLeft'
        group=empty(collection,f'I05_{state}_Post_{label}',(x,y,0),root)
        group['part']='SupportPost'; group['install_height_adjustable']=True
        group['waterline_adjustable']='Move this separate post assembly vertically during integration.'
        if broken: group['state']='broken shortened tip supporting one dropped outer plank segment'
        builder=MeshBuilder(); make_post(builder,.28 if broken else .46,broken)
        make_object(collection,f'I05_{state}_Post_{label}_Timber',builder,mat,group,'SupportPostMesh')

def add_stringers(collection,root,mat,state,collapsed=False):
    for i,y in enumerate((-1.49,1.49),1):
        group=empty(collection,f'I05_{state}_Stringer_{i:02d}',parent=root); group['part']='DeckStringer'
        segments=[(-1.83,1.83,.32,.46)]
        if collapsed and i==1:
            segments=[(-1.58,1.83,.32,.46),(-2.05,-1.66,.14,.28)]
            group['state']='one short dropped segment and one broken gap under the collapsed rear corner'
        for j,(x0,x1,z0,z1) in enumerate(segments,1):
            builder=MeshBuilder()
            solid_prism(builder,[(x0,y-.105),(x1,y-.105),(x1,y+.105),(x0,y+.105)],z0,z1,
                        top_color='wood',edge_color='wood_dark',bevel=.012,bottom_color='wood_dark')
            make_object(collection,f'I05_{state}_Stringer_{i:02d}_Beam_{j:02d}',builder,mat,group,'DeckStringerMesh')

def add_variant(collection,mat,state,root_x,kind):
    root=empty(collection,f'I05_{state}_WoodenDock',(root_x,0,0))
    root['variant']=state; root['nominal_dimensions_blender_xyz_m']=[4.5,4.0,.6]
    root['pivot']='plan center at ground plane (0,0,0)'
    root['fixed_docking_edge']='flat central segment on +X bow edge; never obstruct with post heads'
    root['design']='Ruined East-Asian timber dock; six broad separated boards and four adjustable posts.'
    root['collision']='full stable deck area excluding only the one explicitly damaged outer board or lowered corner.'
    add_support_posts(collection,root,mat,state,collapsed=(kind=='collapsed'))
    add_stringers(collection,root,mat,state,collapsed=(kind=='collapsed'))
    for row in range(6):
        color='wood_light' if row in (0,2,5) else 'wood'
        if kind=='damaged' and row==0:
            # One exposed side board is shortened at the landward end, clear of the docking edge.
            poly=board_polygon(row,x_min=-1.62)
            add_plank(collection,root,mat,f'I05_{state}_DeckPlank_{row+1:02d}',row,poly,top_color=color)
        elif kind=='collapsed' and row==0:
            # One rear corner segment drops 0.18 m; the broad middle and bow docking strip stay level.
            group=empty(collection,f'I05_{state}_DeckPlank_{row+1:02d}',parent=root)
            group['part']='DeckPlank'; group['index']=row+1; group['state']='one dropped outer corner segment'
            main_poly=board_polygon(row,x_min=-1.63)
            main=MeshBuilder(); solid_prism(main,main_poly,.46,.60,top_color=color)
            make_object(collection,f'I05_{state}_DeckPlank_{row+1:02d}_Level',main,mat,group,'DeckPlankMesh')
            low_poly=[(-2.25,-2.0),(-1.66,-2.0),(-1.66,-1.345333),(-2.25,-1.345333)]
            dropped=MeshBuilder(); solid_prism(dropped,low_poly,.28,.42,top_color='wood_light')
            make_object(collection,f'I05_{state}_DeckPlank_{row+1:02d}_DroppedCorner',dropped,mat,group,'DeckPlankMesh')
        else:
            polygon=board_polygon(row)
            add_plank(collection,root,mat,f'I05_{state}_DeckPlank_{row+1:02d}',row,polygon,top_color=color)
    if kind=='damaged': root['damage']='one shortened outer plank at the landward end; docking face intact.'
    if kind=='collapsed': root['damage']='one small rear corner plank segment lowered 0.18 m and its matching post tip broken; center deck and docking edge remain level.'
    return root

def setup_preview(scene,preview):
    data=bpy.data.cameras.new('I05_PreviewCamera_Data'); camera=bpy.data.objects.new('I05_PreviewCamera',data); preview.objects.link(camera); scene.camera=camera
    for name,loc,power,size in [('I05_Key',(-8,-10,11),1700,7),('I05_Fill',(8,-3,7),900,6),('I05_Rim',(0,8,9),1200,5)]:
        light=bpy.data.lights.new(name,'AREA'); light.energy=power; light.shape='DISK'; light.size=size
        obj=bpy.data.objects.new(name,light); preview.objects.link(obj); obj.location=loc
        obj.rotation_euler=(Vector((0,0,.35))-obj.location).to_track_quat('-Z','Y').to_euler()
    groundmat=bpy.data.materials.new('I05_Preview_Ground'); groundmat.use_nodes=True
    bsdf=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=linear('#777A78'); bsdf.inputs['Roughness'].default_value=.95
    me=bpy.data.meshes.new('I05_PreviewFloor_Mesh')
    me.from_pydata([(-250,-250,-.012),(250,-250,-.012),(250,250,-.012),(-250,250,-.012)],[],[(0,1,2,3)]); me.materials.append(groundmat)
    floor=bpy.data.objects.new('I05_PreviewFloor',me); preview.objects.link(floor)
    world=bpy.data.worlds.new('I05_PreviewWorld'); world.use_nodes=True
    background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    background.inputs['Color'].default_value=(.40,.42,.43,1); background.inputs['Strength'].default_value=.55; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('Could not import the current fox scale reference.')
    originals={o:o.name for o in imported}
    for obj in imported:
        for col in list(obj.users_collection): col.objects.unlink(obj)
        preview.objects.link(obj); obj.name='I05_Fox_'+originals[obj].replace('.','_')
        if any(token in originals[obj].lower() for token in ('icosphere','sword')):
            obj.hide_render=True; obj.hide_set(True)
    idle=next((a for a in bpy.data.actions if 'idle' in a.name.lower()),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1); rig.location=(-7.6,-.15,0)
    return camera,rig

# Replace only the generated I05 scene; the default scene and completed assets remain intact.
old=bpy.data.scenes.get('WindProduction_I05')
if old:
    fallback=bpy.data.scenes.get('WindProduction_I04') or bpy.data.scenes.get('Scene')
    if fallback: bpy.context.window.scene=fallback
    bpy.data.scenes.remove(old,do_unlink=True)
for col in list(bpy.data.collections):
    if col.name.startswith('I05_') and col.users==0: bpy.data.collections.remove(col)
for obj in list(bpy.data.objects):
    if obj.name.startswith('I05_') and obj.users==0: bpy.data.objects.remove(obj,do_unlink=True)
for datablocks in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
    for block in list(datablocks):
        if block.name.startswith('I05_') and block.users==0: datablocks.remove(block)

scene=bpy.data.scenes.new('WindProduction_I05'); bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
export=bpy.data.collections.new('I05_Export'); scene.collection.children.link(export)
preview=bpy.data.collections.new('I05_Preview_ONLY'); scene.collection.children.link(preview)
mat=make_material()
states=[('Intact',-4.8,'intact'),('Damaged',0.0,'damaged'),('Collapsed',4.8,'collapsed')]
roots=[add_variant(export,mat,label,x,kind) for label,x,kind in states]
camera,fox=setup_preview(scene,preview)
camera.location=(7,-25,17); camera.rotation_euler=(Vector((0,0,.35))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='PERSP'; camera.data.sensor_fit='VERTICAL'; camera.data.sensor_height=24; camera.data.lens=65
scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
for obj in bpy.context.view_layer.objects: obj.select_set(False)
for obj in export.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=roots[0]
assert bpy.data.scenes.get('Scene') is not None,'The original default Blender scene must remain present.'
print('I05_CREATED',scene.name,'states',len(roots),'export_objects',len(export.objects),'meshes',sum(o.type=='MESH' for o in export.objects),'fox_action',fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,'default_scene_preserved=True')
