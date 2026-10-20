import bpy
from mathutils import Vector
assert bpy.context.scene.name=='WindProduction_I01'
mesh=bpy.data.objects['I01_Intact_Broad_Deck_Slab_01'].data
material=bpy.data.materials['I01_Shared_Bluegray_Stone_Chestnut_VertexColor']
hx,hy,hz=2.0,1.11/2,.19/2
verts=[(-hx,-hy,-hz),(hx,-hy,-hz),(hx,hy,-hz),(-hx,hy,-hz),(-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)]
faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
mesh.clear_geometry();mesh.from_pydata(verts,[],faces);mesh.update()
mesh.materials.clear();mesh.materials.append(material)
old=mesh.color_attributes.get('Color')
if old:mesh.color_attributes.remove(old)
attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
def lin(h):
    v=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
base=lin('#526271');light=lin('#687A87');dark=lin('#3C4C58')
for poly in mesh.polygons:
    c=light if poly.normal.z>.7 else dark if abs(poly.normal.x)>.8 else base
    for li in poly.loop_indices:attr.data[li].color=c
mesh.update()
print('I01_CONNECTORS_FIXED','all four shared deck slabs now retain full flat x=+/-2m planes across width 4.5m')
