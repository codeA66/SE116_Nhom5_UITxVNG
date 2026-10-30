class_name HoverComponent
extends Node
## Giữ thân bay lơ lửng cách mặt đất một độ cao cố định bằng cách đặt vận tốc đứng.
## Không tự chạy: quái bay gọi apply() từ apply_gravity() mỗi physics frame.
## Hiệu năng: một tia mỗi lần gọi, query dùng lại, không cấp phát.

@export var stats: HoverStats

## Độ cao mặt đất gần nhất đã thấy (dùng khi bay trên vực, không có đất bên dưới)
var _ground_y: float = 0.0
var _has_ground: bool = false
var _query: PhysicsRayQueryParameters3D


func _ready() -> void:
	_query = PhysicsRayQueryParameters3D.new()


## Độ cao đích (toạ độ y của gốc thân) hiện tại
func get_target_y() -> float:
	return _ground_y + stats.hover_height


## Quên độ cao đất đã nhớ (sau khi dịch chuyển sang nơi khác)
func reset_memory() -> void:
	_has_ground = false


func apply(body: CharacterBody3D, delta: float) -> void:
	_probe_ground(body)
	var wanted := clampf((get_target_y() - body.global_position.y) * stats.vertical_stiffness, -stats.max_vertical_speed, stats.max_vertical_speed)
	# Dùng move_toward để lực ngoài (cột gió đứng) thắng được hover thay vì bị ghi đè mỗi frame
	body.velocity.y = move_toward(body.velocity.y, wanted, stats.vertical_accel * delta)


func _probe_ground(body: CharacterBody3D) -> void:
	_query.collision_mask = stats.ground_mask
	_query.from = body.global_position + Vector3.UP * stats.probe_up
	_query.to = _query.from + Vector3.DOWN * (stats.probe_up + stats.probe_length)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(_query)
	if not hit.is_empty():
		_ground_y = (hit["position"] as Vector3).y
		_has_ground = true
	elif not _has_ground:
		# Chưa từng thấy đất: coi như đang đúng độ cao
		_ground_y = body.global_position.y - stats.hover_height
		_has_ground = true
