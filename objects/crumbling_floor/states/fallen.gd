extends CrumblingFloorState
## Mất va chạm ngay, phần hình rơi xuống rồi ẩn. Hết respawn_time thì hiện lại.

var _timer: float = 0.0
var _fall_speed: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0
	_fall_speed = 0.0
	floor_tile.set_solid(false)
	floor_tile.notify_crumbled()


func physics_update(delta: float) -> void:
	var d := floor_tile.data
	_timer += delta
	if floor_tile.visual.visible:
		_fall_speed += d.fall_gravity * delta
		var y := floor_tile.visual_offset.y - _fall_speed * delta
		floor_tile.set_visual_offset(Vector3(0.0, y, 0.0))
		if -y >= d.fall_distance:
			floor_tile.hide_visual()
	if _timer >= d.respawn_time:
		state_machine.transition_to(SOLID)
