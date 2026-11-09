class_name IgnitableBrazier
extends Node3D
## Lò / đuốc tắt: Phun lửa (hoặc nguồn lửa bất kỳ) trúng thì thắp sáng mãi, rọi một vùng quanh nó.
## Dùng làm nguồn kích hoạt cho cổng (có signal activated + is_active() như ổ đá của StoneGate).
## Có persistent_id thì nhớ đã thắp qua lần chơi sau.
## Hiệu năng: chỉ nghe signal ignited của BurnableComponent; thắp xong thì tắt luôn vùng bắt lửa.

signal activated

## Cờ lưu trạng thái đã thắp. Để trống = mỗi lần vào khu lại tắt
@export var persistent_id: StringName
@export var lit_energy: float = 3.5
@export var light_range: float = 11.0
@export var light_color: Color = Color(1.0, 0.55, 0.22)
@export_range(0.05, 3.0, 0.05) var light_up_time: float = 0.5

var is_lit: bool = false

@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _light: OmniLight3D = $Light
@onready var _flame: Node3D = $Model.find_child("Flame", true, false) as Node3D


func _ready() -> void:
	_light.light_color = light_color
	_light.omni_range = light_range
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_light_up(true)
		return
	_light.light_energy = 0.0
	_light.visible = false
	if _flame:
		_flame.visible = false
	_burnable.ignited.connect(_on_ignited)


func is_active() -> bool:
	return is_lit


func _on_ignited() -> void:
	if is_lit:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_light_up(false)


func _light_up(instant: bool) -> void:
	is_lit = true
	_burnable.set_enabled(false)
	if _flame:
		_flame.visible = true
	_light.visible = true
	if instant:
		_light.light_energy = lit_energy
	else:
		create_tween().tween_property(_light, ^"light_energy", lit_energy, light_up_time)
	activated.emit()
