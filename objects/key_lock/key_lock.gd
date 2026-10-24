class_name KeyLock
extends Node3D
## Ổ khóa: người chơi đã có chìa đúng key_id thì bấm tương tác để mở; mở một lần rồi giữ nguyên.
## Là nguồn kích hoạt (signal activated + is_active()) nên nối được vào cổng bất kỳ (StoneGate, cửa song sắt,
## PowerConduit...) qua @export. Chưa có chìa thì ổ rung nhẹ báo "khóa".

signal activated

## Phải trùng key_id của KeyPickup tương ứng
@export var key_id: StringName
## Cờ lưu đã mở. Để trống = mỗi lần vào khu ổ lại khóa (chìa vẫn còn)
@export var persistent_id: StringName

@export_group("Feedback")
@export var locked_energy: float = 0.5
@export var unlocked_energy: float = 3.0
@export_range(0.05, 3.0, 0.05) var light_up_time: float = 0.5
## Biên độ rung (m) khi bấm mà chưa có chìa
@export var deny_shake: float = 0.04

var _open: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _light: OmniLight3D = $Glow
@onready var _model: Node3D = $Model


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_set_open()
		return
	_light.light_energy = locked_energy


func is_active() -> bool:
	return _open


func _on_interacted(_interactor: Node3D) -> void:
	if _open:
		return
	if key_id.is_empty() or not GameState.has_flag(key_id):
		_deny()
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_set_open()
	create_tween().tween_property(_light, "light_energy", unlocked_energy, light_up_time)
	activated.emit()


func _set_open() -> void:
	_open = true
	_interactable.enabled = false
	_light.light_energy = unlocked_energy


## Chưa có chìa: rung ngang vài nhịp (không khoá điều khiển, bấm lại được)
func _deny() -> void:
	var tween := create_tween()
	for i in 4:
		tween.tween_property(_model, "position:x", deny_shake * (1.0 if i % 2 == 0 else -1.0), 0.04)
	tween.tween_property(_model, "position:x", 0.0, 0.04)
