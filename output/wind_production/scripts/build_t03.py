import bpy, math
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'

def lin(hex_color):
    rgb=[int(hex_color[i:i+2],16)/255.0 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1.0,)

COLORS={
 'plate_a':lin('#666763'),'plate_b':lin('#6D6E69'),'plate_c':lin('#696A65'),'plate_d':lin('#70716C'),
 'frame':lin('#5B5C58'),'joint':lin('#4F504C'),'sealed_mark':lin('#464743'),
 'side_south':lin('#4F504C'),'side_east':lin('#5A5B57'),'side_north':lin('#555652'),'side_west':lin('#4A4B47'),
 'bevel':lin('#71726C'),'bottom':lin('#434440'),'chip':lin('#747570')
}

CUTS=[-1.97,-1.82,-0.015,0.015,1.82,1.97]

def stone_material():
    mat=bpy.data.materials.new('T03_Stone_SharedPalette');mat.use_nodes=True;mat.diffuse_color=lin('#666763')
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=(1,1,1,1);bsdf.inputs['Roughness'].default_value=.9
    attr=mat.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color'
    mat.node_tree.links.new(attr.outputs['Color'],bsdf.inputs['Base Color'])
    return mat

def preview_setup(scene):
    col=bpy.data.collections.new('T03_Preview_ONLY');scene.collection.children.link(col)
    for src_name,new_name in [('F01_PreviewCamera','T03_PreviewCamera'),('Preview_Key','T03_Preview_Key'),('Preview_Fill','T03_Preview_Fill'),('Preview_Rim','T03_Preview_Rim')]:
        src=bpy.data.objects[src_name];obj=src.copy();obj.data=src.data.copy();obj.name=new_name;col.objects.link(obj)
    def link_fox(obj):
        if obj.name not in ('Icosphere','Sword') and obj.name not in col.objects: col.objects.link(obj)
        for child in obj.children: link_fox(child)
    link_fox(bpy.data.objects['FoxRig'])
    floor_mat=bpy.data.materials.get('T03_Preview_Ground') or bpy.data.materials.new('T03_Preview_Ground')
    floor_mat.use_nodes=True;floor_mat.diffuse_color=lin('#777A7B')
    bsdf=next(n for n in floor_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=lin('#777A7B');bsdf.inputs['Roughness'].default_value=.94
    me=bpy.data.meshes.new('T03_PreviewFloor_Mesh');me.from_pydata([(-250,-250,0),(250,-250,0),(250,250,0),(-250,250,0)],[],[(0,1,2,3)]);me.materials.append(floor_mat)
    floor=bpy.data.objects.new('T03_PreviewFloor',me);col.objects.link(floor)
    world=bpy.data.worlds.get('WindPreviewWorld').copy();world.name='T03_PreviewWorld';scene.world=world
    scene.camera=bpy.data.objects['T03_PreviewCamera']
    return col

def root(collection,name,location,description):
    obj=bpy.data.objects.new(name,None);collection.objects.link(obj);obj.location=location;obj.empty_display_type='PLAIN_AXES'
    obj['pivot']='center of flat walking face; local z=0; slab extends down 0.30 m'
    obj['design']=description
    return obj

def outer_loop():
    p=[]
    for x in CUTS: p.append((x,-1.97))
    for y in CUTS[1:]: p.append((1.97,y))
    for x in reversed(CUTS[:-1]): p.append((x,1.97))
    for y in reversed(CUTS[1:-1]): p.append((-1.97,y))
    return p

def clip_half(poly,nx,ny,limit):
    if not poly:return []
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=a[0]*nx+a[1]*ny-limit;db=b[0]*nx+b[1]*ny-limit
        ina=da<=1e-8;inb=db<=1e-8
        if ina: result.append(a)
        if ina!=inb:
            t=da/(da-db)
            result.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
    return result

def clipped_seal(rect):
    # A painted/flush diagonal mark, represented by coplanar polygons—not a gap or slit.
    a=(-1.68,-1.59);b=(-.18,-.16);dx=b[0]-a[0];dy=b[1]-a[1];length=math.sqrt(dx*dx+dy*dy)
    nx=-dy/length;ny=dx/length;half=.035
    def signed(p):return (p[0]-a[0])*nx+(p[1]-a[1])*ny
    left=clip_half(rect,nx,ny,signed(a)-half)
    right=clip_half(rect,-nx,-ny,-signed(a)-half)
    band=clip_half(clip_half(rect,nx,ny,signed(a)+half),-nx,-ny,-signed(a)+half)
    return [(left,'plate_a'),(right,'plate_a'),(band,'sealed_mark')]

def build_tile(collection,name,mat,parent,variant):
    vertices=[];faces=[];keys=[];cache={}
    def vindex(x,y,z):
        key=(round(x,7),round(y,7),round(z,7))
        if key not in cache:
            cache[key]=len(vertices);vertices.append((x,y,z))
        return cache[key]
    def face3(points,key):
        ids=[vindex(x,y,z) for x,y,z in points]
        if len(set(ids))>=3: faces.append(tuple(ids));keys.append(key)
    # One continuous closed side shell with narrow edge bevels; all thickness lies below z=0.
    loop=outer_loop();N=len(loop)
    scales=[1.0,2.0/1.97,2.0/1.97,2.0/1.97,1.0]
    zs=[-.30,-.265,-.15,-.04,0.0]
    rings=[]
    for ri,(scale,z) in enumerate(zip(scales,zs)):
        ring=[]
        for i,(x,y) in enumerate(loop):
            xx=x*scale;yy=y*scale
            if variant=='chip' and ri==2 and i==5:
                # One shallow side-face bite at the exposed front-right corner. The top and base stay supported.
                xx-=.18;yy+=.18
            ring.append((xx,yy,z))
        rings.append(ring)
    face3(list(reversed(rings[0])),'bottom')
    for ri in range(len(rings)-1):
        low=rings[ri];high=rings[ri+1]
        for i in range(N):
            color=('side_south','side_east','side_north','side_west')[min(i//5,3)]
            if variant=='chip' and ri in (1,2) and i in (4,5): color='chip'
            if ri in (0,3): color='bevel'
            face3([low[i],low[(i+1)%N],high[(i+1)%N],high[i]],color)
    # Tiled, perfectly planar top: coplanar perimeter band, four broad plate faces, flush cross-joints.
    # Collect top polygons first so clipped seal boundaries can split adjacent faces at matching
    # vertices; this avoids T-junctions while keeping the diagonal painted and fully flush.
    top_polys=[]
    for iy in range(5):
        for ix in range(5):
            x0,x1=CUTS[ix],CUTS[ix+1];y0,y1=CUTS[iy],CUTS[iy+1]
            rect=[(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
            if ix in (0,4) or iy in (0,4): pieces=[(rect,'frame')]
            elif ix==2 or iy==2: pieces=[(rect,'joint')]
            elif variant=='seal' and ix==1 and iy==1: pieces=clipped_seal(rect)
            else:
                plate={ (1,1):'plate_a',(3,1):'plate_b',(1,3):'plate_c',(3,3):'plate_d' }[(ix,iy)]
                pieces=[(rect,plate)]
            for poly,key in pieces:
                if len(poly)>=3: top_polys.append((poly,key))
    point_map={}
    for poly,_ in top_polys:
        for x,y in poly: point_map[(round(x,7),round(y,7))]=(x,y)
    all_points=list(point_map.values())
    for poly,key in top_polys:
        refined=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            refined.append(a)
            dx=b[0]-a[0];dy=b[1]-a[1];length2=dx*dx+dy*dy
            if length2<=1e-16: continue
            inserts=[]
            for p in all_points:
                t=((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length2
                if 1e-7<t<1.0-1e-7:
                    distance=abs((p[0]-a[0])*dy-(p[1]-a[1])*dx)/math.sqrt(length2)
                    if distance<=1e-7: inserts.append((t,p))
            refined.extend(p for _,p in sorted(inserts,key=lambda item:item[0]))
        face3([(x,y,0.0) for x,y in refined],key)
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(vertices,[],faces);me.update();me.materials.append(mat)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,key in zip(me.polygons,keys):
        for li in poly.loop_indices: attr.data[li].color=COLORS[key]
    me.calc_loop_triangles()
    obj=bpy.data.objects.new(name,me);collection.objects.link(obj);obj.parent=parent;obj['state']=variant;obj['thickness_m']=.30;obj['connector_extents_xy_m']='[-2,+2] on both axes'
    return obj

# Rebuild only this generated scene when iterating; preserve the original/default and earlier assets.
previous=bpy.data.scenes.get('WindProduction_T03')
if previous:
    fallback=bpy.data.scenes.get('WindProduction_T01') or bpy.data.scenes.get('Scene')
    if fallback:bpy.context.window.scene=fallback
    for obj in list(previous.objects):
        if obj.name.startswith('T03_'): bpy.data.objects.remove(obj,do_unlink=True)
    for col in list(previous.collection.children):
        if col.name in ('T03_Export','T03_Preview_ONLY'):
            previous.collection.children.unlink(col);bpy.data.collections.remove(col)
    oldworld=previous.world;bpy.data.scenes.remove(previous,do_unlink=True)
    if oldworld and oldworld.name=='T03_PreviewWorld' and oldworld.users==0:bpy.data.worlds.remove(oldworld)
    oldmat=bpy.data.materials.get('T03_Stone_SharedPalette')
    if oldmat and oldmat.users==0:bpy.data.materials.remove(oldmat)
    for me in list(bpy.data.meshes):
        if me.name.startswith('T03_') and me.users==0:bpy.data.meshes.remove(me)
old_scene=bpy.context.scene
scene=bpy.data.scenes.new('WindProduction_T03');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
preview_setup(scene)
asset=bpy.data.collections.new('T03_Export');scene.collection.children.link(asset);stone=stone_material()
intact=root(asset,'T03_Intact_Slab',(-6.2,0,.30),'4 x 4 x 0.30 m floor module; four fitted plate panels and a 0.15 m coplanar perimeter band.')
sealed=root(asset,'T03_Sealed_Crack',(-1.1,0,.30),'Same supported flat surface and connector lines; one broad flush diagonal mark, not a physical gap.')
chipped=root(asset,'T03_Chipped_Edge',(6.1,0,.30),'Same full walking surface and connector envelope; one shallow bite on the exposed side edge.')
build_tile(asset,'T03_Intact_Mesh',stone,intact,'intact')
build_tile(asset,'T03_Sealed_Crack_Mesh',stone,sealed,'seal')
build_tile(asset,'T03_Chipped_Edge_Mesh',stone,chipped,'chip')
print('T03_CREATED',scene.name,'states',3,'mesh_parts',sum(o.type=='MESH' for o in asset.objects),'triangles',sum(len(o.data.loop_triangles) for o in asset.objects if o.type=='MESH'),'default_scene_preserved',bpy.data.scenes.get('Scene') is not None)
