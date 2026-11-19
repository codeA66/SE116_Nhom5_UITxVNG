extends EnemyState
## Cùng đồng hồ với clip đã kéo dài, hitbox theo chân hoặc hàm đang đánh.

var _actor: FireSabretooth
var _skill: SabretoothSkill
var _skeleton: Skeleton3D
var _collision: CollisionShape3D
var _bones := PackedInt32Array()
var _second_bones := PackedInt32Array()
var _warning_left: float
var _started: bool
var _completed: bool
var _window := Vector2.ZERO
var _locked_yaw: float
var _locked: bool
var _telegraph: bool
var _flight: bool
var _flight_started: bool
var _flight_speed: float
var _flight_remaining: float
var _animation_rate: float


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_skill = _actor.pending_skill as SabretoothSkill
	_skeleton = _actor.get_node("Model/Visual/Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	_collision = _actor.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	_bones.clear()
	for bone: StringName in _skill.follow_bones:
		_bones.append(_skeleton.find_bone(bone))
	_second_bones.clear()
	for bone: StringName in _skill.second_follow_bones:
		_second_bones.append(_skeleton.find_bone(bone))
	_flight = _skill.flight_window.y > _skill.flight_window.x
	_flight_started = false
	_flight_speed = 0.0
	_flight_remaining = 0.0
	_animation_rate = _actor.profile.pounce_animation_rate if _flight else 1.0
	_started = false
	_completed = false
	_locked = false
	_window = Vector2.ZERO
	_actor.animation_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_warning_left = 0.60 if _skill.skill_id == &"pounce" and not _actor.is_phase_one() and not _actor.manual_skill else 0.0
	_actor.set_telegraph(true)
	_telegraph = true
	if _warning_left > 0.0:
		_actor.motion.play(&"Roaring", _actor.profile.bridge_duration)
	else:
		_start_swing()
	_actor.skill_started.emit(_skill)


func exit() -> void:
	_actor.hitbox.cancel()
	_actor.set_telegraph(false)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_actor.animation_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if not _completed:
		_actor.finish_attack(false)


func physics_update(delta: float) -> void:
	# Lấy pose cùng tick trước khi đặt vùng trúng, tránh hitbox trễ một frame so với móng.
	_actor.animation_player().advance(delta * _animation_rate)
	_skeleton.force_update_all_bone_transforms()
	_actor.apply_gravity(delta)
	if not _started:
		_actor.face_direction(_actor.direction_to_target(), delta)
		_warning_left -= delta
		if _warning_left <= 0.0:
			_start_swing()
		return
	var time := _actor.motion.elapsed()
	var first_hit := _skill.retime(_skill.active_start)
	var lock_before := _actor.profile.attack_aim_lock if _actor.is_phase_one() else _skill.aim_lock_before_active
	var lock_time := _skill.retime(_skill.flight_window.x) if _flight else first_hit - lock_before
	if not _locked and time < lock_time:
		var aim := _actor.direction_to_target().rotated(Vector3.UP, deg_to_rad(_skill.aim_offset_degrees))
		_actor.face_direction(aim, delta)
		_locked_yaw = _actor.model.rotation.y
	else:
		_locked = true
		if _flight and not _flight_started:
			_start_flight()
			time = _actor.motion.elapsed()
		_actor.set_body_yaw(_locked_yaw + (_actor.motion.yaw_at(time) if _skill.follow_authored_yaw else 0.0))
	var preparing_second := _skill.second_hit.y > 0.0 and time >= _skill.retime(_skill.second_anticipation.x) and time < _skill.retime(_skill.second_hit.x)
	var show_telegraph := time < first_hit or preparing_second
	if show_telegraph != _telegraph:
		_telegraph = show_telegraph
		_actor.set_telegraph(_telegraph)
	_update_hitbox(time)
	var speed := 0.0
	if _flight:
		# Giữ phần quãng đường cuối khi thời điểm đáp rơi giữa hai tick vật lý.
		var step := minf(_flight_remaining, _flight_speed * delta)
		_flight_remaining -= step
		speed = step / delta
	elif time >= _skill.retime(_skill.lunge_window.x) and time < _skill.retime(_skill.lunge_window.y):
		speed = _skill.lunge_speed
	var forward := Vector3(sin(_locked_yaw), 0.0, cos(_locked_yaw))
	_actor.velocity.x = forward.x * speed
	_actor.velocity.z = forward.z * speed
	if _actor.motion.finished():
		_completed = true
		_actor.recovering_skill = _skill
		if _actor.is_phase_one() and not _actor.manual_skill:
			_actor.start_phase_one_cycle()
		state_machine.transition_to(&"TigerRecovery")


func _start_swing() -> void:
	_started = true
	_locked_yaw = _actor.model.rotation.y
	_actor.motion.play_skill(_skill, _actor.profile.ready_bridge if _actor.is_phase_one() else _actor.profile.bridge_duration)


func _start_flight() -> void:
	_flight_started = true
	var direction := _actor.direction_to_target()
	_locked_yaw = atan2(direction.x, direction.z)
	var distance := clampf(_actor.distance_to_target() - _actor.profile.pounce_landing_gap, 0.0, _actor.profile.pounce_travel)
	_actor.motion.extend_flight(_skill, distance / maxf(_actor.profile.pounce_speed, 0.1) * _animation_rate)
	var start := _skill.retime(_skill.flight_window.x)
	var duration := _skill.retime(_skill.flight_window.y) - start
	_flight_speed = distance * _animation_rate / maxf(duration, 0.001)
	_flight_remaining = distance


func _update_hitbox(time: float) -> void:
	var bounds := _skill.ai_hit_window_at(time)
	if bounds == Vector2.ZERO:
		if _actor.hitbox.is_active():
			_actor.hitbox.deactivate()
		_window = bounds
		return
	var center := Vector3.ZERO
	var count := 0
	var bones := _second_bones if not _second_bones.is_empty() and bounds.x >= _skill.retime(_skill.second_hit.x) else _bones
	for bone: int in bones:
		if bone >= 0:
			center += _skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)
			count += 1
	_collision.position = _actor.hitbox.to_local(center / count) if count > 0 else _skill.hitbox_center
	(_collision.shape as BoxShape3D).size = _skill.hitbox_size
	if bounds != _window:
		_actor.hitbox.deactivate()
		_actor.hitbox.activate(_skill, (bounds.y - time) / _animation_rate)
		_window = bounds
