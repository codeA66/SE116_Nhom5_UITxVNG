class_name StickBundle
extends Node3D
## Bó gậy cạnh lửa trại: tương tác thì nhận một cây gậy làm đuốc (chưa cháy). Lấy bao nhiêu lần cũng được
## nhưng chỉ cầm một cây; đang cầm thì không hiện gợi ý.

signal stick_taken(actor: Node3D)

@export var torch_scene: PackedScene = preload("res://objects/world/cellar/hand_torch/hand_torch.tscn")

@onready var _interactable: InteractableComponent = $InteractableComponent


func _ready() -> void:
	# Bó gậy dùng chung model đuốc: gậy chưa châm nên ẩn ngọn lửa
	for flame: Node in find_children("Flame*", "Node3D", true, false):
		(flame as Node3D).visible = false
	_interactable.availability_check = func(actor: Node3D) -> bool: return HandTorch.find_on(actor) == null
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(actor: Node3D) -> void:
	HandTorch.give_to(actor, torch_scene)
	stick_taken.emit(actor)
