extends EnemyState
## 5 lượt cào tốc độ cực cao xuyên qua đường ống trụ cảnh báo (cảnh báo 0.3s rồi cào ngay),
## xuất hiện từ đầu ống và chui lại vào hư vô ở cuối ống để lại 3 vệt móng cào + dải lửa decorative.

enum Step { WARN, DASH, GAP }

var _actor: FireSabretooth
var _visual: Node3D
var _step: Step = Step.WARN
var _lanes_done: int = 0
var _time: float = 0.0
var _lane_start: Vector3
var _lane_end: Vector3
var _lane_dir: Vector3
var _base_angle: float = 0.0
var _handoff_to_reform: bool = false
var _hit_ids: Dictionary[int, bool] = {}
var _ray := PhysicsRayQueryParameters3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _cylinder := CylinderShape3D.new()


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_visual = _actor.get_node("Model/Visual") as Node3D
	_ray.collision_mask = 1
	_query.shape = _cylinder
	_query.collision_mask = 2
	_query.collide_with_areas = true
	_query.collide_with_bodies = false


func enter(_previous: StringName) -> void:
	_lanes_done = 0
	_time = 0.0
	_handoff_to_reform = false
	_base_angle = randf() * TAU
	_ray.exclude = [_actor.get_rid()]
	_actor.hitbox.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.phase.show_flame_form()
	_actor.phase.dissolve_finale(0.0)
	_actor.phase.set_reform_progress(1.0)
	_actor.phase.set_ambient_active(false)
	_actor.body_set_collision(false)
	_actor.model.hide()
	_begin_lane()


func exit() -> void:
	_actor.fire_vfx.hide_blitz_lane()
	_actor.phase.set_portal_clip(false)
	_visual.position.y = 0.0
	_actor.model.rotation.x = 0.0
	_actor.velocity = Vector3.ZERO
	if not _handoff_to_reform:
		_actor.model.show()
		_actor.body_set_collision(true)
		_actor.phase.set_ambient_active(true)


func physics_update(delta: float) -> void:
	_time += delta
	_actor.velocity = Vector3.ZERO
	var data := _actor.profile
	match _step:
		Step.WARN:
			var warn_len := maxf(data.blitz_warn_time, 0.05)
			var p := clampf(_time / warn_len, 0.0, 1.0)
			_actor.fire_vfx.show_blitz_lane(_lane_start, _lane_end, data.blitz_lane_radius, p)
			if _time >= warn_len:
				_start_dash()
		Step.DASH:
			var dash_len := maxf(data.blitz_dash_time, 0.06)
			var p := clampf(_time / dash_len, 0.0, 1.0)
			# Hổ lao tốc độ cực cao xuyên từ đầu ống vào -> cuối ống ra, cắt mặt phẳng cổng mượt ở 2 đầu.
			var overshot_start := _lane_start - _lane_dir * 2.2
			var overshot_end := _lane_end + _lane_dir * 2.2
			var pos := overshot_start.lerp(overshot_end, p)
			_actor.global_position = Vector3(pos.x, _lane_start.y - 1.15, pos.z)
			_actor.reset_physics_interpolation()
			if p < 0.5:
				_actor.phase.set_portal_clip(true, _lane_start, _lane_dir)
			else:
				_actor.phase.set_portal_clip(true, _lane_end, -_lane_dir)
			_check_lane_hit()
			if p >= 1.0:
				_finish_dash()
		Step.GAP:
			if _time >= data.blitz_gap_time:
				if _lanes_done >= data.blitz_count:
					_complete_blitz()
				else:
					_begin_lane()


func _begin_lane() -> void:
	_step = Step.WARN
	_time = 0.0
	_hit_ids.clear()
	var data := _actor.profile
	var center := _actor.target.global_position if _actor.has_target() else _actor.global_position
	var floor_y := _floor_y(center)
	var tube_y := floor_y + 1.15
	# Xoay góc đa dạng qua từng lượt để 5 đường ống cắt chéo từ nhiều hướng quanh player.
	var angle := _base_angle + float(_lanes_done) * 1.24 + randf_range(-0.32, 0.32)
	_lane_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	var half_len := data.blitz_lane_length * 0.5
	var center_pt := Vector3(center.x, tube_y, center.z)
	var back_reach := _clamp_to_wall(center_pt, -_lane_dir, half_len)
	var fwd_reach := _clamp_to_wall(center_pt, _lane_dir, half_len)
	_lane_start = center_pt - _lane_dir * back_reach
	_lane_end = center_pt + _lane_dir * fwd_reach
	_actor.fire_vfx.show_blitz_lane(_lane_start, _lane_end, data.blitz_lane_radius, 0.0)


func _start_dash() -> void:
	_step = Step.DASH
	_time = 0.0
	var data := _actor.profile
	_actor.fire_vfx.hide_blitz_lane()
	_actor.fire_vfx.spawn_blitz_trail(_lane_start, _lane_end, data.blitz_lane_radius)
	_actor.face_instantly(_lane_dir)
	_actor.global_position = Vector3(_lane_start.x, _lane_start.y - 1.15, _lane_start.z) - _lane_dir * 2.2
	_actor.reset_physics_interpolation()
	_actor.model.rotation.x = deg_to_rad(8.0)
	_visual.position.y = 0.25
	_actor.model.show()
	_actor.phase.set_ambient_active(true)
	_actor.phase.set_portal_clip(true, _lane_start, _lane_dir)
	_actor.motion.play(&"Attack", 0.0)
	_actor.animation_player().speed_scale = 2.4
	ScreenShake.add_trauma_at(0.24, (_lane_start + _lane_end) * 0.5, 12.0, 26.0)
	_check_lane_hit()


func _finish_dash() -> void:
	_lanes_done += 1
	_step = Step.GAP
	_time = 0.0
	_actor.model.hide()
	_actor.phase.set_portal_clip(false)
	_actor.phase.set_ambient_active(false)
	_actor.model.rotation.x = 0.0
	_visual.position.y = 0.0


func _complete_blitz() -> void:
	if _actor.phase_two_chain or not _actor.manual_skill:
		_handoff_to_reform = true
		state_machine.transition_to(&"TigerFlameReform")
	else:
		_actor.model.show()
		_actor.body_set_collision(true)
		_actor.phase.set_ambient_active(true)
		_actor.finish_phase_two_move()


func _check_lane_hit() -> void:
	var span := _lane_end - _lane_start
	var length := maxf(span.length(), 0.2)
	var facing := Basis.looking_at(_lane_dir, Vector3.UP, true)
	_cylinder.radius = _actor.profile.blitz_lane_radius * 0.88
	_cylinder.height = length
	_query.transform = Transform3D(facing * Basis(Vector3.RIGHT, PI * 0.5), (_lane_start + _lane_end) * 0.5)
	for result: Dictionary in _actor.get_world_3d().direct_space_state.intersect_shape(_query, 16):
		var hurtbox := result.collider as HurtboxComponent
		if hurtbox == null or _hit_ids.has(hurtbox.get_instance_id()):
			continue
		_hit_ids[hurtbox.get_instance_id()] = true
		var hit := DamageInfo.new(_actor.profile.blitz_damage, DamageInfo.Type.FIRE, _lane_dir * 4.5, _actor)
		hit.direction = _lane_dir
		hurtbox.receive_hit(hit)


func _clamp_to_wall(origin: Vector3, dir: Vector3, max_dist: float) -> float:
	_ray.from = origin
	_ray.to = origin + dir * max_dist
	var hit := _actor.get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		return max_dist
	return maxf(2.4, origin.distance_to(hit.position as Vector3) - 0.5)


func _floor_y(at: Vector3) -> float:
	_ray.from = Vector3(at.x, at.y + 4.5, at.z)
	_ray.to = Vector3(at.x, at.y - 4.0, at.z)
	var hit := _actor.get_world_3d().direct_space_state.intersect_ray(_ray)
	return (hit.position as Vector3).y if not hit.is_empty() else _actor.global_position.y
