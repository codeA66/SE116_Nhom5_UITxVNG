class_name KeyLock
extends StaticBody3D
## Ổ khóa chìa làm nguồn cho StoneGate (có signal activated và hàm is_active() như PowerSocket).
## Đứng cạnh ổ bấm interact: chưa có chìa (cờ key_id) thì hộp thoại báo cần chìa; có chìa thì mở khóa,
## ổ sáng lên và phát activated để các cổng nối với ổ này cùng chìm. Lưu cờ persistent_id để lần sau mở sẵn.
## Một ổ có thể làm nguồn cho nhiều cổng (ví dụ hai cổng 4 m ghép thành lối 8 m).
## Hiệu năng: chỉ nghe signal tương tác và progress_changed (đổi chữ gợi ý); không có _process.

signal activated

const DIALOG_SCENE: PackedScene = preload("res://ui/dialog/dialog_box.tscn")

## Cờ cho biết người chơi đang có chìa (KeyPickup / KeyDrop cùng key_id)
@export var key_id: StringName
## Cờ lưu đã mở khóa. Để trống = mỗi lần vào khu ổ lại khóa
@export var persistent_id: StringName
@export var ready_prompt: String = "MỞ KHÓA"
@export var locked_prompt: String = "CỔNG KHÓA"
@export_multiline var locked_text: String = "Cần chìa khóa để mở cổng."
@export_group("Hình ảnh")
@export var locked_color: Color = Color(1.0, 0.18, 0.1, 1.0)
@export var unlocked_color: Color = Color(0.3, 1.0, 0.45, 1.0)
@export var unlocked_light_energy: float = 1.4

var is_unlocked: bool = false
var _dialog: DialogBox

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _keyhole: MeshInstance3D = $Keyhole
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	_interactable.availability_check = func(_actor: Node3D) -> bool: return not is_unlocked
	_interactable.interacted.connect(_on_interacted)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_unlock(true)
		return
	_paint(locked_color)
	_refresh_prompt()
	GameState.progress_changed.connect(_refresh_prompt)


func is_active() -> bool:
	return is_unlocked


func _has_key() -> bool:
	return not key_id.is_empty() and GameState.has_flag(key_id)


func _refresh_prompt() -> void:
	if not is_unlocked:
		_interactable.prompt_text = ready_prompt if _has_key() else locked_prompt


func _on_interacted(actor: Node3D) -> void:
	if is_unlocked:
		return
	if not _has_key():
		_say(locked_text, actor as Player)
		return
	_unlock(false)


## Hộp thoại tạo ở lần báo đầu: ổ chưa ai tương tác thì không tốn node nào
func _say(text: String, player: Player) -> void:
	if _dialog == null:
		_dialog = DIALOG_SCENE.instantiate() as DialogBox
		add_child(_dialog)
	_dialog.say(text, player)


func _unlock(instant: bool) -> void:
	is_unlocked = true
	_interactable.enabled = false
	_paint(unlocked_color)
	if GameState.progress_changed.is_connected(_refresh_prompt):
		GameState.progress_changed.disconnect(_refresh_prompt)
	if instant:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	activated.emit()


func _paint(color: Color) -> void:
	var mat: StandardMaterial3D = _keyhole.material_override as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	_light.light_color = color
	_light.light_energy = unlocked_light_energy if is_unlocked else 0.8
