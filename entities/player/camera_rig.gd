extends Node3D
## Camera tách khỏi player (top_level) để đi theo có độ trễ, không giật theo từng va chạm.

@export var follow_speed: float = 8.0

@onready var _target: Node3D = get_parent()


func _ready() -> void:
	top_level = true
	global_position = _target.global_position


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))
