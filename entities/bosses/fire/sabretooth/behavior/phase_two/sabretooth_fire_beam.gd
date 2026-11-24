extends EnemyState
## Nạp theo player, khóa một giây, rồi quét beam trong năm giây.

const EJECT_MAX_TIME := 0.45
const TURN_DEADZONE := 0.015

var _actor: FireSabretooth
var _skeleton: Skeleton3D
var _jaw: int
var _time: float
var _firing: bool
var _ejecting_player: bool
var _turn_dir: float
var _reverse_pause_left: float


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_skeleton = _actor.get_node("Model/Visual/Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	_jaw = _skeleton.find_bone(&"Sabrecat_Head_jaw_")


func enter(_previous: StringName) -> void:
	_time = 0.0
	_firing = false
	_ejecting_player = false
	_turn_dir = 0.0
	_reverse_pause_left = 0.0
	_actor.velocity = Vector3.ZERO
	_actor.hitbox.cancel()
	_actor.phase.show_flame_form()
	_actor.motion.play(&"FireBeam", _actor.profile.bridge_duration, true)
	# Khi bắt đầu rặn chiêu bắn laser: đẩy ngay player đứng gần văng ra ngoài phạm vi barrier,
	# đồng thời bật hitbox barrier full ngay lập tức (khi player đã ở ngoài hoặc ngay khoảnh khắc vừa trượt ra khỏi mép vòng).
	_push_nearby_target_outward()
	_actor.fire_vfx.update_beam_barrier(_actor.global_position, 0.0, _ejecting_player)


func exit() -> void:
	_actor.fire_vfx.stop_beam()
	_actor.model.rotation.x = 0.0
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0


func physics_update(delta: float) -> void:
	_time += delta
	_actor.apply_gravity(delta)
	var data := _actor.profile
	var firing_at := data.beam_charge_time + data.beam_lock_time
	if _time < data.beam_charge_time:
		_actor.face_direction(_actor.direction_to_target(), delta)
	elif _firing and _actor.has_target():
		var angle_diff: float = _actor.target_angle()
		if _reverse_pause_left > 0.0:
			_reverse_pause_left = maxf(0.0, _reverse_pause_left - delta)
			if absf(angle_diff) > TURN_DEADZONE:
				_turn_dir = signf(angle_diff)
		elif absf(angle_diff) > TURN_DEADZONE:
			var desired_dir: float = signf(angle_diff)
			# Khi player lướt xuyên qua tia buộc Hổ đảo chiều xoay, dừng 0.2s để player có khoảng trống di chuyển.
			if _turn_dir != 0.0 and desired_dir != _turn_dir and data.beam_reverse_pause > 0.0:
				_turn_dir = desired_dir
				_reverse_pause_left = data.beam_reverse_pause
			else:
				_turn_dir = desired_dir
				var player := _actor.target as Character
				var speed := player.movement.max_speed if player else 6.0
				var ramp_t := clampf((_time - firing_at) / maxf(data.beam_duration, 0.1), 0.0, 1.0)
				var track_ratio := lerpf(data.beam_tracking_start_ratio, data.beam_tracking_max_ratio, ramp_t)
				var turn_step := speed * track_ratio / maxf(_actor.distance_to_target(), 2.0) * delta
				_actor.set_body_yaw(rotate_toward(_actor.model.rotation.y, _actor.model.rotation.y + angle_diff, turn_step))
	_skeleton.force_update_all_bone_transforms()
	var forward := _actor.get_facing_direction()
	var mouth := _skeleton.to_global(_skeleton.get_bone_global_pose(_jaw).origin) + Vector3.UP * 0.1
	var orb := mouth + forward * data.beam_muzzle_offset
	_step_player_ejection(delta, data)
	_actor.fire_vfx.update_beam_barrier(_actor.global_position, _time, _ejecting_player)
	if _time < firing_at:
		_actor.fire_vfx.charge(orb, minf(1.0, _time / maxf(data.beam_charge_time, 0.01)))
		return
	var elapsed := _time - firing_at
	if not _firing:
		_firing = true
		_actor.fire_vfx.charge(orb, 1.0)
		ScreenShake.add_trauma_at(0.35, _actor.global_position, 10.0, 28.0)
	var recoil := maxf(0.0, 1.0 - elapsed / 0.3)
	_actor.velocity.x = -forward.x * data.beam_recoil / 0.15 * recoil
	_actor.velocity.z = -forward.z * data.beam_recoil / 0.15 * recoil
	_actor.model.rotation.x = -deg_to_rad(6.0) * sin(clampf(elapsed / 0.6, 0.0, 1.0) * PI)
	_actor.fire_vfx.beam(orb, forward, delta, mouth)
	if elapsed >= data.beam_duration:
		if _actor.phase_two_chain or not _actor.manual_skill:
			_actor.rest_then_phase_two(&"TigerFireFinale")
		else:
			_actor.finish_phase_two_move()


func _push_nearby_target_outward() -> void:
	if not _actor.has_target():
		return
	var target_char := _actor.target as Character
	if target_char == null or target_char.wind_receiver == null:
		return
	var data := _actor.profile
	var barrier_r := maxf(data.beam_barrier_radius, 2.0)
	var push_r := maxf(data.beam_push_radius, barrier_r + 0.6)
	var offset := (target_char.global_position - _actor.global_position).slide(Vector3.UP)
	var dist := offset.length()
	if dist > push_r:
		return
	var dir := offset.normalized() if dist > 0.05 else _actor.get_facing_direction().slide(Vector3.UP).normalized()
	if dir.is_zero_approx():
		dir = Vector3.BACK
	target_char.wind_receiver.clear_push()
	target_char.wind_receiver.push(dir * maxf(data.beam_push_speed, 10.0))
	CombatFx.spawn_hit(_actor.global_position + Vector3.UP * 0.85, dir, Color("#ff6a18"), 1.25)
	ScreenShake.add_trauma_at(0.28, _actor.global_position, 8.0, 20.0)
	# Nếu player đang đứng sẵn bên trong bán kính barrier lúc vừa rặn chiêu, mở đường đẩy thoát ra ngoài trong tối đa EJECT_MAX_TIME rồi khóa cứng tường ngay!
	_ejecting_player = dist < barrier_r + 0.35


func _step_player_ejection(delta: float, data: SabretoothData) -> void:
	if not _ejecting_player:
		return
	if not _actor.has_target() or _time >= EJECT_MAX_TIME:
		_ejecting_player = false
		return
	var target_char := _actor.target as Character
	if target_char == null or target_char.wind_receiver == null:
		_ejecting_player = false
		return
	var barrier_r := maxf(data.beam_barrier_radius, 2.0)
	var offset := (target_char.global_position - _actor.global_position).slide(Vector3.UP)
	var dist := offset.length()
	if dist >= barrier_r + 0.35:
		_ejecting_player = false
		return
	var dir := offset.normalized() if dist > 0.05 else _actor.get_facing_direction().slide(Vector3.UP).normalized()
	if dir.is_zero_approx():
		dir = Vector3.BACK
	target_char.wind_receiver.steer_push(dir * maxf(data.beam_push_speed, 10.0), 95.0, delta)
