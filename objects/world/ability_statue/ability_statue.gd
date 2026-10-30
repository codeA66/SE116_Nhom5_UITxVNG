@tool
class_name AbilityStatue
extends StaticBody3D
## Bức tượng mở khóa kỹ năng. Tương tác một lần: trao AbilityData cho người tương tác rồi sáng lên.
## Dùng chung cho mọi kỹ năng, đổi kỹ năng bằng cách gán file .tres khác.
## @tool chỉ để hiện cảnh báo cấu hình trong editor, logic game không chạy trong editor.

signal activated(ability: AbilityData)

@export var ability: AbilityData:
	set(value):
		ability = value
		update_configuration_warnings()
## ID duy nhất trong toàn game để nhớ đã kích hoạt chưa (ví dụ "zone_1_wind.dash_statue").
## Để trống = không lưu, tượng sẽ kích hoạt lại được mỗi lần vào scene
@export var persistent_id: StringName
## Vật liệu của quả cầu sau khi đã kích hoạt
@export var activated_material: Material

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _orb: MeshInstance3D = $Orb


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if ability == null:
		# Không dừng game vì một tượng cấu hình sai: báo lỗi và tắt tương tác
		push_error("%s chưa gán AbilityData, tượng bị tắt" % get_path())
		_interactable.enabled = false
		return
	if GameState.has_flag(persistent_id):
		_show_activated()
		return
	_interactable.interacted.connect(_on_interacted)


func _get_configuration_warnings() -> PackedStringArray:
	if ability == null:
		return ["Chưa gán AbilityData: kéo một file kỹ năng (ví dụ abilities/dash/dash.tres) vào ô Ability."]
	return []


func _on_interacted(interactor: Node3D) -> void:
	if not interactor.has_method(&"unlock_ability"):
		return
	interactor.call(&"unlock_ability", ability)
	GameState.set_flag(persistent_id)
	_show_activated()
	activated.emit(ability)


func _show_activated() -> void:
	_interactable.enabled = false
	_orb.material_override = activated_material
