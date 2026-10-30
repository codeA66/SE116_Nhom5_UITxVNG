@tool
class_name Pickup
extends Node3D
## Lớp cơ sở cho vật nằm trên đất nhặt được bằng tương tác (vũ khí, sách kỹ năng...).
## Lo phần chung: xoay tại chỗ, nhớ đã nhặt, tương tác. Loại vật mới kế thừa và ghi đè các hàm ảo.
## @tool chỉ để hiện cảnh báo cấu hình trong editor, logic game không chạy trong editor.

## ID duy nhất trong toàn game để nhớ đã nhặt chưa (ví dụ "zone_1_wind.room_02.sword").
## Để trống = không lưu, vật sẽ xuất hiện lại mỗi lần vào scene
@export var persistent_id: StringName
@export var spin_speed: float = 1.5

@onready var _visual: Node3D = $Visual
@onready var _interactable: InteractableComponent = $InteractableComponent


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	if not _get_configuration_warnings().is_empty():
		# Không dừng game vì một vật cấu hình sai: báo lỗi và bỏ vật này
		push_error("%s cấu hình sai, vật phẩm bị bỏ: %s" % [get_path(), ", ".join(_get_configuration_warnings())])
		queue_free()
		return
	if GameState.has_flag(persistent_id):
		queue_free()
		return
	_build_visual(_visual)
	_interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_visual.rotate_y(spin_speed * delta)


## Lớp con ghi đè: thêm model riêng vào visual (để trống nếu scene đã có sẵn model)
func _build_visual(_visual_root: Node3D) -> void:
	pass


## Lớp con ghi đè: người tương tác này có nhận được vật không
func _can_be_picked_by(_interactor: Node3D) -> bool:
	return false


## Lớp con ghi đè: trao vật cho người nhặt
func _give_to(_interactor: Node3D) -> void:
	pass


func _on_interacted(interactor: Node3D) -> void:
	if not _can_be_picked_by(interactor):
		return
	_interactable.enabled = false
	GameState.set_flag(persistent_id)
	_give_to(interactor)
	queue_free()
