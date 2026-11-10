@tool
class_name CharmPickup
extends Pickup
## Bùa nằm trên đất (kiểu Hollow Knight): nhặt là có bùa trong trang Bùa của Tab. Thêm bùa mới chỉ cần đổi ô Charm.
## Phần thưởng của thử thách có thể ẩn sẵn (starts_hidden) rồi phòng gọi reveal() khi thắng.

signal revealed

@export var charm: CharmData:
	set(value):
		charm = value
		update_configuration_warnings()
## Ẩn và không nhặt được cho tới khi có ai gọi reveal()
@export var starts_hidden: bool = false
@export var beam_color: Color = Color("fff1c4")


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or is_queued_for_deletion():
		return
	# Bùa đã có (ví dụ nhận ở nơi khác) thì không đặt thêm bản nữa
	if charm and GameState.owns_charm(charm.id):
		queue_free()
		return
	if starts_hidden:
		hide()
		_interactable.enabled = false
		set_process(false)


## Hiện bùa và cho nhặt; gọi nhiều lần không sao
func reveal() -> void:
	if is_queued_for_deletion() or visible and _interactable.enabled:
		return
	show()
	_interactable.enabled = true
	set_process(true)
	revealed.emit()


func _build_visual(visual_root: Node3D) -> void:
	LootItemBeam.attach_to(visual_root.get_parent() as Node3D, beam_color).show()


func _get_configuration_warnings() -> PackedStringArray:
	if charm == null:
		return ["Chưa gán CharmData vào ô Charm."]
	return []


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player


func _give_to(_interactor: Node3D) -> void:
	GameState.add_charm(charm)
