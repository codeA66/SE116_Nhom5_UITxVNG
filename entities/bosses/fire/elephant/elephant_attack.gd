extends EnemyState
## Mốc đòn đo theo frame của clip để phần lấy đà có thể kéo chậm riêng.

const FIRST_WINDUP_BLEND: float = 0.26
const WINDUP_RELEASE_BLEND: float = 0.10
const SWEEP_LEAD_TIME: float = 0.16
const SWEEP_MAX_LEAD: float = 0.95

var _elephant: WarElephant
var _skill: ElephantSkill
var _animation: AnimationPlayer
var _animation_mode: AnimationMixer.AnimationCallbackModeProcess
var _phase_time: float
var _trail_at: Vector3
var _clip: StringName
var _complete: bool
var _cast: bool
var _last_window: Vector2
var _hit_center: Vector3
var _hit_size: Vector3
var _sweep_aim: Vector3


func enter(_previous: StringName) -> void:
	_elephant = enemy as WarElephant
	_skill = _elephant.pending_skill as ElephantSkill
	_animation = _elephant.animation_player()
	_animation_mode = _animation.callback_mode_process
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animation.speed_scale = 1.0
	_complete = false
	_cast = false
	_trail_at = _elephant.global_position
	_elephant.face_instantly(_elephant.direction_to_target())
	_sweep_aim = _elephant.global_position + _elephant.get_facing_direction()
	_elephant.lava.set_target(_elephant.target as Player)
	var hit := _elephant.attack_collision
	_hit_center = hit.position
	_hit_size = (hit.shape as BoxShape3D).size
	_elephant.coat.set_coating(_skill.kind in [ElephantSkill.Kind.SWEEP, ElephantSkill.Kind.CHARGE],
		_skill.kind in [ElephantSkill.Kind.STOMP, ElephantSkill.Kind.CHARGE],
		_skill.kind == ElephantSkill.Kind.SWEEP)
	_elephant.coat.set_trunk_glow(_skill.kind == ElephantSkill.Kind.RAIN)
	var running_in := _skill.kind == ElephantSkill.Kind.CHARGE and _skill.run_lead_time > 0.0
	if running_in:
		_start_clip(_elephant.wildlife.run_animation)
	elif _skill.kind == ElephantSkill.Kind.CHARGE:
		_start_charge_windup(0.0)
	else:
		_start_clip(_skill.animation)
	if _skill.kind == ElephantSkill.Kind.STOMP:
		var before_hit := _skill.active_start
		for window: Vector2 in _skill.windups:
			before_hit += maxf(0.0, minf(window.y, _skill.active_start) - window.x) * (1.0 / _skill.windup_speed - 1.0)
		_elephant.lava.warn_stomp(_elephant.global_position, _skill.effect_radius, before_hit)
	_elephant.skill_started.emit(_skill)


func exit() -> void:
	_animation.callback_mode_process = _animation_mode
	_elephant.hitbox.cancel()
	var hit := _elephant.attack_collision
	hit.position = _hit_center
	(hit.shape as BoxShape3D).size = _hit_size
	_elephant.coat.set_coating(false, false)
	_elephant.coat.set_trunk_glow(false)
	_elephant.lava.cancel_stomp()
	_elephant.complete_skill(_skill, _complete)


func physics_update(delta: float) -> void:
	_elephant.apply_gravity(delta)
	_phase_time += delta
	if _skill.kind == ElephantSkill.Kind.CHARGE:
		_pursue(delta)
		if _clip != _skill.animation:
			_update_charge_windup(delta)
			return
	else:
		_elephant.move_toward_direction(Vector3.ZERO, delta)
	var speed := 1.0
	var frame := _animation.current_animation_position
	if _skill.kind == ElephantSkill.Kind.SWEEP:
		_track_sweep(frame, delta)
	for window: Vector2 in _skill.windups:
		if frame >= window.x and frame < window.y:
			speed = _skill.windup_speed
			break
	_animation.advance(delta * speed)
	if _skill.kind == ElephantSkill.Kind.RAIN:
		_rain()
		if _clip == _skill.followup:
			if _phase_time >= _skill.followup_duration:
				_finish()
		elif not _animation.is_playing():
			_start_clip(_skill.followup)
		return
	if not _animation.is_playing() or (_skill.kind == ElephantSkill.Kind.CHARGE and _phase_time >= _skill.duration):
		_finish()
		return
	_strike(_animation.current_animation_position)


func _start_clip(clip: StringName, blend: float = WarElephant.POSE_BLEND, start_at: float = 0.0) -> void:
	_clip = clip
	_phase_time = 0.0
	_last_window = Vector2.ZERO
	_elephant.hitbox.cancel()
	_animation.play(clip, blend)
	_animation.advance(0.0)
	if start_at > 0.0:
		_animation.seek(start_at, true)


func _start_charge_windup(run_phase: float) -> void:
	if _animation.has_animation(WarElephant.CHARGE_WINDUP):
		_start_clip(WarElephant.CHARGE_WINDUP, FIRST_WINDUP_BLEND, run_phase)
	else:
		_start_clip(_skill.animation)


func _update_charge_windup(delta: float) -> void:
	_animation.advance(delta)
	if _clip == WarElephant.CHARGE_WINDUP:
		if _phase_time >= FIRST_WINDUP_BLEND + _skill.first_hold_duration:
			_start_clip(_skill.animation, WINDUP_RELEASE_BLEND, _skill.first_hold_frame)
	elif _phase_time + 0.0001 >= _skill.run_lead_time:
		_start_charge_windup(_animation.current_animation_position)


func _rain() -> void:
	if _clip != _skill.followup or _cast or _phase_time < _skill.cast_frame:
		return
	_cast = true
	_elephant.lava.rain(_elephant.coat)


func _strike(frame: float) -> void:
	var window := _skill.hit_window_at(frame)
	if window == _last_window:
		return
	_last_window = window
	if _skill.kind != ElephantSkill.Kind.STOMP:
		_skill.update_hitbox(_elephant.hitbox, frame, 1.0)
	elif window == Vector2.ZERO:
		_elephant.lava.cancel_stomp()
	if window == Vector2.ZERO:
		return
	match _skill.kind:
		ElephantSkill.Kind.SWEEP:
			var origin := _elephant.coat.trunk_tip()
			origin.y = _elephant.global_position.y
			var forward := _elephant.get_facing_direction()
			var heading := (_sweep_aim - origin).slide(Vector3.UP).normalized()
			if heading.dot(forward) <= 0.0:
				heading = forward
			_elephant.lava.send_wave(origin, heading)
		ElephantSkill.Kind.STOMP:
			_elephant.lava.erupt_all(_elephant.global_position, _skill)
			ScreenShake.add_trauma(0.18)


func _track_sweep(frame: float, delta: float) -> void:
	var can_turn := frame < _skill.active_start or (frame >= _skill.active_end and frame < _skill.second_hit.x)
	if not can_turn or not _elephant.has_target():
		return
	var target := _elephant.target
	_sweep_aim = target.global_position
	if target is CharacterBody3D:
		var lead := (target as CharacterBody3D).velocity.slide(Vector3.UP) * SWEEP_LEAD_TIME
		_sweep_aim += lead.limit_length(SWEEP_MAX_LEAD)
	var toward := (_sweep_aim - _elephant.global_position).slide(Vector3.UP).normalized()
	_elephant.face_direction(toward, delta)


func _pursue(delta: float) -> void:
	var direction := _elephant.direction_to_target()
	var player := _elephant.target as Player
	var speed := _skill.lunge_speed
	if player:
		speed = minf(speed, player.movement.max_speed * player.get_terrain_speed() * _elephant.charge_player_speed_ratio)
	var drive := direction * (speed / _elephant.movement.max_speed) if _elephant.distance_to_target() > _elephant.charge_stop_distance else Vector3.ZERO
	_elephant.move_toward_direction(drive, delta)
	_elephant.face_direction(direction, delta)
	var at := _elephant.global_position
	if at.distance_squared_to(_trail_at) >= _elephant.trail_spacing ** 2:
		_elephant.lava.leave_trail(at)
		_trail_at = at


func _finish() -> void:
	_complete = true
	state_machine.transition_to(IDLE)
