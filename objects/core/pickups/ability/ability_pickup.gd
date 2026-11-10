@tool
class_name AbilityPickup
extends Pickup
## Sách trao kỹ năng ở đỉnh trình diễn; hủy trước đỉnh vẫn nhặt lại được.
const Acquisition = preload("res://components/feedback/loot_beam/ability_acquire/ability_acquire_vfx.gd")

@export var ability: AbilityData:
	set(value):
		ability = value
		update_configuration_warnings()
var _receiver: Node3D
var _committed: bool = false
var _was_spinning: bool = false
@onready var _acquisition: Acquisition = get_node_or_null(^"AbilityAcquireVfx") as Acquisition

## Base nối tương tác vào override; trình diễn con đã chuẩn bị trước warmup của khu.
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or is_queued_for_deletion(): return
	if _acquisition != null:
		_acquisition.burst_peaked.connect(_commit_acquisition)
		_acquisition.finished.connect(_finish_acquisition)
		_acquisition.cancelled.connect(_cancel_acquisition)

## Giữ sách và trì hoãn cờ persistent, không đổi hành vi các loại Pickup khác.
func _on_interacted(interactor: Node3D) -> void:
	if not _can_be_picked_by(interactor): return
	if _acquisition == null:
		super._on_interacted(interactor)
		return
	_receiver = interactor
	_committed = false
	_was_spinning = is_processing()
	_interactable.enabled = false
	set_process(false)
	if not _acquisition.play(interactor,ability):
		_cancel_acquisition(false)
		return
	# Trình diễn vừa dừng thế giới (Interactor không tự cập nhật nữa): chọn lại mục tiêu ngay để chữ "nhặt" tắt luôn
	var seeker := interactor.get(&"interactor") as InteractorComponent
	if seeker: seeker.refresh_focus()

## Commit đúng một lần kể cả có nhiều frame hoặc nhiều listener ở đỉnh.
func _commit_acquisition() -> void:
	if _committed: return
	_committed = true
	if is_instance_valid(_receiver): _give_to(_receiver)
	else: GameState.unlock_ability(ability)
	GameState.set_flag(persistent_id)

## Xóa pickup sau khi icon đã tới HUD, không làm đứt chuỗi giữa chừng.
func _finish_acquisition() -> void:
	queue_free()

## Hủy sau commit vẫn giữ phần thưởng; trước commit trả sách và tương tác.
func _cancel_acquisition(committed: bool) -> void:
	if committed or _committed:
		queue_free()
		return
	_receiver = null
	_interactable.enabled = true
	set_process(_was_spinning)


## Cảnh báo thiếu dữ liệu ngay trong editor, trước lúc người chơi nhặt sách.
func _get_configuration_warnings() -> PackedStringArray:
	if ability == null:
		return ["Chưa gán AbilityData: kéo một file kỹ năng (ví dụ abilities/wind_blast/wind_blast.tres) vào ô Ability."]
	return []


## Chỉ nhận interactor có giao diện mở khóa, không buộc vào lớp Player cụ thể.
func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor.has_method(&"unlock_ability")


## Giữ đường trao kỹ năng public sẵn có để các receiver khác vẫn tái dùng được.
func _give_to(interactor: Node3D) -> void:
	interactor.call(&"unlock_ability", ability)
