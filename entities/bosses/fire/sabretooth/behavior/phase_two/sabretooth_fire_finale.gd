extends EnemyState
## Lùi lấy đà, vồ vòng cung và nghiêng chúi người sẵn trên không để vừa chạm cổng vô hình trên sàn
## thì trượt xiên biến mất tự nhiên từ đầu đến chóp 3 đuôi lửa, tạo vụ nổ 10m rồi chuyển sang 5x Phantom Blitz.

const LEAP_FRAMES := Vector2(0.3, 0.467)
const MIN_FLIGHT_TIME := 0.22
const POST_BLAST_CHAIN_DELAY := 0.68

var _actor: FireSabretooth
var _visual: Node3D
var _time: float
var _flying: bool
var _airborne: bool
var _diving: bool
var _exploded: bool
var _handoff_to_blitz: bool
var _backward: Vector3
var _dive_dir: Vector3
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
	_diving = false
	_exploded = false
	_handoff_to_blitz = false
	_backward = -_actor.get_facing_direction()
	_dive_dir = _actor.get_facing_direction()
	_actor.hitbox.cancel()
	_actor.phase.show_flame_form()
	_actor.phase.set_portal_clip(false)
	_actor.phase.set_reform_progress(1.0)
	_actor.model.rotation.x = 0.0
	_visual.position = Vector3.ZERO
	_actor.motion.play(&"BackUp", _actor.profile.bridge_duration, true)


func exit() -> void:
	_visual.position = Vector3.ZERO
	_actor.model.rotation.x = 0.0
	_actor.velocity = Vector3.ZERO
	_actor.fire_vfx.hide_void_seam()
	_actor.phase.set_portal_clip(false)
	if not _handoff_to_blitz and not _actor.encounter_complete:
		_actor.fire_vfx.cancel()
		_actor.phase.dissolve_finale(0.0)
		_actor.model.show()
		_actor.body_set_collision(true)
		_actor.phase.set_ambient_active(true)


func physics_update(delta: float) -> void:
	_time += delta
	if not _diving:
		_actor.apply_gravity(delta)
	else:
		_actor.velocity = Vector3.ZERO
	var data := _actor.profile
	if not _flying:
		if _time < data.finale_backup_distance / maxf(data.finale_backup_speed, 0.1):
			_actor.walk(_backward, data.finale_backup_speed, delta, true)
			return
		_launch()
	if not _diving:
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
			var vel := (next - _actor.global_position).slide(Vector3.UP) / delta
			_actor.velocity.x = vel.x
			_actor.velocity.z = vel.z
			# Nâng cong vòng nhảy mượt rồi chúi mũi xuống sớm ngay trên không (progress 0.24 -> 0.96 đạt ~58 độ)
			# để vừa chạm điểm chui xuống là hổ đã ở tư thế lao đầu vào cổng không gian rất tự nhiên.
			_visual.position.y = sin(progress * PI) * data.finale_pounce_height
			var pitch_arc := lerpf(deg_to_rad(-14.0), deg_to_rad(58.0), smoothstep(0.18, 0.94, progress))
			_actor.model.rotation.x = pitch_arc
			_actor.animation_player().seek(_actor.motion.bridge_duration + lerpf(LEAP_FRAMES.x, LEAP_FRAMES.y, progress), true)
			if progress >= 0.72:
				var pre_t := clampf((progress - 0.72) / 0.28, 0.0, 1.0)
				_actor.fire_vfx.show_void_seam(_landing, _dive_dir, pre_t * 0.25)
				_actor.phase.set_portal_clip(true, _landing + Vector3.UP * 0.04, Vector3.UP)
			return
		_landing = _actor.global_position
		_diving = true
		_time = 0.0
		_actor.velocity = Vector3.ZERO
		_actor.fire_vfx.vanish(_landing)
		_actor.fire_vfx.show_void_seam(_landing, _dive_dir, 0.25)
		_actor.phase.set_portal_clip(true, _landing + Vector3.UP * 0.04, Vector3.UP)
		_actor.body_set_collision(false)
		return
	if not _exploded:
		var dive_len := maxf(data.dive_duration, 0.28)
		var dive_t := clampf(_time / dive_len, 0.0, 1.0)
		if _actor.model.visible:
			# Trượt xiên dọc theo đúng chiều nghiêng 60 độ của thân hổ (vừa tiến nhẹ theo trục Z local vừa lặn sâu xuống Y),
			# giúp mõm/đầu vào cổng trước -> vai -> thân -> chân sau -> chóp 3 đuôi lửa chui lọt gọn qua đúng 1 khe trên sàn!
			var ease_dive := pow(dive_t, 0.92)
			var dive_angle := lerpf(deg_to_rad(58.0), deg_to_rad(65.0), ease_dive)
			_actor.model.rotation.x = dive_angle
			var slide_dist := lerpf(0.0, 4.45, ease_dive)
			_visual.position = Vector3(0.0, 0.12 - sin(dive_angle) * slide_dist, cos(dive_angle) * slide_dist * 0.48)
			_actor.phase.dissolve_finale(smoothstep(0.32, 1.0, dive_t))
			_actor.fire_vfx.show_void_seam(_landing, _dive_dir, lerpf(0.25, 1.0, dive_t))
			if dive_t >= 1.0:
				_actor.model.hide()
				_actor.phase.set_portal_clip(false)
				_actor.phase.set_ambient_active(false)
				_actor.fire_vfx.hide_void_seam()
		_actor.fire_vfx.warn(_landing, clampf(_time / maxf(data.finale_warning_time, 0.01), 0.0, 1.0))
		if _time < maxf(data.finale_warning_time, dive_len):
			return
		_exploded = true
		_time = 0.0
		_actor.fire_vfx.hide_void_seam()
		_actor.fire_vfx.burst(_landing)
		ScreenShake.add_trauma_at(0.72, _landing, data.finale_radius * 0.72, data.finale_radius * 2.1)
		_actor.finale_blast.global_position = _landing + Vector3.UP * 0.5
		_actor.finale_blast.radius = data.finale_radius
		_actor.finale_blast.attack.damage = data.finale_damage
		_actor.finale_blast.explode(_actor)
		return
	if _actor.phase_two_chain or not _actor.manual_skill:
		if _time >= POST_BLAST_CHAIN_DELAY:
			_handoff_to_blitz = true
			state_machine.transition_to(&"TigerPhantomBlitz")
	elif _time >= data.finale_fade_time:
		_actor.model.show()
		_actor.body_set_collision(true)
		_actor.phase.dissolve_finale(0.0)
		_actor.phase.set_ambient_active(true)
		_actor.finish_phase_two_move()


func _launch() -> void:
	_flying = true
	var rate := _actor.profile.pounce_animation_rate
	_time = -(_actor.profile.bridge_duration + LEAP_FRAMES.x) / rate
	_flight_start = _actor.global_position
	var direction := _actor.direction_to_target()
	_dive_dir = direction
	_actor.face_instantly(direction)
	var distance := minf(_actor.distance_to_target(), _actor.profile.finale_pounce_range)
	var collision := KinematicCollision3D.new()
	if _actor.test_move(_actor.global_transform, direction * distance, collision):
		distance = maxf(0.0, collision.get_travel().length() - 0.1)
	_landing = _flight_start + direction * distance
	_flight_duration = maxf(MIN_FLIGHT_TIME, distance / maxf(_actor.profile.finale_pounce_speed, 0.1))
	_actor.motion.play(&"Leaper", _actor.profile.bridge_duration)
	_actor.animation_player().speed_scale = rate
