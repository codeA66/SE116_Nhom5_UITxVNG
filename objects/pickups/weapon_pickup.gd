class_name WeaponPickup
extends Node3D
## Vũ khí nằm trên đất. Người chơi bấm tương tác để nhặt; model và tên lấy từ WeaponData.

@export var weapon: WeaponData
@export var spin_speed: float = 1.5

@onready var _visual: Node3D = $Visual
@onready var _interactable: InteractableComponent = $InteractableComponent


func _ready() -> void:
	assert(weapon != null, "%s chưa gán WeaponData" % name)
	if weapon.model_scene:
		_visual.add_child(weapon.model_scene.instantiate())
	_interactable.set_prompt_text("[E] Nhặt %s" % weapon.display_name)
	_interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_visual.rotate_y(spin_speed * delta)


func _on_interacted(interactor: Node3D) -> void:
	if not interactor.has_method(&"pick_up_weapon"):
		return
	_interactable.enabled = false
	interactor.call(&"pick_up_weapon", weapon)
	queue_free()
