# PHẦN B quái 1 "Liềm gió tha hoá": chân (Leg_L/Leg_R) + đuôi (Tail_1/Tail_2).
# Toạ độ viết theo Godot (X, Y lên, Z trước) quanh pivot, đổi sang Blender khi tạo đỉnh.
import bpy, bmesh, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C

FUR = dict(base="#4A3B36", top="#725B4E", bottom="#3A2E2A")
FOOT = "#3A2E2A"
INK = "#241C2B"

LEG_PIVOT_Y = 0.50
LEG_X = 0.13
TAIL_PIVOT = (0.0, 0.55, -0.25)
TAIL_LEN = 0.8
TAIL_SEGS = 8  # 4 mỗi phần
SWAY = 0.025  # lắc ngang nhẹ kiểu gió lốc
TAIL_LAT = 0.30  # đuôi vồng lệch sang +X để lộ ra khỏi sau thân ở góc camera game


def tail_sway(i):
    s = i / TAIL_SEGS
    return SWAY * math.sin(s * math.pi * 2.0) + TAIL_LAT * s ** 1.4
TAIL_WIDEN = 1.3  # đuôi rậm: bề ngang X rộng hơn bề dày


def _v(p):
    return C.godot_to_blender(*p)


def loft(bm, rings, cap=True):
    """Nối các vòng đỉnh (toạ độ Godot cục bộ) thành ống. Trả về (vòng đỉnh, mặt theo đoạn, mặt nắp)."""
    vr = [[bm.verts.new(_v(p)) for p in ring] for ring in rings]
    segs = []
    n = len(rings[0])
    for a in range(len(vr) - 1):
        segs.append([bm.faces.new((vr[a][i], vr[a][(i + 1) % n], vr[a + 1][(i + 1) % n], vr[a + 1][i])) for i in range(n)])
    caps = []
    if cap:
        caps.append(bm.faces.new(vr[0]))
        caps.append(bm.faces.new(vr[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return vr, segs, caps


def box_ring(c, d, w, t):
    """Vòng 4 đỉnh vuông góc đoạn nằm trong YZ. c=(y,z), d=hướng (y,z), w=nửa rộng X, t=nửa dày."""
    n = (-d[1], d[0])
    return [(sx * w, c[0] + n[0] * st * t, c[1] + n[1] * st * t) for sx, st in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def seg_box(bm, c0, c1, w0, t0, w1, t1):
    d = Vector((c1[0] - c0[0], c1[1] - c0[1])).normalized()
    loft(bm, [box_ring(c0, (d.x, d.y), w0, t0), box_ring(c1, (d.x, d.y), w1, t1)])


def build_leg(name, pivot_g, coll):
    parts = []
    hip = (0.02, 0.0)           # (y, z) quanh pivot
    knee = (-0.17, 0.105)       # đùi chếch trước 30° so với phương thẳng đứng
    ankle = (-0.405, -0.115)    # cẳng chếch sau 45°
    heel_z, toe_z = -0.17, -0.03
    b = bmesh.new(); seg_box(b, hip, knee, 0.080, 0.100, 0.050, 0.060); C.bevel(b, 0.02); parts.append(b)
    b = bmesh.new(); seg_box(b, knee, ankle, 0.050, 0.055, 0.035, 0.035); C.bevel(b, 0.012); parts.append(b)
    # bàn chân dài 0.14 rộng 0.10, đế chạm y = -0.50
    b = bmesh.new()
    loft(b, [[(-0.05, -0.50, heel_z), (0.05, -0.50, heel_z), (0.05, -0.43, heel_z), (-0.05, -0.43, heel_z)],
             [(-0.05, -0.50, toe_z), (0.05, -0.50, toe_z), (0.05, -0.455, toe_z), (-0.05, -0.455, toe_z)]])
    C.bevel(b, 0.012); parts.append(b)
    # 3 ngón vát nhọn
    for sx in (-0.035, 0.0, 0.035):
        b = bmesh.new()
        r0 = [(sx - 0.016, -0.50, toe_z - 0.01), (sx + 0.016, -0.50, toe_z - 0.01), (sx + 0.016, -0.455, toe_z - 0.01), (sx - 0.016, -0.455, toe_z - 0.01)]
        r1 = [(sx - 0.007, -0.50, toe_z + 0.05), (sx + 0.007, -0.50, toe_z + 0.05), (sx + 0.007, -0.485, toe_z + 0.05), (sx - 0.007, -0.485, toe_z + 0.05)]
        loft(b, [r0, r1]); parts.append(b)
    # mông to Ø ~0.22 liền vào hông (icosphere 20 mặt, kéo giãn)
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=1, radius=0.5)
    for v in b.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        v.co = _v((x * 0.24, 0.035 + z * 0.24, -0.02 - y * 0.26))
    parts.append(b)
    bm = C.merge(parts)
    C.paint(bm, FUR["base"], FUR["top"], FUR["bottom"])
    lay = bm.loops.layers.color.get("Col")
    cf = C.srgb(FOOT)
    for f in bm.faces:
        if f.calc_center_median().z < -0.395:  # Blender Z = Godot Y: bàn chân/ngón
            for l in f.loops:
                l[lay] = (*cf, 1.0)
    return C.finish(bm, name, _v(pivot_g), collection=coll)


def tail_path():
    """TAIL_SEGS+1 điểm (y, z, góc) quanh Tail_1: ra sau, vồng lên, chóp cuộn ~0.5 vòng."""
    n_fine = 400
    ds = TAIL_LEN / n_fine
    th = lambda s: math.radians(-5 + 95 * s + 100 * (max(0.0, (s - 0.70) / 0.30) ** 1.4))
    y = z = 0.0
    fine = [(0.0, 0.0, th(0))]
    for k in range(1, n_fine + 1):
        a = th((k - 0.5) / n_fine)
        z += -math.cos(a) * ds  # a=0: ra sau (-Z); a=90°: lên
        y += math.sin(a) * ds
        fine.append((y, z, th(k / n_fine)))
    return [fine[round(i * n_fine / TAIL_SEGS)] for i in range(TAIL_SEGS + 1)]


def tail_radius(s):
    # 0.05 gốc (dày 0.10), phình 0.08 giữa (0.16), 0.015 chóp (0.03)
    if s < 0.5:
        return 0.06 + 0.04 * (s / 0.5)
    return 0.10 - 0.08 * ((s - 0.5) / 0.5)


def hex_ring(p, r, sway):
    y, z, a = p
    ty, tz = math.sin(a), -math.cos(a)
    ny, nz = -tz, ty
    pts = []
    for k in range(6):
        ang = math.radians(60 * k)
        ax, an = math.cos(ang) * r * TAIL_WIDEN, math.sin(ang) * r
        pts.append((sway + ax, y + ny * an, z + nz * an))
    return pts


def build_tail(coll):
    path = tail_path()
    sways = [tail_sway(i) for i in range(TAIL_SEGS + 1)]
    rings = [hex_ring(p, tail_radius(i / TAIL_SEGS), sways[i]) for i, p in enumerate(path)]
    bm1 = bmesh.new()
    loft(bm1, rings[0:5])
    C.paint(bm1, FUR["base"], FUR["top"], FUR["bottom"])
    t1 = C.finish(bm1, "Tail_1", _v(TAIL_PIVOT), collection=coll)
    # Tail_2: pivot ở cuối Tail_1 (tâm vòng 4)
    off = Vector((sways[4], path[4][0], path[4][1]))
    rings2 = [[(p[0] - off.x, p[1] - off.y, p[2] - off.z) for p in r] for r in rings[4:9]]
    bm2 = bmesh.new()
    vr, segs, caps = loft(bm2, rings2)
    C.paint(bm2, FUR["base"], FUR["top"], FUR["bottom"])
    lay = bm2.loops.layers.color.get("Col")
    ci = C.srgb(INK)
    for f in segs[2] + segs[3] + [caps[1]]:  # chóp mực: 2 đoạn cuối
        for l in f.loops:
            l[lay] = (*ci, 1.0)
    pivot2 = (TAIL_PIVOT[0] + off.x, TAIL_PIVOT[1] + off.y, TAIL_PIVOT[2] + off.z)
    t2 = C.finish(bm2, "Tail_2", _v(pivot2), parent=t1, collection=coll)
    return t1, t2, pivot2


def build(collection):
    out = {}
    out["Leg_L"] = build_leg("Leg_L", (LEG_X, LEG_PIVOT_Y, 0.0), collection)
    out["Leg_R"] = build_leg("Leg_R", (-LEG_X, LEG_PIVOT_Y, 0.0), collection)
    t1, t2, p2 = build_tail(collection)
    out["Tail_1"], out["Tail_2"] = t1, t2
    print("Tail_2 pivot Godot:", tuple(round(v, 4) for v in p2))
    return out


def _tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def _bounds_godot(obs):
    mn = Vector((9, 9, 9)); mx = Vector((-9, -9, -9))
    for o in obs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            g = Vector((w.x, w.z, -w.y))
            for i in range(3):
                mn[i] = min(mn[i], g[i]); mx[i] = max(mx[i], g[i])
    return mn, mx


def _side_render(path, cen, dist=3.0):
    sc = bpy.context.scene
    cam = sc.camera
    cam.location = cen + Vector((dist, 0, 0))
    cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.context.scene.collection
    objs = build(col)
    # khối hông tạm CHỈ để ảnh dễ nhìn (không nằm trong build)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = C.godot_to_blender(v.co.x * 0.40, 0.58 + v.co.z * 0.24, -v.co.y * 0.36 - 0.02)
    C.paint(bm, "#6A5A50", "#7A6A5E", "#4A3B36")
    hip = C.finish(bm, "_TempHips", C.godot_to_blender(0, 0, 0), collection=col)
    bpy.context.view_layer.update()

    total = 0
    for k, o in objs.items():
        t = _tris(o); total += t
        mn, mx = _bounds_godot([o])
        print(k, "pivot_godot", (round(o.location.x, 3), round(o.location.z, 3), round(-o.location.y, 3)),
              "tris", t, "bbox_godot min", tuple(round(v, 3) for v in mn), "max", tuple(round(v, 3) for v in mx))
    print("TONG tam giac phan B:", total)
    mn, mx = _bounds_godot(list(objs.values()))
    print("Hop bao B (Godot): min", tuple(round(v, 3) for v in mn), "max", tuple(round(v, 3) for v in mx))
    for o in objs.values():
        C.check_colors(o, [FUR["base"], FUR["top"], FUR["bottom"], FOOT, INK])

    sp = r"C:\Users\DANGQU~1\AppData\Local\Temp\claude\C--Code-UITxVNG-SE116-Nhom5-UITxVNG\f4275fa5-8d1d-4075-a562-9e0a975e0903\scratchpad"
    cen = Vector((0, 0, 0.55))
    C.render_preview(os.path.join(sp, "part_b.png"), list(objs.values()) + [hip], distance=3.0)
    _side_render(os.path.join(sp, "part_b_side.png"), cen)
    hip.hide_render = True
    C.render_preview(os.path.join(sp, "part_b_sil.png"), list(objs.values()), silhouette=True, distance=3.0)
    _side_render(os.path.join(sp, "part_b_sil_side.png"), cen)
