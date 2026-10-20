import bpy, bmesh, math, os, shutil
from mathutils import Matrix

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'; OUT=ROOT+'/assets/generated/wind_ruins/a03'; PRE=ROOT+'/output/wind_production/a03'
CONCEPT=ROOT+'/output/wind_production/concepts/a03_concept_v1.png'; PROMPT=ROOT+'/output/wind_production/concepts/a03_prompt.txt'
assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT)
assert not os.path.exists(OUT),'Refusing to overwrite existing A03 outputs'
assert bpy.context.scene.name=='WindProduction_A02',bpy.context.scene.name
assert 'Scene' in bpy.data.scenes and all(n in bpy.data.objects for n in ('Cube','Camera','Light'))
os.makedirs(OUT+'/source',exist_ok=False);os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w',encoding='utf-8').close();shutil.copy2(CONCEPT,OUT+'/concept.png');shutil.copy2(PROMPT,PRE+'/concept_prompt.txt')

old=bpy.data.scenes['WindProduction_A02'];scene=bpy.data.scenes.new('WindProduction_A03');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
scene.world=old.world.copy() if old.world else bpy.data.worlds.new('A03_PreviewWorld');scene.world.name='A03_PreviewWorld'
scene.render.engine=old.render.engine;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.render.film_transparent=False
preview=bpy.data.collections.new('A03_Preview_ONLY');export=bpy.data.collections.new('A03_Export');scene.collection.children.link(preview);scene.collection.children.link(export)
for src_name,name in [('A02_PreviewCamera','A03_PreviewCamera'),('A02_Preview_Key','A03_Preview_Key'),('A02_Preview_Fill','A03_Preview_Fill'),('A02_Preview_Rim','A03_Preview_Rim')]:
    src=bpy.data.objects[src_name];ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name=name;preview.objects.link(ob);ob.matrix_world=src.matrix_world.copy()
    if ob.type=='CAMERA':scene.camera=ob
src_rig=bpy.data.objects['A02_PreviewFox_FoxRig'];source_objects=[]
def collect(ob):
    source_objects.append(ob)
    for child in ob.children:collect(child)
collect(src_rig);copies={};world_matrices={ob:ob.matrix_world.copy() for ob in source_objects}
for src in source_objects:
    ob=src.copy()
    if src.data:ob.data=src.data.copy()
    ob.name='A03_PreviewFox_'+src.name.replace('A02_PreviewFox_','');preview.objects.link(ob);copies[src]=ob
for src,ob in copies.items():
    if src.parent in copies:ob.parent=copies[src.parent]
    ob.matrix_world=world_matrices[src]
    for mod in ob.modifiers:
        if mod.type=='ARMATURE' and mod.object in copies:mod.object=copies[mod.object]
fox=copies[src_rig]
if fox.animation_data:fox.animation_data_clear()
if src_rig.animation_data and src_rig.animation_data.action:
    fox.animation_data_create();fox.animation_data.action=src_rig.animation_data.action
fox.location=(0,-.8,0);scene.frame_set(1)

def lin(h):
    q=[int(h[i:i+2],16)/255 for i in (1,3,5)];q=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in q];return tuple(q)+(1,)
palette={'stone':lin('#797A72'),'top':lin('#898A81'),'side':lin('#686A64'),'base':lin('#6D7069'),'fracture':lin('#565851'),'sage':lin('#70786F'),'ground':lin('#777A7B')}
mat=bpy.data.materials.new('A03_Shared_Ruined_Limestone');mat.use_nodes=True
bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Base Color'].default_value=(1,1,1,1);bsdf.inputs['Roughness'].default_value=.92
attr=mat.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color';mat.node_tree.links.new(attr.outputs['Color'],bsdf.inputs['Base Color'])
floor_mat=bpy.data.materials.new('A03_Preview_Ground');floor_mat.use_nodes=True;next(n for n in floor_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=palette['ground']
fm=bpy.data.meshes.new('A03_PreviewGround_Mesh');fm.from_pydata([(-60,-60,-.04),(60,-60,-.04),(60,60,-.04),(-60,60,-.04)],[],[(0,1,2,3)]);fm.materials.append(floor_mat)
floor=bpy.data.objects.new('A03_PreviewGround',fm);preview.objects.link(floor)

def prism(name,profile,depth,tone='stone',cut_edges=()):
    # Closed low-poly extrusion of a broad X/Z silhouette along the depth axis Y.
    n=len(profile);y0=-depth/2;y1=depth/2
    verts=[(x,y0,z) for x,z in profile]+[(x,y1,z) for x,z in profile]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    for i in range(n):j=(i+1)%n;faces.append((i,j,n+j,n+i))
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.materials.append(mat);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.update()
    col=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        no=poly.normal;idx=poly.index-2
        if idx in cut_edges:chosen=palette['fracture']
        elif no.z>.75:chosen=palette['top']
        elif tone=='base' and abs(no.y)>.7:chosen=palette['sage'] if poly.center.x<-1.7 else palette['base']
        elif abs(no.y)>.7:chosen=palette[tone]
        else:chosen=palette['side']
        for li in poly.loop_indices:col.data[li].color=chosen
    ob=bpy.data.objects.new(name,me);export.objects.link(ob);return ob

def root(name):
    ob=bpy.data.objects.new(name,None);ob.empty_display_type='PLAIN_AXES';ob.empty_display_size=.24;export.objects.link(ob);return ob
def attach(ob,parent):
    ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4);ob.location=(0,0,0);return ob

foot_profile=[(-1.97,0),(1.97,0),(2,.03),(2,.09),(1.97,.12),(-1.97,.12),(-2,.09),(-2,.03)]
cap_profile=[(-2,.88),(1.97,.88),(2,.91),(2,.97),(1.97,1),(-1.97,1),(-2,.97),(-2,.91)]
intact=root('A03_Intact')
attach(prism('A03_Intact_Base',foot_profile,.35,'base'),intact)
attach(prism('A03_Intact_Broad_Wall',[(-1.98,.12),(1.98,.12),(1.94,.88),(-1.94,.88)],.27,'stone'),intact)
attach(prism('A03_Intact_Cap',cap_profile,.35,'top'),intact)

# The broken-low variant removes a broad center section of the panel and cap; its base stays continuous.
broken=root('A03_Broken_Low')
attach(prism('A03_Broken_Low_Continuous_Base',foot_profile,.35,'base'),broken)
left_profile=[(-1.98,.12),(-.65,.12),(-.78,.40),(-.56,.62),(-.72,.88),(-1.94,.88)]
right_profile=[(.65,.12),(1.98,.12),(1.94,.88),(.72,.88),(.56,.62),(.78,.40)]
attach(prism('A03_Broken_Left_Panel',left_profile,.27,'stone',(1,2,3)),broken)
attach(prism('A03_Broken_Right_Panel',right_profile,.27,'stone',(3,4,5)),broken)
left_cap=[(-2,.88),(-.72,.88),(-.56,1),(-2,1)]
right_cap=[(.72,.88),(2,.88),(2,1),(.56,1)]
attach(prism('A03_Broken_Left_Cap',left_cap,.35,'top',(1,)),broken)
attach(prism('A03_Broken_Right_Cap',right_cap,.35,'top',(3,)),broken)

# The terminal reuses the same footprint/cap section and tapers one closed end down into a long clean plane.
terminal=root('A03_Terminal_End')
attach(prism('A03_Terminal_Base',foot_profile,.35,'base'),terminal)
terminal_body=[(-1.98,.12),(2,.12),(2,.55),(1.65,.88),(-1.94,.88)]
terminal_cap=[(-2,.88),(1.65,.88),(2,.55),(2,.67),(1.65,1),(-2,1)]
attach(prism('A03_Terminal_Tapered_Wall',terminal_body,.27,'stone'),terminal)
attach(prism('A03_Terminal_Cap',terminal_cap,.35,'top'),terminal)
scene.frame_set(1)
for ob in bpy.context.view_layer.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=intact
print('A03_BUILD_OK',scene.name,'roots',intact.name,broken.name,terminal.name,'components',len(export.objects),'fox_idle',getattr(getattr(fox.animation_data,'action',None),'name',None),'original_scene_preserved',bpy.data.scenes['Scene'].name)
