class_name PyralonRig
extends Node
## Giữ rig gốc, ghi lại pose cất cánh và đóng cán rìu thành các clip có thể chạy trong menu O.

const LAUNCH := &"pyralon/WingLaunch"
const BARRAGE := &"pyralon/WingBarrage"
const LAND := &"pyralon/WingLand"
const COMMAND := &"pyralon/AxeSignal"
const SAMPLE_RATE := 30.0
const COMMAND_HIT := 0.60

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
	return library


func _hover(pose: Array[Transform3D], idle: Array[Transform3D], flap: float, wing_weight: float = 1.0) -> Array[Transform3D]:
	for bone: int in pose.size():
		if _skeleton.get_bone_name(bone).begins_with("Shoulder"):
			_repose_branch(pose, bone, pose[_skeleton.get_bone_parent(bone)] * _local(idle, bone))
	# Mở rộng Wing1 sang hai bên giữ lộ đầu boss, rồi bẻ Wing2 chĩa thẳng về trước tạo dáng chữ U (khớp Top-Down concept).
	for bone: int in pose.size():
		var name := _skeleton.get_bone_name(bone)
		if name.begins_with("Wing1"):
			var side := 1.0 if name.ends_with(".L") else -1.0
			var spread := Basis(Vector3.BACK, -side * 0.46 * wing_weight)
			var yaw := Basis(Vector3.UP, -side * (0.26 + flap * 0.05) * wing_weight)
			var pitch := Basis(Vector3.RIGHT, 0.18 * wing_weight)
			var adjusted := pose[bone]
			adjusted.basis = (yaw * pitch * spread) * adjusted.basis
			_repose_branch(pose, bone, adjusted)
	for bone: int in pose.size():
		var name := _skeleton.get_bone_name(bone)
		if name.begins_with("Wing2"):
			var side := 1.0 if name.ends_with(".L") else -1.0
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
