class_name Campfire
extends StaticBody3D
## Lửa trại lớn: lúc đầu tắt (chỉ có củi), trúng Phun lửa (nguồn lửa bất kỳ) thì bùng cháy.
## Khi đang cháy, player tới gần tương tác thì nhận ngay một cây gậy đã châm thành đuốc sáng; đang cầm đuốc thì châm lại
## cho đầy giờ nếu sắp tắt. Gợi ý chỉ hiện khi lửa đã cháy. Có persistent_id thì nhớ đã đốt qua lần chơi sau.
## Hiệu năng: chỉ nghe signal ignited của BurnableComponent; cháy rồi thì tắt luôn vùng bắt lửa.

signal torch_lit(actor: Node3D)
signal activated

## Cờ lưu trạng thái đã đốt. Để trống = mỗi lần vào khu lại tắt
@export var persistent_id: StringName
@export var lit_energy: float = 2.5
@export_group("Gợi ý châm đuốc")
@export var light_prompt: String = "THẮP ĐUỐC"
## Chưa cầm đuốc: lấy một cây gậy đã châm từ lửa trại
@export var take_prompt: String = "LẤY ĐUỐC"
@export var torch_scene: PackedScene = preload("res://objects/world/cellar/hand_torch/hand_torch.tscn")
@export var refill_prompt: String = "CHÂM LẠI"
## Đuốc còn trên tỉ lệ thời gian này thì ẩn gợi ý châm lại (tránh tưởng chưa châm được)
@export_range(0.0, 1.0, 0.01) var refill_threshold: float = 0.8

var is_lit: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
## Gợi ý + tàn lửa lúc chưa cháy để người chơi biết đây là thứ đốt được
@onready var _hint: WorldHint = $UnlitHint
@onready var _embers: GPUParticles3D = $Embers
@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _light: OmniLight3D = $Light
@onready var _feedback: FlameFeedback = $FlameFeedback
# glTF có thể thêm hậu tố vào tên node ngọn lửa
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D


func _ready() -> void:
	# Chập chờn màu / vị trí đèn + hạt lửa do FlameFeedback lo (cùng hệ với đuốc)
	_feedback.setup(_flame, _light, lit_energy)
	_interactable.availability_check = _can_light_torch
	_interactable.interacted.connect(_on_interacted)
	_hint.visible_check = func() -> bool: return not is_lit
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
	_embers.emitting = false
	_embers.visible = false
	_hint.refresh()
	if _flame:
		_flame.visible = true
	_light.visible = true
	if instant:
		_feedback.start_quiet()
	else:
		_feedback.ignite()
	activated.emit()


## Prompt đổi chữ theo trạng thái đuốc: chưa cháy → thắp, đang cháy nhưng đã vơi → châm lại, còn gần đầy → ẩn
func _can_light_torch(actor: Node3D) -> bool:
	if not is_lit:
		return false
	var torch: HandTorch = HandTorch.find_on(actor)
	if torch == null:
		_interactable.prompt_text = take_prompt
		return true
	if not torch.is_lit:
		_interactable.prompt_text = light_prompt
		return true
	_interactable.prompt_text = refill_prompt
	return torch.time_left() < torch.burn_time * refill_threshold


func _on_interacted(actor: Node3D) -> void:
	if not is_lit:
		return
	var torch: HandTorch = HandTorch.give_to(actor, torch_scene)
	torch.light_up()
	torch_lit.emit(actor)
