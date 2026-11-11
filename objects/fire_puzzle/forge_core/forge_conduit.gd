class_name ForgeConduit
extends Node3D
## Ống dẫn lửa của lò cao ở Hub tier 2: tắt tới khi GameState có cờ flag (nhặt lõi tương ứng) thì bừng sáng.
## Có signal activated + is_active() nên dùng làm nguồn cho cổng (StoneGate.sources): đủ ba ống thì cửa mở.
## Hiệu năng: nghe GameState.progress_changed tới khi có cờ rồi ngắt; không có _process.

signal activated

## Cờ của lõi lò ứng với ống này
@export var flag: StringName
@export var lit_light_energy: float = 3.0
@export_range(0.0, 3.0, 0.05) var light_up_time: float = 0.8

var _active: bool = false

@onready var _flame: Node3D = $Flame
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	if flag.is_empty():
		push_error("%s chưa đặt cờ, ống dẫn không bao giờ sáng" % get_path())
		return
	if GameState.has_flag(flag):
		_light_up(true)
		return
	_flame.visible = false
	_light.light_energy = 0.0
	GameState.progress_changed.connect(_on_progress_changed)


func is_active() -> bool:
	return _active


func _on_progress_changed() -> void:
	if _active or not GameState.has_flag(flag):
		return
	GameState.progress_changed.disconnect(_on_progress_changed)
	_light_up(false)


func _light_up(instant: bool) -> void:
	_active = true
	_flame.visible = true
	if instant or light_up_time <= 0.0:
		_light.light_energy = lit_light_energy
		_flame.scale = Vector3.ONE
	else:
		_flame.scale = Vector3.ONE * 0.1
		var tween := create_tween().set_parallel()
		tween.tween_property(_light, ^"light_energy", lit_light_energy, light_up_time)
		tween.tween_property(_flame, ^"scale", Vector3.ONE, light_up_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	activated.emit()
