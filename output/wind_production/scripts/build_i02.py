import bpy, bmesh, math, os, shutil
from mathutils import Matrix, Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/i02';PRE=ROOT+'/output/wind_production/i02'
CONCEPT=ROOT+'/output/wind_production/concepts/i02_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/i02_prompt.txt'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
assert os.path.isdir(OUT+'/source') and os.path.isfile(OUT+'/source/.gdignore')
assert not os.path.exists(OUT+'/i02_modular_bridge_pier.glb')
assert bpy.context.scene.name=='WindProduction_I01',bpy.context.scene.name
assert 'Scene' in bpy.data.scenes and all(n in bpy.data.objects for n in ('Cube','Camera','Light'))
os.makedirs(PRE,exist_ok=True)
previous=bpy.context.scene;scene=bpy.data.scenes.new('WindProduction_I02');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
scene.world=previous.world.copy() if previous.world else bpy.data.worlds.new('I02_PreviewWorld');scene.world.name='I02_PreviewWorld'
scene.render.engine=previous.render.engine;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.render.film_transparent=False
preview=bpy.data.collections.new('I02_Preview_ONLY');export=bpy.data.collections.new('I02_Export');scene.collection.children.link(preview);scene.collection.children.link(export)
for src_name,name in [('I01_PreviewCamera','I02_PreviewCamera'),('I01_Preview_Key','I02_Preview_Key'),('I01_Preview_Fill','I02_Preview_Fill'),('I01_Preview_Rim','I02_Preview_Rim')]:
    src=bpy.data.objects[src_name];ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name=name;preview.objects.link(ob);ob.matrix_world=src.matrix_world.copy()
    if ob.type=='CAMERA':scene.camera=ob
src_rig=bpy.data.objects['I01_PreviewFox_FoxRig'];src_objects=[]
def collect(ob):
    src_objects.append(ob)
    for child in ob.children:collect(child)
collect(src_rig);copies={};world={ob:ob.matrix_world.copy() for ob in src_objects}
for src in src_objects:
    ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name='I02_PreviewFox_'+src.name.replace('I01_PreviewFox_','');preview.objects.link(ob);copies[src]=ob
for src,ob in copies.items():
    if src.parent in copies:ob.parent=copies[src.parent]
    ob.matrix_world=world[src]
    for mod in ob.modifiers:
        if mod.type=='ARMATURE' and mod.object in copies:mod.object=copies[mod.object]
fox=copies[src_rig]
if fox.animation_data:fox.animation_data_clear()
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create();fox.animation_data.action=src_rig.animation_data.action
fox.scale=(1.404,1.404,1.404);fox.location=(1.4,-1.8,0);scene.frame_set(1)

def linear(h):
    vals=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1,)
COLORS={'stone':linear('#526271'),'stone_light':linear('#687A87'),'stone_dark':linear('#3C4C58'),
        'bronze':linear('#8B7550'),'moss':linear('#596B4E'),'ground':linear('#777A7B')}
mat=bpy.data.materials.new('I02_Shared_Bluegray_Stone_Bronze_VertexColor');mat.use_nodes=True
bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Base Color'].default_value=(1,1,1,1);bsdf.inputs['Roughness'].default_value=.84
vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
ground_mat=bpy.data.materials.new('I02_Preview_Neutral_Gray');ground_mat.use_nodes=True
next(n for n in ground_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=COLORS['ground']
gm=bpy.data.meshes.new('I02_PreviewGround_Mesh');gm.from_pydata([(-60,-60,-.05),(60,-60,-.05),(60,60,-.05),(-60,60,-.05)],[],[(0,1,2,3)]);gm.materials.append(ground_mat)
ground=bpy.data.objects.new('I02_PreviewGround',gm);preview.objects.link(ground)

def color_mesh(me,tone='stone',fracture=False):
    me.update();attr=me.color_attributes.get('Color') or me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        c=COLORS[tone]
        if tone=='stone':
            if fracture and poly.index<2:c=COLORS['stone_dark']
            elif poly.normal.z>.68:c=COLORS['stone_light']
            elif fracture and abs(poly.normal.z)>.12:c=COLORS['stone_dark']
            elif poly.index%9==0:c=COLORS['stone_light']
        for li in poly.loop_indices:attr.data[li].color=c

def root(name,parent=None,loc=(0,0,0),rot=(0,0,0)):
    ob=bpy.data.objects.new(name,None);ob.empty_display_type='PLAIN_AXES';ob.empty_display_size=.14;export.objects.link(ob)
    if parent:ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4)
    ob.location=loc;ob.rotation_euler=rot;return ob
def part(name,mesh,parent,loc=(0,0,0)):
    ob=bpy.data.objects.new(name,mesh);export.objects.link(ob);ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4);ob.location=loc;return ob

def octagon(hw,hd,cut):
    return [(-hw+cut,-hd),(hw-cut,-hd),(hw,-hd+cut),(hw,hd-cut),(hw-cut,hd),(-hw+cut,hd),(-hw,hd-cut),(-hw,-hd+cut)]
def rings_mesh(name,rings,tone='stone',fracture=False):
    verts=[]
    for ring in rings:
        z,hx,hy,cut=ring[:4];cx=ring[4] if len(ring)>4 else 0;cy=ring[5] if len(ring)>5 else 0
        offsets=ring[6] if len(ring)>6 else None
        for i,(x,y) in enumerate(octagon(hx,hy,cut)):
            verts.append((cx+x,cy+y,z+(offsets[i] if offsets else 0)))
    faces=[tuple(reversed(range(8))),tuple(range((len(rings)-1)*8,len(rings)*8))]
    for ri in range(len(rings)-1):
        a=ri*8;b=(ri+1)*8
        for j in range(8):k=(j+1)%8;faces.append((a+j,a+k,b+k,b+j))
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    me.materials.append(mat);color_mesh(me,tone,fracture);return me

def prism_mesh(name,poly,z0,z1,tone='stone'):
    # Counter-clockwise plan outline, extruded to a closed, clean low-poly chunk.
    n=len(poly);verts=[(x,y,z0) for x,y in poly]+[(x,y,z1) for x,y in poly]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n):j=(i+1)%n;faces.append((i,j,n+j,n+i))
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    me.materials.append(mat);color_mesh(me,tone);return me

def box_mesh(name,dims,tone='stone'):
    hx,hy,hz=(v/2 for v in dims);verts=[(-hx,-hy,-hz),(hx,-hy,-hz),(hx,hy,-hz),(-hx,hy,-hz),(-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.materials.append(mat);color_mesh(me,tone);return me

full_base_poly=octagon(.60,.60,.08)
notched_base_poly=[(-.52,-.60),(.10,-.60),(.25,-.38),(.40,-.60),(.52,-.60),(.60,-.52),(.60,.52),(.52,.60),(-.52,.60),(-.60,.52),(-.60,-.52)]
foot_fragment_poly=[(.10,-.60),(.40,-.60),(.25,-.38)]
BASE_INTACT=prism_mesh('I02_Foot_Platform_Shared_Mesh',full_base_poly,0,.18,'stone')
BASE_BROKEN=prism_mesh('I02_Broken_Notched_Foot_Platform_Mesh',notched_base_poly,0,.18,'stone')
FOOT_FRAGMENT=prism_mesh('I02_Matching_Foot_Fragment_Mesh',foot_fragment_poly,0,.18,'stone')
BASE_SHOULDER=rings_mesh('I02_Foot_Tapered_Shoulder_Shared_Mesh',[(0,.58,.58,.08),(.37,.45,.45,.065)],'stone')
LOWER_MESH=rings_mesh('I02_Lower_Repeatable_Shaft_Module_Mesh',[(0,.42,.42,.06),(1.05,.405,.405,.058),(2.20,.39,.39,.055)],'stone')
UPPER_MESH=rings_mesh('I02_Upper_Repeatable_Shaft_Module_Mesh',[(0,.39,.39,.055),(1.97,.357,.357,.05)],'stone')
COURSE_BAND=box_mesh('I02_Stone_Course_Seam_Shared_Mesh',(.81,.81,.038),'bronze')
CRADLE_NECK=box_mesh('I02_Fork_Cradle_Neck_Shared_Mesh',(.78,.72,.30),'stone')
FORK_LEFT=rings_mesh('I02_Fork_Arm_Left_Shared_Mesh',[(2.15,.17,.17,.045,0,-.36),(2.35,.16,.16,.04,0,-.35),(2.65,.135,.13,.035,0,-.31)],'stone')
FORK_RIGHT=rings_mesh('I02_Fork_Arm_Right_Shared_Mesh',[(2.15,.17,.17,.045,0,.36),(2.35,.16,.16,.04,0,.35),(2.65,.135,.13,.035,0,.31)],'stone')

intact=root('I02_Intact')
part('I02_Intact_Foot_Platform',BASE_INTACT,intact)
part('I02_Intact_Foot_Tapered_Shoulder',BASE_SHOULDER,intact,(0,0,.175))
part('I02_Intact_Shaft_Lower_Repeatable_Module',LOWER_MESH,intact,(0,0,.55))
upper_group=root('I02_Intact_Upper_Module_Assembly',intact,(0,0,2.75))
part('I02_Intact_Shaft_Upper_Repeatable_Module',UPPER_MESH,upper_group)
part('I02_Intact_Single_Stone_Course_Seam',COURSE_BAND,intact,(0,0,2.75))
part('I02_Intact_Fork_Cradle_Neck',CRADLE_NECK,upper_group,(0,0,2.12))
part('I02_Intact_Fork_Arm_Left',FORK_LEFT,upper_group)
part('I02_Intact_Fork_Arm_Right',FORK_RIGHT,upper_group)

# Same original course-cut loop forms the visible seam in the intact state and
# the matching fracture interface in the leaning state.
fracture_offsets=[.055,.12,.105,.025,-.06,-.115,-.075,.005]
LOWER_BROKEN=rings_mesh('I02_Broken_Lower_Stump_Matching_Cut_Mesh',[(0,.42,.42,.06),(1.05,.405,.405,.058),(2.20,.39,.39,.055,0,0,fracture_offsets)],'stone',True)
UPPER_BROKEN=rings_mesh('I02_Broken_Upper_Shaft_Matching_Cut_Mesh',[(0,.39,.39,.055,0,0,fracture_offsets),(1.97,.357,.357,.05)],'stone',True)
broken=root('I02_Broken_Leaning')
part('I02_Broken_Notched_Foot_Platform',BASE_BROKEN,broken)
part('I02_Broken_Foot_Tapered_Shoulder',BASE_SHOULDER,broken,(0,0,.175))
part('I02_Broken_Matching_Loose_Foot_Fragment',FOOT_FRAGMENT,broken,(0,-.10,0))
part('I02_Broken_Lower_Stump_Matching_Face',LOWER_BROKEN,broken,(0,0,.55))
lean=math.radians(11)
fallen_upper=root('I02_Broken_Leaning_Upper_Repeatable_Assembly',broken,(.08,0,2.75),(0,lean,0))
part('I02_Broken_Upper_Shaft_Matching_Face',UPPER_BROKEN,fallen_upper)
part('I02_Broken_Upper_Fork_Cradle_Neck',CRADLE_NECK,fallen_upper,(0,0,2.12))
part('I02_Broken_Upper_Fork_Arm_Left',FORK_LEFT,fallen_upper)
part('I02_Broken_Upper_Fork_Arm_Right',FORK_RIGHT,fallen_upper)

# A reusable extension sample is source-only, excluded from the exported catalog asset.
extension=bpy.data.objects.new('I02_Optional_Shaft_Extension_Module_SOURCE_ONLY',LOWER_MESH);preview.objects.link(extension);extension.location=(2.2,0,0);extension.hide_render=True;extension.hide_set(True)
notes=bpy.data.objects.new('I02_Assembly_Notes_SOURCE_ONLY',None);notes['intact_envelope_m']='1.2 x 1.2 x 5.4';notes['taper_percent']=15;notes['insert_height_by']='duplicate I02_Optional_Shaft_Extension_Module_SOURCE_ONLY between repeatable lower and upper modules';notes['fork_beam_axis']='X';preview.objects.link(notes)
camera=bpy.data.objects['I02_PreviewCamera'];camera.location=(8,-12,7.8);camera.rotation_euler=(Vector((0,0,2.65))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='PERSP';camera.data.lens=45
for name in ('I02_Preview_Key','I02_Preview_Fill','I02_Preview_Rim'):
    light=bpy.data.objects[name];light.data.color=(1,1,1);light.data.energy*=.96
if scene.world and scene.world.use_nodes:next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=.32
scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX'
for ob in bpy.context.view_layer.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=intact
print('I02_BUILD_OK',scene.name,'roots',intact.name,broken.name,'modular_shaft',LOWER_MESH.name,UPPER_MESH.name,'fracture_offsets',fracture_offsets,'original_scene_preserved','Scene')
