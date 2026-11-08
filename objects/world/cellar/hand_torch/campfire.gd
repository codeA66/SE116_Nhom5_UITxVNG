class_name Campfire
extends StaticBody3D
## Lửa trại lớn: lúc đầu tắt (chỉ có củi), trúng Phun lửa (nguồn lửa bất kỳ) thì bùng cháy.
## Khi đang cháy, player cầm gậy (HandTorch) tới gần, tương tác thì châm thành đuốc sáng (châm lại cho đầy giờ nếu sắp tắt).
## Gợi ý chỉ hiện khi lửa đã cháy và đang cầm gậy. Có persistent_id thì nhớ đã đốt qua lần chơi sau.
## Hiệu năng: chỉ nghe signal ignited của BurnableComponent; cháy rồi thì tắt luôn vùng bắt lửa.

signal torch_lit(actor: Node3D)
signal activated

## Cờ lưu trạng thái đã đốt. Để trống = mỗi lần vào khu lại tắt
@export var persistent_id: StringName
@export var lit_energy: float = 2.5
@export_range(0.05, 3.0, 0.05) var light_up_time: float = 0.6

var is_lit: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _light: OmniLight3D = $Light
# glTF có thể thêm hậu tố vào tên node ngọn lửa
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D


func _ready() -> void:
	_interactable.availability_check = func(actor: Node3D) -> bool: return is_lit and HandTorch.find_on(actor) != null
	_interactable.interacted.connect(_on_interacted)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_light_up(true)
		return
	_light.light_energy = 0.0
	_light.visible = false
	if _flame:
		_flame.visible = false
	_burnable.ignited.connect(_on_ignited)


func is_active() -> bool:
	return is_lit


func _on_ignited() -> void:
	if is_lit:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_light_up(false)


func _light_up(instant: bool) -> void:
	is_lit = true
	_burnable.set_enabled(false)
	if _flame:
		_flame.visible = true
	_light.visible = true
	if instant:
		_light.light_energy = lit_energy
	else:
		create_tween().tween_property(_light, ^"light_energy", lit_energy, light_up_time)
	activated.emit()


func _on_interacted(actor: Node3D) -> void:
	if not is_lit:
		return
	var torch: HandTorch = HandTorch.find_on(actor)
	if torch == null:
		return
	torch.light_up()
	torch_lit.emit(actor)
