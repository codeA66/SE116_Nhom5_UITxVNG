extends EnemyState
## Lùi lấy đà, vồ tới điểm đã chốt rồi tan thành lửa; vụ nổ báo trước một giây.

const LEAP_FRAMES := Vector2(0.3, 0.467)
const MIN_FLIGHT_TIME := 0.18
const DISSOLVE_TIME := 0.58

var _actor: FireSabretooth
var _visual: Node3D
var _time: float
var _flying: bool
var _airborne: bool
var _vanished: bool
var _exploded: bool
var _backward: Vector3
var _flight_duration: float
var _flight_start: Vector3
var _landing: Vector3


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_visual = _actor.get_node("Model/Visual") as Node3D


func enter(_previous: StringName) -> void:
	_time = 0.0
	_flying = false
	_airborne = false
	_vanished = false
	_exploded = false
	_backward = -_actor.get_facing_direction()
	_actor.hitbox.cancel()
	_actor.phase.show_flame_form()
	_actor.motion.play(&"BackUp", _actor.profile.bridge_duration, true)


func exit() -> void:
	_visual.position.y = 0.0
	_actor.velocity = Vector3.ZERO
	if not _actor.encounter_complete:
		_actor.fire_vfx.cancel()
		_actor.phase.dissolve_finale(0.0)
		_actor.model.show()
		_actor.phase.set_ambient_active(true)


func physics_update(delta: float) -> void:
	_time += delta
	if not _vanished:
		_actor.apply_gravity(delta)
	else:
		_actor.velocity = Vector3.ZERO
	var data := _actor.profile
	if not _flying:
		if _time < data.finale_backup_distance / maxf(data.finale_backup_speed, 0.1):
			_actor.walk(_backward, data.finale_backup_speed, delta, true)
			return
		_launch()
	if not _vanished:
		if _time < 0.0:
			_actor.velocity.x = 0.0
			_actor.velocity.z = 0.0
			return
		if not _airborne:
			_airborne = true
			_actor.animation_player().pause()
		if _time < _flight_duration:
			var progress := minf(1.0, (_time + delta) / _flight_duration)
			var next := _flight_start.lerp(_landing, progress)
			var velocity := (next - _actor.global_position).slide(Vector3.UP) / delta
			_actor.velocity.x = velocity.x
			_actor.velocity.z = velocity.z
			_visual.position.y = sin(progress * PI) * data.finale_pounce_height
			_actor.animation_player().seek(_actor.motion.bridge_duration + lerpf(LEAP_FRAMES.x, LEAP_FRAMES.y, progress), true)
			return
		_landing = _actor.global_position
		_vanished = true
		_time = 0.0
		_actor.velocity = Vector3.ZERO
		_actor.fire_vfx.vanish(_landing)
		_actor.body_set_collision(false)
		return
	if not _exploded:
		if _actor.model.visible:
			var dissolve := clampf(_time / DISSOLVE_TIME, 0.0, 1.0)
			_actor.phase.dissolve_finale(dissolve)
			if dissolve >= 1.0:
				_actor.model.hide()
				_actor.phase.set_ambient_active(false)
		_actor.fire_vfx.warn(_landing, clampf(_time / maxf(data.finale_warning_time, 0.01), 0.0, 1.0))
		if _time < data.finale_warning_time:
			return
		_exploded = true
		_time = 0.0
		_actor.fire_vfx.burst(_landing)
		ScreenShake.add_trauma_at(0.67, _landing, data.finale_radius * 0.68, data.finale_radius * 2.0)
		_actor.finale_blast.global_position = _landing + Vector3.UP * 0.5
		_actor.finale_blast.radius = data.finale_radius
		_actor.finale_blast.attack.damage = data.finale_damage
		_actor.finale_blast.explode(_actor)
	if _time >= data.finale_fade_time:
		_actor.finish_phase_two()


func _launch() -> void:
	_flying = true
	var rate := _actor.profile.pounce_animation_rate
	_time = -(_actor.profile.bridge_duration + LEAP_FRAMES.x) / rate
	_flight_start = _actor.global_position
	var direction := _actor.direction_to_target()
	_actor.face_instantly(direction)
	var distance := minf(_actor.distance_to_target(), _actor.profile.finale_pounce_range)
	var collision := KinematicCollision3D.new()
	if _actor.test_move(_actor.global_transform, direction * distance, collision):
		distance = maxf(0.0, collision.get_travel().length() - 0.1)
	_landing = _flight_start + direction * distance
	_flight_duration = maxf(MIN_FLIGHT_TIME, distance / maxf(_actor.profile.finale_pounce_speed, 0.1))
	_actor.motion.play(&"Leaper", _actor.profile.bridge_duration)
	_actor.animation_player().speed_scale = rate
