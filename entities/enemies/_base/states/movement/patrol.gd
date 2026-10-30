extends EnemyState
## Đi chậm tới một điểm ngẫu nhiên quanh chỗ xuất phát (hoặc quay về nhà sau khi bỏ đuổi), tới nơi thì đứng chờ.

## Tới gần điểm đích chừng này thì coi như đã tới (m)
const ARRIVE_DISTANCE := 0.4
## Đi quá lâu mà chưa tới (kẹt tường, rào) thì bỏ điểm này
const MAX_WALK_TIME := 6.0

var _point: Vector3
var _walk_time: float = 0.0


func enter(previous: StringName) -> void:
	_walk_time = 0.0
	# Vừa bỏ đuổi thì quay về nhà trước, không đi lang thang ngay
	if previous == enemy.chase_state or enemy.distance_from_home() > enemy.data.patrol_radius:
		_point = enemy.home_position
	else:
		var angle := randf() * TAU
		var dist := randf_range(enemy.data.patrol_radius * 0.3, enemy.data.patrol_radius)
		_point = enemy.home_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
	enemy.play_anim(ANIM_WALK)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if _check_target():
		return
	var offset := _point - enemy.global_position
	offset.y = 0.0
	_walk_time += delta
	if offset.length() < ARRIVE_DISTANCE or _walk_time > MAX_WALK_TIME:
		state_machine.transition_to(IDLE)
		return
	enemy.move_toward_direction(offset.normalized() * enemy.data.patrol_speed_scale, delta)
