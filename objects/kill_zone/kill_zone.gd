@tool
class_name KillZone
extends Area3D
## Vùng chết (vực, nước độc...). Báo cho body đi vào bằng on_kill_zone_entered();
## mỗi loại body tự quyết định xử lý (player về chỗ an toàn, quái chết...).

@export var size: Vector3 = Vector3(10.0, 2.0, 10.0):
	set(value):
		size = value
		if is_node_ready():
			_apply_size()

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	monitorable = false
	body_entered.connect(_on_body_entered)


func _apply_size() -> void:
	# Shape đánh dấu local_to_scene nên mỗi vật có bản riêng: chỉ đổi kích thước, không tạo shape mới
	# (tạo mới sẽ làm editor ghi thêm shape thừa vào scene cha khi lưu)
	(_shape.shape as BoxShape3D).size = size


func _on_body_entered(body: Node3D) -> void:
	if body.has_method(&"on_kill_zone_entered"):
		body.call(&"on_kill_zone_entered")
