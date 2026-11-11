extends ForgePlayerState
## Lốc Lửa: đứng lại, quay về hướng ra chiêu, tới cast_time thì phóng một cột lốc lửa từ pool rồi về state thường.

var _data: FireCycloneData
var _pool: ObjectPool
var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _cast: bool = false


func enter(_previous: StringName) -> void:
	_data = player.start_skill(FireCycloneData.ID) as FireCycloneData
	_ensure_pool()
	_direction = get_cast_direction()
	_elapsed = 0.0
	_cast = false
	player.face_instantly(_direction)
	player.play_action(_data.animation, _data.anim_speed)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_toward_direction(Vector3.ZERO, delta)
	if not _cast and _elapsed >= _data.cast_time:
		_cast = true
		var cyclone := _pool.acquire() as FireCyclone
		var origin := player.global_position + _direction * _data.spawn_distance
		cyclone.launch(player, origin, _direction, _data.speed, _data.lifetime)
	if _elapsed >= _data.duration and _cast:
		finish()


## Pool là con của player để được dọn cùng player khi rời khu
func _ensure_pool() -> void:
	if is_instance_valid(_pool):
		return
	_pool = ObjectPool.new()
	_pool.name = "FireCyclonePool"
	_pool.scene = _data.cyclone_scene
	_pool.initial_size = _data.pool_size
	_pool.configure_instance = func(node: Node) -> void:
		node.connect(&"finished", _pool.release.bind(node))
	player.add_child(_pool)
