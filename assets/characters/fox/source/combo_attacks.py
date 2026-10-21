# Thêm 2 đòn combo kiếm cho cáo vào file .blend rồi xuất lại fox_spirit.glb:
#   Attack_Backhand: chém ngược tay (trái sang phải), nối tiếp từ tư thế cuối của Attack_Horizontal
#   Attack_Finisher: nhát kết liễu (thủ thế xa bên phải, khuỵu người, vung rộng phải sang trái, giữ thế rồi thu)
# Chỉ làm lại 2 action này, không đụng action có sẵn (Run / Idle đã tinh chỉnh bằng refine_locomotion.py).
# Quy ước hướng giống slash() trong expressive_motion.py: vector (phải, lên, trước) của cánh tay phải.
# Chạy: blender -b fox_spirit_animated.blend --python combo_attacks.py -- <thư_mục_xuất> [--save]
#   --save: ghi đè file .blend và animation_manifest.json (chỉ dùng khi xuất vào thư mục assets/characters/fox thật)
import bpy, math, os, sys, json
from mathutils import Vector, Matrix, Quaternion

rig = bpy.data.objects["FoxRig"]
scene = bpy.context.scene
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[0] if argv else r"C:\Code\UITxVNG\SE116_Nhom5_UITxVNG\assets\characters\fox"
save_source = "--save" in argv

REST = Vector((.22, -.97, .03))
REST_BLADE = Vector((.52, -.38, -.76)).normalized()


def P(x, h, f): return Vector((x, -f, h))


def rot(name, x=0, y=0, z=0):
    b = rig.pose.bones[name]; b.rotation_mode = 'XYZ'; b.rotation_euler = [math.radians(a) for a in (x, y, z)]


def reset():
    for b in rig.pose.bones:
        b.rotation_mode = 'XYZ'; b.location = (0, 0, 0); b.rotation_euler = (0, 0, 0); b.scale = (1, 1, 1)


def aim(name, head, target):
    b = rig.pose.bones[name]; rest = b.bone.matrix_local.to_quaternion()
    q = (b.bone.tail_local - b.bone.head_local).rotation_difference(target - head) @ rest
    b.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4(); bpy.context.view_layer.update()


def chain(first, second, target, bend):
    a = rig.pose.bones[first]; b = rig.pose.bones[second]; head = a.head.copy()
    d = target - head; distance = min(d.length, a.bone.length + b.bone.length - .0001)
    direction = d.normalized()
    along = (a.bone.length ** 2 - b.bone.length ** 2 + distance ** 2) / (2 * distance)
    perp = (bend - direction * bend.dot(direction)).normalized()
    joint = head + direction * along + perp * math.sqrt(max(0, a.bone.length ** 2 - along ** 2))
    aim(first, head, joint); aim(second, joint, target)


def foot(side, forward, lift=0, pitch=0, wide=0):
    target = P((.13 + wide) if side == "R" else -(.13 + wide), .115 + lift, forward)
    chain("Thigh_" + side, "Shin_" + side, target, Vector((0, -1, 0)))
    b = rig.pose.bones["Foot_" + side]
    q = Quaternion((1, 0, 0), math.radians(pitch)) @ b.bone.matrix_local.to_quaternion()
    b.matrix = Matrix.Translation(target) @ q.to_matrix().to_4x4(); bpy.context.view_layer.update()


def left_arm(x, h, forward):
    target = P(-x, h, forward)
    shoulder = rig.pose.bones["UpperArm_L"].head.copy()
    direction = (target - shoulder).normalized()
    for name in ["UpperArm_L", "Forearm_L", "Hand_L"]:
        bone = rig.pose.bones[name]; start = bone.head.copy()
        aim(name, start, start + direction * bone.bone.length)


def right_arm(direction, sweeping):
    # Cánh tay thẳng từ vai; lưỡi kiếm nằm ngang theo hướng tay khi đang vung, thả xuống khi thủ / thu
    for name in ["UpperArm_R", "Forearm_R", "Hand_R"]:
        bone = rig.pose.bones[name]; start = bone.head.copy()
        aim(name, start, start + Vector((direction.x, -direction.z, direction.y)) * bone.bone.length)
    weapon = rig.pose.bones["Weapon_R"]
    blade = Vector((direction.x, -direction.z, 0)).normalized() if sweeping else REST_BLADE
    q = Vector((0, 0, -1)).rotation_difference(blade) @ weapon.bone.matrix_local.to_quaternion()
    weapon.matrix = Matrix.Translation(weapon.head) @ q.to_matrix().to_4x4()
    bpy.context.view_layer.update()


def tail(phase, amount=1):
    for index, name in enumerate(["Tail01", "Tail02", "Tail03"]):
        b = rig.pose.bones[name]
        yaw = math.radians((7 + index * 4) * amount * math.sin(phase - index * .65))
        pitch = math.radians((1.5 + index) * amount * math.sin(phase - index * .55 + .6))
        q = Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), pitch) @ b.bone.matrix_local.to_quaternion()
        b.matrix = Matrix.Translation(b.head) @ q.to_matrix().to_4x4(); bpy.context.view_layer.update()


def smooth(u): return u * u * (3 - 2 * u)


def sweep_dir(angle_degrees, up=-.22):
    a = math.radians(angle_degrees)
    return Vector((math.cos(a), up, math.sin(a))).normalized()


def body(yaw, crouch=0.0, lean=4.0):
    rig.pose.bones["Hips"].location.y = -.02 - crouch
    rot("Hips", 0, yaw * .25); rot("Spine", lean, yaw * .75); rot("Head", -2, -yaw * .35)
    bpy.context.view_layer.update()


def backhand(t):
    # Nối từ tư thế cuối nhát 1 (tay bên trái phía trước), kéo thêm về trái rồi quét sang phải
    end_first = Vector((-.60, -.22, .79)).normalized()
    wind = Vector((-.95, -.25, .18)).normalized()
    if t < .2:
        u = smooth(t / .2); direction = end_first.lerp(wind, u).normalized(); yaw = 27 + 8 * u; sweeping = True
    elif t < .5:
        u = (t - .2) / .3; direction = sweep_dir(165 - 180 * u); yaw = 35 - 60 * u; sweeping = True
    else:
        u = smooth((t - .5) / .5); direction = sweep_dir(-15).lerp(REST, u).normalized(); yaw = -25 * (1 - u)
        sweeping = t < .65
    body(yaw, .015 * math.sin(math.pi * min(1, t / .6)))
    foot("R", .05); foot("L", .0)
    left_arm(.245, .65, -.02 + .04 * math.sin(math.pi * t))
    right_arm(direction, sweeping)
    tail(t * math.tau, .55)


def finisher(t):
    # Thủ thế xa bên phải + khuỵu, vung rộng sang trái, giữ thế một chút rồi thu về
    wind = Vector((.95, -.08, -.45)).normalized()
    end = sweep_dir(150, -.3)
    if t < .35:
        u = smooth(t / .35); direction = REST.lerp(wind, u).normalized(); yaw = -45 * u
        crouch = .04 * u; lean = 4 + 4 * u; sweeping = t > .25
    elif t < .55:
        u = (t - .35) / .2; direction = sweep_dir(-25 + 175 * u, -.08 - .22 * u); yaw = -45 + 85 * u
        crouch = .04 + .035 * u; lean = 8 + 8 * u; sweeping = True
    elif t < .75:
        u = (t - .55) / .2; direction = end; yaw = 40 - 4 * u; crouch = .075 - .01 * u; lean = 16 - 2 * u
        sweeping = True
    else:
        u = smooth((t - .75) / .25); direction = end.lerp(REST, u).normalized(); yaw = 36 * (1 - u)
        crouch = .065 * (1 - u); lean = 14 - 10 * u; sweeping = False
    body(yaw, crouch, lean)
    # Chân dang rộng khi khuỵu để không xuyên đất (IK chân)
    spread = crouch * .9
    foot("R", .06 + spread, 0, 0, spread * .6); foot("L", -.02 - spread * .5, 0, 0, spread * .4)
    left_arm(.26 + crouch, .64 - crouch * .6, -.05 + crouch * 1.5)
    right_arm(direction, sweeping)
    tail(t * math.tau, .7)


definitions = [("Attack_Backhand", 16, backhand), ("Attack_Finisher", 25, finisher)]
for name, end, pose in definitions:
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks):
        if track.name == name: rig.animation_data.nla_tracks.remove(track)
    if name in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[name])
    a = bpy.data.actions.new(name); a.use_fake_user = True; rig.animation_data.action = a
    for f in range(1, end + 1):
        scene.frame_set(f); reset(); pose((f - 1) / (end - 1))
        for b in rig.pose.bones:
            b.keyframe_insert("rotation_euler", frame=f, group=b.name)
            b.keyframe_insert("location", frame=f, group=b.name)
            b.keyframe_insert("scale", frame=f, group=b.name)
    a["loop"] = False
    a["duration_seconds"] = (end - 1) / 30
    rig.animation_data.action = None
    tr = rig.animation_data.nla_tracks.new(); tr.name = name; tr.strips.new(name, 1, a); tr.mute = True


# Góc mũi kiếm quanh thân theo từng frame (0 = trước mặt, + = sang trái): để đặt mốc hitbox
def tip_angles(action_name):
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    first, last = [int(v) for v in action.frame_range]
    angles = []
    for f in range(first, last + 1):
        scene.frame_set(f)
        weapon = rig.pose.bones["Weapon_R"]; hips = rig.pose.bones["Hips"]
        tip = weapon.tail - hips.head
        # Cáo nhìn về -Y; +X là bên tay phải theo quy ước của rig này
        angles.append(round(math.degrees(math.atan2(-tip.x, -tip.y)), 1))
    rig.animation_data.action = None
    return angles


report = {n: tip_angles(n) for n in ["Attack_Horizontal", "Attack_Backhand", "Attack_Finisher"]}
for n, angles in report.items():
    print("TIP", n, angles)

rig.animation_data.action = bpy.data.actions["Idle_Sword"]; scene.frame_start = 1; scene.frame_end = 91; scene.frame_set(1)
os.makedirs(out, exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
for n in ["Body", "Head", "Tail", "Eyes", "Sword", "FoxRig"]: bpy.data.objects[n].select_set(True)
bpy.context.view_layer.objects.active = rig
options = dict(filepath=os.path.join(out, "fox_spirit.glb"), export_format='GLB', use_selection=True,
               export_animations=True, export_yup=True, export_frame_range=False, export_force_sampling=True,
               export_animation_mode='ACTIONS')
if "export_optimize_animation_size" in bpy.ops.export_scene.gltf.get_rna_type().properties:
    options["export_optimize_animation_size"] = False
bpy.ops.export_scene.gltf(**options)
print("EXPORTED", options["filepath"])
if save_source:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source", "fox_spirit_animated.blend"))
    manifest_path = os.path.join(out, "source", "animation_manifest.json")
    with open(manifest_path, encoding="utf-8") as f: manifest = json.load(f)
    for name, end, _ in definitions:
        manifest[name] = {"loop": False, "duration": (end - 1) / 30}
    with open(manifest_path, "w", encoding="utf-8") as f: json.dump(manifest, f, indent=2)
    print("SAVED source + manifest")
