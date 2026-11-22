extends EnemyState
## Tái hình thành Hổ Răng Kiếm Phase 2 từ các vệt lửa xoáy tụ giữa hư vô (4 giai đoạn theo Concept Art),
## rồi chuyển sang pha săn & đánh cận chiến nhanh trước khi lặp lại chuỗi chiêu đặc biệt.

var _actor: FireSabretooth
var _time: float = 0.0
var _spot: Vector3
var _done: bool = false
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_ray.collision_mask = 1


func enter(_previous: StringName) -> void:
	_time = 0.0
	_done = false
	_ray.exclude = [_actor.get_rid()]
	_spot = _pick_open_spot()
	_actor.hitbox.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.global_position = _spot
	_actor.reset_physics_interpolation()
	if _actor.has_target():
		_actor.face_instantly(_actor.direction_to_target())
	_actor.phase.show_flame_form()
	_actor.phase.dissolve_finale(0.0)
	_actor.phase.set_portal_clip(false)
	_actor.phase.set_reform_progress(0.0)
	_actor.body_set_collision(false)
	_actor.model.show()
	_actor.motion.play(&"Growling", 0.0, true)
	_actor.fire_vfx.update_reform(_spot, 0.0)


func exit() -> void:
	_actor.fire_vfx.hide_reform()
	_actor.phase.set_reform_progress(1.0)
	_actor.body_set_collision(true)
	_actor.phase.set_ambient_active(true)
	_actor.model.show()


func physics_update(delta: float) -> void:
	_time += delta
	_actor.velocity = Vector3.ZERO
	var duration := maxf(_actor.profile.reform_duration, 0.35)
	var progress := clampf(_time / duration, 0.0, 1.0)
	_actor.fire_vfx.update_reform(_spot, progress)
	_actor.phase.set_reform_progress(progress)
	if progress < 1.0:
		return
	if not _done:
		_done = true
		_actor.body_set_collision(true)
		_actor.phase.set_ambient_active(true)
		_actor.fire_vfx.hide_reform()
		ScreenShake.add_trauma_at(0.22, _spot, 9.0, 22.0)
		if _actor.phase_two_chain or not _actor.manual_skill:
			_actor.rest_then_phase_two(&"TigerFangSnap")
		else:
			_actor.finish_phase_two_move()


func _pick_open_spot() -> Vector3:
	if not _actor.has_target():
		return _actor.global_position
	var origin := _actor.target.global_position
	var base_angle := randf() * TAU
	for i: int in 12:
		var ang := base_angle + float(i) * (TAU / 12.0)
		var dist := randf_range(5.5, 8.2)
		var cand := origin + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		_ray.from = Vector3(origin.x, origin.y + 1.0, origin.z)
		_ray.to = Vector3(cand.x, origin.y + 1.0, cand.z)
		if not _actor.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty():
			continue
		_ray.from = Vector3(cand.x, origin.y + 4.0, cand.z)
		_ray.to = Vector3(cand.x, origin.y - 3.0, cand.z)
		var floor_hit := _actor.get_world_3d().direct_space_state.intersect_ray(_ray)
		if not floor_hit.is_empty():
			return floor_hit.position as Vector3
	return _actor.global_position
