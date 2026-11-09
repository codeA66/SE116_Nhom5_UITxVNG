class_name PowerSocket
extends StaticBody3D
## Ổ nạp năng lượng (trên bệ cổng xoáy...): player có vật phẩm (cờ required_item_flag) bấm interact thì lắp vào,
## viên đá hiện trên ổ, lưu cờ persistent_id và phát activated. Cổng / máy dùng cờ này (WarpPortal.required_flag)
## hoặc dùng ổ làm nguồn qua is_active(). Chưa có vật phẩm: bấm interact thì hộp thoại báo missing_text, không lắp được.
## Hiệu năng: chỉ nghe signal tương tác.

signal activated

## Cờ cho biết player đang có vật phẩm cần lắp
@export var required_item_flag: StringName
## Cờ lưu đã lắp
@export var persistent_id: StringName
@export var ready_prompt: String = "NẠP ĐÁ NĂNG LƯỢNG"
@export var missing_prompt: String = "KIỂM TRA CỔNG"
@export_multiline var missing_text: String = "Cổng thiếu năng lượng, không hoạt động.
Cần một viên Đá Năng Lượng."

var is_powered: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _stone: Node3D = $Stone
@onready var _dialog: DialogBox = $DialogBox


func _ready() -> void:
	_interactable.availability_check = func(_actor: Node3D) -> bool: return not is_powered
	_interactable.interacted.connect(_on_interacted)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_power(true)
		return
	_stone.hide()
	_refresh_prompt()
	GameState.progress_changed.connect(_refresh_prompt)


func is_active() -> bool:
	return is_powered


func _refresh_prompt() -> void:
	if is_powered:
		return
	_interactable.prompt_text = ready_prompt if _has_item() else missing_prompt


func _has_item() -> bool:
	return not required_item_flag.is_empty() and GameState.has_flag(required_item_flag)


func _on_interacted(actor: Node3D) -> void:
	if is_powered:
		return
	if not _has_item():
		_dialog.say(missing_text, actor as Player)
		return
	_power(false)


func _power(instant: bool) -> void:
	is_powered = true
	_interactable.enabled = false
	_stone.show()
	if GameState.progress_changed.is_connected(_refresh_prompt):
		GameState.progress_changed.disconnect(_refresh_prompt)
	if instant:
		return
	_stone.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_stone, ^"scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	activated.emit()
