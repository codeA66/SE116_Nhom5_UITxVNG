@tool
class_name WeaponPickup
extends Node3D
## Vũ khí nằm trên đất. Người chơi bấm tương tác để nhặt; model và tên lấy từ WeaponData.
## @tool chỉ để hiện cảnh báo cấu hình trong editor, logic game không chạy trong editor.

@export var weapon: WeaponData:
	set(value):
		weapon = value
		update_configuration_warnings()
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
	if weapon == null:
		# Không dừng game vì một vật cấu hình sai: báo lỗi và bỏ vật này
		push_error("%s chưa gán WeaponData, vật phẩm bị bỏ" % get_path())
		queue_free()
		return
	if GameState.has_flag(persistent_id):
		queue_free()
		return
	if weapon.model_scene:
		var model := weapon.model_scene.instantiate() as Node3D
		model.scale = Vector3.ONE * weapon.model_scale
		_visual.add_child(model)
	_interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_visual.rotate_y(spin_speed * delta)


func _get_configuration_warnings() -> PackedStringArray:
	if weapon == null:
		return ["Chưa gán WeaponData: kéo một file vũ khí (ví dụ resources/weapons/sword.tres) vào ô Weapon."]
	return []


func _on_interacted(interactor: Node3D) -> void:
	if not interactor.has_method(&"pick_up_weapon"):
		return
	_interactable.enabled = false
	GameState.set_flag(persistent_id)
	interactor.call(&"pick_up_weapon", weapon)
	queue_free()
