class_name InteractorComponent
extends Area3D
## Gắn vào nhân vật. Luôn chọn InteractableComponent gần nhất trong tầm làm mục tiêu hiện tại.

signal focus_changed(target: InteractableComponent)

var current: InteractableComponent


func _ready() -> void:
	monitorable = false


func _physics_process(_delta: float) -> void:
	_update_focus()


## Tương tác với mục tiêu hiện tại. Trả về false nếu không có gì để tương tác
func try_interact() -> bool:
	if not is_instance_valid(current) or not current.can_interact(owner as Node3D):
		return false
	current.interact(owner as Node3D)
	return true


func _update_focus() -> void:
	var nearest: InteractableComponent = null
	var best_distance := INF
	for area in get_overlapping_areas():
		var interactable := area as InteractableComponent
		if interactable == null or not interactable.can_interact(owner as Node3D):
			continue
		var distance := global_position.distance_squared_to(interactable.global_position)
		if nearest == null or interactable.interaction_priority > nearest.interaction_priority \
				or (interactable.interaction_priority == nearest.interaction_priority and distance < best_distance):
			best_distance = distance
			nearest = interactable

	# Mục tiêu cũ có thể đã bị xóa (ví dụ vật phẩm vừa được nhặt)
	if not is_instance_valid(current):
		current = null
	if nearest == current:
		return
	current = nearest
	focus_changed.emit(current)
