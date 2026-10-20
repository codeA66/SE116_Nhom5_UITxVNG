import bpy, bmesh, math, os, shutil
from mathutils import Matrix, Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/i01'
PRE=ROOT+'/output/wind_production/i01'
CONCEPT=ROOT+'/output/wind_production/concepts/i01_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/i01_prompt.txt'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
assert os.path.isdir(OUT+'/source') and os.path.isfile(OUT+'/source/.gdignore')
assert not os.path.exists(OUT+'/i01_modular_bridge_span.glb')
assert bpy.context.scene.name=='WindProduction_A05', bpy.context.scene.name
assert 'Scene' in bpy.data.scenes and all(n in bpy.data.objects for n in ('Cube','Camera','Light'))
os.makedirs(PRE,exist_ok=True)

previous=bpy.context.scene
scene=bpy.data.scenes.new('WindProduction_I01');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
scene.world=previous.world.copy() if previous.world else bpy.data.worlds.new('I01_PreviewWorld');scene.world.name='I01_PreviewWorld'
scene.render.engine=previous.render.engine;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.render.film_transparent=False
preview=bpy.data.collections.new('I01_Preview_ONLY');export=bpy.data.collections.new('I01_Export')
scene.collection.children.link(preview);scene.collection.children.link(export)

for src_name,name in [('A05_PreviewCamera','I01_PreviewCamera'),('A05_Preview_Key','I01_Preview_Key'),('A05_Preview_Fill','I01_Preview_Fill'),('A05_Preview_Rim','I01_Preview_Rim')]:
    src=bpy.data.objects[src_name];ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name=name;preview.objects.link(ob);ob.matrix_world=src.matrix_world.copy()
    if ob.type=='CAMERA':scene.camera=ob
src_rig=bpy.data.objects['A05_PreviewFox_FoxRig'];src_objects=[]
def collect(ob):
    src_objects.append(ob)
    for child in ob.children:collect(child)
collect(src_rig);copies={};world={ob:ob.matrix_world.copy() for ob in src_objects}
for src in src_objects:
    ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name='I01_PreviewFox_'+src.name.replace('A05_PreviewFox_','');preview.objects.link(ob);copies[src]=ob
for src,ob in copies.items():
    if src.parent in copies:ob.parent=copies[src.parent]
    ob.matrix_world=world[src]
    for mod in ob.modifiers:
        if mod.type=='ARMATURE' and mod.object in copies:mod.object=copies[mod.object]
fox=copies[src_rig]
if fox.animation_data:fox.animation_data_clear()
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create();fox.animation_data.action=src_rig.animation_data.action
fox.scale=(1.404,1.404,1.404);fox.location=(0,-1.0,0);scene.frame_set(1)

def linear(h):
    vals=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    vals=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals]
    return tuple(vals)+(1,)
COLORS={'stone':linear('#526271'),'stone_light':linear('#687A87'),'stone_dark':linear('#3C4C58'),
        'wood':linear('#654637'),'wood_light':linear('#785442'),'bronze':linear('#8B7550'),
        'ground':linear('#777A7B')}
mat=bpy.data.materials.new('I01_Shared_Bluegray_Stone_Chestnut_VertexColor');mat.use_nodes=True
bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Base Color'].default_value=(1,1,1,1);bsdf.inputs['Roughness'].default_value=.84
vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
ground_mat=bpy.data.materials.new('I01_Preview_Neutral_Gray');ground_mat.use_nodes=True
next(n for n in ground_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=COLORS['ground']
gm=bpy.data.meshes.new('I01_PreviewGround_Mesh');gm.from_pydata([(-60,-60,-.05),(60,-60,-.05),(60,60,-.05),(-60,60,-.05)],[],[(0,1,2,3)]);gm.materials.append(ground_mat)
ground=bpy.data.objects.new('I01_PreviewGround',gm);preview.objects.link(ground)

def color_mesh(me,tone,fracture=False):
    me.update();attr=me.color_attributes.get('Color') or me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        c=COLORS[tone]
        if tone.startswith('stone'):
            if poly.normal.z>.70:c=COLORS['stone_light']
            elif fracture and abs(poly.normal.x)>.48:c=COLORS['stone_dark']
            elif poly.index%5==0:c=COLORS['stone_light']
        elif tone=='wood' and poly.index%4==0:c=COLORS['wood_light']
        for li in poly.loop_indices:attr.data[li].color=c

def box_mesh(name,dims,tone,bevel=0.0):
    hx,hy,hz=(d/2 for d in dims)
    verts=[(-hx,-hy,-hz),(hx,-hy,-hz),(hx,hy,-hz),(-hx,hy,-hz),(-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.materials.append(mat);me.update()
    if bevel>0:
        ob=bpy.data.objects.new(name+'_Bevel_Helper',me);export.objects.link(ob)
        mod=ob.modifiers.new('Slim_Broad_Edge_Bevel','BEVEL');mod.width=bevel;mod.segments=1;mod.limit_method='ANGLE';mod.angle_limit=math.radians(25)
        bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);ob.select_set(False)
        me=ob.data;export.objects.unlink(ob);bpy.data.objects.remove(ob,do_unlink=True)
    color_mesh(me,tone);return me

def root(name):
    ob=bpy.data.objects.new(name,None);ob.empty_display_type='PLAIN_AXES';ob.empty_display_size=.22;export.objects.link(ob);return ob
def part(name,mesh,parent,loc=(0,0,0)):
    ob=bpy.data.objects.new(name,mesh);export.objects.link(ob);ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4);ob.location=loc;return ob

def clip(poly,fn):
    out=[]
    if not poly:return out
    for a,b in zip(poly,poly[1:]+poly[:1]):
        fa,fb=fn(a),fn(b);ina, inb=fa<=1e-9,fb<=1e-9
        if ina:out.append(a)
        if ina!=inb:
            t=fa/(fa-fb);out.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
    return out

def cut_polygon(xmin,xmax,ymin,ymax,slope,offset,side,half_gap):
    rect=[(xmin,ymin),(xmax,ymin),(xmax,ymax),(xmin,ymax)]
    if side=='left':
        return clip(rect,lambda p:p[0]-slope*p[1]-offset+half_gap)
    return clip(rect,lambda p:-p[0]+slope*p[1]+offset+half_gap)

def prism_split_mesh(name,dims,center_y,z0,z1,slope,offset,tone,gap=.14):
    length,width=dims[0],dims[1];xmin,xmax=-length/2,length/2;ymin=center_y-width/2;ymax=center_y+width/2
    me=bpy.data.meshes.new(name+'_Mesh');verts=[];faces=[]
    for side in ('left','right'):
        # Unequal top/bottom cut offsets make two broad, slanted fracture planes.
        shrink=.028
        top_gap=gap/2;bottom_gap=max(.015,gap/2-shrink)
        bottom=cut_polygon(xmin,xmax,ymin,ymax,slope,offset,side,bottom_gap)
        top=cut_polygon(xmin,xmax,ymin,ymax,slope,offset,side,top_gap)
        if len(bottom)<3 or len(bottom)!=len(top):continue
        start=len(verts);count=len(bottom)
        verts.extend((x,y,z0) for x,y in bottom);verts.extend((x,y,z1) for x,y in top)
        faces.append(tuple(reversed(range(start,start+count))))
        faces.append(tuple(range(start+count,start+2*count)))
        for i in range(count):
            j=(i+1)%count;faces.append((start+i,start+j,start+count+j,start+count+i))
    me.from_pydata(verts,[],faces);bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.materials.append(mat);color_mesh(me,tone,fracture=True);return me

slab_y=1.11; slab_centers=(-1.695,-.565,.565,1.695)
assert abs(4*slab_y+3*.02-4.5)<1e-9
deck_mesh=box_mesh('I01_Deck_Slab_Shared_Mesh',(4.0,slab_y,.19),'stone',0.0)
beam_mesh=box_mesh('I01_Underside_Beam_Shared_Mesh',(4.0,.30,.25),'wood',.016)
intact=root('I01_Intact')
for i,y in enumerate(slab_centers,1):part(f'I01_Intact_Broad_Deck_Slab_{i:02d}',deck_mesh,intact,(0,y,.355))
for i,y in enumerate((-1.70,0,1.70),1):part(f'I01_Intact_Chestnut_Underside_Beam_{i:02d}',beam_mesh,intact,(0,y,.125))

broken=root('I01_Diagonal_Break')
for i,y in enumerate(slab_centers,1):
    slope=.32 if i<=2 else .36
    offset=(i-2.5)*.018
    me=prism_split_mesh(f'I01_Broken_Deck_Slab_{i:02d}',(4.0,slab_y),y,.26,.45,slope,offset,'stone',.14)
    part(f'I01_Broken_Deck_Slab_{i:02d}_Matching_Fragments',me,broken)
for i,y in enumerate((-1.70,0,1.70),1):
    me=prism_split_mesh(f'I01_Broken_Underside_Beam_{i:02d}',(4.0,.30),y,0,.25,.34,0,'wood',.12)
    part(f'I01_Broken_Underside_Beam_{i:02d}_Matching_Fragments',me,broken)

# Removable notes stay in the preview-only collection and never enter the GLB.
notes=bpy.data.objects.new('I01_Module_Assembly_Notes',None);notes.empty_display_type='CUBE';notes['module_end_connectors']='flat, full-section X=-2m and X=+2m';notes['walking_width_axis']='Blender Y maps to Godot Z';notes['deck_slab_count']=4;preview.objects.link(notes)
camera=bpy.data.objects['I01_PreviewCamera'];camera.location=(0,-16,8);camera.rotation_euler=(Vector((0,0,.36))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='PERSP';camera.data.lens=40
for name in ('I01_Preview_Key','I01_Preview_Fill','I01_Preview_Rim'):
    light=bpy.data.objects[name];light.data.color=(1,1,1);light.data.energy*=.92
if scene.world and scene.world.use_nodes:next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=.32
scene.render.engine='CYCLES';scene.cycles.samples=18;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX'
for ob in bpy.context.view_layer.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=intact
print('I01_BUILD_OK',scene.name,'roots',intact.name,broken.name,'four_deck_slabs',len(slab_centers),'underside_beams',3,'palette',COLORS,'original_scene_preserved','Scene')
