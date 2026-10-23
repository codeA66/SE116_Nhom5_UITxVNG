"""Run only through the connected Blender MCP. Non-destructive palace asset production."""
raise RuntimeError('DISABLED AFTER CRASH: do not replay this batch. Blender 5.2 crashed in bpy.data.libraries.write(Scene). Resume one asset at a time with a separately validated save path.')
import bpy, math, json, os
from mathutils import Vector
from mathutils.geometry import tessellate_polygon
from pathlib import Path

PROJECT = Path('C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
DEST = PROJECT / 'assets/generated/wind_ruins/palace'
BACKUP = Path('C:/Code/UITxVNG/blend_backup/wind_palace')
WORK = PROJECT / 'output/wind_palace_production'
VERSION = 'v01'
for p in (DEST, BACKUP, WORK): p.mkdir(parents=True, exist_ok=True)
if bpy.data.scenes.get('WindPalace_Production_v01'):
    raise RuntimeError('Production scene already exists. Resume from manifest; do not recreate assets.')

scene = bpy.data.scenes.new('WindPalace_Production_v01')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1

def linear(v): return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
def rgb(h): return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4)) + (1,)
C = {k:rgb(v) for k,v in dict(stone='D7D2B6',light='E2DEC9',edge='B8B49F',dark='173F49',teal='426E70',jade='55958B',gold='AD8D50',wood='655548',paper='C6BE9D',shadow='555B79',mint='B8E6CD').items()}
mat = bpy.data.materials.new('WP_VertexColor_Matte_v01')
mat.use_nodes = True
n = mat.node_tree.nodes
bsdf = next(x for x in n if x.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Roughness'].default_value = 0.92
attr = n.new('ShaderNodeVertexColor'); attr.layer_name = 'Color'
mat.node_tree.links.new(attr.outputs['Color'],bsdf.inputs['Base Color'])
mat.diffuse_color = C['stone']
glow = bpy.data.materials.new('WP_VertexColor_Energy_v01'); glow.use_nodes=True
gb=next(x for x in glow.node_tree.nodes if x.type=='BSDF_PRINCIPLED')
ga=glow.node_tree.nodes.new('ShaderNodeVertexColor');ga.layer_name='Color'
glow.node_tree.links.new(ga.outputs['Color'],gb.inputs['Base Color'])
glow.node_tree.links.new(ga.outputs['Color'],gb.inputs['Emission Color'])
gb.inputs['Emission Strength'].default_value=0.65;gb.inputs['Roughness'].default_value=0.85

class Geo:
    def __init__(self): self.v=[];self.f=[];self.c=[]
    def face(self,points,color):
        base=len(self.v); self.v.extend(tuple(p) for p in points)
        # Explicit triangulation: files contain no n-gons.
        for tri in tessellate_polygon([[Vector(p) for p in points]]):
            ids=[]
            for q in tri:
                ids.append(base+(q if isinstance(q,int) else min(range(len(points)), key=lambda j:(Vector(points[j])-q).length_squared)))
            self.f.append(ids);self.c.append(C[color] if isinstance(color,str) else color)
    def box(self,center,size,color='stone',angle=0):
        x,y,z=center; a,b,c=[d/2 for d in size];cs,sn=math.cos(angle),math.sin(angle)
        p=[]
        for u,v,w in [(-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]:
            p.append((x+u*cs-v*sn,y+u*sn+v*cs,z+w))
        for ids in [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]: self.face([p[i] for i in ids],color)
    def prism(self,points,depth,color='stone',y=0):
        # Points in x,z. Positive polygon orientation gives a front normal toward -Y.
        pts=list(points)
        area=sum(pts[i][0]*pts[(i+1)%len(pts)][1]-pts[(i+1)%len(pts)][0]*pts[i][1] for i in range(len(pts)))
        if area<0: pts.reverse()
        front=[(x,y-depth/2,z) for x,z in pts]; back=[(x,y+depth/2,z) for x,z in pts]
        self.face(front,color);self.face(back[::-1],color)
        for i in range(len(pts)):
            j=(i+1)%len(pts);self.face([front[i],back[i],back[j],front[j]],color)
    def column(self,center,r0,r1,height,color='stone',sides=8,phase=math.pi/8):
        x,y,z=center
        a=[(x+r0*math.cos(phase+2*math.pi*i/sides),y+r0*math.sin(phase+2*math.pi*i/sides),z) for i in range(sides)]
        b=[(x+r1*math.cos(phase+2*math.pi*i/sides),y+r1*math.sin(phase+2*math.pi*i/sides),z+height) for i in range(sides)]
        self.face(a[::-1],color);self.face(b,color)
        for i in range(sides):j=(i+1)%sides;self.face([a[i],a[j],b[j],b[i]],color)
    def beam(self,a,b,width,color='wood'):
        d=Vector(b)-Vector(a);d.normalize()
        u=d.cross(Vector((0,0,1)))
        if u.length<.01:u=d.cross(Vector((0,1,0)))
        u.normalize();u*=width/2;v=d.cross(u);v.normalize();v*=width/2
        pa=[Vector(a)+u+v,Vector(a)-u+v,Vector(a)-u-v,Vector(a)+u-v]
        pb=[p+Vector(b)-Vector(a) for p in pa]
        self.face(pa[::-1],color);self.face(pb,color)
        for i in range(4): j=(i+1)%4;self.face([pa[i],pa[j],pb[j],pb[i]],color)
    def object(self,name,collection,emission=False):
        mesh=bpy.data.meshes.new(name+'_Mesh');mesh.from_pydata(self.v,[],self.f);mesh.update()
        colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for poly,col in zip(mesh.polygons,self.c):
            for li in poly.loop_indices: colors.data[li].color=col
        mesh.materials.append(glow if emission else mat)
        obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj)
        return obj

assets=[]
def asset(code,label,category='architecture',notes=''):
    col=bpy.data.collections.new(code+'_'+label);scene.collection.children.link(col)
    root=bpy.data.objects.new(code+'_'+label,None);col.objects.link(root)
    root.empty_display_type='PLAIN_AXES';root.empty_display_size=.25
    item=dict(code=code,name=label,category=category,collection=col,root=root,notes=notes,objects=[])
    assets.append(item);return item
def part(a,name,g,emission=False):
    obj=g.object(name,a['collection'],emission);obj.parent=a['root'];a['objects'].append(obj);return obj
def marker(a,name,loc):
    o=bpy.data.objects.new(name,None);a['collection'].objects.link(o);o.parent=a['root'];o.location=loc;o.empty_display_size=.2;o.empty_display_type='PLAIN_AXES';return o
def trim(g,w,h,depth):
    g.box((0,0,.19),(w,depth+.12,.38),'dark')
    g.box((0,0,h-.12),(w,depth+.08,.24),'edge')
def arch_shape(w,h): return [(-w/2,0),(w/2,0),(w/2,h*.67),(w*.30,h*.84),(0,h),(-w*.30,h*.84),(-w/2,h*.67)]
def arch_frame(g,innerw=2,h=3,thick=.22,depth=.55):
    outer=arch_shape(innerw+2*thick,h+thick);inner=arch_shape(innerw,h)
    for i in range(1,7):
        j=(i+1)%7
        g.prism([inner[i],outer[i],outer[j],inner[j]],depth,'stone')
    for x in (-1,1):g.box((x*(innerw/2+thick/2),0,.16),(thick+.14,depth+.12,.32),'dark')

# Reusable foundations, walls and palace openings.
for code,label,size in [('WP_A01','floor_4m',(4,4,.3)),('WP_A02','floor_2m',(2,4,.3)),('WP_A03','floor_1m',(1,4,.3))]:
    a=asset(code,label);g=Geo();g.box((0,0,size[2]/2),size);part(a,'Floor',g)
a=asset('WP_A04','floor_border_4m');g=Geo();g.box((0,0,.15),(4,.6,.3));g.box((0,-.17,.305),(4,.12,.01),'dark');g.box((0,-.25,.308),(4,.035,.016),'gold');part(a,'FloorBorder',g)
for code,label,h in [('WP_A05','wall_4m',4),('WP_A06','hall_wall_8m',8)]:
    a=asset(code,label);g=Geo();g.box((0,0,h/2),(4,.4,h));trim(g,4,h,.4);part(a,'Wall',g)
a=asset('WP_A07','wall_corner');g=Geo();g.box((0,0,2),(.6,.6,4));trim(g,.64,4,.6);part(a,'Corner',g)
a=asset('WP_A08','wall_breached');g=Geo();g.prism([(-2,0),(-.5,0),(-.65,1.1),(-1.15,1.45),(-.8,2),(-1.3,2.45),(-1.05,3.3),(-.6,4),(-2,4)],.4);g.prism([(.75,0),(2,0),(2,4),(1.15,4),(.85,3.2),(1.2,2.7),(.65,2),(.95,1.3)],.4);g.box((-1.45,0,.18),(1.1,.52,.36),'dark');g.box((1.4,0,.18),(1.2,.52,.36),'dark');part(a,'BrokenWall',g)
for code,label,w,h in [('WP_A09','arch_doorway',2,3),('WP_A10','arch_grand',4,5)]:
    a=asset(code,label);g=Geo();arch_frame(g,w,h,.25,.6);part(a,'ArchFrame',g)
a=asset('WP_A11','doorway_wall_4m');g=Geo();g.box((-1.65,0,2),(.7,.4,4));g.box((1.65,0,2),(.7,.4,4));g.prism([(-1.3,4),(1.3,4),(1.3,2.1),(.65,2.75),(0,3.25),(-.65,2.75),(-1.3,2.1)],.4);arch_frame(g,2,3,.25,.6);part(a,'DoorwayWall',g)
for code,label,broken in [('WP_A12','wind_window',False),('WP_A13','wind_window_broken',True)]:
    a=asset(code,label);g=Geo();g.box((-1.4,0,2), (1.2,.4,4));g.box((1.4,0,2),(1.2,.4,4));g.box((0,0,.5),(1.6,.4,1));g.prism([(-.8,4),(.8,4),(.8,2.9),(0,3.75),(-.8,2.9)],.4);g.box((0,0,1.02),(1.9,.65,.18),'edge')
    if not broken:
        g.beam((0,0,1.1),(0,0,3.7),.07,'gold');g.beam((-.7,0,2.2),(0,0,2.75),.06,'gold');g.beam((.7,0,2.2),(0,0,2.75),.06,'gold')
    else:g.beam((0,0,1.1),(.06,0,1.7),.07,'gold')
    part(a,'WindowWall',g)
for code,label,h in [('WP_A14','pillar_4m',4),('WP_A15','pillar_8m',8),('WP_A16','pillar_broken',1.65)]:
    a=asset(code,label);g=Geo();g.column((0,0,0),.68,.68,.22,'dark');g.column((0,0,.22),.55,.47,.22,'edge');g.column((0,0,.44),.43,.32,h-.84);g.column((0,0,h-.40),.46,.49,.16,'edge');g.column((0,0,h-.24),.52,.52,.20);g.column((0,0,.43),.435,.435,.045,'gold');part(a,'Pillar',g)
a=asset('WP_A17','blade_buttress');g=Geo();g.prism([(-.5,0),(.5,0),(.26,4.8),(0,5.5),(-.26,4.8)],.85);g.box((0,0,.18),(1.15,1,.36),'dark');part(a,'Buttress',g)
for code,label,rise in [('WP_A18','stairs_rise_2m',2),('WP_A19','stairs_rise_4m',4)]:
    a=asset(code,label,notes='Godot: use a simple ramp collider. Width 3m; climb toward Blender +Y.');g=Geo();steps=round(rise/.2);run=steps*.3
    # Solid side profile extruded across width with shared solid volume (no overlapping boxes).
    profile=[(-run/2,0),(run/2,0),(run/2,rise)]
    for i in range(steps-1,-1,-1): profile.extend([(-run/2+i*.3,(i+1)*.2),(-run/2+i*.3,i*.2)])
    p=[Vector((y,z,0)) for y,z in profile]
    # Build directly, side faces in YZ planes.
    for x,rev in [(-1.5,True),(1.5,False)]:g.face([(x,y,z) for y,z in (profile[::-1] if rev else profile)],'stone')
    for i in range(len(profile)):
        j=(i+1)%len(profile);y,z=profile[i];Y,Z=profile[j];g.face([(-1.5,y,z),(1.5,y,z),(1.5,Y,Z),(-1.5,Y,Z)],'edge' if z==Z else 'stone')
    part(a,'StairSolid',g);marker(a,'LowerLanding',(0,-run/2,0));marker(a,'UpperLanding',(0,run/2,rise))
a=asset('WP_A20','landing_3m');g=Geo();g.box((0,0,.15),(3,3,.3));part(a,'Landing',g)
a=asset('WP_A21','balustrade_2m');g=Geo();g.box((0,0,.1),(2,.3,.2),'dark');g.box((0,0,.96),(2,.34,.14))
for x in (-.88,-.44,0,.44,.88):g.column((x,0,.2),.105,.075,.69,'stone',4,math.pi/4)
part(a,'Balustrade',g)
a=asset('WP_A22','balustrade_post');g=Geo();g.box((0,0,.52),(.38,.38,1.04));g.box((0,0,1.08),(.5,.5,.12),'edge');part(a,'Post',g)
a=asset('WP_A23','gallery_support');g=Geo();g.prism([(-.22,0),(.22,0),(.22,1.3),(-1.2,1.3),(-1.2,1.05),(-.55,.65)],.45,'dark');part(a,'Corbel',g)
a=asset('WP_A24','roof_rib_4m');g=Geo();g.prism([(-2,0),(-1.8,0),(0,1.5),(1.8,0),(2,0),(0,1.85)],.3,'edge');part(a,'RoofRib',g)

def leaf(g,x,y,z,s=1,color='gold'):
    g.prism([(x-.11*s,z),(x+.13*s,z+.28*s),(x+.05*s,z+.62*s),(x-.15*s,z+.28*s)],.035,color,y)
def emblem(g,y,z,scale=1):
    # Three broad sculptural ribbons, ivory wind emblem, not a generic fan.
    for k in range(3):
        points=[(-.45,.1),(-.15,.16),(.19,.39),(.43,.42),(.27,.23),(-.04,.03),(-.3,-.03)]
        g.prism([(x*scale,(v+z/scale+k*.23)*scale) for x,v in points],.018,'light',y)

# Doors: leaf geometry origins on hinge, visibly separate nodes.
a=asset('WP_D01','royal_double_door','decor',notes='DoorLeaf_L/R are local hinge pivots; +Z front in Godot.')
g=Geo();arch_frame(g,3,4.5,.27,.65);part(a,'DoorFrame',g)
for side in (-1,1):
    g=Geo();poly=arch_shape(3,4.5)
    pts=[(-1.5,.05),(0,.05),(0,4.45),(-.9,3.8),(-1.5,3)] if side==-1 else [(0,.05),(1.5,.05),(1.5,3),(.9,3.8),(0,4.45)]
    g.prism(pts,.14,'dark',-.04)
    for x in ([ -1.39,-.10] if side==-1 else [.10,1.39]):g.box((x,-.13,1.55),(.045,.035,2.8),'gold')
    g.box((side*.12,-.19,1.6),(.055,.1,.32),'gold')
    o=part(a,'DoorLeaf_L' if side==-1 else 'DoorLeaf_R',g)
    hinge=Vector((side*1.5,0,0));
    for v in o.data.vertices:v.co-=hinge
    o.location=hinge
a=asset('WP_D02','single_door','decor');g=Geo();g.prism(arch_shape(1.9,2.95),.14,'dark');g.box((.72,-.11,1.3),(.06,.08,.26),'gold');part(a,'DoorLeaf',g)

for code,label,standing,torn in [('WP_D03','wind_banner_wall',False,False),('WP_D04','wind_banner_torn',False,True),('WP_D05','wind_flag_standing',True,False)]:
    a=asset(code,label,'decor',notes='Animated gentle breeze morph; BannerCloth and WindEmblem separate from pole. Loop amplitude intentionally small.')
    g=Geo();pole=3.7 if standing else 3.5
    if standing:
        g.column((0,0,0),.38,.32,.18,'dark');g.column((0,0,.18),.2,.14,.2,'edge');g.column((0,0,.38),.055,.055,pole-.38,'gold')
    g.beam((-.7,0,pole),(.7,0,pole),.075,'gold');leaf(g,0,0,pole,.65)
    part(a,'BannerSupport',g)
    g=Geo();cols=8;rows=12
    for j in range(rows):
        for i in range(cols):
            pts=[]
            for I,J in [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]:
                u=I/cols;v=J/rows;x=(u-.5)*1.1
                z=pole-.08-v*2.45
                if J==rows:z+=.22*abs(u-.5)*2 if not torn else (.25 if I%3 else -.1)
                y=-.035+math.sin(v*4+u*1.4)*.10*v
                pts.append((x,y,z))
            g.face(pts,'teal' if j<3 else 'dark');g.face(pts[::-1],'teal' if j<3 else 'dark')
    cloth=part(a,'BannerCloth',g)
    cloth.shape_key_add(name='Basis');gust=cloth.shape_key_add(name='GentleBreeze')
    for v in gust.data:
        t=(pole-.08-v.co.z)/2.45;v.co.y+=.12*max(t,0)**1.4;v.co.x+=.035*max(t,0)**2
    for frame,value in [(1,0),(33,1),(65,0)]:gust.value=value;gust.keyframe_insert(data_path='value',frame=frame)
    scene.frame_end=65
    g=Geo();emblem(g,-.17,pole-1.4,.72);symbol=part(a,'WindEmblem',g)
    symbol.shape_key_add(name='Basis');sg=symbol.shape_key_add(name='GentleBreeze')
    for v in sg.data:
        t=(pole-.08-v.co.z)/2.45;v.co.y+=.12*max(t,0)**1.4;v.co.x+=.035*max(t,0)**2
    for frame,value in [(1,0),(33,1),(65,0)]:sg.value=value;sg.keyframe_insert(data_path='value',frame=frame)

for code,label,length in [('WP_D06','carpet_straight_4m',4),('WP_D07','carpet_end',2)]:
    a=asset(code,label,'decor',notes='Place 0.015m above floor. No coincident surfaces.');g=Geo();g.box((0,0,.015),(1.8,length,.03),'dark')
    for x in (-.82,.82):g.box((x,0,.034),(.035,length,.008),'gold')
    part(a,'Carpet',g)
a=asset('WP_D08','royal_bench','decor');g=Geo();g.box((0,0,.55),(1.8,.6,.14),'wood')
for x in (-.65,.65):g.box((x,0,.25),(.15,.5,.5),'dark')
g.box((0,.24,.89),(1.8,.10,.55),'teal');part(a,'Bench',g)
a=asset('WP_D09','library_shelf','decor');g=Geo()
for x in (-1.05,1.05):g.box((x,0,1.5),(.14,.5,3),'wood')
g.box((0,.22,1.5),(2.1,.08,3),'dark')
for z in (.1,.78,1.48,2.18,2.9):g.box((0,0,z),(2.2,.55,.1),'wood')
for row,z in enumerate((.15,.83,1.53,2.23)):
    for i in range(9):
        color=['teal','shadow','wood','paper','dark'][(i+row*2)%5];height=.40+.06*((i+row)%3)
        g.box((-.89+i*.22,-.04,z+height/2),(.15,.32,height),color)
part(a,'Bookshelf',g)
a=asset('WP_D10','reading_table','decor');g=Geo();g.box((0,0,.85),(1.8,.9,.12),'wood')
for x in (-.7,.7):
    for y in (-.3,.3):g.box((x,y,.4),(.1,.1,.8),'dark')
g.box((-.3,0,.925),(.5,.35,.025),'paper');g.box((.3,.1,.95),(.3,.23,.08),'teal');part(a,'ReadingTable',g)
a=asset('WP_D11','dining_table','decor');g=Geo();g.box((0,0,.9),(1.3,4,.14),'wood')
for y in (-1.45,1.45):g.box((0,y,.43),(.9,.22,.86),'dark')
part(a,'DiningTable',g)
a=asset('WP_D12','royal_chair','decor');g=Geo();g.box((0,0,.48),(.62,.62,.12),'wood');g.box((0,.27,.98),(.62,.1,.95),'dark')
for x in (-.24,.24):
    for y in (-.24,.24):g.box((x,y,.22),(.09,.09,.44),'wood')
part(a,'Chair',g)
a=asset('WP_D13','planter','decor');g=Geo();g.column((0,0,0),.3,.48,.68,'dark');g.column((0,0,.65),.5,.5,.1,'gold');g.column((0,0,.75),.43,.43,.035,'wood')
for i in range(7):
    angle=i*2.4; x=.26*math.sin(angle);y=.26*math.cos(angle);z=.85+.14*(i%3)
    g.beam((0,0,.76),(x,y,z+.35),.035,'wood');leaf(g,x,y,z,.65,'jade')
part(a,'Planter',g)
a=asset('WP_D14','sail_storage','decor');g=Geo()
for x in (-.9,.9):g.box((x,0,1.25),(.14,.7,2.5),'wood')
for z in (.25,1.25,2.25):
    g.box((0,0,z),(2,.75,.1),'dark')
    for x in (-.45,.4):g.column((x,0,z+.05),.26,.26,.65,'teal',8)
part(a,'SailRack',g)
a=asset('WP_D15','bed_royal','decor');g=Geo();g.box((0,0,.30),(1.9,2.7,.6),'dark');g.box((0,0,.65),(1.75,2.5,.18),'paper');g.box((0,-.4,.76),(1.78,1.6,.12),'teal');g.box((0,.85,.80),(1.25,.5,.18),'light');g.box((0,1.3,1.1),(2,.14,1.6),'wood');part(a,'RoyalBed',g)
a=asset('WP_D16','wall_lantern','decor');g=Geo();g.box((0,.12,.5),(.18,.15,1),'dark');g.beam((0,0,.7),(0,-.4,.7),.08,'gold');g.column((0,-.4,.25),.16,.16,.38,'gold',6);g.column((0,-.4,.63),.2,.02,.16,'dark',6);part(a,'LanternFrame',g);g=Geo();g.column((0,-.4,.30),.12,.12,.28,'paper',6);part(a,'LanternGlow',g,True)
a=asset('WP_D17','rubble_cluster','decor');g=Geo()
for x,y,z,s,ang in [(-.55,0,.18,(.65,.55,.36),.2),(.15,.1,.25,(.7,.6,.5),-.25),(.65,-.16,.13,(.38,.35,.26),.6),(-.2,.43,.12,(.4,.3,.24),.5)]:g.box((x,y,z),s,'edge',ang)
part(a,'Rubble',g)
a=asset('WP_D18','fallen_beam','decor');g=Geo();g.box((0,0,.16),(3.4,.28,.32),'wood',.15);g.box((-.4,0,.18),(.14,.32,.36),'gold',.15);part(a,'FallenBeam',g)
a=asset('WP_D19','wind_sovereign_statue','decor');g=Geo();g.column((0,0,0),.85,.85,.2,'dark');g.column((0,0,.2),.75,.65,.3,'stone')
g.column((0,0,.5),.60,.29,2.4,'stone',6);g.column((0,0,2.9),.27,.21,.5,'light',5)
g.prism([(-.18,3.28),(-.32,3.75),(0,3.6),(.32,3.75),(.18,3.28)],.28,'gold')
g.beam((-.28,0,2.65),(-.8,-.12,2.3),.2,'stone');g.beam((.28,0,2.65),(.8,-.12,2.3),.2,'stone')
# Open crescent instrument, broad polygon segments.
for i in range(9):
    a0=math.radians(200+i*15);a1=a0+math.radians(15)
    g.prism([(r*math.cos(t),2.95+r*math.sin(t)) for r,t in [(1,a0),(1,a1),(.84,a1),(.84,a0)]],.10,'gold',-.12)
part(a,'Statue',g)
a=asset('WP_D20','wind_throne','decor');g=Geo();g.box((0,0,.15),(2.4,2,.3),'dark');g.box((0,0,.65),(1.45,1.2,.7));g.prism([(-.8,.6),(.8,.6),(.8,2.3),(.3,3.1),(0,3.5),(-.3,3.1),(-.8,2.3)],.25,'dark',.55)
for x in (-.85,.85):g.box((x,0,1.15),(.25,1.35,.2),'gold')
emblem(g,.40,2.1,.8);part(a,'Throne',g)

# Functional visual models; do not add gameplay scripts or overwrite current objects.
a=asset('WP_I01','wind_charger','interactive',notes='Visual only. Rotor and Charge_Lens_0..3 separate; bind existing WindCharger after configuration check.')
g=Geo();g.column((0,0,0),.65,.65,.2,'dark');g.column((0,0,.2),.5,.32,.95);g.column((0,0,1.15),.46,.46,.12,'gold');part(a,'ChargerBody',g)
g=Geo()
for i in range(3):
    t=i*2*math.pi/3
    g.prism([(0,0),(.10,.15),(.42,.30),(.50,.16),(.2,-.02)],.06,'gold') if i==0 else None
# Geometry authored around rotor origin, then rotate vertices for three sails.
g=Geo()
for i in range(3):
    t=i*2*math.pi/3;pts=[(.10,-.04),(.18,.11),(.53,.2),(.46,-.06)]
    g.prism([(x*math.cos(t)-z*math.sin(t),x*math.sin(t)+z*math.cos(t)) for x,z in pts],.08,'gold')
rot=part(a,'Rotor',g);rot.location=(0,0,1.70)
for i in range(4):
    g=Geo();g.box((0,0,0),(.12,.035,.12),'mint');o=part(a,'Charge_Lens_%d'%i,g,True);o.location=(-.27+i*.18,-.37,.95)
a=asset('WP_I02','wind_lift','interactive',notes='Visual with independent Platform, LowerStop/UpperStop at 0/4m. Collider and wind VFX in Godot; wind, not chains, lifts it.')
g=Geo();g.box((0,0,.1),(3.4,3.4,.2),'dark')
for x in (-1.6,1.6):g.box((x,1.6,2.4),(.22,.22,4.8),'dark')
g.box((0,1.6,4.8),(3.6,.3,.3));part(a,'LiftFrame',g)
g=Geo();g.box((0,0,.15),(3,3,.3));g.box((0,0,.31),(2.7,2.7,.02),'dark')
for x in (-1.4,1.4):g.box((x,0,.34),(.045,2.85,.02),'gold')
part(a,'Platform',g);marker(a,'LowerStop',(0,0,0));marker(a,'UpperStop',(0,0,4))
a=asset('WP_I03','updraft_vent','interactive',notes='Stone vent only; particles, collision, WindZone and side landing configured in Godot.')
g=Geo()
for i in range(12):
    t=i*2*math.pi/12;T=(i+1)*2*math.pi/12
    p=[(r*math.cos(q),r*math.sin(q),z) for r,q,z in [(1.1,t,.05),(1.1,T,.05),(1.1,T,.25),(1.1,t,.25),(.82,t,.05),(.82,T,.05),(.82,T,.25),(.82,t,.25)]]
    for ids in [(0,1,2,3),(4,7,6,5),(3,2,6,7),(0,4,5,1),(0,3,7,4),(1,5,6,2)]:g.face([p[j] for j in ids],'edge')
for x in (-.55,-.28,0,.28,.55):g.box((x,0,.12),(.07,1.3,.10),'dark')
part(a,'VentRim',g)
a=asset('WP_I04','wind_checkpoint','interactive');g=Geo();g.column((0,0,0),.65,.65,.18,'dark');g.column((0,0,.18),.5,.32,.5);g.column((0,0,.68),.36,.36,.12,'gold');part(a,'ShrineBase',g)
g=Geo();g.prism([(-.16,.05),(0,0),(.16,.05),(.22,.4),(0,.72),(-.22,.4)],.28,'mint');o=part(a,'Crystal',g,True);o.location=(0,0,.95)

# Stage assets with reusable data, with no instance of the old map.
for i,a in enumerate(assets):
    a['root'].location=((i%9)*6,(i//9)*9,0)
scene.frame_set(1)
manifest=[]
export_props={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
for a in assets:
    folder=DEST/a['code'];folder.mkdir(parents=True,exist_ok=True)
    path=folder/(a['code']+'_'+a['name']+'_'+VERSION+'.glb')
    source=BACKUP/(a['code']+'_'+a['name']+'_'+VERSION+'.blend')
    if path.exists() or source.exists():raise RuntimeError('Refusing to overwrite: '+str(path))
    old=a['root'].location.copy();a['root'].location=(0,0,0)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in a['collection'].objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=a['root']
    args=dict(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=True,export_cameras=False,export_lights=False)
    if 'export_all_vertex_colors' in export_props:args['export_all_vertex_colors']=True
    if 'export_attributes' in export_props:args['export_attributes']=True
    bpy.ops.export_scene.gltf(**args)
    source_scene=bpy.data.scenes.new(a['code']+'_Source')
    source_scene.collection.children.link(a['collection']);source_scene.frame_end=65;source_scene.unit_settings.system='METRIC'
    bpy.data.libraries.write(str(source),{source_scene},fake_user=True,compress=True)
    bpy.data.scenes.remove(source_scene)
    points=[obj.matrix_local@v.co for obj in a['objects'] for v in obj.data.vertices]
    mn=[min(p[j] for p in points) for j in range(3)];mx=[max(p[j] for p in points) for j in range(3)]
    tris=sum(len(o.data.polygons) for o in a['objects'])
    manifest.append(dict(code=a['code'],name=a['name'],category=a['category'],status='exported_pending_visual_and_glb_audit',glb=str(path),blend=str(source),triangles=tris,mesh_count=len(a['objects']),material_count=len({m.name for o in a['objects'] for m in o.data.materials}),size_blender_xyz=[round(mx[j]-mn[j],3) for j in range(3)],notes=a['notes']))
    a['root'].location=old
(WORK/'asset_state.json').write_text(json.dumps(dict(version=VERSION,scene=scene.name,assets=manifest),ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(BACKUP/'wind_palace_production_v01.blend'))
print(json.dumps(dict(scene=scene.name,exported=len(manifest),triangles=sum(x['triangles'] for x in manifest),max_triangles=max(x['triangles'] for x in manifest),manifest=str(WORK/'asset_state.json')),indent=2))
