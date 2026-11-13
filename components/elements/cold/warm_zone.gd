class_name WarmZone
extends Area3D
## Chỗ ấm (quanh lửa trại) trong vùng lạnh: player đứng trong thì ColdZone coi như được sưởi.
## Hiệu năng: chỉ đếm player vào / ra bằng signal.

var _player_inside: bool = false


func _ready() -> void:
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void: if body is Player: _player_inside = true)
	body_exited.connect(func(body: Node3D) -> void: if body is Player: _player_inside = false)


func has_player() -> bool:
	return _player_inside
