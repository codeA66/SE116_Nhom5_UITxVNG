class_name BlowableCover
extends StaticBody3D
## Lá che khe đi sẽ biến mất vĩnh viễn sau cú thổi đầu tiên.

signal uncovered

@export var persistent_id: StringName

var is_uncovered: bool = false
@onready var _pile: WindReactiveLeafPile = $LeafPile
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Chỉ kéo dài hình lá, tránh scale Area3D phi đồng đều trên Jolt.
	_pile.get_node("Model").scale = Vector3(0.8, 1.0, 2.1)
	_pile.blown_away.connect(_on_blown_away)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_set_uncovered()


func _on_blown_away() -> void:
	_set_uncovered()


func _set_uncovered() -> void:
	if is_uncovered:
		return
	is_uncovered = true
	_pile.visible = false
	_pile.get_node("WindReceiver").set_deferred(&"monitorable", false)
	_collision.set_deferred(&"disabled", true)
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	uncovered.emit()
