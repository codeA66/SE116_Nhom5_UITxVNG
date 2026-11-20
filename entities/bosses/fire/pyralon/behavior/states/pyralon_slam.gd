extends PyralonAttackState

var _ring: Array[PyralonFeather] = []
var _released: bool


func enter(previous: StringName) -> void:
	super(previous)
	_released = false


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
			for _index: int in config.radial_count:
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
	bird.field.ground.fissure(at, bird.target)
	var speed := bird.player_speed() * bird.profile.radial_speed_ratio
	for index: int in _ring.size():
		_ring[index].fire(_heading(index), speed)
	_ring.clear()
	_released = true


func _heading(index: int) -> Vector3:
	var angle := TAU * index / _ring.size() + elapsed * 2.5
	return Vector3(sin(angle), 0.0, cos(angle))
