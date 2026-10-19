class_name WindReactiveProp
extends Node3D
## Lớp nối tín hiệu gió; mỗi vật tự cài hành vi hình ảnh riêng.

const DEFAULT_DATA: WindReactData = preload("res://resources/wind_reactive/default.tres")

@export var data: WindReactData = DEFAULT_DATA
@export var model_path: NodePath = ^"Model"

@onready var _model: Node3D = get_node(model_path) as Node3D
@onready var _reactive: WindReactiveComponent = $WindReactive


func _ready() -> void:
	set_process(false)
	_reactive.reacted.connect(_on_reacted)
	_reactive.wind_changed.connect(_on_wind_changed)
	_setup_visual()


func _setup_visual() -> void:
	pass


func _on_reacted(_direction: Vector3, _strength: float) -> void:
	pass


func _on_wind_changed(_direction: Vector3, _strength: float) -> void:
	pass
