extends EnemyState
## Nạp theo player, khóa một giây, rồi quét beam trong năm giây.

var _actor: FireSabretooth
var _skeleton: Skeleton3D
var _jaw: int
var _time: float
var _firing: bool


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_skeleton = _actor.get_node("Model/Visual/Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	_jaw = _skeleton.find_bone(&"Sabrecat_Head_jaw_")


func enter(_previous: StringName) -> void:
	_time = 0.0
	_firing = false
	_actor.velocity = Vector3.ZERO
	_actor.hitbox.cancel()
	_actor.phase.show_flame_form()
	_actor.motion.play(&"FireBeam", _actor.profile.bridge_duration, true)


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
		var player := _actor.target as Character
		var speed := player.movement.max_speed if player else 6.0
		var ramp_t := clampf((_time - firing_at) / maxf(data.beam_duration, 0.1), 0.0, 1.0)
		var track_ratio := lerpf(data.beam_tracking_start_ratio, data.beam_tracking_max_ratio, ramp_t)
		var turn_step := speed * track_ratio / maxf(_actor.distance_to_target(), 2.0) * delta
		_actor.set_body_yaw(rotate_toward(_actor.model.rotation.y, _actor.model.rotation.y + _actor.target_angle(), turn_step))
	_skeleton.force_update_all_bone_transforms()
	var forward := _actor.get_facing_direction()
	var mouth := _skeleton.to_global(_skeleton.get_bone_global_pose(_jaw).origin) + Vector3.UP * 0.1
	var orb := mouth + forward * data.beam_muzzle_offset
	_actor.fire_vfx.update_beam_barrier(_actor.global_position, _time)
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
