"""Dựng điện thờ rồng bạc; Blender Z lên, phía bắc là +Y."""
from pathlib import Path
import math
import random
import runpy
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PROJECT = HERE.parents[5]
LIBRARY = PROJECT / "assets/models/map_temple/source/build_temple_hub.py"
KIT = runpy.run_path(str(LIBRARY), run_name="sanctuary_helpers")
TEX_SOURCE = LIBRARY.parent / "textures"
RADIUS = 15.8
RNG = random.Random(742)


def linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def pbr(name: str, prefix: str, tint: tuple[float, float, float]) -> bpy.types.Material:
    folder = ROOT / "textures" / name
    folder.mkdir(parents=True, exist_ok=True)
    mat = bpy.data.materials.new("Sanctuary_" + name)
    mat.use_nodes = True
    mat.diffuse_color = (*[linear(c) for c in tint], 1)
    mat.use_backface_culling = True
    is_floor=name=="paving" or name.startswith("tile_variants/")
    KIT["TEX_SIZE"][mat.name] = 8.0 if is_floor else 6.0
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    for suffix, socket, non_color in (("Diffuse", "Base Color", False), ("Rough", "Roughness", True), ("nor_gl", "Normal", True)):
        path = folder / (suffix + ".jpg")
        if not path.exists() or suffix == "Diffuse" or path.stat().st_mtime < Path(__file__).stat().st_mtime:
            image = bpy.data.images.load(str(TEX_SOURCE / (prefix + "_" + suffix + ".jpg")), check_existing=True)
            # Giới hạn 1K để ba bộ PBR không chiếm VRAM của đạn và hiệu ứng chiến đấu.
            image = image.copy()
            image.scale(1024, 1024)
            if suffix == "Diffuse":
                pixels = np.empty(1024 * 1024 * 4, dtype=np.float32)
                image.pixels.foreach_get(pixels)
                rgba = pixels.reshape(-1, 4)
                luminance=rgba[:, :3] @ np.array((0.2126,0.7152,0.0722))
                contrast=0.25 if is_floor else 0.38
                variation=1.0+contrast*(luminance/max(float(luminance.mean()),0.001)-1.0)
                rgba[:, :3]=np.clip(variation[:,None]*np.array([linear(c) for c in tint]),0,1)
                image.pixels.foreach_set(rgba.ravel())
            image.file_format = "JPEG"
            image.filepath_raw = str(path)
            image.save()
            bpy.data.images.remove(image)
        image = bpy.data.images.load(str(path), check_existing=True)
        if non_color:
            image.colorspace_settings.name = "Non-Color"
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        output = tex.outputs["Color"]
        if suffix == "nor_gl":
            normal = mat.node_tree.nodes.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = 0.10 if is_floor else 0.16
            mat.node_tree.links.new(output, normal.inputs["Color"])
            output = normal.outputs["Normal"]
        mat.node_tree.links.new(output, bsdf.inputs[socket])
    return mat


def flat(name: str, color: tuple[float, float, float], metallic: float = 0) -> bpy.types.Material:
    return KIT["material"]("Sanctuary_" + name, tuple(linear(c) for c in color), roughness=0.82, metallic=metallic)


def cloth_material() -> bpy.types.Material:
    folder=ROOT/"textures/tile_variants/cloth"
    folder.mkdir(parents=True,exist_ok=True)
    mat=flat("woven_silk",(0.18,0.36,0.37))
    shader=next(node for node in mat.node_tree.nodes if node.type=="BSDF_PRINCIPLED")
    shader.inputs["Roughness"].default_value=0.94
    y,x=np.mgrid[0:512,0:512]
    weave=np.sin(x*math.tau/8)*np.sin(y*math.tau/8)
    for name,normal in (("woven_color",False),("woven_normal",True)):
        path=folder/(name+".png")
        if not path.exists():
            pixels=np.ones((512,512,4),dtype=np.float32)
            if normal:
                pixels[:,:,0]=0.5+np.cos(x*math.tau/8)*0.035
                pixels[:,:,1]=0.5+np.cos(y*math.tau/8)*0.035
                pixels[:,:,2]=0.998
            else:
                pigment=np.array([linear(c) for c in (0.18,0.36,0.37)])
                pixels[:,:,:3]=(1+weave[:,:,None]*0.14)*pigment
            image=bpy.data.images.new(name,width=512,height=512)
            if normal:
                image.colorspace_settings.name="Non-Color"
            image.pixels.foreach_set(pixels.ravel())
            image.file_format="PNG"
            image.filepath_raw=str(path)
            image.save()
            bpy.data.images.remove(image)
        texture=mat.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image=bpy.data.images.load(str(path),check_existing=True)
        if normal:
            texture.image.colorspace_settings.name="Non-Color"
            node=mat.node_tree.nodes.new("ShaderNodeNormalMap")
            node.inputs["Strength"].default_value=0.18
            mat.node_tree.links.new(texture.outputs["Color"],node.inputs["Color"])
            mat.node_tree.links.new(node.outputs["Normal"],shader.inputs["Normal"])
        else:
            mat.node_tree.links.new(texture.outputs["Color"],shader.inputs["Base Color"])
    return mat


def emit(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material, group: bpy.types.Collection, bevel: float = 0.04, smooth: bool = False) -> bpy.types.Object:
    obj = KIT["obj_from_bm"](name, bm, mat, group, smooth=smooth, bevel=bevel)
    if bevel:
        obj.modifiers[0].segments = 3
    return obj


def box(bm: bmesh.types.BMesh, center: tuple, size: tuple, angle: float = 0) -> None:
    KIT["add_box"](bm, Vector(center), size, angle)


def path_mesh(points: list[tuple], widths: list[float], depths: list[float]) -> bmesh.types.BMesh:
    bm = bmesh.new()
    rings = []
    for i, (x, y, z) in enumerate(points):
        ring = []
        for j in range(8):
            a = math.tau * j / 8
            ring.append(bm.verts.new((x + math.cos(a) * widths[i], y + math.sin(a) * depths[i], z)))
        rings.append(ring)
    bm.faces.new(rings[0][::-1])
    for first, second in zip(rings, rings[1:]):
        for j in range(8):
            bm.faces.new((first[j], first[(j + 1) % 8], second[(j + 1) % 8], second[j]))
    bm.faces.new(rings[-1])
    return bm


def spiral(bm: bmesh.types.BMesh, center: Vector, scale: float, height: float) -> None:
    points = []
    for i in range(81):
        t = i / 80
        a = t * math.pi * 3.2
        r = (0.10 + t * 0.85) * scale
        points.append(center + Vector((r * math.cos(a), r * math.sin(a), height)))
    for a, b in zip(points, points[1:]):
        KIT["add_segment"](bm, a, b, 0.065 * scale, 0.06)


def build_stage(m: dict, group: bpy.types.Collection) -> None:
    bm = bmesh.new()
    KIT["add_cyl"](bm, Vector((0, 0, -0.9)), RADIUS, RADIUS, 0.88, 128)
    emit("ArenaFloor", bm, m["paving"], group, bevel=0.018)
    paving=[bmesh.new() for _ in range(3)]
    for course in range(7):
        inner=0.02 if course==0 else 2.2*course
        outer=min(15.72,2.2*(course+1))
        count=max(7,round(outer*1.8))
        for i in range(count):
            tone=RNG.randrange(3)
            slab=paving[tone]
            a=math.tau*(i+0.5*(course%2))/count
            b=a+math.tau/count
            for sector in range(10):
                first=a+0.003+(b-a-0.006)*sector/10
                last=a+0.003+(b-a-0.006)*(sector+1)/10
                ring=[]
                for radius,angle in ((inner+0.025,first),(outer-0.025,first),(outer-0.025,last),(inner+0.025,last)):
                    ring.append(slab.verts.new((radius*math.cos(angle),radius*math.sin(angle),0.025)))
                slab.faces.new(ring)
    for index,slab in enumerate(paving):
        bmesh.ops.remove_doubles(slab,verts=list(slab.verts),dist=0.00001)
        region=bmesh.ops.extrude_face_region(slab,geom=list(slab.faces))
        vertices=[v for v in region["geom"] if isinstance(v,bmesh.types.BMVert)]
        bmesh.ops.translate(slab,verts=vertices,vec=Vector((0,0,-0.09)))
        emit("CarvedFlagstones_%d"%index,slab,m["tile_%d"%index],group,bevel=0.018)
    bm = bmesh.new()
    KIT["lathe"](bm, Vector(), [(12.7, -8), (13.9, -5.8), (14.3, -5.5), (14.3, -4.4), (15.1, -4.1), (15.1, -3), (15.4, -2.8), (15.4, -1.2), (15.8, -0.96)], 128)
    emit("LayeredFoundation", bm, m["rock"], group, bevel=0.055)
    trim = bmesh.new()
    for radius, z in ((15.6, -1.04), (15.05, -3.08), (14.3, -4.48)):
        KIT["add_torus"](trim, Vector((0, 0, z)), radius, 0.13, Matrix.Identity(3), 128, 8)
    emit("FoundationMouldings", trim, m["stone"], group)
    rear=bmesh.new()
    # Khép mặt trên để dưới chân vòm là đá thật, không nhìn xuyên ra trời qua lòng bệ rỗng.
    KIT["lathe"](rear,Vector((0,17,0)),[(12.0,-8.1),(14.5,-6.2),(15.9,-3.8),(16.1,-1.2),(16.4,-0.75),(16.4,-0.36),(0,-0.36)],96)
    emit("SanctuaryRockFooting",rear,m["rock"],group,bevel=0.09)
    supports=bmesh.new()
    for i in range(8):
        angle=math.tau*i/8+math.pi/8
        for radius,z,width,depth,height in ((14.8,-6.8,2.1,1.7,5.0),(14.9,-6.5,2.7,2.0,0.42),(15.1,-2.2,2.5,2.1,0.55)):
            box(supports,(math.cos(angle)*radius,math.sin(angle)*radius,z+height*0.5),(depth,width,height),angle)
    emit("ButtressedDrum",supports,m["stone"],group,bevel=0.095)
    rails = bmesh.new()
    caps = bmesh.new()
    posts = bmesh.new()
    for i in range(64):
        a, b = math.tau * i / 64, math.tau * (i + 1) / 64
        p = Vector((math.cos(a) * 15.2, math.sin(a) * 15.2, 0))
        q = Vector((math.cos(b) * 15.2, math.sin(b) * 15.2, 0))
        mid = (p + q) * 0.5
        yaw = math.atan2(q.y - p.y, q.x - p.x)
        box(rails, (mid.x, mid.y, 0.12), ((q-p).length, 0.44, 0.24), yaw)
        box(rails, (mid.x, mid.y, 0.78), ((q-p).length, 0.44, 0.20), yaw)
        box(rails, (p.x, p.y, 0.46), (0.23, 0.44, 0.44), yaw)
        arch=[]
        tangent=(q-p).normalized()
        for j in range(17):
            t=j/16
            arch.append(mid+tangent*((t-0.5)*(q-p).length*0.82)+Vector((0,0,0.32+0.36*math.sin(t*math.pi))))
        for first,second in zip(arch,arch[1:]):
            KIT["add_segment"](rails,first,second,0.10,0.44)
        box(caps, (mid.x, mid.y, 0.96), ((q-p).length, 0.66, 0.14), yaw)
        if i % 4 == 0:
            box(posts, (p.x, p.y, 0.61), (0.70, 0.70, 1.14), a)
            box(posts, (p.x, p.y, 1.21), (0.91, 0.91, 0.16), a)
    emit("ParapetStone", rails, m["stone"], group, bevel=0.025)
    emit("ParapetCaps", caps, m["edge"], group, bevel=0.03)
    emit("ParapetPosts", posts, m["edge"], group, bevel=0.07)
    inlay = bmesh.new()
    for arm in range(3):
        first, second = [], []
        for i in range(91):
            t=i/90
            a=arm*math.tau/3 + t*math.pi*1.5
            r=0.4+5.8*t
            width=0.05+0.28*math.sin(math.pi*t)
            first.append(inlay.verts.new(((r-width)*math.cos(a),(r-width)*math.sin(a),0.068)))
            second.append(inlay.verts.new(((r+width)*math.cos(a),(r+width)*math.sin(a),0.068)))
        for i in range(90):
            inlay.faces.new((first[i],second[i],second[i+1],first[i+1]))
    emit("WindSeal", inlay, m["inlay"], group, bevel=0.012)


def stone_profile(name: str, outline: list[tuple[float, float]], depth: float, y: float,
        mat: bpy.types.Material, group: bpy.types.Collection) -> bpy.types.Object:
    bm=bmesh.new()
    front=[bm.verts.new((x,y-depth*0.5,z)) for x,z in outline]
    back=[bm.verts.new((x,y+depth*0.5,z)) for x,z in outline]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(len(front)):
        j=(i+1)%len(front)
        bm.faces.new((front[i],back[i],back[j],front[j]))
    return emit(name,bm,mat,group,bevel=0.075)


def curved_line(name: str, points: list[Vector], radius: float, material: bpy.types.Material,
        group: bpy.types.Collection) -> None:
    data=bpy.data.curves.new(name,"CURVE")
    data.dimensions="3D"
    data.resolution_u=12
    data.bevel_depth=radius
    data.bevel_resolution=3
    spline=data.splines.new("POLY")
    spline.points.add(len(points)-1)
    for target,point in zip(spline.points,points):
        target.co=(*point,1)
    obj=bpy.data.objects.new(name,data)
    group.objects.link(obj)
    data.materials.append(material)
    # Mesh giữ đúng đường viền này khi xuất sang glTF.
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)


def build_shrine(m: dict, group: bpy.types.Collection) -> None:
    for side,depth,height in ((-1,12.0,16.5),(1,13.4,15.0),(-1,17.8,17.3)):
        outline=[]
        center=[]
        base=side*(14.8 if depth<16 else 10.5)
        for i in range(81):
            t=i/80
            x=base-side*(0.9*t+7.8*t*t)
            z=-0.4+height*t
            width=(1.9*(1-t)**0.80+0.18)
            center.append((x,z,width))
            outline.append((x-side*width,z))
        outline.extend((x+side*width,z) for x,z,width in reversed(center))
        stone_profile("WingStone_%s_%s"%(side,int(depth)),outline,1.7,depth,m["stone"],group)
        # Gân cùng đường cong với cánh giúp hình dáng đọc được từ camera cao.
        for flank in (-1,1):
            line=[Vector((x+side*width*0.81*flank,depth-0.91,z)) for x,z,width in center[2:-3]]
            curved_line("WingEdge",line,0.085,m["edge"],group)
        glyph=[]
        for j in range(101):
            t=j/100
            angle=t*math.pi*3.25
            radius=0.09+1.08*t
            glyph.append(Vector((base-side*0.8+radius*math.cos(angle),depth-0.94,3.5+radius*math.sin(angle))))
        curved_line("CarvedWingSpiral",glyph,0.065,m["inlay"],group)
        for j in range(8):
            t=0.12+j*0.095
            x,z,width=center[int(t*80)]
            points=[Vector((x+side*width*f,depth-0.93,z+0.18*math.sin(f*2))) for f in (-0.75,-0.3,0.2,0.70)]
            curved_line("WingStoneJoint",points,0.021,m["shadow"],group)
    # Vòm có lòng rỗng và tường hậu lùi sâu để ánh sáng tạo được chiều sâu thật.
    outer=[(-12.6,-0.6),(-12.6,5.0),(-12,8.0),(-10.5,10.8),(-8,13.0),(-4,14.6),(0,15.2),(4,14.6),(8,13.0),(10.5,10.8),(12,8),(12.6,5),(12.6,-0.6)]
    inner=[(8.9,-0.6),(8.9,5),(7.8,7.8),(5.3,10.2),(2.4,11.5),(0,12.0),(-2.4,11.5),(-5.3,10.2),(-7.8,7.8),(-8.9,5),(-8.9,-0.6)]
    stone_profile("VaultedSanctuary",outer+inner,3.0,19.0,m["stone"],group)
    for offset in (0.0,0.34):
        front=[Vector((x*(1+offset*0.03),17.34-offset*0.11,z+offset*0.5)) for x,z in inner]
        curved_line("VaultMoulding",front,0.10,m["edge"],group)
    back=[(-10,-0.4),(-10,4),(-8,7),(-4,9.5),(0,10),(4,9.5),(8,7),(10,4),(10,-0.4)]
    stone_profile("RecessedRockWall",back,2.0,24,m["rock"],group)
    ribs=bmesh.new()
    for x in (-7.7,-4.9,4.9,7.7):
        KIT["add_segment"](ribs,Vector((x,23.0,0)),Vector((x*0.68,21.0,11.8)),0.55,0.62)
    emit("DeepVaultRibs",ribs,m["stone"],group,bevel=0.09)
    crown=[(-10.8,11.9),(-9.7,13.7),(-7.4,14.4),(-6.2,14.1),(-4.3,15.2),(-2.8,15.7),(-1.6,15.5),(-0.3,16.1),(1.1,15.8),(2.7,16.0),(3.6,15.2),(5.7,14.9),(7.4,14.0),(9.8,13.7),(11,12.0),(8.3,12.8),(4.2,14.0),(0,14.6),(-4.2,14.0),(-8.3,12.8)]
    stone_profile("BrokenCrownStones",crown,1.7,18.1,m["edge"],group)
    # Mặt phù điêu nằm lùi trong trán vòm, tránh cảm giác biểu tượng dán nổi.
    medallion=bmesh.new()
    outline=[Vector((1.5*math.cos(i*math.tau/48),17.455,13.65+1.5*math.sin(i*math.tau/48))) for i in range(48)]
    medallion.faces.new([medallion.verts.new(v) for v in outline])
    emit("CrownCarvingInset",medallion,m["stone"],group,bevel=0)
    glyph=[]
    for i in range(110):
        t=i/109
        angle=t*math.pi*3.0
        radius=0.08+0.98*t
        glyph.append(Vector((radius*math.cos(angle),17.37,13.65+radius*math.sin(angle))))
    curved_line("CrownCarving",glyph,0.072,m["inlay"],group)
    shelf=[(-7.8,8.2),(-7.3,8.75),(-3.6,8.67),(-0.9,8.83),(2.0,8.71),(5.1,8.82),(7.6,8.4),(7.3,7.75),(4.5,7.67),(1.4,7.76),(-1.7,7.61),(-5.5,7.78)]
    stone_profile("DragonRoostShelf",shelf,4.7,20.0,m["stone"],group)
    for index,x in enumerate((-5.8,-2.9,0,2.9,5.8)):
        corbel=bmesh.new()
        profile=[(21.4,5.7),(18.25,7.5),(18.25,7.65),(21.4,7.65)]
        first=[corbel.verts.new((x-0.24,y,z)) for y,z in profile]
        last=[corbel.verts.new((x+0.24,y,z)) for y,z in profile]
        corbel.faces.new(first)
        corbel.faces.new(last[::-1])
        for i in range(4):
            corbel.faces.new((first[i],last[i],last[(i+1)%4],first[(i+1)%4]))
        emit("RoostCorbel_%d"%index,corbel,m["edge"],group,bevel=0.05)
    for index,(x,y,z) in enumerate(((-13.2,10.9,11.2),(12.9,12.4,10),(-7.8,16.8,15))):
        bell=bmesh.new()
        KIT["lathe"](bell,Vector((x,y,z-2)),[(0.7,0),(0.76,0.14),(0.62,0.24),(0.47,0.50),(0.38,1),(0.20,1.24)],64)
        KIT["add_segment"](bell,Vector((x,y,z-0.8)),Vector((x,y,z+1.0)),0.060,0.060)
        emit("BronzeBell_%d"%index,bell,m["bronze"],group,bevel=0.02,smooth=True)
        for ring_height,radius in ((z-1.98,0.74),(z-0.95,0.38)):
            line=[Vector((x+math.cos(i*math.tau/64)*radius,y+math.sin(i*math.tau/64)*radius,ring_height)) for i in range(65)]
            curved_line("BellRim",line,0.040,m["bronze"],group)
        cloth=bmesh.new()
        grid=[]
        for i in range(65):
            t=i/64
            strip=[]
            for j in range(13):
                v=j/12
                zcloth=z-1.1-1.3*math.sin(t*3)-v*1.4*(1-t*0.8)+0.08*math.sin(t*16+v*2)
                # Đuôi rách đổi chiều dài để các nếp vải không gập xuyên nhau.
                tip=9*t-0.25*(1+math.sin(j*2.4))*t**10
                strip.append(cloth.verts.new((x+tip,y+0.7*math.sin(t*7)+v*0.14,zcloth)))
            grid.append(strip)
        for i in range(64):
            for j in range(12):
                if i>57 and (j in (3,7)):
                    continue
                cloth.faces.new((grid[i][j],grid[i+1][j],grid[i+1][j+1],grid[i][j+1]))
        obj=emit("TornSilk_%d"%index,cloth,m["cloth"],group,bevel=0,smooth=True)
        obj.data.materials[0].use_backface_culling=False


def build_clouds(group: bpy.types.Collection) -> None:
    material=bpy.data.materials.new("Sanctuary_PaintedStorm")
    material.use_nodes=True
    material.use_backface_culling=False
    nodes=material.node_tree.nodes
    nodes.clear()
    output=nodes.new("ShaderNodeOutputMaterial")
    emission=nodes.new("ShaderNodeEmission")
    texture=nodes.new("ShaderNodeTexImage")
    texture.image=bpy.data.images.load(str(ROOT/"textures/weather/storm_backdrop.png"),check_existing=True)
    emission.inputs["Strength"].default_value=0.58
    material.node_tree.links.new(texture.outputs["Color"],emission.inputs["Color"])
    material.node_tree.links.new(emission.outputs[0],output.inputs["Surface"])
    # Vòm liên tục tránh đường nối ngang giữa biển mây và hậu cảnh.
    bm=bmesh.new()
    bmesh.ops.create_uvsphere(bm,u_segments=128,v_segments=64,radius=85)
    layer=bm.loops.layers.uv.verify()
    for face in bm.faces:
        face.normal_flip()
        coords=[]
        for loop in face.loops:
            point=loop.vert.co
            u=math.atan2(point.y,point.x)/math.tau+0.5
            v=math.asin(max(-1,min(1,point.z/85)))/math.pi+0.5
            coords.append((loop,u,v))
        crosses=max(u for _,u,_ in coords)-min(u for _,u,_ in coords)>0.5
        for loop,u,v in coords:
            loop[layer].uv=(u+1 if crosses and u<0.5 else u,v)
    mesh=bpy.data.meshes.new("StormVault")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    for face in mesh.polygons:
        face.use_smooth=True
    obj=bpy.data.objects.new("StormVault",mesh)
    group.objects.link(obj)
    obj.visible_shadow=False


def setup_preview(destination: Path) -> None:
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1440
    scene.render.resolution_y=1000
    scene.render.resolution_percentage=100
    scene.view_settings.view_transform="AgX"
    world=bpy.data.worlds.new("StormSky")
    world.use_nodes=True
    scene.world=world
    nodes=world.node_tree.nodes
    env=nodes.new("ShaderNodeTexEnvironment")
    env.image=bpy.data.images.load(str(TEX_SOURCE/"overcast_soil_puresky_2k.hdr"))
    bg=next(n for n in nodes if n.type=="BACKGROUND")
    world.node_tree.links.new(env.outputs[0],bg.inputs["Color"])
    bg.inputs["Strength"].default_value=0.42
    lights=KIT["collection"]("PreviewLighting")
    for name, loc, color, energy, size in (("CloudBreak",(9,-3,24),(0.68,0.87,1),24000,8),("SoftFill",(-13,-14,14),(0.51,0.67,0.76),18000,16)):
        data=bpy.data.lights.new(name,"AREA")
        data.energy=energy
        data.color=color
        data.shape="DISK"
        data.size=size
        obj=bpy.data.objects.new(name,data)
        lights.objects.link(obj)
        obj.location=loc
        obj.rotation_euler=(Vector((0,3,0))-obj.location).to_track_quat("-Z","Y").to_euler()
    cam_data=bpy.data.cameras.new("ConceptReview")
    cam=bpy.data.objects.new("ConceptReview",cam_data)
    scene.collection.objects.link(cam)
    cam.location=(9,-46,33)
    cam.rotation_euler=(Vector((0,3,5))-cam.location).to_track_quat("-Z","Y").to_euler()
    cam_data.type="ORTHO"
    cam_data.ortho_scale=56
    scene.camera=cam
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(destination)


def build() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m={
        "paving":pbr("paving","stone_tiles_02",(0.32,0.39,0.41)),
        "stone":pbr("stone","aerial_rocks_02",(0.29,0.36,0.38)),
        "rock":pbr("rock","aerial_rocks_02",(0.22,0.28,0.31)),
        "edge":pbr("edge","aerial_rocks_02",(0.37,0.42,0.43)),
        "shadow":flat("recess",(0.065,0.10,0.13)),
        "inlay":flat("wind_seal",(0.19,0.27,0.28)),
        "bronze":flat("aged_bronze",(0.36,0.28,0.15),0.65),
        "cloth":cloth_material(),
    }
    for index,tint in enumerate(((0.31,0.36,0.37),(0.37,0.41,0.42),(0.40,0.43,0.43))):
        m["tile_%d"%index]=pbr("tile_variants/tone_%d"%index,"stone_tiles_02",tint)
    build_stage(m,KIT["collection"]("SanctuaryStage"))
    build_shrine(m,KIT["collection"]("SanctuaryShrine"))
    build_clouds(KIT["collection"]("SanctuaryWeather"))
    accents=KIT["collection"]("SanctuaryShrine")
    moss=flat("moss",(0.23,0.28,0.16))
    growth=bmesh.new()
    for i in range(96):
        a=math.tau*i/96
        radius=RNG.uniform(14.2,14.8)
        x,y=math.cos(a)*radius,math.sin(a)*radius
        for blade in range(1):
            ox,oy=RNG.uniform(-0.12,0.12),RNG.uniform(-0.12,0.12)
            foot=Vector((x+ox,y+oy,0.04))
            tip=foot+Vector((0.25+RNG.random()*0.25,0.08,RNG.uniform(0.12,0.38)))
            growth.faces.new((growth.verts.new(foot+Vector((-0.035,0,0))),growth.verts.new(foot+Vector((0.035,0,0))),growth.verts.new(tip)))
    emit("WindBentGrasses",growth,moss,accents,bevel=0)
    # Độ mòn nằm trên mesh thật để bản xuất giữ được mép đá.
    for obj in list(accents.objects):
        if obj.type=="MESH" and obj.name.startswith(("WingStone_","BrokenSanctuaryCrown","DragonRoostShelf")):
            mod=obj.modifiers.new("StoneErosion","DISPLACE")
            tex=bpy.data.textures.new(obj.name+"_erosion",type="CLOUDS")
            tex.noise_scale=0.31
            mod.texture=tex
            mod.strength=0.055
            mod.mid_level=0.5
    # Va chạm lấy từ đúng mesh sàn và lan can trước bevel để mép hình khớp mặt đi.
    coll=KIT["collection"]("SanctuaryCollision")
    for name in ("ArenaFloor","ParapetStone","ParapetPosts"):
        original=bpy.data.objects[name]
        obj=bpy.data.objects.new(name+"-colonly",original.data.copy())
        coll.objects.link(obj)
        obj.hide_render=True
        obj.display_type="WIRE"


if __name__=="__main__":
    build()
    output=Path(sys.argv[sys.argv.index("--")+1])
    output.mkdir(parents=True,exist_ok=True)
    setup_preview(output/"blender_review.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(output/"wind_sanctuary.blend"), relative_remap=False)
    bpy.ops.render.render(write_still=True)
