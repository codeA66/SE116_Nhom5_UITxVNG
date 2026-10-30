@tool
class_name BoulderResetPlate
extends Area3D
## Phiến đá khôi phục: người chơi lại gần bấm tương tác thì các đá trượt gán ở ô Boulders (chưa vào ổ) về lại chỗ ban đầu.
## Bấm chủ động thay cho giẫm lên: đi ngang qua phiến không vô tình xoá công đang giải.

signal reset_done

@export var boulders: Array[WindBoulder] = []:
	set(value):
		boulders = value
		update_configuration_warnings()
## Phiến bừng sáng trong bấy nhiêu giây khi reset, báo cho người chơi là đã có tác dụng
@export_range(0.05, 2.0, 0.05) var flash_time: float = 0.4

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _rune: MeshInstance3D = $Rune


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Gốc chỉ còn là chỗ đặt; tương tác qua InteractableComponent nên không cần dò thân vật lý
	monitoring = false
	_interactable.interacted.connect(_on_interacted)


func _get_configuration_warnings() -> PackedStringArray:
	if boulders.is_empty():
		return ["Chưa gán đá ở ô Boulders: phiến này không làm gì."]
	return []


func _on_interacted(_interactor: Node3D) -> void:
	var any := false
	for boulder in boulders:
		if boulder and boulder.reset_to_start():
			any = true
	if any:
		_flash()
		reset_done.emit()


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(_rune, ^"scale", Vector3.ONE * 1.6, flash_time * 0.3)
	tween.tween_property(_rune, ^"scale", Vector3.ONE, flash_time * 0.7)
