import bpy, math
from mathutils import Matrix
assert bpy.context.scene.name=='WindProduction_A04'
scene=bpy.context.scene;export=bpy.data.collections['A04_Export'];mat=bpy.data.materials['A04_Shared_Slate_Bronze_Chestnut_VertexColor']
palette={'edge':(0.0844,0.1441,0.1878,1)}
for ob in list(export.objects):
    if '_Upturned_Eave_Tip_' in ob.name:
        bpy.data.objects.remove(ob,do_unlink=True)
def make_tip(name,center,dims,parent,rot):
    hx,hy,hz=(v/2 for v in dims)
    verts=[(-hx,-hy,-hz),(hx,-hy,-hz),(hx,hy,-hz),(-hx,hy,-hz),(-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.materials.append(mat);me.update()
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        for li in poly.loop_indices:attr.data[li].color=palette['edge']
    ob=bpy.data.objects.new(name,me);export.objects.link(ob);ob.location=center;ob.rotation_euler=rot;ob.parent=parent;ob.matrix_parent_inverse=Matrix.Identity(4);return ob
for root in (bpy.data.objects['A04_Intact'],bpy.data.objects['A04_Damaged_Corner']):
    damaged=root.name.endswith('Corner')
    for sy in (-1,1):
        for sx in (-1,1):
            if damaged and (sx,sy)==(1,-1):continue
            ob=make_tip(f'{root.name}_Upturned_Eave_Tip_{sx:+d}_{sy:+d}',
                        (sx*2.68,sy*1.92,.463+.075),(.60,.14,.14),root,(0,-sx*.20,0))
            if sy<0:
                front_name='A04_Damaged_Front_Removable_Panel' if damaged else 'A04_Intact_Front_Removable_Panel'
                ob.parent=bpy.data.objects[front_name];ob.matrix_parent_inverse=Matrix.Identity(4)
for name in ('A04_Preview_Key','A04_Preview_Fill','A04_Preview_Rim'):
    light=bpy.data.objects[name];light.data.energy*=.56;light.data.color=(1.0,1.0,1.0)
if scene.world and scene.world.use_nodes:
    bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Strength'].default_value=.28
bpy.context.view_layer.update()
def root_bounds(root):
    pts=[];inv=root.matrix_world.inverted()
    for ob in root.children_recursive:
        if ob.type=='MESH':pts.extend(inv@(ob.matrix_world@v.co) for v in ob.data.vertices)
    return [round(min(p[i] for p in pts),6) for i in range(3)],[round(max(p[i] for p in pts),6) for i in range(3)]
print('A04_REPAIR_COMPLETE',{'intact':root_bounds(bpy.data.objects['A04_Intact']),'damaged':root_bounds(bpy.data.objects['A04_Damaged_Corner']),'upturned_tips':sum(1 for o in export.objects if '_Upturned_Eave_Tip_' in o.name),'light_energies':{n:bpy.data.objects[n].data.energy for n in ('A04_Preview_Key','A04_Preview_Fill','A04_Preview_Rim')}})
