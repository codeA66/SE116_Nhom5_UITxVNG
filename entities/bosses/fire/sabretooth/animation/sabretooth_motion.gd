class_name SabretoothMotion
extends Node
## Clip AI có root cố định, track nối dáng và pha chân riêng với bản xem animation gốc.

const LIBRARY := &"sabretooth_ai"
const SLOT := &"Motion"
const PATH := &"sabretooth_ai/Motion"
const LOOP_SLOT := &"Loop"
const LOOP_PATH := &"sabretooth_ai/Loop"
const CINEMATIC_SLOT := &"CinematicRoar"
const CINEMATIC_ROAR := &"sabretooth_ai/CinematicRoar"
const SAMPLE_RATE := 30.0
const GROUNDING := preload("res://entities/bosses/fire/sabretooth/animation/sabretooth_grounding.gd")
const STANDING: Array[StringName] = [&"Warning", &"Growling", &"Roaring"]
const MIRRORED: Dictionary[StringName, StringName] = {&"SwatLft": &"SwatRgt", &"TurnLeft": &"TurnRight", &"Spin180": &"Spin180Right"}
const GAITS: Array[StringName] = [&"Run", &"Run2", &"Trot", &"Stalker", &"BackUp"]
const FEET: Array[StringName] = [&"Sabrecat_RightHand_RHnd_", &"Sabrecat_LeftHand_LHnd_", &"Sabrecat_RightFoot_RFot_", &"Sabrecat_LeftFoot_LFot_"]

static var _shared_clips: Dictionary[StringName, Animation] = {}
static var _shared_yaw: Dictionary[StringName, PackedVector2Array] = {}
static var _shared_turns: Dictionary[StringName, float] = {}
static var _shared_preview: Dictionary[StringName, Animation] = {}
static var _cinematic_roar: Animation

var bridge_duration: float = 0.0
var _animator: AnimationPlayer
var _skeleton: Skeleton3D
var _library := AnimationLibrary.new()
var _clips: Dictionary[StringName, Animation] = {}
var _yaw_points: Dictionary[StringName, PackedVector2Array] = {}
var _turns: Dictionary[StringName, float] = {}
var _pelvis: int
var _hips: int
var _anchor: Vector3
var _played_length: float = 0.0
var _content_length: float = 0.0
var _yaw := Curve.new()
var _looping: bool = false
var _skeleton_path: String
var _grounding := GROUNDING.new()
var _limb_positions: Dictionary[int, Vector3] = {}
var _limb_scales: Dictionary[int, Vector3] = {}


func setup(actor: PreviewFireBoss) -> void:
	_animator = actor.animation_player()
	_skeleton = actor.get_node("Model/Visual/Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	_hips = _skeleton.find_bone(&"Hips")
	_pelvis = _skeleton.find_bone(&"Sabrecat__pelv_")
	var track_path := _animator.get_animation(&"Warning").track_get_path(0)
	_skeleton_path = String(track_path.get_concatenated_names())
	_grounding.setup(_skeleton, _skeleton.get_node("FireSabretooth_Body") as MeshInstance3D)
	_animator.stop()
	_skeleton.reset_bone_poses()
	_animator.play(&"Warning", 0.0)
	_animator.advance(0.0)
	_skeleton.force_update_all_bone_transforms()
	_anchor = _skeleton.get_bone_global_pose(_pelvis).origin
	for name: StringName in FEET:
		var end := _skeleton.find_bone(name)
		var root := _skeleton.get_bone_parent(_skeleton.get_bone_parent(end))
		for bone: int in _skeleton.get_bone_count():
			var ancestor := bone
			while ancestor >= 0 and ancestor != root:
				ancestor = _skeleton.get_bone_parent(ancestor)
			if ancestor == root:
				_limb_positions[bone] = _skeleton.get_bone_pose_position(bone)
				_limb_scales[bone] = _skeleton.get_bone_pose_scale(bone)
	var original := _animator.get_animation_library(&"")
	if _shared_clips.is_empty():
		for clip: StringName in original.get_animation_list():
			_clips[clip] = _normalize(clip, original.get_animation(clip))
		for clip: StringName in STANDING:
			_clips[clip] = _upright_clip(_clips[clip])
		for clip: StringName in GAITS:
			_clips[clip] = _close_gait(_clips[clip])
		_cinematic_roar = _clips[&"Roaring"]
		_clips[&"FireBeam"] = _beam_clip(_clips[&"Roaring"])
		_yaw_points[&"FireBeam"] = PackedVector2Array()
		_turns[&"FireBeam"] = 0.0
		for clip: StringName in MIRRORED:
			var mirrored := MIRRORED[clip]
			_clips[mirrored] = _mirror_clip(_clips[clip])
			_shared_preview[mirrored] = _mirror_clip(original.get_animation(clip))
			var points := PackedVector2Array()
			for point: Vector2 in _yaw_points[clip]:
				points.append(Vector2(point.x, -point.y))
			_yaw_points[mirrored] = points
			_turns[mirrored] = -_turns[clip]
		_shared_clips = _clips
		_shared_yaw = _yaw_points
		_shared_turns = _turns
	else:
		# Các bản spawn dùng lại dữ liệu gốc bất biến, chỉ copy clip đang phát khi cần nối.
		_clips = _shared_clips
		_yaw_points = _shared_yaw
		_turns = _shared_turns
	# Cùng dáng chân đã sửa cho menu O và đoạn gầm đổi phase.
	for clip: StringName in STANDING:
		original.add_animation(clip, _clips[clip])
	for clip: StringName in MIRRORED.values():
		original.add_animation(clip, _shared_preview[clip])
	original.add_animation(&"FireBeam", _clips[&"FireBeam"])
	_animator.stop()
	_skeleton.reset_bone_poses()
	_library.add_animation(CINEMATIC_SLOT, _cinematic_roar)
	_animator.add_animation_library(LIBRARY, _library)
	_yaw.min_value = -TAU
	_yaw.max_value = TAU


func source_length(clip: StringName) -> float:
	return _clips[clip].length if _clips.has(clip) else 0.0


func turn_angle(clip: StringName) -> float:
	return _turns.get(clip, 0.0)


func elapsed() -> float:
	if _animator.current_animation == LOOP_PATH:
		return _animator.current_animation_position
	return clampf(_animator.current_animation_position - bridge_duration, 0.0, _content_length)


func finished() -> bool:
	if _looping:
		return false
	return _animator.current_animation_position >= _played_length - 0.002 or not _animator.is_playing()


func remaining() -> float:
	return maxf(0.0, _played_length - _animator.current_animation_position)


func content_length() -> float:
	return _content_length


func play_warning(seconds: float, blend: float) -> void:
	var animation := _trim_clip(_clips[&"Roaring"], seconds)
	if seconds > animation.length:
		var scale := seconds / animation.length
		for track: int in animation.get_track_count():
			for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
				animation.track_set_key_time(track, key, animation.track_get_key_time(track, key) * scale)
		animation.length = seconds
	_yaw.clear_points()
	_start(animation, blend, false)


func extend_flight(skill: SabretoothSkill, seconds: float) -> void:
	var old_extra := skill.flight_extra
	var from := bridge_duration + skill.retime(skill.flight_window.x)
	var to := bridge_duration + skill.retime(skill.flight_window.y)
	skill.set_flight_duration(seconds)
	var extra := skill.flight_extra - old_extra
	var position := _animator.current_animation_position
	var animation := _animator.get_animation(PATH).duplicate() as Animation
	for track: int in animation.get_track_count():
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			var time := animation.track_get_key_time(track, key)
			animation.track_set_key_time(track, key, time + extra * clampf((time - from) / maxf(to - from, 0.001), 0.0, 1.0))
	animation.length += extra
	_content_length += extra
	_played_length += extra
	var points := PackedVector2Array()
	for point: Vector2 in _yaw_points[skill.animation]:
		points.append(Vector2(skill.retime(point.x), point.y))
	_set_yaw(points, _content_length)
	# Đổi dữ liệu rồi seek một lần về cùng pose, tránh engine giữ chiều dài clip bay cũ.
	_animator.pause()
	_library.remove_animation(SLOT)
	_library.add_animation(SLOT, animation)
	_animator.play(PATH, 0.0)
	_animator.seek(position, true)


func yaw_at(time: float) -> float:
	return _yaw.sample(clampf(time / maxf(_content_length, 0.001), 0.0, 1.0)) if _yaw.point_count > 0 else 0.0


func play(clip: StringName, bridge_seconds: float = 0.20, loop: bool = false, gait_phase: bool = false) -> float:
	if not _clips.has(clip):
		return 0.0
	var animation := _clips[clip]
	if gait_phase and clip in GAITS:
		animation = _shift_gait(animation, _best_phase(animation))
	_set_yaw(_yaw_points[clip], animation.length)
	return _start(animation, bridge_seconds, loop)


func play_skill(skill: SabretoothSkill, bridge_seconds: float = 0.20) -> float:
	if not _clips.has(skill.animation):
		return 0.0
	var animation := _clips[skill.animation].duplicate() as Animation
	for track: int in animation.get_track_count():
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_set_key_time(track, key, skill.retime(animation.track_get_key_time(track, key)))
	animation.length = skill.retime(animation.length)
	var points := PackedVector2Array()
	for point: Vector2 in _yaw_points[skill.animation]:
		points.append(Vector2(skill.retime(point.x), point.y))
	_set_yaw(points, animation.length)
	skill.runtime_clip = PATH
	return _start(animation, bridge_seconds, false)


func play_sequence(clips: Array[StringName], bridge_seconds: float = 0.20, part_time: float = 0.0) -> float:
	if clips.is_empty():
		return 0.0
	var combined := _trim_clip(_clips[clips[0]], part_time)
	for index: int in range(1, clips.size()):
		var next := _trim_clip(_clips[clips[index]], part_time)
		var end := combined.length
		_bridge_poses(combined, end, bridge_seconds, _globals_at(combined, end), _globals_at(next, 0.0))
		for track: int in next.get_track_count():
			var type := next.track_get_type(track)
			if not _bone_track(type):
				continue
			var path := next.track_get_path(track)
			var destination := combined.find_track(path, type)
			if destination < 0:
				destination = combined.add_track(type)
				combined.track_set_path(destination, path)
			for key: int in next.track_get_key_count(track):
				combined.track_insert_key(destination, end + bridge_seconds + next.track_get_key_time(track, key), next.track_get_key_value(track, key))
		combined.length = end + bridge_seconds + next.length
	_yaw.clear_points()
	return _start(combined, bridge_seconds, false)


func _trim_clip(source: Animation, limit: float) -> Animation:
	var animation := source.duplicate() as Animation
	if limit <= 0.0 or limit >= source.length:
		return animation
	animation.length = limit
	for track: int in animation.get_track_count():
		if not _bone_track(animation.track_get_type(track)):
			continue
		var last: Variant = _sample(source, track, limit)
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			if animation.track_get_key_time(track, key) > limit:
				animation.track_remove_key(track, key)
		animation.track_insert_key(track, limit, last)
	return animation


func _mirror_clip(source: Animation) -> Animation:
	var animation := source.duplicate() as Animation
	var channels := _bone_channels(animation)
	for track: int in animation.get_track_count():
		if _bone_track(animation.track_get_type(track)) and _skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames()) >= 0:
			for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
				animation.track_remove_key(track, key)
	var opposites := PackedInt32Array()
	var rests: Array[Transform3D] = []
	for bone: int in _skeleton.get_bone_count():
		var name := String(_skeleton.get_bone_name(bone))
		var opposite := name
		if name.contains("Left"):
			opposite = name.replace("Left", "Right").replace("_L", "_R")
		elif name.contains("Right"):
			opposite = name.replace("Right", "Left").replace("_R", "_L")
		var found := _skeleton.find_bone(opposite)
		opposites.append(found if found >= 0 else bone)
		rests.append(_skeleton.get_bone_global_rest(bone))
	var reflect := Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3.BACK), Vector3(_anchor.x * 2.0, 0, 0))
	var steps := maxi(2, ceili(source.length * 60.0))
	for frame: int in steps + 1:
		var time := source.length * frame / steps
		var original := _globals_at(source, time)
		var poses: Array[Transform3D] = []
		for bone: int in original.size():
			var opposite := opposites[bone]
			var mirrored := reflect * original[opposite] * rests[opposite].affine_inverse() * reflect * rests[bone]
			mirrored.origin = reflect * original[opposite].origin
			poses.append(mirrored)
		_write_pose(animation, channels, poses, time)
	return animation


func preview_loop(source: Animation, seconds: float) -> Animation:
	var animation := source.duplicate() as Animation
	_bridge_poses(animation, source.length, seconds, _globals_at(source, source.length), _globals_at(source, 0.0))
	animation.length += seconds
	animation.loop_mode = Animation.LOOP_NONE
	return animation


func _upright_clip(source: Animation) -> Animation:
	var animation := source.duplicate() as Animation
	var path := NodePath(_skeleton_path + ":" + String(_skeleton.get_bone_name(_hips)))
	var channels := Vector3i(animation.find_track(path, Animation.TYPE_POSITION_3D), animation.find_track(path, Animation.TYPE_ROTATION_3D), animation.find_track(path, Animation.TYPE_SCALE_3D))
	for track: int in [channels.x, channels.y, channels.z]:
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, key)
	var steps := maxi(2, ceili(source.length * 60.0))
	var corrections: Array[Transform3D] = []
	for frame: int in steps + 1:
		corrections.append(_grounding.support_transform(_globals_at(source, source.length * frame / steps)))
	for frame: int in steps + 1:
		var correction := corrections[maxi(0, frame - 3)]
		var count := 1.0
		for neighbor: int in range(maxi(0, frame - 3) + 1, mini(steps, frame + 3) + 1):
			count += 1.0
			correction = correction.interpolate_with(corrections[neighbor], 1.0 / count)
		var time := source.length * frame / steps
		var poses := _globals_at(source, time)
		var parent := _skeleton.get_bone_parent(_hips)
		var adjusted := correction * poses[_hips]
		var local := poses[parent].affine_inverse() * adjusted if parent >= 0 else adjusted
		animation.position_track_insert_key(channels.x, time, local.origin)
		animation.rotation_track_insert_key(channels.y, time, local.basis.get_rotation_quaternion())
		animation.scale_track_insert_key(channels.z, time, local.basis.get_scale())
	return animation


func _lock_limb_lengths(animation: Animation) -> void:
	for track: int in animation.get_track_count():
		var bone := _skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames())
		if not _limb_positions.has(bone):
			continue
		var type := animation.track_get_type(track)
		for key: int in animation.track_get_key_count(track):
			if type == Animation.TYPE_POSITION_3D:
				animation.track_set_key_value(track, key, _limb_positions[bone])
			elif type == Animation.TYPE_SCALE_3D:
				animation.track_set_key_value(track, key, _limb_scales[bone])

func _normalize(name: StringName, source: Animation) -> Animation:
	var animation := source.duplicate() as Animation
	animation.loop_mode = Animation.LOOP_NONE
	var keys := maxi(1, ceili(source.length * 120.0))
	var path: NodePath
	for track: int in source.get_track_count():
		var candidate := source.track_get_path(track)
		if candidate.get_subname_count() == 1 and candidate.get_subname(0) == &"Hips":
			path = candidate
			break
	if path.is_empty():
		_yaw_points[name] = PackedVector2Array()
		_turns[name] = 0.0
		return animation
	for track: int in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_path(track) == path:
			animation.remove_track(track)
	var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
	var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
	var scale_track := animation.add_track(Animation.TYPE_SCALE_3D)
	for track: int in [position_track, rotation_track, scale_track]:
		animation.track_set_path(track, path)
	_animator.stop()
	_skeleton.reset_bone_poses()
	_animator.play(name, 0.0)
	_animator.advance(0.0)
	var yaw_points := PackedVector2Array()
	var last_yaw := 0.0
	var first_yaw := 0.0
	for key: int in keys + 1:
		var time := source.length * key / keys
		_animator.seek(time, true)
		_skeleton.force_update_all_bone_transforms()
		var pelvis := _skeleton.get_bone_global_pose(_pelvis)
		var lateral := pelvis.basis.z.slide(Vector3.UP)
		var angle := atan2(lateral.x, lateral.z) if lateral.length_squared() > 0.001 else last_yaw
		if key == 0:
			first_yaw = angle
			last_yaw = angle
		angle = last_yaw + angle_difference(last_yaw, angle)
		last_yaw = angle
		yaw_points.append(Vector2(time, angle - first_yaw))
		# Hiệu chỉnh gốc ở Hips để toàn bộ con cháu giữ đúng chuyển động chân/cổ.
		var correction := Transform3D(Basis(Vector3.UP, PI * 0.5 - angle), Vector3.ZERO)
		var turned := correction * pelvis.origin
		correction.origin = Vector3(_anchor.x - turned.x, 0.0, _anchor.z - turned.z)
		var global := correction * _skeleton.get_bone_global_pose(_hips)
		var parent := _skeleton.get_bone_parent(_hips)
		var pose := global if parent < 0 else _skeleton.get_bone_global_pose(parent).affine_inverse() * global
		animation.position_track_insert_key(position_track, time, pose.origin)
		animation.rotation_track_insert_key(rotation_track, time, pose.basis.get_rotation_quaternion())
		animation.scale_track_insert_key(scale_track, time, pose.basis.get_scale())
	_yaw_points[name] = yaw_points
	_turns[name] = last_yaw - first_yaw
	_lock_limb_lengths(animation)
	return animation


func _start(source: Animation, seconds: float, loop: bool) -> float:
	var animation := source.duplicate() as Animation
	bridge_duration = maxf(0.0, seconds)
	_content_length = source.length
	if bridge_duration > 0.0:
		_skeleton.force_update_all_bone_transforms()
		var current := _global_poses()
		var first := _globals_at(source, 0.0)
		for track: int in animation.get_track_count():
			if not _bone_track(animation.track_get_type(track)):
				continue
			for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
				animation.track_set_key_time(track, key, animation.track_get_key_time(track, key) + bridge_duration)
		_bridge_poses(animation, 0.0, bridge_duration, current, first)
	animation.length = source.length + bridge_duration
	animation.loop_mode = Animation.LOOP_NONE
	_looping = loop
	_played_length = animation.length
	_animator.stop(true)
	if _library.has_animation(SLOT):
		_library.remove_animation(SLOT)
	if _library.has_animation(LOOP_SLOT):
		_library.remove_animation(LOOP_SLOT)
	_library.add_animation(SLOT, animation)
	if loop:
		var loop_clip := source.duplicate() as Animation
		loop_clip.loop_mode = Animation.LOOP_LINEAR
		_library.add_animation(LOOP_SLOT, loop_clip)
	_animator.speed_scale = 1.0
	_animator.play(PATH, 0.0)
	_animator.advance(0.0)
	if loop:
		_animator.queue(LOOP_PATH)
	return _played_length


func _bridge_poses(animation: Animation, offset: float, seconds: float, from: Array[Transform3D], to: Array[Transform3D]) -> void:
	# Nối trong không gian khớp để phép quay giữ nguyên độ dài tay chân.
	var channels := _bone_channels(animation)
	var local_from: Array[Transform3D] = []
	var local_to: Array[Transform3D] = []
	for bone: int in from.size():
		var parent := _skeleton.get_bone_parent(bone)
		local_from.append(from[parent].affine_inverse() * from[bone] if parent >= 0 else from[bone])
		local_to.append(to[parent].affine_inverse() * to[bone] if parent >= 0 else to[bone])
	var steps := maxi(2, ceili(seconds * 60.0))
	for step: int in steps + 1:
		var weight := smoothstep(0.0, 1.0, float(step) / steps)
		for bone: int in from.size():
			var local := local_from[bone].interpolate_with(local_to[bone], weight)
			var time := offset + seconds * step / steps
			animation.position_track_insert_key(channels[bone].x, time, _limb_positions.get(bone, local.origin))
			animation.rotation_track_insert_key(channels[bone].y, time, local.basis.get_rotation_quaternion())
			animation.scale_track_insert_key(channels[bone].z, time, _limb_scales.get(bone, local.basis.get_scale()))


func _bone_channels(animation: Animation) -> Array[Vector3i]:
	var channels: Array[Vector3i] = []
	for bone: int in _skeleton.get_bone_count():
		var path := NodePath(_skeleton_path + ":" + String(_skeleton.get_bone_name(bone)))
		var tracks := Vector3i(-1, -1, -1)
		for axis: int in 3:
			var type: Animation.TrackType = [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D][axis]
			tracks[axis] = animation.find_track(path, type)
			if tracks[axis] < 0:
				tracks[axis] = animation.add_track(type)
				animation.track_set_path(tracks[axis], path)
		channels.append(tracks)
	return channels


func _write_pose(animation: Animation, channels: Array[Vector3i], poses: Array[Transform3D], time: float) -> void:
	for bone: int in poses.size():
		var parent := _skeleton.get_bone_parent(bone)
		var local := poses[parent].affine_inverse() * poses[bone] if parent >= 0 else poses[bone]
		animation.position_track_insert_key(channels[bone].x, time, _limb_positions.get(bone, local.origin))
		animation.rotation_track_insert_key(channels[bone].y, time, local.basis.get_rotation_quaternion())
		animation.scale_track_insert_key(channels[bone].z, time, _limb_scales.get(bone, local.basis.get_scale()))


func _global_poses() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone: int in _skeleton.get_bone_count():
		poses.append(_skeleton.get_bone_global_pose(bone))
	return poses


func _globals_at(animation: Animation, time: float) -> Array[Transform3D]:
	var saved: Array[Transform3D] = []
	for bone: int in _skeleton.get_bone_count():
		saved.append(Transform3D(Basis(_skeleton.get_bone_pose_rotation(bone)).scaled(_skeleton.get_bone_pose_scale(bone)), _skeleton.get_bone_pose_position(bone)))
	_skeleton.reset_bone_poses()
	for track: int in animation.get_track_count():
		var type := animation.track_get_type(track)
		if not _bone_track(type):
			continue
		var bone := _skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames())
		if bone < 0:
			continue
		var pose: Variant = _sample(animation, track, time)
		if type == Animation.TYPE_POSITION_3D:
			_skeleton.set_bone_pose_position(bone, pose)
		elif type == Animation.TYPE_ROTATION_3D:
			_skeleton.set_bone_pose_rotation(bone, pose)
		else:
			_skeleton.set_bone_pose_scale(bone, pose)
	_skeleton.force_update_all_bone_transforms()
	var sampled := _global_poses()
	for bone: int in saved.size():
		_skeleton.set_bone_pose_position(bone, saved[bone].origin)
		_skeleton.set_bone_pose_rotation(bone, saved[bone].basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, saved[bone].basis.get_scale())
	_skeleton.force_update_all_bone_transforms()
	return sampled


func _best_phase(animation: Animation) -> float:
	var best := 0.0
	var least := INF
	for frame: int in 16:
		var time := animation.length * frame / 16.0
		var score := 0.0
		for name: StringName in FEET:
			var bone := _skeleton.find_bone(name)
			for track: int in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D or animation.track_get_path(track).get_concatenated_subnames() != name:
					continue
				var candidate: Quaternion = animation.rotation_track_interpolate(track, time)
				score += absf(candidate.angle_to(_skeleton.get_bone_pose_rotation(bone)))
		if score < least:
			least = score
			best = time
	return best


func _shift_gait(source: Animation, phase: float) -> Animation:
	var animation := source.duplicate() as Animation
	var keys := maxi(2, ceili(source.length * SAMPLE_RATE))
	for track: int in animation.get_track_count():
		if not _bone_track(animation.track_get_type(track)):
			continue
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, key)
		for key: int in keys + 1:
			var time := source.length * key / keys
			var sample_time := fposmod(time + phase, source.length)
			animation.track_insert_key(track, time, _sample(source, track, sample_time))
	return animation


func _close_gait(source: Animation) -> Animation:
	# Hai đầu vòng dùng cùng một dáng; đổi pha chân không còn đi qua bước nhảy của clip gốc.
	var animation := source.duplicate() as Animation
	var seam := minf(0.09, source.length * 0.15)
	var steps := ceili(source.length * 60.0)
	for track: int in source.get_track_count():
		if not _bone_track(source.track_get_type(track)):
			continue
		var rotation := source.track_get_type(track) == Animation.TYPE_ROTATION_3D
		var first: Variant = _sample(source, track, 0.0)
		var last: Variant = _sample(source, track, source.length)
		var anchor: Variant = first.slerp(last, 0.5) if rotation else first.lerp(last, 0.5)
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, key)
		for frame: int in steps + 1:
			var time := source.length * frame / steps
			var value: Variant = _sample(source, track, time)
			var weight := maxf(1.0 - smoothstep(0.0, seam, time), smoothstep(source.length - seam, source.length, time))
			value = value.slerp(anchor, weight) if rotation else value.lerp(anchor, weight)
			animation.track_insert_key(track, time, value)
		if rotation:
			var samples: Array[Quaternion] = []
			for frame: int in steps:
				samples.append(animation.track_get_key_value(track, frame))
			for frame: int in steps + 1:
				var filtered := samples[frame % steps]
				var total := 4.0
				for neighbor: int in [-2, -1, 1, 2]:
					var weight := 2.0 if absi(neighbor) == 1 else 1.0
					total += weight
					filtered = filtered.slerp(samples[posmod(frame + neighbor, steps)], weight / total)
				animation.track_set_key_value(track, frame, filtered)
	return animation


func _beam_clip(source: Animation) -> Animation:
	var animation := source.duplicate() as Animation
	var channels := _bone_channels(animation)
	for track: int in animation.get_track_count():
		if _skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames()) < 0:
			continue
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, key)
	var neck := _skeleton.find_bone(&"Sabrecat_Neck_Nek0_")
	animation.length = 1.4
	for frame: int in 85:
		var time := animation.length * frame / 84.0
		var roar := _globals_at(source, 0.67 + 0.07 * sin(TAU * time / animation.length))
		var poses := _globals_at(_clips[&"Growling"], 0.15 + 0.03 * sin(TAU * time / animation.length))
		for bone: int in poses.size():
			var ancestor := bone
			while ancestor >= 0 and ancestor != neck:
				ancestor = _skeleton.get_bone_parent(ancestor)
			if ancestor == neck:
				var parent := _skeleton.get_bone_parent(bone)
				poses[bone] = poses[parent] * (roar[parent].affine_inverse() * roar[bone])
		var forward := poses[neck].basis.x.normalized()
		var pitch := atan2(forward.y, forward.slide(Vector3.UP).length()) + deg_to_rad(8.0)
		var turn := Basis(Vector3.RIGHT, pitch)
		var root := poses[neck].origin
		var correction := Transform3D(turn, root - turn * root)
		for bone: int in poses.size():
			var ancestor := bone
			while ancestor >= 0 and ancestor != neck:
				ancestor = _skeleton.get_bone_parent(ancestor)
			if ancestor == neck:
				poses[bone] = correction * poses[bone]
		_write_pose(animation, channels, poses, time)
	return animation


func _set_yaw(points: PackedVector2Array, length: float) -> void:
	_yaw.clear_points()
	for point: Vector2 in points:
		_yaw.add_point(Vector2(point.x / maxf(length, 0.001), point.y), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)


func _bone_track(type: Animation.TrackType) -> bool:
	return type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]


func _sample(animation: Animation, track: int, time: float) -> Variant:
	var type := animation.track_get_type(track)
	if type == Animation.TYPE_ROTATION_3D:
		return animation.rotation_track_interpolate(track, time)
	if type == Animation.TYPE_SCALE_3D:
		return animation.scale_track_interpolate(track, time)
	return animation.position_track_interpolate(track, time)
