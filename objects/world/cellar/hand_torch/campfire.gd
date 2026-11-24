class_name Campfire
extends StaticBody3D
## Lửa trại lớn: luôn cháy sẵn từ lúc vào khu (không cần Phun lửa để nhóm).
## Player tới gần tương tác thì nhận ngay một cây gậy đã châm thành đuốc sáng; đang cầm đuốc thì châm lại
## cho đầy giờ nếu sắp tắt.
## Hiệu năng: không có _process; ánh lửa chập chờn do FlameFeedback lo.

signal torch_lit(actor: Node3D)
signal activated

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
@onready var _light: OmniLight3D = $Light
@onready var _feedback: FlameFeedback = $FlameFeedback
# glTF có thể thêm hậu tố vào tên node ngọn lửa
@onready var _flame: Node3D = $Model.find_child("Flame*", true, false) as Node3D


func _ready() -> void:
	# Chập chờn màu / vị trí đèn + hạt lửa do FlameFeedback lo (cùng hệ với đuốc)
	_feedback.setup(_flame, _light, lit_energy)
	_interactable.availability_check = _can_light_torch
	_interactable.interacted.connect(_on_interacted)
	_light_up()


func is_active() -> bool:
	return is_lit


func _light_up() -> void:
	is_lit = true
	if _flame:
		_flame.visible = true
	_light.visible = true
	_feedback.start_quiet()
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
