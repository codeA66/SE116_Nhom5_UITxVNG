# PHẦN C của Quái 1 "Liềm gió tha hoá": tay trái (Arm_L), tay phải + lưỡi liềm (ArmBlade_R), BladeGlow.
# Mọi toạ độ viết theo hệ Godot (X, Y lên, Z trước), tương đối quanh pivot, đổi sang Blender ở hàm _g.
import bpy, bmesh, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C

# ---- Màu theo đặc tả ----
ARM_BASE, ARM_TOP, ARM_BOT = "#4A3B36", "#725B4E", "#3A2E2A"
STEEL = "#2E3640"
EDGE = "#E3E8EA"
INK = "#241C2B"
CLAW = "#D8CFC0"
GLOW = "#FF7A4D"

# ---- Pivot (Godot) ----
PIVOT_L = (0.20, 0.92, 0.18)
PIVOT_R = (-0.20, 0.92, 0.18)

# ---- Thông số lưỡi (đề bài) ----
CHORD = 0.72
SAGITTA = 0.22
SEGMENTS = 8
W_BASE, W_TIP = 0.16, 0.02
T_SPINE_BASE, T_SPINE_TIP = 0.04, 0.02   # độ dày sống (tổng)
T_EDGE = 0.01                            # độ dày cạnh sắc
EDGE_BAND = 0.03                         # bề rộng dải cạnh sắc sáng
GLOW_W = 0.025
TILT_DEG = 30.0                          # mặt phẳng lưỡi nghiêng so với mặt ngang
# Cổ tay phải (Godot, cục bộ quanh vai) và hướng dây cung lúc nghỉ
WRIST_R = Vector((-0.08, -0.25, 0.04))
CHORD_DIR_REST = Vector((-0.85, -0.23, 0.47)).normalized()


def _g(v):
    return C.godot_to_blender(v[0], v[1], v[2])


def _frame(t):
    t = Vector(t).normalized()
    ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
    u = t.cross(ref).normalized()
    v = t.cross(u).normalized()
    return u, v


def _limb(bm, pts, radii, sides=6, cap_start=True, cap_end=True):
    """Chi thon theo đường gấp khúc; mỗi điểm một vòng 'sides' đỉnh."""
    pts = [Vector(p) for p in pts]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        u, v = _frame(t)
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            q = p + radii[i] * (math.cos(a) * u + math.sin(a) * v)
            ring.append(bm.verts.new(_g(q)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new([rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]])
    if cap_start:
        bm.faces.new(rings[0])
    if cap_end:
        bm.faces.new(rings[-1][::-1])
    return rings


def _claw(bm, base, direction, length=0.06, radius=0.014):
    """Móng: chóp 4 cạnh dài 'length' m."""
    d = Vector(direction).normalized()
    u, v = _frame(d)
    ring = [bm.verts.new(_g(Vector(base) + radius * (math.cos(a) * u + math.sin(a) * v)))
            for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    tip = bm.verts.new(_g(Vector(base) + d * length))
    bm.faces.new(ring[::-1])
    for k in range(4):
        bm.faces.new([ring[k], ring[(k + 1) % 4], tip])


def _recalc(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


# ------------------------------------------------------------------ Tay trái
def _build_arm_l():
    bm = bmesh.new()
    pts = [(0, 0, 0), (0.02, -0.12, 0.05), (0.03, -0.24, 0.12), (0.035, -0.34, 0.20), (0.035, -0.40, 0.25)]
    rad = [0.06, 0.052, 0.042, 0.038, 0.046]   # bàn tay phình nhẹ ở cuối
    _limb(bm, pts, rad)
    _recalc(bm)
    C.paint(bm, ARM_BASE, ARM_TOP, ARM_BOT)
    cl = bmesh.new()
    hand = Vector(pts[-1])
    cdir = Vector((0, -0.55, 0.83))
    for dx, yaw in ((-0.03, -0.18), (0.0, 0.0), (0.03, 0.18)):
        d = Vector((cdir.x + yaw, cdir.y, cdir.z))
        _claw(cl, hand + Vector((dx, -0.01, 0.01)), d, 0.06, 0.014)
    _recalc(cl)
    C.paint(cl, CLAW)
    return C.merge([bm, cl])


# ------------------------------------------------------------------ Lưỡi liềm
def blade_frame():
    """d = hướng dây cung, c = hướng lõm (nghiêng 30 độ lên), n = pháp tuyến mặt rộng (hướng lên)."""
    d = CHORD_DIR_REST.copy()
    up = Vector((0, 1, 0))
    ch = up.cross(d)  # vuông góc d và nằm ngang
    # phía lõm (cạnh sắc) quay vào trong/trước, theo hướng chém phải -> trái
    if ch.dot(Vector((0.59, 0, 0.8))) < 0:
        ch = -ch
    ch.normalize()
    ang = math.radians(TILT_DEG)
    c = (ch * math.cos(ang) + up * math.sin(ang)).normalized()
    n = d.cross(c).normalized()
    if n.y < 0:
        n = -n
    return d, c, n


def blade_geometry():
    d, c, n = blade_frame()
    p0 = WRIST_R - c * 0.06           # đầu sống lưỡi (gốc)
    R = (CHORD ** 2 / 4 + SAGITTA ** 2) / (2 * SAGITTA)
    theta = math.asin(CHORD / 2 / R)
    mid = p0 + d * (CHORD / 2)
    cen = mid + c * (R - SAGITTA)
    return dict(d=d, c=c, n=n, p0=p0, R=R, theta=theta, cen=cen)


def _spine_pt(g, phi, r):
    rho = math.sin(phi) * g["d"] - math.cos(phi) * g["c"]
    return g["cen"] + r * rho


def _build_blade_bm():
    g = blade_geometry()
    R, th = g["R"], g["theta"]
    n = g["n"]
    bm = bmesh.new()
    stations = []
    for k in range(SEGMENTS + 1):
        s = k / SEGMENTS
        phi = -th + 2 * th * s
        w = W_BASE + (W_TIP - W_BASE) * s
        t = (T_SPINE_BASE + (T_SPINE_TIP - T_SPINE_BASE) * s) / 2
        e = T_EDGE / 2
        bw = max(w - EDGE_BAND, w * 0.5)
        hb = t + (e - t) * (bw / w)
        # (khoảng vào trong từ sống, độ cao theo n)
        prof = [(0, t), (bw, hb), (w, e), (w, -e), (bw, -hb), (0, -t)]
        stations.append([bm.verts.new(_g(_spine_pt(g, phi, R - dr) + n * h)) for (dr, h) in prof])
    tag = {}
    # cạnh i: 0 sống-trên | 1 băng trên | 2 mép | 3 băng dưới | 4 sống-dưới | 5 sống ngoài
    for k in range(SEGMENTS):
        for i in range(6):
            f = bm.faces.new([stations[k][i], stations[k][(i + 1) % 6], stations[k + 1][(i + 1) % 6], stations[k + 1][i]])
            tag[f] = (k, i)
    tag[bm.faces.new(stations[0][::-1])] = (0, 9)
    tag[bm.faces.new(stations[-1])] = (SEGMENTS - 1, 9)
    _recalc(bm)
    col = bm.loops.layers.color.new("Col")
    cs, ce, ci = C.srgb(STEEL), C.srgb(EDGE), C.srgb(INK)
    for f, (k, i) in tag.items():
        if i in (1, 2, 3):
            c_ = ce
        elif k <= 1 and (i != 9 or k == 0):
            c_ = ci
        else:
            c_ = cs
        for l in f.loops:
            l[col] = (*c_, 1.0)
    return bm, g


def _build_glow_bm(g):
    """Dải sáng 0.025 m nằm trên dải cạnh sắc, bám cạnh lõm."""
    R, th, n = g["R"], g["theta"], g["n"]
    bm = bmesh.new()
    rings = []
    for k in range(SEGMENTS + 1):
        s = k / SEGMENTS
        phi = -th + 2 * th * s
        w = W_BASE + (W_TIP - W_BASE) * s
        t = (T_SPINE_BASE + (T_SPINE_TIP - T_SPINE_BASE) * s) / 2
        e = T_EDGE / 2
        gw = min(GLOW_W, w * 0.5)
        r_out = w - 0.002
        r_in = r_out - gw

        def hh(dr):
            # mặt nêm nội suy sống -> mép, nhô 0.004 để không z-fight
            return t + (e - t) * (dr / w) + 0.004
        prof = ((r_in, hh(r_in)), (r_out, hh(r_out)), (r_out, -hh(r_out)), (r_in, -hh(r_in)))
        rings.append([bm.verts.new(_g(_spine_pt(g, phi, R - dr) + n * h)) for (dr, h) in prof])
    for k in range(SEGMENTS):
        for i in range(4):
            bm.faces.new([rings[k][i], rings[k][(i + 1) % 4], rings[k + 1][(i + 1) % 4], rings[k + 1][i]])
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    _recalc(bm)
    return bm


def _build_arm_r_bm(g):
    bm = bmesh.new()
    w = WRIST_R
    pts = [Vector((0, 0, 0)), w * 0.35, w * 0.7, Vector(w), w + g["c"] * 0.02]
    rad = [0.06, 0.054, 0.048, 0.056, 0.056]   # loe nhẹ thành vòng bọc cổ tay nơi gắn lưỡi
    _limb(bm, pts, rad)
    _recalc(bm)
    C.paint(bm, ARM_BASE, ARM_TOP, ARM_BOT)
    return bm


def build(collection):
    out = {}
    out["Arm_L"] = C.finish(_build_arm_l(), "Arm_L", C.godot_to_blender(*PIVOT_L), collection=collection)
    blade_bm, g = _build_blade_bm()
    arm_bm = _build_arm_r_bm(g)
    ab = C.finish(C.merge([arm_bm, blade_bm]), "ArmBlade_R", C.godot_to_blender(*PIVOT_R), collection=collection)
    out["ArmBlade_R"] = ab
    gl = C.finish(_build_glow_bm(g), "BladeGlow", C.godot_to_blender(*PIVOT_R),
                  material=C.glow_material("Enemy1_Glow", GLOW), parent=ab, collection=collection)
    out["BladeGlow"] = gl
    return out


# ------------------------------------------------------------------ Đo đạc / báo cáo
def tip_local_godot():
    g = blade_geometry()
    return g["p0"] + g["d"] * CHORD


def extension_angles(target_z=1.275):
    """Góc xoay quanh pivot (Godot Euler YXZ: pitch X áp trước, yaw Y sau) để mũi với tới z thế giới = target_z."""
    tip = tip_local_godot()
    piv = Vector(PIVOT_R)
    best = []
    for ai in range(-180, 181):
        a = math.radians(ai)
        for bi in range(-90, 91):
            b = math.radians(bi)
            y1 = tip.y * math.cos(b) - tip.z * math.sin(b)
            z1 = tip.y * math.sin(b) + tip.z * math.cos(b)
            x2 = tip.x * math.cos(a) + z1 * math.sin(a)
            z2 = -tip.x * math.sin(a) + z1 * math.cos(a)
            wx, wy, wz = piv.x + x2, piv.y + y1, piv.z + z2
            if abs(wz - target_z) < 0.01 and 0.6 <= wy <= 1.1:
                best.append((abs(ai) + abs(bi), ai, bi, wx, wy, wz))
    best.sort()
    return best[:3]


def _render(path, objects, mode, size=700, distance=3.0, silhouette=False):
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
    sh.background_color = C.srgb("#93A39A")
    sc.render.resolution_x = sc.render.resolution_y = size
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    center = sum(pts, Vector()) / len(pts)
    cd = bpy.data.cameras.get("_C") or bpy.data.cameras.new("_C")
    cd.lens_unit = "FOV"
    cd.angle = math.radians(30)
    cam = bpy.data.objects.get("_C") or bpy.data.objects.new("_C", cd)
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    if mode == "top":
        cam.location = center + Vector((0, 0, distance))
        cam.rotation_euler = (0, 0, 0)
    else:
        p = math.radians(50)
        cam.location = center + Vector((0, -distance * math.cos(p), distance * math.sin(p)))
        cam.rotation_euler = (math.radians(90) - p, 0, 0)
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("đã render", path)


def _tris(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


if __name__ == "__main__":
    SCR = r"C:\Users\DANGQU~1\AppData\Local\Temp\claude\C--Code-UITxVNG-SE116-Nhom5-UITxVNG\f4275fa5-8d1d-4075-a562-9e0a975e0903\scratchpad"
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)  # bỏ Cube/Light/Camera mặc định
    col = bpy.context.scene.collection
    objs = build(col)
    # Thân tạm chỉ để dễ nhìn (không thuộc phần C), toạ độ Godot: tâm (0,1.15,0.05), cỡ 0.44 x 0.75 x 0.30
    tb = bmesh.new()
    bmesh.ops.create_cube(tb, size=1.0)
    for v in tb.verts:
        v.co = C.godot_to_blender(v.co.x * 0.44, 1.15 + v.co.z * 0.75, 0.05 + v.co.y * 0.30)
    C.bevel(tb, 0.03)
    C.paint(tb, "#8A8580", "#9A958F", "#6E6A66")
    tmp = C.finish(tb, "_TmpTorso", (0, 0, 0), collection=col)
    allo = list(objs.values()) + [tmp]
    for nm, o in objs.items():
        print(nm, "pivot(Blender)", tuple(round(x, 3) for x in o.location),
              "kích thước(B) X,Y,Z", tuple(round(x, 3) for x in o.dimensions), "tam giác", _tris(o))
    print("Tổng tam giác phần C:", sum(_tris(o) for o in objs.values()))
    tip = tip_local_godot()
    print("Mũi lưỡi nghỉ (Godot thế giới):", tuple(round(x, 3) for x in (Vector(PIVOT_R) + tip)))
    ab = objs["ArmBlade_R"]
    bd = blade_geometry()["d"]
    axis = Vector((bd.x, -bd.z, bd.y))
    far = max(ab.data.vertices, key=lambda v: (ab.matrix_world @ v.co).dot(axis))
    wv = ab.matrix_world @ far.co
    print("Đỉnh mesh xa nhất theo dây cung (Godot thế giới):", (round(wv.x, 3), round(wv.z, 3), round(-wv.y, 3)))
    print("Góc xoay tới z=1.275 (tổng|a|+|b|, yaw_Y, pitch_X, mũi world xyz):")
    for r in extension_angles():
        print("  ", tuple(round(x, 3) for x in r))
    for nm, o in objs.items():
        if nm != "BladeGlow":
            C.check_colors(o, [ARM_BASE, ARM_TOP, ARM_BOT, STEEL, EDGE, INK, CLAW])
    _render(os.path.join(SCR, "part_c.png"), allo, "angle")
    _render(os.path.join(SCR, "part_c_sil.png"), allo, "angle", silhouette=True)
    _render(os.path.join(SCR, "part_c_top.png"), allo, "top")
