extends PyralonAttackState

var _ring: Array[PyralonFeather] = []
var _released: bool
var _crimson_ring: bool = false


func enter(previous: StringName) -> void:
	super(previous)
	_released = false
	_crimson_ring = bird.is_phase_two()


func exit() -> void:
	for feather: PyralonFeather in _ring:
		bird.field.recycle(feather)
	_ring.clear()
	super()


func physics_update(delta: float) -> void:
	tick_pose(delta)
	var config := bird.profile
	var flying := elapsed >= config.slam_takeoff and elapsed < config.slam_impact - 0.10
	stay_in_place(delta, flying)
	bird.update_axe_hit(skill, elapsed)
	if elapsed >= config.slam_takeoff and not _released:
		if _ring.is_empty():
			var count := config.p2_radial_count if _crimson_ring else config.radial_count
			for _index: int in count:
				if _crimson_ring:
					_ring.append(bird.field.new_crimson_wall(bird.global_position))
				else:
					_ring.append(bird.field.new_white(bird.global_position))
		_spin_ring()
		if elapsed >= config.slam_impact:
			_impact()
	if elapsed >= maxf(skill.duration, config.slam_impact + config.rear_lock_time):
		bird.finish_move(skill)


func _spin_ring() -> void:
	var lift := bird.pose.displacement()
	var height := 0.85 + maxf(0.0, lift.y)
	var center := bird.global_position + lift.slide(Vector3.UP) + Vector3.UP * height
	for index: int in _ring.size():
		var direction := _heading(index)
		_ring[index].orbit(center + direction * bird.profile.radial_radius, direction)


func _impact() -> void:
	var at := bird.field.floor_at(bird.pose.axe_edge())
	bird.field.effect(PyralonFireFx.Kind.SLAM_BURST, at, Vector3.ZERO, Vector2.ONE * 1.95, 0.56)
	var base_speed := bird.player_speed() * bird.profile.radial_speed_ratio
	if _crimson_ring:
		# Phase 2: 36 lông đỏ tốc độ 1.6x cắm giữ lên tường + vệt chém lửa dọc mở cổng không gian bắn xích lửa!
		var speed := base_speed * bird.profile.crimson_speed_mult
		for index: int in _ring.size():
			_ring[index].fire_crimson_wall(_heading(index), speed)
		var slash_dir := bird.get_facing_direction().slide(Vector3.UP)
		if bird.has_target():
			var to_player := (bird.target.global_position - at).slide(Vector3.UP)
			if to_player.length_squared() > 0.01:
				slash_dir = to_player
		bird.field.rift_chain.launch(at, slash_dir.normalized(), bird.target, speed)
	else:
		bird.field.ground.fissure(at, bird.target)
		for index: int in _ring.size():
			_ring[index].fire(_heading(index), base_speed)
	_ring.clear()
	_released = true


func _heading(index: int) -> Vector3:
	var angle := TAU * index / _ring.size() + elapsed * 2.5
	return Vector3(sin(angle), 0.0, cos(angle))
