class_name PyralonRig
extends Node
## Giữ rig gốc, ghi lại pose cất cánh và đóng cán rìu thành các clip có thể chạy trong menu O.

const LAUNCH := &"pyralon/WingLaunch"
const BARRAGE := &"pyralon/WingBarrage"
const LAND := &"pyralon/WingLand"
const COMMAND := &"pyralon/AxeSignal"
const SKY_LAUNCH := &"pyralon/SkyLaunch"
const SKY_DIVE_LAND := &"pyralon/SkyDiveLand"
const SKY_DIVE_RISE := &"pyralon/SkyDiveRise"
const SKY_REASCENT := &"pyralon/SkyReAscent"
const RESONANCE_SLAM := &"pyralon/ResonanceSlam"
const COLLAPSE := &"pyralon/Collapse"
const GET_UP := &"pyralon/GetUp"
const SAMPLE_RATE := 30.0
const SKY_DIVE_RISE_LENGTH := 1.25
const COMMAND_HIT := 0.60
const SKY_LAUNCH_BLAST := 0.90
const SKY_REASCENT_BLAST := 0.58
const RESONANCE_HIT := 0.68

static var _library: AnimationLibrary
var _skeleton: Skeleton3D
var _animator: AnimationPlayer
var _path: String
var _pelvis: int
var _hand: int
var _arm: int
var _wing_tips := PackedInt32Array()
var _wing_mids := PackedInt32Array()
var _axe_end: Vector3
var _axe_edge: Vector3
var _rest_pelvis: Vector3


func setup(actor: Pyralon) -> void:
	_animator = actor.animation_player()
	_skeleton = actor.model.find_child("Skeleton3D", true, false) as Skeleton3D
	_path = String(_animator.get_node(_animator.root_node).get_path_to(_skeleton))
	_hand = _skeleton.find_bone(&"Hand.R")
	_arm = _skeleton.find_bone(&"UpperArm.R")
	_pelvis = _skeleton.find_bone(&"Pelvis")
	for suffix: String in [".L", ".R"]:
		_wing_tips.append(_skeleton.find_bone("Wing2" + suffix))
		_wing_mids.append(_skeleton.find_bone("Wing1" + suffix))
	_axe_points(actor.model.find_child("Pyralon_Axe", true, false) as MeshInstance3D)
	var idle := _sample(&"Idle1", 0.0)
	_rest_pelvis = idle[_pelvis].origin
	if _library == null:
		_library = _build_library(idle)
	_animator.add_animation_library(&"pyralon", _library)
	actor.play_anim(&"Idle")


func update_bones() -> void:
	_skeleton.force_update_all_bone_transforms()


func displacement() -> Vector3:
	var point := _skeleton.get_bone_global_pose(_pelvis).origin
	return _skeleton.global_basis * (point - _rest_pelvis)


func axe_edge() -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_hand) * _axe_edge)


func axe_end() -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_hand) * _axe_end)


func wing_point(side: int, tip: bool) -> Vector3:
	var bone := _wing_tips[side] if tip else _wing_mids[side]
	var pose := _skeleton.get_bone_global_pose(bone)
	return _skeleton.to_global(pose.origin + pose.basis.y.normalized() * (1.35 if tip else 0.52))


func _build_library(idle: Array[Transform3D]) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var hover := _hover(_sample(&"Action_005", 1.22), idle, 0.0)
	library.add_animation(&"WingLaunch", _bake(1.22, func(t: float) -> Array[Transform3D]:
		var pose := _sample(&"Action_005", t * 1.22)
		return _hover(pose, idle, 0.0, smoothstep(0.05, 0.96, t))))
	var barrage := _bake(0.60, func(t: float) -> Array[Transform3D]:
		return _hover(_sample(&"Action_005", 1.22), idle, sin(TAU * t)))
	barrage.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(&"WingBarrage", barrage)
	var land := _bake(0.50, func(t: float) -> Array[Transform3D]:
		return _blend(hover, idle, smoothstep(0.0, 1.0, t)))
	library.add_animation(&"WingLand", land)
	if _animator.has_animation(&"AxeSignal"):
		library.add_animation(&"AxeSignal", _animator.get_animation(&"AxeSignal").duplicate() as Animation)
	else:
		library.add_animation(&"AxeSignal", _bake(1.0, func(t: float) -> Array[Transform3D]:
			return _stamp(idle, t)))
	# 4 clip Phase 2 dùng lại rig gốc:
	# - SkyLaunch (2.02s): 3 nhịp vỗ cánh hoàn toàn tự nhiên từ Action_005:
	#   2 nhịp đầu nguyên bản (0.00..1.62s) + nhịp 3 copy nguyên nhịp vỗ thứ 2 (1.00..1.62s) tăng tốc phóng thẳng lên trời!
	# - SkyDiveLand (0.52s): lao nhanh xuống tư thế khuỵu chân tạo crater
	# - SkyReAscent (0.48s): tái sử dụng đúng nhịp vỗ thứ 2 tăng tốc của Action_005 (1.00..1.62s) để bay vọt lên
	# - ResonanceSlam (1.65s): nhấc cán rìu cao -> giữ 0.5s trên không -> giậm mạnh đuôi cán xuống sàn
	library.add_animation(&"SkyLaunch", _bake(2.02, func(t: float) -> Array[Transform3D]:
		return _sky_launch_pose(idle, t)))
	library.add_animation(&"SkyDiveLand", _bake(0.52, func(t: float) -> Array[Transform3D]:
		return _sky_dive_land_pose(idle, t)))
	var impact_pose := _sky_dive_land_pose(idle, 0.46)
	var deep_crouch := _sky_dive_land_pose(idle, 1.0)
	var upright := _sample(&"Idle2", 0.0) if _animator.has_animation(&"Idle2") else idle
	library.add_animation(&"SkyDiveRise", _bake(SKY_DIVE_RISE_LENGTH, func(t: float) -> Array[Transform3D]:
		return _sky_dive_rise_pose(impact_pose, deep_crouch, upright, t)))
	library.add_animation(&"SkyReAscent", _bake(0.48, func(t: float) -> Array[Transform3D]:
		return _sky_reascent_pose(idle, t)))
	library.add_animation(&"ResonanceSlam", _bake(1.65, func(t: float) -> Array[Transform3D]:
		return _resonance_slam_pose(idle, t)))
	# 2 clip chết ngã gục & gượng đứng dậy nhịp chậm dramatic (2.55s mỗi clip, khớp liền mạch 100%):
	var crouch := _sample(&"Action_005", 2.54)
	library.add_animation(&"Collapse", _bake(2.55, func(t: float) -> Array[Transform3D]:
		return _collapse_pose(idle, crouch, t)))
	library.add_animation(&"GetUp", _bake(2.55, func(t: float) -> Array[Transform3D]:
		return _get_up_pose(idle, crouch, t)))
	return library


func _relax_arms(pose: Array[Transform3D], idle: Array[Transform3D]) -> void:
	for bone: int in pose.size():
		if _skeleton.get_bone_name(bone).begins_with("Shoulder"):
			_repose_branch(pose, bone, pose[_skeleton.get_bone_parent(bone)] * _local(idle, bone))


func _aim_wings(pose: Array[Transform3D], w1_dir: Vector3, w2_dir: Vector3, weight: float) -> void:
	# Đặt hướng tuyệt đối cho Wing1 & Wing2 theo trục skeleton (+X = trái, +Y = lên, +Z = trước) để motion dang rộng -> quất thẳng xuống cực uy lực, không bắt chéo.
	if weight <= 0.001:
		return
	for bone: int in pose.size():
		var bone_name := _skeleton.get_bone_name(bone)
		if bone_name.begins_with("Wing1"):
			var side := 1.0 if bone_name.ends_with(".L") else -1.0
			var cur_dir := pose[bone].basis.y.normalized()
			var target_dir := Vector3(side * w1_dir.x, w1_dir.y, w1_dir.z).normalized()
			var align := Basis(Quaternion(cur_dir, target_dir))
			var adjusted := pose[bone]
			adjusted.basis = Basis.IDENTITY.slerp(align, weight) * adjusted.basis
			_repose_branch(pose, bone, adjusted)
	for bone: int in pose.size():
		var bone_name := _skeleton.get_bone_name(bone)
		if bone_name.begins_with("Wing2"):
			var side := 1.0 if bone_name.ends_with(".L") else -1.0
			var cur_dir := pose[bone].basis.y.normalized()
			var target_dir := Vector3(side * w2_dir.x, w2_dir.y, w2_dir.z).normalized()
			var align := Basis(Quaternion(cur_dir, target_dir))
			var adjusted := pose[bone]
			adjusted.basis = Basis.IDENTITY.slerp(align, weight) * adjusted.basis
			_repose_branch(pose, bone, adjusted)


func _flare_wings_up(pose: Array[Transform3D], weight: float) -> void:
	_aim_wings(pose, Vector3(0.76, 0.56, -0.34), Vector3(0.62, 0.72, -0.30), weight)


func _sky_launch_pose(idle: Array[Transform3D], t: float) -> Array[Transform3D]:
	# Lần bay lên trời đầu tiên (2.02s): 3 nhịp vỗ cánh tự nhiên từ Action_005:
	# - t 0.000..0.802 (1.62s): 2 nhịp vỗ cánh & khép chân nguyên bản của Action_005 (0.00s..1.62s).
	# - t 0.802..1.000 (0.40s): Copy nguyên bản nhịp vỗ cánh thứ 2 của Action_005 (1.00s..1.62s) tăng tốc 1.55x phóng thẳng lên trời!
	const RAW_END_T := 0.802
	if t < RAW_END_T:
		var src_t := lerpf(0.0, 1.62, t / RAW_END_T)
		var raw_pose := _sample(&"Action_005", src_t)
		_relax_arms(raw_pose, idle)
		return raw_pose
	var flap3_u := clampf((t - RAW_END_T) / (1.0 - RAW_END_T), 0.0, 1.0)
	var flap3_src := lerpf(1.00, 1.62, flap3_u)
	var flap3_pose := _sample(&"Action_005", flap3_src)
	_relax_arms(flap3_pose, idle)
	# Chuyển mượt siêu ngắn từ cuối nhịp vỗ 2 (1.62s) sang đầu nhịp vỗ 3 (1.00s) để không khựng khung.
	if flap3_u < 0.14:
		var prev_end := _sample(&"Action_005", 1.62)
		_relax_arms(prev_end, idle)
		return _blend(prev_end, flap3_pose, smoothstep(0.0, 0.14, flap3_u))
	return flap3_pose


func _sky_dive_land_pose(idle: Array[Transform3D], t: float) -> Array[Transform3D]:
	var src_t := lerpf(1.98, 2.58, smoothstep(0.0, 0.62, t))
	var pose := _sample(&"Action_005", src_t)
	_relax_arms(pose, idle)
	_flare_wings_up(pose, smoothstep(0.15, 0.55, t))
	return pose


func _sky_dive_rise_pose(impact_pose: Array[Transform3D], deep_crouch: Array[Transform3D], upright: Array[Transform3D], t: float) -> Array[Transform3D]:
	# Nhấc người đứng dậy chậm rãi, nặng và đầy uy lực từ tư thế cúi gập sau cú đập đất chuyển Phase:
	# - 0.00..0.18: Lắng hết xung lực chạm đất xuống đáy tư thế khuỵu (khớp mượt từ frame Impact Frame).
	# - 0.18..0.28: Khựng ngắn đầy trọng lượng trong lúc camera zoom sát vào Pyralon.
	# - 0.28..1.00: Nâng hông & chân trước -> mở ngực & trải rộng cánh uy nghi -> ngẩng đầu sau cùng về dáng mặc định!
	if t < 0.18:
		return _blend(impact_pose, deep_crouch, smoothstep(0.0, 0.18, t))
	if t < 0.28:
		var hold_u := (t - 0.18) / 0.10
		var held: Array[Transform3D] = deep_crouch.duplicate()
		var pelv := held[_pelvis]
		pelv.origin.y -= sin(hold_u * PI) * 0.025
		_repose_branch(held, _pelvis, pelv)
		return held
	var base_u := clampf((t - 0.28) / 0.72, 0.0, 1.0)
	var body_u := smoothstep(0.0, 0.88, base_u)
	var chest_u := smoothstep(0.12, 0.94, base_u)
	var head_u := smoothstep(0.36, 1.0, base_u)
	var pose := _blend(deep_crouch, upright, body_u)
	var chest_idx := _skeleton.find_bone(&"Chest")
	var neck_idx := _skeleton.find_bone(&"Neck1")
	var head_idx := _skeleton.find_bone(&"Head")
	var chest_lag := maxf(0.0, body_u - chest_u)
	if chest_idx >= 0 and chest_lag > 0.001:
		var cp := pose[chest_idx]
		cp.basis = Basis(Vector3.RIGHT, 0.55 * chest_lag) * cp.basis
		_repose_branch(pose, chest_idx, cp)
	var head_lag := maxf(0.0, body_u - head_u)
	if neck_idx >= 0 and head_lag > 0.001:
		var np := pose[neck_idx]
		np.basis = Basis(Vector3.RIGHT, 0.34 * head_lag) * np.basis
		_repose_branch(pose, neck_idx, np)
	if head_idx >= 0 and head_lag > 0.001:
		var hp := pose[head_idx]
		hp.basis = Basis(Vector3.RIGHT, 0.52 * head_lag) * hp.basis
		_repose_branch(pose, head_idx, hp)
	# Trải rộng đôi cánh chậm rãi theo đà nhấc người rồi thu êm về tư thế đứng thẳng uy nghi.
	var wing_spread := sin(base_u * PI) * 0.58 * (1.0 - smoothstep(0.76, 1.0, base_u))
	if wing_spread > 0.001:
		_aim_wings(pose, Vector3(0.84, 0.34, -0.38), Vector3(0.78, 0.30, -0.44), wing_spread)
	return pose


func _sky_reascent_pose(idle: Array[Transform3D], t: float) -> Array[Transform3D]:
	# Các lần bay lại sau (0.48s): tái sử dụng đúng bản copy nhịp vỗ cánh thứ 2 tăng tốc của Action_005 (1.00s..1.62s)!
	var land_end := _sky_dive_land_pose(idle, 1.0)
	var flap_u := clampf((t - 0.14) / 0.86, 0.0, 1.0)
	var flap_src := lerpf(1.00, 1.62, flap_u)
	var flap_pose := _sample(&"Action_005", flap_src)
	_relax_arms(flap_pose, idle)
	if t < 0.22:
		return _blend(land_end, flap_pose, smoothstep(0.0, 0.22, t))
	return flap_pose


func _resonance_slam_pose(idle: Array[Transform3D], t: float) -> Array[Transform3D]:
	# 0.00..0.24: Nhấc cán rìu lên cao hơn bình thường.
	# 0.24..0.55 (~0.51s): Giữ rìu trên cao đầy uy lực + mở cánh rộng lấy đà!
	# 0.55..0.68: Giậm thật mạnh đuôi cán rìu xuống đất tại RESONANCE_HIT (0.68)!
	# 0.68..1.00: Giữ thế chạm đất rồi thu về Idle.
	var has_src := _animator.has_animation(&"AxeSignal")
	var src_len := _animator.get_animation(&"AxeSignal").length if has_src else 1.0
	var mapped: float
	if t < 0.24:
		mapped = lerpf(0.0, 0.36, smoothstep(0.0, 0.24, t))
	elif t < 0.55:
		mapped = 0.36
	elif t < RESONANCE_HIT:
		mapped = lerpf(0.36, 0.68, smoothstep(0.55, RESONANCE_HIT, t))
	elif t < 0.85:
		mapped = lerpf(0.68, 0.74, (t - RESONANCE_HIT) / (0.85 - RESONANCE_HIT))
	else:
		mapped = lerpf(0.74, 1.0, smoothstep(0.85, 1.0, t))
	var pose := _sample(&"AxeSignal", mapped * src_len) if has_src else _stamp(idle, mapped)
	var high_lift := smoothstep(0.04, 0.22, t) * (1.0 - smoothstep(0.55, RESONANCE_HIT, t))
	var slam_drive := smoothstep(0.58, RESONANCE_HIT, t) * (1.0 - smoothstep(0.84, 1.0, t))
	if high_lift > 0.001:
		var tremble := sin(t * 48.0) * 0.015 if (t >= 0.24 and t <= 0.55) else 0.0
		var arm_pose := pose[_arm]
		arm_pose.origin += Vector3(0.0, (0.36 + tremble) * high_lift, -0.06 * high_lift)
		arm_pose.basis = Basis(Vector3.RIGHT, -0.60 * high_lift) * arm_pose.basis
		_repose_branch(pose, _arm, arm_pose)
		_flare_wings_up(pose, 0.80 * high_lift)
	if slam_drive > 0.001:
		var chest_idx := _skeleton.find_bone(&"Chest")
		if chest_idx >= 0:
			var cp := pose[chest_idx]
			cp.basis = Basis(Vector3.RIGHT, 0.18 * slam_drive) * cp.basis
			_repose_branch(pose, chest_idx, cp)
		_flare_wings_up(pose, 0.45 * slam_drive)
	return pose


func _aim_segment(pose: Array[Transform3D], bone_idx: int, child_idx: int, target_dir: Vector3, weight: float) -> void:
	if bone_idx < 0 or child_idx < 0 or weight <= 0.001:
		return
	var cur_vec := pose[child_idx].origin - pose[bone_idx].origin
	if cur_vec.length_squared() < 0.0001:
		return
	var align := Basis(Quaternion(cur_vec.normalized(), target_dir.normalized()))
	var adjusted := pose[bone_idx]
	adjusted.basis = Basis.IDENTITY.slerp(align, weight) * adjusted.basis
	_repose_branch(pose, bone_idx, adjusted)


func _aim_bone_basis(pose: Array[Transform3D], bone_idx: int, x_dir: Vector3, y_dir: Vector3, z_dir: Vector3, weight: float) -> void:
	if bone_idx < 0 or weight <= 0.001:
		return
	var target_b := Basis(x_dir.normalized(), y_dir.normalized(), z_dir.normalized()).orthonormalized()
	var current_scale := pose[bone_idx].basis.get_scale()
	var cur_b := pose[bone_idx].basis.orthonormalized()
	var blended := cur_b.slerp(target_b, weight)
	var adjusted := pose[bone_idx]
	adjusted.basis = blended.scaled(current_scale)
	_repose_branch(pose, bone_idx, adjusted)


func _collapse_pose(idle: Array[Transform3D], crouch: Array[Transform3D], t: float) -> Array[Transform3D]:
	# Dáng chết ngã gục chậm dramatic (2.55s) nằm ÚP SẤP tự nhiên theo giải phẫu rig chim gốc:
	# - 0.00..0.20: Giật lùi mất thăng bằng.
	# - 0.20..0.48: Khuỵu 2 gối nặng xuống trước mặt.
	# - 0.48..0.86: Đổ thẳng úp sấp về phía trước (lưng hướng lên, không xoắn thân), đầu nghiêng sang một bên,
	#               hai tay vươn về trước gập khuỷu úp bàn tay xuống sàn (rìu nằm gọn trong bàn tay phải và áp PHẲNG hoàn toàn trên sàn),
	#               hai cánh úp phẳng đối xứng hai bên, hai chân chim sau (Main Thigh -> Main Knee -> Main Lower Leg -> Main Foot -> Toe Base)
	#               co cong tự nhiên nằm sát mặt sàn chứ không duỗi thẳng cứng và không bao giờ vểnh chân lên trời!
	# - 0.86..1.00: Lắng nhẹ rồi bất động hoàn toàn.
	var chest_idx := _skeleton.find_bone(&"Chest")
	var neck_idx := _skeleton.find_bone(&"Neck1")
	var head_idx := _skeleton.find_bone(&"Head")
	var arm_l := _skeleton.find_bone(&"UpperArm.L")
	var elbow_l := _skeleton.find_bone(&"Elbow.L")
	var fore_l := _skeleton.find_bone(&"Forearm.L")
	var hand_l := _skeleton.find_bone(&"Hand.L")
	var elbow_r := _skeleton.find_bone(&"Elbow.R")
	var fore_r := _skeleton.find_bone(&"Forearm.R")
	var m_thigh_l := _skeleton.find_bone(&"Main Thigh.L")
	var m_knee_l := _skeleton.find_bone(&"Main Knee.L")
	var m_lower_l := _skeleton.find_bone(&"Main Lower Leg.L")
	var m_foot_l := _skeleton.find_bone(&"Main Foot.L")
	var toe_base_l := _skeleton.find_bone(&"Toe Base.L")
	var toe_tip_l := _skeleton.find_bone(&"Toe1.L")
	var m_thigh_r := _skeleton.find_bone(&"Main Thigh.R")
	var m_knee_r := _skeleton.find_bone(&"Main Knee.R")
	var m_lower_r := _skeleton.find_bone(&"Main Lower Leg.R")
	var m_foot_r := _skeleton.find_bone(&"Main Foot.R")
	var toe_base_r := _skeleton.find_bone(&"Toe Base.R")
	var toe_tip_r := _skeleton.find_bone(&"Toe1.R")
	var tail_base := _skeleton.find_bone(&"TailBase")
	var tail_mid := _skeleton.find_bone(&"Tail.005")

	var recoil_w := sin(clampf(t / 0.22, 0.0, 1.0) * PI) if t < 0.22 else 0.0
	var kneel_t := smoothstep(0.16, 0.48, t)
	var fall_t := pow(clampf((t - 0.48) / 0.38, 0.0, 1.0), 1.32)
	var settle_t := clampf((t - 0.86) / 0.14, 0.0, 1.0)
	var bounce := sin(settle_t * PI) * (1.0 - settle_t) * 0.025 if t >= 0.86 else 0.0

	var pose := _blend(idle, crouch, kneel_t * (1.0 - fall_t * 0.88))
	_relax_arms(pose, idle)

	# 1. Hạ Pelvis sát sàn và đổ úp sấp ngang phẳng (roll = 0) để toàn thân - chân - tay áp thật sát mặt đất (không lơ lửng!).
	var pelv := pose[_pelvis]
	var target_pelv_y := lerpf(pelv.origin.y, 0.17, fall_t) + bounce * 0.22
	pelv.origin = Vector3(pelv.origin.x, target_pelv_y, pelv.origin.z + 0.14 * kneel_t + 0.44 * fall_t)
	var pelv_pitch := -0.14 * recoil_w + 0.14 * kneel_t * (1.0 - fall_t) + 1.48 * fall_t - bounce * 0.15
	pelv.basis = Basis(Vector3.RIGHT, pelv_pitch) * pelv.basis
	_repose_branch(pose, _pelvis, pelv)

	# 2. Điều khiển ĐÚNG chuỗi xương chân thực (Main Thigh -> Main Knee -> Main Lower Leg -> Main Foot -> Toe Base):
	#    Hai chân chim co cong tự nhiên chữ S và hạ sát hẳn xuống mặt sàn, bàn chân và móng nằm bẹp thư giãn sát đất.
	if fall_t > 0.001:
		var leg_w := smoothstep(0.0, 0.94, fall_t)
		# Chân trái (+X): đùi hạ sát sàn mở ra ngoài, gối co tự nhiên vào trong rồi cổ chân & móng mở bẹp sát mặt đất.
		_aim_segment(pose, m_thigh_l, m_knee_l, Vector3(0.50, -0.22, -0.84), leg_w)
		_aim_segment(pose, m_knee_l, m_lower_l, Vector3(-0.22, -0.10, -0.97), leg_w)
		_aim_segment(pose, m_lower_l, m_foot_l, Vector3(-0.30, -0.06, -0.95), leg_w)
		_aim_segment(pose, m_foot_l, toe_base_l, Vector3(0.32, -0.05, -0.95), leg_w)
		_aim_segment(pose, toe_base_l, toe_tip_l, Vector3(0.52, -0.14, -0.84), leg_w)

		# Chân phải (-X): co cong nhẹ bất đối xứng tự nhiên và hạ sát mặt sàn.
		_aim_segment(pose, m_thigh_r, m_knee_r, Vector3(-0.58, -0.22, -0.78), leg_w)
		_aim_segment(pose, m_knee_r, m_lower_r, Vector3(0.24, -0.10, -0.96), leg_w)
		_aim_segment(pose, m_lower_r, m_foot_r, Vector3(0.36, -0.06, -0.93), leg_w)
		_aim_segment(pose, m_foot_r, toe_base_r, Vector3(-0.28, -0.05, -0.96), leg_w)
		_aim_segment(pose, toe_base_r, toe_tip_r, Vector3(-0.48, -0.14, -0.86), leg_w)

		if tail_base >= 0 and tail_mid >= 0:
			_aim_segment(pose, tail_base, tail_mid, Vector3(0.04, -0.08, -0.99), leg_w)

	# 3. Cột sống & cổ ngang bằng sát sàn (không chúi đầu thấp hơn hông khiến toàn thân bị nâng hở sàn) -> đầu áp má sang bên nghỉ trên đất.
	if chest_idx >= 0 and fall_t > 0.001:
		_aim_segment(pose, chest_idx, neck_idx, Vector3(0.0, 0.07, 1.0), fall_t)
	elif chest_idx >= 0:
		var cp := pose[chest_idx]
		cp.basis = Basis(Vector3.RIGHT, -0.14 * recoil_w + 0.08 * kneel_t) * cp.basis
		_repose_branch(pose, chest_idx, cp)
	if neck_idx >= 0 and fall_t > 0.001:
		_aim_segment(pose, neck_idx, head_idx, Vector3(0.0, 0.04, 1.0), fall_t)
	if head_idx >= 0:
		var hp := pose[head_idx]
		hp.basis = (Basis(Vector3.UP, 1.08 * fall_t) * Basis(Vector3.RIGHT, -0.76 * fall_t)) * hp.basis
		_repose_branch(pose, head_idx, hp)

	# 4. Cả hai tay vươn về trước hạ sát mặt sàn; riêng tay phải (Hand.R) căn ĐẦY ĐỦ 3 TRỤC
	#    sao cho mu bàn tay (+Z) ngửa lên, lòng bàn tay úp sát sàn và cả cán + lưỡi rìu áp nằm bẹp 100% trên mặt sàn!
	if fall_t > 0.001:
		var arm_w := smoothstep(0.0, 0.92, fall_t)
		_aim_segment(pose, arm_l, elbow_l, Vector3(0.68, -0.07, 0.73), arm_w)
		var f_l := fore_l if fore_l >= 0 else elbow_l
		_aim_segment(pose, f_l, hand_l, Vector3(0.10, -0.03, 0.99), arm_w)

		_aim_segment(pose, _arm, elbow_r, Vector3(-0.72, -0.19, 0.67), arm_w)
		var f_r := fore_r if fore_r >= 0 else elbow_r
		_aim_segment(pose, f_r, _hand, Vector3(-0.42, -0.14, 0.90), arm_w)
		if _hand >= 0:
			var hand_y := Vector3(-0.64, 0.0, 0.77).normalized()
			var hand_z := Vector3.UP
			var hand_x := hand_y.cross(hand_z).normalized()
			_aim_bone_basis(pose, f_r, hand_x, hand_y, hand_z, arm_w * 0.65)
			_aim_bone_basis(pose, _hand, hand_x, hand_y, hand_z, arm_w)

	# 5. Đôi cánh trải rộng úp phẳng tự nhiên hai bên, xuôi nhẹ về sau sát mặt sàn (không vặn vẹo).
	if t < 0.22:
		_aim_wings(pose, Vector3(0.84, 0.42, -0.32), Vector3(0.88, 0.34, -0.28), recoil_w * 0.50)
	else:
		var w_flat := smoothstep(0.32, 0.88, t)
		_aim_wings(pose, Vector3(0.84, -0.07, -0.54), Vector3(0.74, -0.05, -0.67), w_flat)

	# 6. Kẹp sạch toàn bộ khớp thực (gồm Main Foot, Toe Base, Toe1, Hand, đầu & 2 đầu rìu) nằm sát mặt sàn (0% xuyên sàn, 0% hở sàn).
	var min_y := INF
	for bname: StringName in [
		&"Pelvis", &"Chest", &"Neck1", &"Head",
		&"Elbow.L", &"Hand.L", &"Elbow.R", &"Hand.R",
		&"Main Knee.L", &"Main Knee.R", &"Main Foot.L", &"Main Foot.R",
		&"Toe Base.L", &"Toe Base.R", &"Toe1.L", &"Toe1.R"
	]:
		var idx := _skeleton.find_bone(bname)
		if idx >= 0:
			min_y = minf(min_y, pose[idx].origin.y)
	if _hand >= 0:
		var axe_blade_pt := pose[_hand] * _axe_edge
		var axe_butt_pt := pose[_hand] * _axe_end
		min_y = minf(min_y, minf(axe_blade_pt.y, axe_butt_pt.y))
	var floor_clearance := lerpf(0.05, 0.08, fall_t)
	if min_y < floor_clearance:
		var lifted := pose[_pelvis]
		lifted.origin.y += floor_clearance - min_y
		_repose_branch(pose, _pelvis, lifted)
	return pose


func _get_up_pose(idle: Array[Transform3D], crouch: Array[Transform3D], t: float) -> Array[Transform3D]:
	# Khớp chính xác 100% từ frame cuối của Collapse (t = 1.0) -> gượng chống rìu từ từ (2.55s) -> đứng bật dậy về Idle1!
	var collapsed := _collapse_pose(idle, crouch, 1.0)
	var kneel_brace := _collapse_pose(idle, crouch, 0.52)
	var head_idx := _skeleton.find_bone(&"Head")
	if t < 0.30:
		# Nhịp đầu từ tốn: ngẩng đầu dò sức & chống tay lên sàn.
		var u := smoothstep(0.0, 0.30, t)
		var pose := _blend(collapsed, kneel_brace, u * 0.34)
		if head_idx >= 0:
			var hp := pose[head_idx]
			hp.basis = Basis(Vector3.RIGHT, -0.24 * u) * hp.basis
			_repose_branch(pose, head_idx, hp)
		return pose
	elif t < 0.68:
		# Đẩy mạnh thân từ nằm lên tư thế khuỵu gối vững vàng.
		var u := smoothstep(0.30, 0.68, t)
		var pose := _blend(collapsed, kneel_brace, lerpf(0.34, 1.0, u))
		var spread := sin(u * PI) * 0.48
		_aim_wings(pose, Vector3(0.88, 0.16, -0.28), Vector3(0.92, 0.08, -0.22), spread)
		return pose
	else:
		# Đứng thẳng dậy từ tốn về Idle1 kèm 1 nhịp bung cánh đầy uy lực.
		var u := smoothstep(0.68, 1.0, t)
		var pose := _blend(kneel_brace, idle, u)
		var flare := sin(u * PI) * 0.52
		_flare_wings_up(pose, flare)
		return pose


func _hover(pose: Array[Transform3D], idle: Array[Transform3D], flap: float, wing_weight: float = 1.0) -> Array[Transform3D]:
	for bone: int in pose.size():
		if _skeleton.get_bone_name(bone).begins_with("Shoulder"):
			_repose_branch(pose, bone, pose[_skeleton.get_bone_parent(bone)] * _local(idle, bone))
	# Mở rộng Wing1 sang hai bên giữ lộ đầu boss, rồi bẻ Wing2 chĩa thẳng về trước tạo dáng chữ U (khớp Top-Down concept).
	for bone: int in pose.size():
		var bone_name := _skeleton.get_bone_name(bone)
		if bone_name.begins_with("Wing1"):
			var side := 1.0 if bone_name.ends_with(".L") else -1.0
			var spread := Basis(Vector3.BACK, -side * 0.46 * wing_weight)
			var yaw := Basis(Vector3.UP, -side * (0.26 + flap * 0.05) * wing_weight)
			var pitch := Basis(Vector3.RIGHT, 0.18 * wing_weight)
			var adjusted := pose[bone]
			adjusted.basis = (yaw * pitch * spread) * adjusted.basis
			_repose_branch(pose, bone, adjusted)
	for bone: int in pose.size():
		var bone_name := _skeleton.get_bone_name(bone)
		if bone_name.begins_with("Wing2"):
			var side := 1.0 if bone_name.ends_with(".L") else -1.0
			var yaw := Basis(Vector3.UP, -side * (0.76 + flap * 0.14) * wing_weight)
			var pitch := Basis(Vector3.RIGHT, (0.24 + flap * 0.06) * wing_weight)
			var adjusted := pose[bone]
			adjusted.basis = (pitch * yaw) * adjusted.basis
			_repose_branch(pose, bone, adjusted)
	return pose


func _stamp(idle: Array[Transform3D], t: float) -> Array[Transform3D]:
	var pose: Array[Transform3D] = idle.duplicate()
	var down := smoothstep(0.27, COMMAND_HIT, t) * (1.0 - smoothstep(0.75, 1.0, t))
	var shoulder := pose[_arm].origin
	var initial := pose[_hand].origin - shoulder
	var grip := Vector3(-0.78, 1.50 - 0.45 * down, 0.97)
	var shoulder_turn := Basis(Quaternion(initial.normalized(), (grip - shoulder).normalized()))
	_repose_branch(pose, _arm, Transform3D(shoulder_turn * pose[_arm].basis, shoulder))
	var axis := (pose[_hand].basis * (_axe_edge - _axe_end)).normalized()
	var up := Vector3(0.0, 1.0, 0.05).normalized()
	var wrist := pose[_hand]
	wrist.basis = Basis(Quaternion(axis, up)) * wrist.basis
	# Đặt đầu cán sát sàn ở frame chạm, giữ chiều dài cánh tay từ rig gốc.
	var butt := wrist * _axe_end
	var reach := wrist.origin - shoulder
	var lowered := reach + Vector3.DOWN * maxf(0.0, butt.y - 0.02)
	if down > 0.0:
		var turn := Basis(Quaternion(reach.normalized(), lowered.normalized()))
		_repose_branch(pose, _arm, Transform3D(Basis.IDENTITY.slerp(turn, down) * pose[_arm].basis, shoulder))
		wrist.origin = pose[_hand].origin
	_repose_branch(pose, _hand, wrist)
	return pose


func _axe_points(mesh: MeshInstance3D) -> void:
	var skin := mesh.skin
	var bind := Transform3D.IDENTITY
	for index: int in skin.get_bind_count():
		if skin.get_bind_name(index) == &"Hand.R":
			bind = skin.get_bind_pose(index)
			break
	var bounds := mesh.get_aabb()
	var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low_pts: Array[Vector3] = []
	var high_pts: Array[Vector3] = []
	var lower := Vector3.ZERO
	var upper := Vector3.ZERO
	for point: Vector3 in points:
		if point.z < bounds.position.z + bounds.size.z * 0.12:
			lower += point
			low_pts.append(point)
		if point.z > bounds.end.z - bounds.size.z * 0.12:
			upper += point
			high_pts.append(point)
	var low_center := lower / maxi(1, low_pts.size())
	var high_center := upper / maxi(1, high_pts.size())
	# Đầu có bán kính tỏa rộng hơn là lưỡi rìu; đầu nhỏ gọn là đuôi cán.
	var low_spread := 0.0
	for p: Vector3 in low_pts:
		low_spread = maxf(low_spread, p.distance_to(low_center))
	var high_spread := 0.0
	for p: Vector3 in high_pts:
		high_spread = maxf(high_spread, p.distance_to(high_center))
	if high_spread >= low_spread:
		_axe_edge = bind * high_center
		_axe_end = bind * low_center
	else:
		_axe_edge = bind * low_center
		_axe_end = bind * high_center


func _bake(length: float, pose_at: Callable) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.step = 1.0 / SAMPLE_RATE
	var count := _skeleton.get_bone_count()
	for bone: int in count:
		var path := NodePath(_path + ":" + String(_skeleton.get_bone_name(bone)))
		for type: Animation.TrackType in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var track := animation.add_track(type)
			animation.track_set_path(track, path)
	var steps := maxi(1, ceili(length * SAMPLE_RATE))
	for frame: int in steps + 1:
		var t := float(frame) / steps
		var poses: Array[Transform3D] = pose_at.call(t)
		for bone: int in count:
			var local := _local(poses, bone)
			animation.position_track_insert_key(bone * 3, t * length, local.origin)
			animation.rotation_track_insert_key(bone * 3 + 1, t * length, local.basis.get_rotation_quaternion())
			animation.scale_track_insert_key(bone * 3 + 2, t * length, local.basis.get_scale())
	return animation


func _sample(clip: StringName, time: float) -> Array[Transform3D]:
	if _animator.current_animation != clip:
		_animator.play(clip, 0.0)
		_animator.advance(0.0)
	_animator.seek(time, true)
	_skeleton.force_update_all_bone_transforms()
	var poses: Array[Transform3D] = []
	for bone: int in _skeleton.get_bone_count():
		poses.append(_skeleton.get_bone_global_pose(bone))
	return poses


func _local(poses: Array[Transform3D], bone: int) -> Transform3D:
	var parent := _skeleton.get_bone_parent(bone)
	return poses[bone] if parent < 0 else poses[parent].affine_inverse() * poses[bone]


func _blend(a: Array[Transform3D], b: Array[Transform3D], weight: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone: int in a.size():
		var parent := _skeleton.get_bone_parent(bone)
		var local := _local(a, bone).interpolate_with(_local(b, bone), weight)
		result.append(local if parent < 0 else result[parent] * local)
	return result


func _repose_branch(poses: Array[Transform3D], start: int, replacement: Transform3D) -> void:
	var adjustment := replacement * poses[start].affine_inverse()
	for bone: int in range(start, poses.size()):
		var ancestor := bone
		while ancestor > start:
			ancestor = _skeleton.get_bone_parent(ancestor)
		if ancestor == start:
			poses[bone] = adjustment * poses[bone]
