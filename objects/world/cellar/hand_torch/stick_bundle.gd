class_name StickBundle
extends Node3D
## Bó gậy cạnh lửa trại: tương tác thì nhận một cây gậy làm đuốc (chưa cháy). Lấy bao nhiêu lần cũng được
## nhưng chỉ cầm một cây; đang cầm thì không hiện gợi ý.

signal stick_taken(actor: Node3D)

@export var torch_scene: PackedScene = preload("res://objects/world/cellar/hand_torch/hand_torch.tscn")
## Câu gợi ý bước tiếp theo, hiện ngay sau khi lấy gậy
@export var taken_hint: String = "Châm gậy ở lửa trại"
@export_range(0.5, 10.0, 0.1) var taken_hint_time: float = 2.5
@export_group("Nảy gậy khi nhận")
## Co dẹt lúc vừa nhận rồi nảy về 1 (TRANS_BACK vượt quá một chút cho có lực)
@export var pop_squash: Vector3 = Vector3(1.4, 0.6, 1.4)
@export_range(0.05, 1.0, 0.01) var pop_time: float = 0.22

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _hint: WorldHint = $Hint


func _ready() -> void:
	# Bó gậy dùng chung model đuốc: gậy chưa châm nên ẩn ngọn lửa
	for flame: Node in find_children("Flame*", "Node3D", true, false):
		(flame as Node3D).visible = false
	_interactable.availability_check = func(actor: Node3D) -> bool: return HandTorch.find_on(actor) == null
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(actor: Node3D) -> void:
	var torch: HandTorch = HandTorch.give_to(actor, torch_scene)
	# Chỉ nảy phần hình: co giãn cả đuốc làm méo vùng châm lửa (Jolt không nhận scale không đều)
	var visual: Node3D = torch.get_node_or_null(^"Model") as Node3D
	_pop(visual if visual else torch)
	_hint.flash(taken_hint, taken_hint_time)
	# Châm xong thì gợi ý "châm gậy" hết ý nghĩa: tắt ngay
	if not torch.lit.is_connected(_hint.cancel_flash):
		torch.lit.connect(_hint.cancel_flash, CONNECT_ONE_SHOT)
	stick_taken.emit(actor)


func _pop(target: Node3D) -> void:
	var base: Vector3 = target.scale
	target.scale = base * pop_squash
	create_tween().tween_property(target, ^"scale", base, pop_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
