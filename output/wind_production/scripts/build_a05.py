import bpy, bmesh, math, os, shutil
from mathutils import Matrix, Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG';OUT=ROOT+'/assets/generated/wind_ruins/a05';PRE=ROOT+'/output/wind_production/a05'
CONCEPT=ROOT+'/output/wind_production/concepts/a05_concept_v1.png';PROMPT=ROOT+'/output/wind_production/concepts/a05_prompt.txt'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
assert not os.path.exists(OUT),'Refusing to overwrite existing A05 outputs'
assert bpy.context.scene.name=='WindProduction_A04',bpy.context.scene.name
assert 'Scene' in bpy.data.scenes and all(n in bpy.data.objects for n in ('Cube','Camera','Light'))
os.makedirs(OUT+'/source',exist_ok=False);os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w',encoding='utf-8').close();shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PROMPT,PRE+'/concept_prompt.txt')

old=bpy.data.scenes['WindProduction_A04'];scene=bpy.data.scenes.new('WindProduction_A05');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
scene.world=old.world.copy() if old.world else bpy.data.worlds.new('A05_PreviewWorld');scene.world.name='A05_PreviewWorld'
scene.render.engine=old.render.engine;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.render.film_transparent=False
preview=bpy.data.collections.new('A05_Preview_ONLY');export=bpy.data.collections.new('A05_Export');scene.collection.children.link(preview);scene.collection.children.link(export)
for src_name,name in [('A04_PreviewCamera','A05_PreviewCamera'),('A04_Preview_Key','A05_Preview_Key'),('A04_Preview_Fill','A05_Preview_Fill'),('A04_Preview_Rim','A05_Preview_Rim')]:
    src=bpy.data.objects[src_name];ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name=name;preview.objects.link(ob);ob.matrix_world=src.matrix_world.copy()
    if ob.type=='CAMERA':scene.camera=ob
src_rig=bpy.data.objects['A04_PreviewFox_FoxRig'];src_objects=[]
def collect(ob):
    src_objects.append(ob)
    for child in ob.children:collect(child)
collect(src_rig);copies={};world={ob:ob.matrix_world.copy() for ob in src_objects}
for src in src_objects:
    ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name='A05_PreviewFox_'+src.name.replace('A04_PreviewFox_','');preview.objects.link(ob);copies[src]=ob
for src,ob in copies.items():
    if src.parent in copies:ob.parent=copies[src.parent]
    ob.matrix_world=world[src]
    for mod in ob.modifiers:
        if mod.type=='ARMATURE' and mod.object in copies:mod.object=copies[mod.object]
fox=copies[src_rig]
if fox.animation_data:fox.animation_data_clear()
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create();fox.animation_data.action=src_rig.animation_data.action
fox.scale=(1.404,1.404,1.404);fox.location=(0,-.8,0);scene.frame_set(1)

def lin(h):
    q=[int(h[i:i+2],16)/255 for i in (1,3,5)];q=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in q];return tuple(q)+(1,)
PALETTE={'stone':lin('#526271'),'stone_light':lin('#687A87'),'stone_shadow':lin('#3C4C58'),
         'wood':lin('#654637'),'bronze':lin('#8B7550'),'socket_dark':lin('#34434E'),'ground':lin('#777A7B')}
mat=bpy.data.materials.new('A05_Shared_Slate_Chestnut_Bronze_VertexColor');mat.use_nodes=True
bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Base Color'].default_value=(1,1,1,1);bsdf.inputs['Roughness'].default_value=.84
vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
ground_mat=bpy.data.materials.new('A05_Preview_Neutral_Gray');ground_mat.use_nodes=True
next(n for n in ground_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=lin('#777A7B')
gm=bpy.data.meshes.new('A05_PreviewGround_Mesh');gm.from_pydata([(-60,-60,-.05),(60,-60,-.05),(60,60,-.05),(-60,60,-.05)],[],[(0,1,2,3)]);gm.materials.append(ground_mat)
ground=bpy.data.objects.new('A05_PreviewGround',gm);preview.objects.link(ground)

def color_mesh(me,tone,faceted=False):
    me.update();attr=me.color_attributes.get('Color') or me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        c=PALETTE[tone]
        if faceted:
            if poly.normal.z>.55:c=PALETTE['stone_light']
            elif poly.normal.y<-.6:c=PALETTE['stone_shadow']
            elif poly.index%3==0:c=PALETTE['stone_light']
        for li in poly.loop_indices:attr.data[li].color=c

def mesh_box(name,dims,tone,bevel=0):
    hx,hy,hz=(d/2 for d in dims);verts=[(-hx,-hy,-hz),(hx,-hy,-hz),(hx,hy,-hz),(-hx,hy,-hz),(-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.materials.append(mat);me.update()
    if bevel>0:
        ob=bpy.data.objects.new(name+'_Bevel_Helper',me);export.objects.link(ob)
        mod=ob.modifiers.new('Slim_Broad_Plane_Bevel','BEVEL');mod.width=bevel;mod.segments=1;mod.limit_method='ANGLE';mod.angle_limit=math.radians(25)
        bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);ob.select_set(False)
        me=ob.data;export.objects.unlink(ob);bpy.data.objects.remove(ob,do_unlink=True)
    color_mesh(me,tone);return me

def root(name,parent=None,loc=(0,0,0),rot=(0,0,0)):
    ob=bpy.data.objects.new(name,None);ob.empty_display_type='PLAIN_AXES';ob.empty_display_size=.16;export.objects.link(ob)
    if parent:ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4)
    ob.location=loc;ob.rotation_euler=rot;return ob
def part(name,mesh,parent,loc=(0,0,0),rot=(0,0,0)):
    ob=bpy.data.objects.new(name,mesh);export.objects.link(ob);ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4);ob.location=loc;ob.rotation_euler=rot;return ob

def octagon(hw,hd,cut):
    return [(-hw+cut,-hd),(hw-cut,-hd),(hw,-hd+cut),(hw,hd-cut),(hw-cut,hd),(-hw+cut,hd),(-hw,hd-cut),(-hw,-hd+cut)]
def post_mesh():
    rings=[(0,.15,.125,.048),(.14,.15,.125,.048),(.22,.13,.11,.044),(.61,.13,.11,.044),(.73,.14,.115,.042),(.78,.14,.115,.042)]
    verts=[]
    for z,hw,hd,cut in rings:verts.extend((x,y,z) for x,y in octagon(hw,hd,cut))
    faces=[tuple(reversed(range(8))),tuple(range((len(rings)-1)*8,len(rings)*8))]
    for ring_i in range(len(rings)-1):
        a=ring_i*8;b=(ring_i+1)*8
        for j in range(8):nj=(j+1)%8;faces.append((a+j,a+nj,b+nj,b+j))
    me=bpy.data.meshes.new('A05_Faceted_Post_Body_Shared_Mesh');me.from_pydata(verts,[],faces);bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.materials.append(mat);color_mesh(me,'stone',True);return me
BODY=post_mesh();CAP_STONE=mesh_box('A05_Decorative_Cap_Stone',(.30,.25,.08),'stone_light',.012);CAP_BRONZE=mesh_box('A05_Decorative_Cap_Bronze',(.26,.22,.04),'bronze',.008)
BAR_MESH=mesh_box('A05_Crossbar_Shared_Mesh',(3.4,.16,.14),'wood',.018)
SOCKET_H=mesh_box('A05_Socket_Horizontal_Shared_Mesh',(.18,.04,.025),'bronze',.004)
SOCKET_V=mesh_box('A05_Socket_Vertical_Shared_Mesh',(.025,.04,.18),'bronze',.004)

def post(state,name,x,fallen=False):
    loc=(x,0,.15 if fallen else 0);rot=(0,-math.pi/2,0) if fallen else (0,0,0)
    pr=root(name,state,loc,rot);part(name+'_Broad_Tapered_Stone_Body',BODY,pr)
    cap_group=root(name+'_Decorative_Caps_OPTIONAL',pr)
    part(name+'_Cap_Stone_OPTIONAL',CAP_STONE,cap_group,(0,0,.82))
    part(name+'_Cap_Bronze_Accent_OPTIONAL',CAP_BRONZE,cap_group,(0,0,.88))
    return pr

def socket(state,name,x,z,side):
    # U bracket faces the central opening; it remains as a visible recess without the rail.
    center_x=x+side*.09
    part(name+'_Socket_Lip_Upper',SOCKET_H,state,(center_x,-.105,z+.09))
    part(name+'_Socket_Lip_Lower',SOCKET_H,state,(center_x,-.105,z-.09))
    part(name+'_Socket_Outer_Jamb',SOCKET_V,state,(x+side*.09,-.105,z))

intact=root('A05_Intact')
post(intact,'A05_Intact_Post_Left',-1.85)
post(intact,'A05_Intact_Post_Right',1.85)
socket(intact,'A05_Intact_Socket_Left',-1.70,.62,1)
socket(intact,'A05_Intact_Socket_Right',1.70,.62,-1)
part('A05_Intact_Chestnut_Crossbar',BAR_MESH,intact,(0,0,.62))

missing=root('A05_Missing_Rail')
post(missing,'A05_Missing_Post_Left',-1.85)
post(missing,'A05_Missing_Post_Right',1.85)
socket(missing,'A05_Missing_Socket_Left',-1.70,.62,1)
socket(missing,'A05_Missing_Socket_Right',1.70,.62,-1)

fallen=root('A05_Fallen_Post_Displaced_Rail')
post(fallen,'A05_Fallen_Post_Left',-1.85)
post(fallen,'A05_Fallen_Post_Right',1.85,fallen=True)
socket(fallen,'A05_Fallen_Socket_Left',-1.70,.62,1)
socket(fallen,'A05_Fallen_Socket_At_Post_Base',1.70,.16,-1)
rail_angle=math.atan2(.46,3.4)
part('A05_Fallen_Displaced_Crossbar',BAR_MESH,fallen,(0,0,.39),(0,rail_angle,0))

# Keep a preview-only note with the exact mating and assembly measurements.
loc=bpy.data.objects.new('A05_Source_Assembly_Notes',None);loc.empty_display_type='CUBE';loc.empty_display_size=.10;loc['end_snap_points_x_m']='-2.0,+2.0';loc['crossbar_opening_below_m']=.52;loc['optional_caps']='named *_OPTIONAL and kept in independent cap child nodes';preview.objects.link(loc)
cam=bpy.data.objects['A05_PreviewCamera'];cam.location=(0,-13,6);cam.rotation_euler=(Vector((0,0,.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.lens=35
for name in ('A05_Preview_Key','A05_Preview_Fill','A05_Preview_Rim'):
    light=bpy.data.objects[name];light.data.color=(1,1,1);light.data.energy*=.90
if scene.world and scene.world.use_nodes:next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=.32
scene.render.engine='CYCLES';scene.cycles.samples=18;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX'
for ob in bpy.context.view_layer.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=intact
print('A05_BUILD_OK',scene.name,'roots',intact.name,missing.name,fallen.name,'shared_bar_mesh',BAR_MESH.name,'fox_idle',getattr(getattr(fox.animation_data,'action',None),'name',None),'original_scene_preserved',bpy.data.scenes['Scene'].name)
