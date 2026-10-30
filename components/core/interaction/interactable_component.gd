class_name InteractableComponent
extends Area3D
## Gắn vào vật tương tác được (vũ khí, rương, cửa, NPC...).
## InteractorComponent chọn vật gần nhất; UI gợi ý đọc prompt_text và vị trí từ đây.

signal interacted(interactor: Node3D)

## Chữ hành động hiển thị trên gợi ý, ví dụ "PICK UP", "OPEN", "TALK"
@export var prompt_text: String = "INTERACT"
## Điểm neo gợi ý so với vật, UI chiếu điểm này lên màn hình
@export var prompt_offset: Vector3 = Vector3.ZERO

var enabled: bool = true


func _ready() -> void:
	monitoring = false
	monitorable = true


func get_prompt_position() -> Vector3:
	return global_position + prompt_offset


func interact(interactor: Node3D) -> void:
	if not enabled:
		return
	interacted.emit(interactor)
