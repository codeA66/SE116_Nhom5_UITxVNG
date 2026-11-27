# Sinh levels/zone_3_fire/tier_1/tiger_arena/tiger_arena.tscn (dau truong ho tam dung bang fire kit).
# Chay: python docs/zone_3_fire/build_tiger_arena.py levels/zone_3_fire/tier_1/tiger_arena/tiger_arena.tscn
import math, sys

KIT = "res://assets/models/map_fire/fire_kit/"
ext = [
    ("Script", "res://levels/_base/zone_root.gd", "zone"),
    ("PackedScene", "res://levels/zone_3_fire/tier_1/lighting/fire_lighting.tscn", "lighting"),
    ("Script", "res://entities/player/camera/camera_view_data.gd", "view_data"),
    ("Script", "res://objects/hub/zone_camera_view/zone_camera_view.gd", "view"),
    ("Script", "res://objects/core/spawn_point/spawn_point.gd", "spawn"),
    ("PackedScene", "res://objects/core/encounter/boss_fight/boss_fight.tscn", "boss_fight"),
    ("PackedScene", "res://entities/bosses/fire/fire_sabretooth.tscn", "tiger"),
    ("PackedScene", "res://objects/core/encounter/boss_fight/arena_gate/arena_gate.tscn", "gate"),
    ("PackedScene", "res://objects/world/camera_cutscene/camera_cutscene.tscn", "cutscene"),
    ("Resource", "res://resources/world/cutscenes/tiger_intro.tres", "intro_data"),
    ("Script", "res://objects/combat/spawner_cage/flag_reveal.gd", "flag_reveal"),
    ("PackedScene", "res://objects/core/portal/portal.tscn", "portal"),
]
kit = ["floor_4m", "floor_vein_4m", "wall_4m", "wall_low_4m", "fire_pillar",
       "chain_hanging_4m", "wall_broken_4m"]
for k in kit:
    ext.append(("PackedScene", KIT + k + ".glb", "k_" + k))

TOP = 0.32
# Tam tuong kit rong 4,06 m dat cach nhau 4 m thi chong 6 cm, mat ngoai trung nhau -> loang o moi moi noi.
# Thu ve dung 4 m de hai tam chi cham mep.
FIT = 4.0 / 4.06
# Tuong vuong goc o goc phong ha xuong 4 cm de mat tren khong trung do cao voi tuong canh no (chong loang)
SINK = 0.04
subs, nodes, shapes = [], [], []


def v3(x, y, z):
    return "Vector3(%g, %g, %g)" % (x, y, z)


def node(name, parent, typ=None, inst=None, props=None, paths=None):
    head = '[node name="%s"' % name
    if typ:
        head += ' type="%s"' % typ
    if parent is not None:
        head += ' parent="%s"' % parent
    if paths:
        head += ' node_paths=PackedStringArray(%s)' % ", ".join('"%s"' % p for p in paths)
    if inst:
        head += ' instance=ExtResource("%s")' % inst
    head += "]"
    lines = [head]
    for k, v in (props or {}).items():
        lines.append("%s = %s" % (k, v))
    nodes.append("\n".join(lines))


def piece(name, parent, k, x, y, z, ry=0.0, sx=1.0):
    props = {"position": v3(x, y, z)}
    if ry:
        props["rotation"] = v3(0, round(math.radians(ry), 6), 0)
    if sx != 1.0:
        props["scale"] = v3(round(sx, 4), 1, 1)
    node(name, parent, inst="k_" + k, props=props)


def box(name, cx, cy, cz, sx, sy, sz):
    sid = "Box_" + name
    subs.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = %s' % (sid, v3(round(sx, 4), round(sy, 4), round(sz, 4))))
    shapes.append((name, cx, cy, cz, sid))


node("TigerArena", None, "Node3D", props={"script": 'ExtResource("zone")', "default_spawn_id": '&"tiger_arena_entry"'})
node("FireLighting", ".", inst="lighting")
subs.append('[sub_resource type="Resource" id="ArenaView"]\nscript = ExtResource("view_data")\ndistance = 38.0\nyaw_degrees = 45.0')
node("ZoneCameraView", ".", "Node", props={"script": 'ExtResource("view")', "view": 'SubResource("ArenaView")'})

node("Architecture", ".", "Node3D")
node("Floor", "Architecture", "Node3D")
veins = {(-4, 4), (8, -4), (-8, -8), (4, 8)}
i = 0
for x in range(-12, 13, 4):
    for z in range(-12, 13, 4):
        i += 1
        piece("Tile%d" % i, "Architecture/Floor", "floor_vein_4m" if (x, z) in veins else "floor_4m", x, 0, z)
for x in (-16, -20):
    i += 1
    piece("Tile%d" % i, "Architecture/Floor", "floor_4m", x, 0, 0)
box("Floor", 0, TOP / 2, 0, 28, TOP, 28)
box("Hall", -18, TOP / 2, 0, 8, TOP, 4)

node("Walls", "Architecture", "Node3D")
W = 13.65
for n, x in enumerate(range(-12, 13, 4)):
    piece("North%d" % n, "Architecture/Walls", "wall_4m", x, TOP, -W, sx=FIT)
    piece("South%d" % n, "Architecture/Walls", "wall_low_4m", x, TOP, W, sx=FIT)
box("NorthWall", 0, TOP + 2, -W, 28.2, 4, 0.82)
box("SouthWall", 0, TOP + 0.625, W, 28.2, 1.25, 0.82)
# Dong: chua loi ra 4 m o z = 0
for n, z in enumerate((-12, -8, -4, 4, 8, 12)):
    piece("East%d" % n, "Architecture/Walls", "wall_low_4m", W, TOP - SINK, z, ry=90, sx=FIT)
box("EastWallN", W, TOP + 0.625, -8.03, 0.82, 1.25, 12.06)
box("EastWallS", W, TOP + 0.625, 8.03, 0.82, 1.25, 12.06)
# Tay: song sat rong 7,1 m o giua; moi ben 2 tam tuong keo gian phu tu 3,55 toi 13,65
seg = (13.65 - 3.55) / 2.0
sx = seg / 4.06
for n, c in enumerate((3.55 + seg / 2, 3.55 + seg * 1.5)):
    piece("WestS%d" % n, "Architecture/Walls", "wall_4m", -W, TOP - SINK, c, ry=90, sx=sx)
    piece("WestN%d" % n, "Architecture/Walls", "wall_4m", -W, TOP - SINK, -c, ry=90, sx=sx)
box("WestWallN", -W, TOP + 2, -(3.55 + seg), 0.82, 4, seg * 2)
box("WestWallS", -W, TOP + 2, 3.55 + seg, 0.82, 4, seg * 2)
# Hanh lang vao (diem den cua cong dich chuyen)
for n, x in enumerate((-16, -20)):
    piece("HallN%d" % n, "Architecture/Walls", "wall_4m", x, TOP, -2.41, sx=FIT)
    piece("HallS%d" % n, "Architecture/Walls", "wall_low_4m", x, TOP, 2.41, sx=FIT)
piece("HallEnd", "Architecture/Walls", "wall_4m", -22.41, TOP - SINK, 0, ry=90)
box("HallWallN", -18, TOP + 2, -2.41, 8.1, 4, 0.82)
box("HallWallS", -18, TOP + 0.625, 2.41, 8.1, 1.25, 0.82)
box("HallEndWall", -22.41, TOP + 2, 0, 0.82, 4, 4.8)

node("Braziers", "Architecture", "Node3D")
for n, (x, z) in enumerate(((-11.3, -11.3), (11.3, -11.3), (-11.3, 11.3), (11.3, 11.3))):
    piece("Brazier%d" % n, "Architecture/Braziers", "fire_pillar", x, TOP, z)
    box("Brazier%d" % n, x, TOP + 1.75, z, 1.9, 3.5, 1.9)

node("Den", "Architecture", "Node3D")
piece("ChainL", "Architecture/Den", "chain_hanging_4m", -1.5, TOP, -13.0)
piece("ChainR", "Architecture/Den", "chain_hanging_4m", 1.5, TOP, -13.0)
piece("Rubble", "Architecture/Den", "wall_broken_4m", 5.0, TOP, -11.6)
box("Rubble", 5.0, TOP + 1.5, -11.6, 4, 3, 1.6)

node("Collision", ".", "StaticBody3D")
for (name, cx, cy, cz, sid) in shapes:
    node(name, "Collision", "CollisionShape3D", props={"position": v3(round(cx, 4), round(cy, 4), round(cz, 4)), "shape": 'SubResource("%s")' % sid})

node("Anchors", ".", "Node3D")
node("Entry", "Anchors", "Marker3D", props={"position": v3(-19.5, TOP, 0), "rotation": v3(0, -1.570796, 0), "script": 'ExtResource("spawn")', "spawn_id": '&"tiger_arena_entry"'})
node("ArenaInside", "Anchors", "Marker3D", props={"position": v3(-6, TOP, 0)})
node("DenFocus", "Anchors", "Marker3D", props={"position": v3(0, TOP, -8)})

node("EntryGate", ".", inst="gate", paths=["encounter"], props={"position": v3(-W, TOP, 0), "rotation": v3(0, 1.570796, 0), "encounter": 'NodePath("../TigerFight")'})
node("TigerFight", ".", inst="boss_fight", paths=["introduction"], props={"position": v3(0, TOP, 0), "boss_scene": 'ExtResource("tiger")', "persistent_id": '&"level_3.boss_defeated"', "trigger_size": v3(24, 4, 24), "visible_before_start": "true", "introduction": 'NodePath("../TigerIntro")'})
# Mo hinh ho nhin theo +Z: de rotation 0 de ho nhin ra giua san (phia player buoc vao)
node("Spawn", "TigerFight", props={"position": v3(0, 0, -8)})
node("TigerIntro", ".", inst="cutscene", paths=["focus_target", "trigger_source"], props={"data": 'ExtResource("intro_data")', "focus_target": 'NodePath("../Anchors/DenFocus")', "persistent_id": '&"level_3.tiger.intro_seen"', "trigger_source": 'NodePath("../TigerFight")', "trigger_signal": '&"intro_requested"'})

node("ExitReveal", ".", "Node3D", props={"script": 'ExtResource("flag_reveal")', "flag": '&"level_3.boss_defeated"'})
node("Portal", "ExitReveal", inst="portal", props={"position": v3(12.2, TOP, 0), "rotation": v3(0, -1.570796, 0), "portal_id": '&"tiger_arena_exit"', "target_zone": '"res://levels/zone_3_fire/tier_2/tier_2.tscn"', "target_portal_id": '&"start"'})

out = ["[gd_scene format=3]", ""]
for t, p, i2 in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i2))
out.append("")
out += [s + "\n" for s in subs]
out += [n + "\n" for n in nodes]
open(sys.argv[1], "w", encoding="utf-8", newline="\n").write("\n".join(out))
