@tool
class_name FireShrineVisual
extends ShrineVisual
## Miếu Lửa (checkpoint_shrine_fire.glb): tắt thì chỉ còn đá, sáng thì ngọn lửa hiện và đèn bừng lên.
## Chỉ đổi hình ảnh; không truy cập tiến trình hoặc ghi save. Hiệu năng: chỉ tween khi đổi trạng thái.

@export var lit_energy: float = 2.5
@export_range(0.0, 3.0, 0.05) var activation_time: float = 0.6
## Xem trước trạng thái sáng trong editor
@export var preview_active: bool = false:
	set(value):
		preview_active = value
		if is_node_ready() and Engine.is_editor_hint():
			set_active(value, null, 0.0, true)

var _last_target: bool = false
var _tween: Tween

@onready var _light: OmniLight3D = $Light
# glTF có thể thêm hậu tố vào tên node ngọn lửa
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D


func _ready() -> void:
	set_active(preview_active if Engine.is_editor_hint() else false, null, 0.0, true)


func set_active(enabled: bool, _legacy_material: Material = null, _spin_degrees: float = 12.0, immediate: bool = false) -> void:
	if not is_node_ready():
		return
	if enabled == _last_target and not immediate:
		return
	_last_target = enabled
	if _tween:
		_tween.kill()
	if _flame:
		_flame.visible = enabled
	var target: float = lit_energy if enabled else 0.0
	if immediate or activation_time <= 0.0:
		_light.light_energy = target
		_light.visible = enabled
		return
	_light.visible = true
	_tween = create_tween()
	_tween.tween_property(_light, ^"light_energy", target, activation_time)
	if not enabled:
		_tween.tween_callback(_light.hide)
