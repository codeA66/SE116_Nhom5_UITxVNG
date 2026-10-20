import bpy, math, json, os
from mathutils import Vector
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/f01'
PRE=ROOT+'/output/wind_production/f01'
os.makedirs(OUT+'/source',exist_ok=True)
os.makedirs(PRE,exist_ok=True)
open(OUT+'/source/.gdignore','w').close()
old_scene=bpy.context.scene
scene=bpy.data.scenes.new('WindProduction_F01')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0
asset=bpy.data.collections.new('F01_Export')
scene.collection.children.link(asset)
preview=bpy.data.collections.new('F01_Preview_ONLY')
scene.collection.children.link(preview)
def linear(x): return x/12.92 if x<=0.04045 else ((x+0.055)/1.055)**2.4
def rgb(s): return tuple(linear(int(s[i:i+2],16)/255) for i in (1,3,5))+(1,)
COL={'wood':rgb('#524C43'),'metal':rgb('#363C3D'),'stone':rgb('#767773'),'cloth':rgb('#E8E7DF'),'emblem':rgb('#4D565C')}
mat=bpy.data.materials.new('F01_Palette_VertexColor')
mat.use_nodes=True
mat.use_backface_culling=False
bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
bs.inputs['Roughness'].default_value=.86
attr=mat.node_tree.nodes.new('ShaderNodeVertexColor')
attr.layer_name='Color'
mat.node_tree.links.new(attr.outputs['Color'],bs.inputs['Base Color'])
root=bpy.data.objects.new('F01_WindMainBanner',None)
asset.objects.link(root)
root['dimensions_design_m']='pole4.8; cloth1.2x2.4; top4.3 bottom1.9; crossbar1.55'
root['front']='Godot +Z / Blender -Y'
root['concept_approved']='f01_concept_v2.png'
parts=[]
def mesh(name,vs,fs,color,uv=False):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(vs,[],fs); me.update()
    ob=bpy.data.objects.new(name,me); asset.objects.link(ob); ob.parent=root
    me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for i in range(len(me.loops)): ca.data[i].color=COL[color]
    if uv:
        tex=me.uv_layers.new(name='WindUV_TopAnchorU0')
        for p in me.polygons:
            for li in p.loop_indices:
                co=me.vertices[me.loops[li].vertex_index].co
                tex.data[li].uv=((4.3-co.z)/2.4,(co.x+.6)/1.2)
    parts.append(ob); return ob
def ringmesh(name,rings,color,n=8):
    vs=[]
    for z,rx,ry,cx,cy in rings:
        for i in range(n):
            a=(i+.5)*2*math.pi/n;vs.append((cx+rx*math.cos(a),cy+ry*math.sin(a),z))
    fs=[tuple(reversed(range(n)))]
    for k in range(len(rings)-1):
        for i in range(n):fs.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
    fs.append(tuple((len(rings)-1)*n+i for i in range(n)))
    return mesh(name,vs,fs,color)
def box(name,dim,loc,color,bevel=0):
    x,y,z=[v/2 for v in dim];cx,cy,cz=loc
    vs=[(cx+a*x,cy+b*y,cz+c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    ob=mesh(name,vs,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],color)
    if bevel:
        bpy.context.view_layer.objects.active=ob;ob.select_set(True)
        mod=ob.modifiers.new('Broad edge chamfer','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name);ob.select_set(False)
    return ob
box('Foot_Stone',(0.55,.55,.25),(0,0,.125),'stone',.045)
ringmesh('Pole_Octagonal',[(.25,.105,.105,0,0),(4.8,.065,.065,0,0)],'wood')
ringmesh('Foot_Collar',[(.25,.126,.126,0,0),(.32,.126,.126,0,0),(.34,.108,.108,0,0)],'metal')
ringmesh('Upper_Collar',[(4.28,.087,.087,0,0),(4.39,.087,.087,0,0)],'metal')
box('Crossbar',(1.55,.09,.095),(0,0,4.3),'wood',.012)
for sign in [-1,1]:box('Crossbar_End_'+str(sign),(.065,.115,.125),(sign*.7425,0,4.3),'metal',.008)
# Broad billow; all deformation is part of the rest mesh and remains separate from pole.
def depth(x,z):
    t=(4.3-z)/2.4; q=(x+.6)/1.2
    return -.13+.16*t*t+.095*math.sin(q*2*math.pi+.3)*t+.045*math.sin(q*4*math.pi)*t
vs=[];fs=[];nx=16;nz=24
for j in range(nz+1):
    t=j/nz
    for i in range(nx+1):
        x=-.6+1.2*i/nx; bottom=1.9+.20*(1-abs(x)/.6)
        z=4.3+(bottom-4.3)*t;vs.append((x,depth(x,z),z))
for j in range(nz):
    for i in range(nx):
        a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
cloth=mesh('Cloth_Wind_Animated',vs,fs,'cloth',True)
cloth['uv_anchor']='UV.u=0 at crossbar; u=1 lowest free edge; top horizontal fixed'
cloth['wind_sweep_clearance_m']=.8
# Mark is geometry using same shared vertex color material, on both faces of the cloth.
ev=[];ef=[]
def strip(points,widths,side):
    start=len(ev)
    for k,(x,z) in enumerate(points):
        a=points[max(0,k-1)]; b=points[min(len(points)-1,k+1)]
        dx=b[0]-a[0]; dz=b[1]-a[1];l=math.hypot(dx,dz)
        for s in [-1,1]:
            xx=x+s*(-dz/l)*widths[k]/2;zz=z+s*(dx/l)*widths[k]/2
            ev.append((xx,depth(xx,zz)+side*.004,zz))
    for k in range(len(points)-1):ef.append((start+2*k,start+2*k+1,start+2*k+3,start+2*k+2))
for side in [-1,1]:
    pts=[(.365*math.cos(math.radians(28+304*k/64)),3.57+.365*math.sin(math.radians(28+304*k/64))) for k in range(65)]
    strip(pts,[.12]*65,side)
    for row in [-1,0,1]:
        pts=[]; widths=[]
        for k in range(17):
            t=k/16;x=-.245+.49*t; z=3.57+row*.18+.057*math.sin((t-.5)*math.pi*1.5)
            pts.append((x,z));widths.append(.016+.092*math.sin(math.pi*t)**.55)
        strip(pts,widths,side)
emblem=mesh('Cloth_Emblem',ev,ef,'emblem',True)
# Join emblem to cloth, retaining one animated object and one material.
bpy.ops.object.select_all(action='DESELECT');cloth.select_set(True);emblem.select_set(True);bpy.context.view_layer.objects.active=cloth;bpy.ops.object.join()
parts.remove(emblem)
# Cloth has static top-edge weight to support later deformation integration.
group=cloth.vertex_groups.new(name='Anchor_Top')
for v in cloth.data.vertices:
    if v.co.z>4.28:group.add([v.index],1,'REPLACE')
# Source retains all original scene data; no existing object is removed or changed.
print('CREATED',len(parts),'asset objects in isolated scene',scene.name)
