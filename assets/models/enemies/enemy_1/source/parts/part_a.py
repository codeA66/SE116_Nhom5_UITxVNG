# PHẦN A (thân + đầu) của Quái 1 "Liềm gió tha hoá" (kamaitachi bị tha hoá).
# Object: Hips, Torso, Head, EyesGlow (con của Head). Origin = pivot, không xoay lúc nghỉ.
# Toạ độ pivot theo Godot (X, Y lên, Z trước); trong file này dựng theo toạ độ Godot rồi đổi sang Blender.
import bpy, bmesh, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C

# Bảng màu (sRGB hex)
FUR = "#4A3B36"
FUR_TOP = "#725B4E"
FUR_BOT = "#3A2E2A"
CREAM = "#D8CFC0"
INK = "#241C2B"
EYE = "#C8553D"

OCT = 8
_R = 1.0 / math.cos(math.radians(180.0 / OCT))  # đổi nửa-cạnh phẳng sang bán kính đa giác


def _g(p, pivot):
    """Điểm Godot (world) -> toạ độ Blender cục bộ quanh pivot."""
    return C.godot_to_blender(*(Vector(p) - Vector(pivot)))


def _loft(rings, pivot):
    """Các vòng bát giác (c, nửa_rộng_x, nửa_dày, ) theo đường dẫn; trả bmesh kín.
    Mỗi vòng nằm trong mặt phẳng vuông góc đường dẫn, trục 1 = X, trục 2 = cross(X, tiếp tuyến)."""
    bm = bmesh.new()
    cs = [Vector(r[0]) for r in rings]
    vr = []
    for i, r in enumerate(rings):
        a = cs[max(i - 1, 0)]
        b = cs[min(i + 1, len(cs) - 1)]
        t = (b - a).normalized()
        ax1 = Vector((1, 0, 0))
        ax2 = ax1.cross(t).normalized()
        ring = []
        for k in range(OCT):
            ang = math.radians(22.5 + 45.0 * k)
            p = cs[i] + ax1 * (math.cos(ang) * r[1] * _R) + ax2 * (math.sin(ang) * r[2] * _R)
            ring.append(bm.verts.new(_g(p, pivot)))
        vr.append(ring)
    for i in range(len(vr) - 1):
        for k in range(OCT):
            bm.faces.new((vr[i][k], vr[i][(k + 1) % OCT], vr[i + 1][(k + 1) % OCT], vr[i + 1][k]))
    bm.faces.new(vr[0])
    bm.faces.new(vr[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def _hull(points, pivot):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(_g(p, pivot))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    inner = [g for g in res["geom_interior"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.delete(bm, geom=inner, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def _box(center, size, pivot, rot_x=0.0, rot_z=0.0):
    """Hộp nhỏ (Godot), xoay quanh X rồi Z (độ)."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                v = Vector((sx * hx, sy * hy, sz * hz))
                cx, sxr = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
                v = Vector((v.x, v.y * cx - v.z * sxr, v.y * sxr + v.z * cx))
                cz, szr = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
                v = Vector((v.x * cz - v.y * szr, v.x * szr + v.y * cz, v.z))
                pts.append(Vector(center) + v)
    return _hull(pts, pivot)


def _blob(center, radii, pivot, rot_x=0.0, rot_z=0.0):
    """Cầu thấp (icosphere 1 lần chia) co theo radii: dùng cho tai tròn."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    cx, sxr = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
    cz, szr = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
    for v in bm.verts:
        p = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))  # Blender cục bộ tạm
        # đổi sang Godot: radii cho theo Godot (x, y, z) -> giữ nguyên chỉ số, xoay rồi đưa vào Blender
        g = Vector((v.co.x * radii[0], v.co.z * radii[1], v.co.y * radii[2]))
        g = Vector((g.x, g.y * cx - g.z * sxr, g.y * sxr + g.z * cx))
        g = Vector((g.x * cz - g.y * szr, g.x * szr + g.y * cz, g.z))
        v.co = _g(Vector(center) + g, (0, 0, 0)) if False else C.godot_to_blender(*(Vector(center) + g - Vector(pivot)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def _tris(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


def _paint_fur(bm):
    C.paint(bm, FUR, FUR_TOP, FUR_BOT)


# ---------------------------------------------------------------- các bộ phận
HIPS_PIVOT = (0.0, 0.55, -0.05)
TORSO_PIVOT = (0.0, 0.62, 0.0)
HEAD_PIVOT = (0.0, 1.10, 0.30)


def _build_hips():
    p = HIPS_PIVOT
    rings = [
        ((0, 0.43, -0.08), 0.12, 0.13),
        ((0, 0.50, -0.07), 0.16, 0.17),
        ((0, 0.57, -0.05), 0.17, 0.17),
        ((0, 0.65, -0.01), 0.14, 0.13),
    ]
    # đường dẫn của hông gần thẳng đứng nhưng ax2 = cross(X, t) -> dày theo Z; ok
    bm = _loft(rings, p)
    C.bevel(bm, 0.02)
    _paint_fur(bm)
    # mặt dưới hông tối hơn nhưng mặt trước-dưới (chỗ gắn chân) giữ màu bụng kem nhạt
    C.paint(bm, FUR, FUR_TOP, FUR_BOT)
    return bm


def _build_torso():
    p = TORSO_PIVOT
    # chữ S: hông rộng 0.34 -> eo 0.28 -> ngực 0.40 x 0.30 -> cổ; nghiêng ~35 độ về trước
    rings = [
        ((0, 0.60, -0.06), 0.34 / 2, 0.30 / 2),   # hông
        ((0, 0.75, 0.05), 0.28 / 2, 0.26 / 2),    # eo
        ((0, 0.88, 0.15), 0.40 / 2, 0.30 / 2),    # ngực
        ((0, 1.00, 0.22), 0.36 / 2, 0.26 / 2),    # vai/ngực trên
        ((0, 1.09, 0.29), 0.18 / 2, 0.18 / 2),    # cổ
    ]
    bm = _loft(rings, p)
    C.bevel(bm, 0.02)
    _paint_fur(bm)
    bm.normal_update()
    # yếm kem: mặt trước/dưới của ngực-cổ (Blender: trước = -Y, z cục bộ = y Godot - 0.62)
    def bib(f):
        c = f.calc_center_median()
        return f.normal.y < -0.25 and c.z > 0.12 and abs(c.x) < 0.14
    C.paint(bm, CREAM, CREAM, CREAM, face_filter=bib)
    # mảng mực: một bên vai trái (+X) của thân
    def ink(f):
        c = f.calc_center_median()
        return c.x > 0.10 and 0.17 < c.z < 0.36 and c.y > -0.20 and f.normal.x > 0.3
    C.paint(bm, INK, INK, INK, face_filter=ink)
    # gai lưng (3 nêm nhỏ, sáng hơn một bậc) cho silhouette chồn
    spines = []
    for (y, z, s) in ((0.84, -0.02, 0.045), (0.74, -0.09, 0.04), (0.65, -0.14, 0.035)):
        w = _hull([
            (-0.035, y - 0.04, z - 0.07), (0.035, y - 0.04, z - 0.07),
            (-0.035, y - 0.04, z + 0.05), (0.035, y - 0.04, z + 0.05),
            (0, y + s, z - 0.09),
        ], p)
        C.paint(w, FUR_TOP, FUR_TOP, FUR_TOP)
        spines.append(w)
    return C.merge([bm] + spines)


def _ear_rings(sx, cy, z, k, dz):
    # tai tròn cao 0.10: vòm 4 vòng, nghiêng nhẹ ra ngoài; k = tỉ lệ (mặt trong nhỏ hơn)
    x0 = sx * 0.085
    return [
        ((x0, cy + 0.08, z + dz), 0.10 / 2 * k, 0.06 / 2 * k),
        ((x0 + sx * 0.006, cy + 0.13, z + dz), 0.100 / 2 * k, 0.055 / 2 * k),
        ((x0 + sx * 0.014, cy + 0.19, z + dz), 0.075 / 2 * k, 0.040 / 2 * k),
        ((x0 + sx * 0.020, cy + 0.225, z + dz), 0.035 / 2 * k, 0.025 / 2 * k),
    ]


def _build_head():
    p = HEAD_PIVOT
    cy = HEAD_PIVOT[1]
    z0 = HEAD_PIVOT[2]
    # nêm: sọ rộng 0.26 -> mõm 0.06, dài 0.38 về +Z (sau sọ -0.08 .. mũi +0.30)
    rings = [
        ((0, cy + 0.00, z0 - 0.08), 0.20 / 2, 0.18 / 2),
        ((0, cy + 0.01, z0 - 0.02), 0.26 / 2, 0.22 / 2),
        ((0, cy + 0.00, z0 + 0.10), 0.22 / 2, 0.19 / 2),
        ((0, cy - 0.025, z0 + 0.22), 0.12 / 2, 0.11 / 2),
        ((0, cy - 0.04, z0 + 0.30), 0.06 / 2, 0.07 / 2),
    ]
    bm = _loft(rings, p)
    _paint_fur(bm)
    bm.normal_update()
    # cằm + má dưới + mặt dưới mõm màu kem
    def chin(f):
        c = f.calc_center_median()
        return f.normal.z < -0.3 or (c.z < -0.0 and False)
    # Blender: z cục bộ = Y Godot; mặt dưới có normal.z < 0
    def chin2(f):
        c = f.calc_center_median()
        return f.normal.z < -0.25 and c.y < 0.0 + 0.30  # cả phần dưới đầu
    C.paint(bm, CREAM, CREAM, CREAM, face_filter=lambda f: f.normal.z < -0.3 and -f.calc_center_median().y > 0.0)
    # mũi mực
    nose = _hull([
        (-0.032, cy - 0.015, z0 + 0.26), (0.032, cy - 0.015, z0 + 0.26),
        (-0.032, cy - 0.065, z0 + 0.26), (0.032, cy - 0.065, z0 + 0.26),
        (-0.025, cy - 0.015, z0 + 0.325), (0.025, cy - 0.015, z0 + 0.325),
        (-0.025, cy - 0.06, z0 + 0.325), (0.025, cy - 0.06, z0 + 0.325),
    ], p)
    C.bevel(nose, 0.006)
    C.paint(nose, INK, INK, INK)
    parts = [bm, nose]
    # tai nhỏ tròn cao 0.10: vỏ lông + mặt trong kem
    for sx in (-1, 1):
        ear = _loft(_ear_rings(sx, cy, z0 - 0.045, 1.0, 0.0), p)
        C.paint(ear, FUR_TOP, FUR_TOP, FUR_BOT)
        inner = _loft(_ear_rings(sx, cy, z0 - 0.045, 0.62, 0.02), p)
        C.paint(inner, CREAM, CREAM, CREAM)
        parts += [ear, inner]
    return C.merge(parts)


def _build_eyes():
    p = HEAD_PIVOT
    cy = HEAD_PIVOT[1]
    z0 = HEAD_PIVOT[2]
    parts = []
    for sx in (-1, 1):
        # mắt dẹt hơi xếch, nằm trên mặt bên-trước sọ
        b = _box((sx * 0.082, cy + 0.045, z0 + 0.10), (0.06, 0.055, 0.085), p, rot_z=sx * 20)
        C.paint(b, EYE, EYE, EYE)
        parts.append(b)
    return C.merge(parts)


def build(collection):
    """Dựng phần A, trả dict tên -> Object."""
    coll = collection
    hips = C.finish(_build_hips(), "Hips", C.godot_to_blender(*HIPS_PIVOT), collection=coll)
    torso = C.finish(_build_torso(), "Torso", C.godot_to_blender(*TORSO_PIVOT), collection=coll)
    head = C.finish(_build_head(), "Head", C.godot_to_blender(*HEAD_PIVOT), collection=coll)
    eyes = C.finish(_build_eyes(), "EyesGlow", C.godot_to_blender(*HEAD_PIVOT),
                    material=C.glow_material("Enemy1_Glow", "#FF7A4D"), collection=coll)
    for o in (hips, torso, head, eyes):
        ca = o.data.color_attributes.get("Col")
        if ca is not None:
            o.data.color_attributes.active_color = ca  # Workbench đọc lớp màu active
            o.data.color_attributes.render_color_index = o.data.color_attributes.find("Col")
    bpy.context.view_layer.update()
    # Mắt dùng material phát sáng, không cần lớp màu đỉnh (có lớp màu thì exporter tách thêm material Enemy1_Glow.001)
    ca_eyes = eyes.data.color_attributes.get("Col")
    if ca_eyes is not None:
        eyes.data.color_attributes.remove(ca_eyes)
    eyes.parent = head
    eyes.matrix_parent_inverse = head.matrix_world.inverted()
    bpy.context.view_layer.update()
    return {"Hips": hips, "Torso": torso, "Head": head, "EyesGlow": eyes}


def _report(objs):
    total = 0
    for name, o in objs.items():
        n = sum(len(pl.vertices) - 2 for pl in o.data.polygons)
        total += n
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        # đổi lại Godot: (x, z_b, -y_b)
        gmn = (mn.x, mn.z, -mx.y)
        gmx = (mx.x, mx.z, -mn.y)
        print("OBJ %-9s tris=%4d pivotG=(%.2f,%.2f,%.2f) Godot min=(%.3f,%.3f,%.3f) max=(%.3f,%.3f,%.3f) size=(%.3f,%.3f,%.3f)" % (
            name, n, o.matrix_world.translation.x, o.matrix_world.translation.z, -o.matrix_world.translation.y,
            *gmn, *gmx, gmx[0] - gmn[0], gmx[1] - gmn[1], gmx[2] - gmn[2]))
    print("TỔNG tam giác:", total)


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    out = r"C:\Users\DANGQU~1\AppData\Local\Temp\claude\C--Code-UITxVNG-SE116-Nhom5-UITxVNG\f4275fa5-8d1d-4075-a562-9e0a975e0903\scratchpad"
    objs = build(bpy.context.scene.collection)
    _report(objs)
    exp = [FUR, FUR_TOP, FUR_BOT, CREAM, INK, EYE]
    for o in objs.values():
        if o.name != "EyesGlow":
            C.check_colors(o, exp)
    C.check_colors(objs["EyesGlow"], [EYE])
    lst = list(objs.values())
    C.render_preview(os.path.join(out, "part_a.png"), lst, size=700, distance=2.4)
    if os.environ.get("PART_A_DEBUG"):
        cam = bpy.data.objects["_PreviewCam"]
        ctr = Vector((0, 0.1, 0.85))
        for nm, off, rot in (("side", (2.4, 0, 0.2), (84, 0, 90)), ("34", (1.6, -1.6, 0.9), (72, 0, 45))):
            cam.location = ctr + Vector(off)
            cam.rotation_euler = tuple(math.radians(a) for a in rot)
            bpy.context.scene.render.filepath = os.path.join(out, "part_a_dbg_%s.png" % nm)
            bpy.ops.render.render(write_still=True)
    C.render_preview(os.path.join(out, "part_a_sil.png"), lst, size=700, silhouette=True, distance=2.4)
