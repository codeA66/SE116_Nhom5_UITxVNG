class_name RoomCutaway
extends Area3D
## Chỉ cắt mặt tường quay về camera khi ở trong phòng; va chạm vẫn giữ nguyên.

@export var front_wall_visuals: Node3D
## Mặc định giữ nguyên tường; chỉ bật nếu phòng có camera cố định phù hợp.
@export var cutaway_enabled: bool = false

var _inside: bool = false
var _overview: bool = false


func _ready() -> void:
	body_entered.connect(_entered)
	body_exited.connect(_exited)
	set_process(false)
	set_physics_process(false)
	_refresh()


func set_overview(value: bool) -> void:
	_overview = value
	_refresh()


func _entered(body: Node3D) -> void:
	if body is Player:
		_inside = true
		_refresh()


func _exited(body: Node3D) -> void:
	if body is Player:
		_inside = false
		_refresh()


func _refresh() -> void:
	if front_wall_visuals:
		front_wall_visuals.visible = not cutaway_enabled or _overview or not _inside
