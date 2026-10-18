# Thư viện dùng chung cho đội dựng model quái (Blender 5.2, chạy nền hoặc qua MCP).
# Quy ước:
#  - Toạ độ Blender: Z lên, mặt trước quái quay về -Y. Đổi từ Godot: blender(x, y, z) = (X_g, -Z_g, Y_g).
#  - Mỗi object đặt origin đúng ở pivot (khớp) theo đặc tả; đỉnh mesh tính theo toạ độ cục bộ quanh pivot.
#  - MÀU: lớp màu đỉnh "Col" trong bmesh nhận giá trị sRGB (hex/255). KHÔNG tự đổi sRGB -> linear
#    (Blender đã tự đổi khi lưu; tự đổi thêm = đổi hai lần, màu tối hẳn — lỗi của bản dựng trước).
#  - Mặt hướng lên (normal.z > 0.5) tô màu "top", hướng xuống tô "bottom", còn lại "base" (giống bộ khối gió).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix


def srgb(hex_str):
    h = hex_str.lstrip("#")
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0)


def godot_to_blender(x, y, z):
    return Vector((x, -z, y))


def kit_material():
    m = bpy.data.materials.get("Kit_Stone")
    if m:
        return m
    m = bpy.data.materials.new("Kit_Stone")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.95
    return m


def glow_material(name="Enemy1_Glow", hex_str="#FF7A4D", strength=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = srgb(hex_str)
    b.inputs["Base Color"].default_value = (*c, 1.0)
    for key in ("Emission Color", "Emission"):
        if key in b.inputs:
            b.inputs[key].default_value = (*c, 1.0)
            break
    if "Emission Strength" in b.inputs:
        b.inputs["Emission Strength"].default_value = strength
    return m


def bevel(bm, offset=0.025, segments=1):
    """Vát cạnh cho khối lớn (bộ khối gió vát 0.02–0.03 m, 1 đoạn)."""
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=offset, segments=segments, affect="EDGES", profile=0.5)


def paint(bm, base, top=None, bottom=None, face_filter=None):
    """Tô màu đỉnh theo hướng mặt. base/top/bottom là chuỗi hex. face_filter(face) -> bool để chỉ tô một phần."""
    bm.normal_update()
    col = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
    cb, ct, cd = srgb(base), srgb(top or base), srgb(bottom or base)
    for f in bm.faces:
        if face_filter and not face_filter(f):
            continue
        c = ct if f.normal.z > 0.5 else (cd if f.normal.z < -0.5 else cb)
        for l in f.loops:
            l[col] = (*c, 1.0)
    return bm


def finish(bm, name, pivot, material=None, parent=None, collection=None):
    """Tạo object từ bmesh (đỉnh theo toạ độ cục bộ quanh pivot), origin = pivot (toạ độ Blender, world)."""
    for f in bm.faces:
        f.smooth = False
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # Đặt "Col" làm lớp màu đang dùng + lớp màu render: không có thì Workbench (render_preview) hiện xám
    col = me.color_attributes.get("Col")
    if col:
        me.color_attributes.active_color = col
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    ob = bpy.data.objects.new(name, me)
    ob.location = pivot
    me.materials.append(material or kit_material())
    (collection or bpy.context.scene.collection).objects.link(ob)
    if parent:
        mw = ob.matrix_world.copy()
        ob.parent = parent
        ob.matrix_world = mw
    return ob


def merge(bms):
    out = bmesh.new()
    me = bpy.data.meshes.new("_tmp_merge")
    for b in bms:
        b.to_mesh(me)
        out.from_mesh(me)
        b.free()
    bpy.data.meshes.remove(me)
    return out


def check_colors(obj, expect_hex_list):
    """Kiểm màu: đọc color_srgb của lớp "Col" và in các màu khác nhau (đối chiếu với hex đặc tả)."""
    me = obj.data
    a = me.color_attributes.get("Col")
    if a is None:
        print(obj.name, "KHÔNG có lớp màu Col")
        return
    found = sorted({"#%02X%02X%02X" % tuple(round(c * 255) for c in d.color_srgb[:3]) for d in a.data})
    print(obj.name, "màu thực:", found, "| mong đợi:", expect_hex_list)


def render_preview(path_png, objects, background_hex="#93A39A", size=600, silhouette=False, distance=4.5):
    """Render thử ở góc camera game (cúi 50° nhìn từ phía trước = phía -Y) bằng Workbench, nền màu sàn map."""
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "SINGLE" if silhouette else "VERTEX"
    if silhouette:
        sh.single_color = (0, 0, 0)
    sh.background_type = "VIEWPORT"
    sh.background_color = srgb(background_hex)
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.film_transparent = False
    # Tâm khung = tâm bao các object
    pts = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    center = sum(pts, Vector()) / len(pts)
    cam_data = bpy.data.cameras.get("_PreviewCam") or bpy.data.cameras.new("_PreviewCam")
    cam_data.lens_unit = "FOV"
    cam_data.angle = math.radians(30)
    cam = bpy.data.objects.get("_PreviewCam") or bpy.data.objects.new("_PreviewCam", cam_data)
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    pitch = math.radians(50)
    cam.location = center + Vector((0, -distance * math.cos(pitch), distance * math.sin(pitch)))
    cam.rotation_euler = (math.radians(90) - pitch, 0, 0)
    sc.camera = cam
    sc.render.filepath = path_png
    bpy.ops.render.render(write_still=True)
    print("đã render", path_png)
