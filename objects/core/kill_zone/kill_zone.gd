@tool
class_name KillZone
extends Area3D
## Vùng chết (vực, nước độc...). Báo cho body đi vào bằng on_kill_zone_entered();
## mỗi loại body tự quyết định xử lý (player về chỗ an toàn, quái chết...).
## Bật Lethal (nước sâu, dung nham...): báo on_lethal_zone_entered() để body chết thật;
## body không có hàm đó thì xử lý như vùng chết thường.

## Đồng bộ hai chiều với hộp CollisionShape3D qua BoxShapeSyncComponent: kéo gizmo hộp cũng cập nhật ô này
@export var size: Vector3 = Vector3(10.0, 2.0, 10.0):
	set(value):
		if size == value:
			return
		size = value
		if is_node_ready():
			_box_sync.apply(size)

## Chết thật (hồi sinh ở checkpoint) thay vì đưa về chỗ đứng an toàn
@export var lethal: bool = false

@onready var _box_sync: BoxShapeSyncComponent = $BoxShapeSync


func _ready() -> void:
	_box_sync.apply(size)
	_box_sync.size_changed.connect(_on_box_size_changed)
	if Engine.is_editor_hint():
		return
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if lethal and body.has_method(&"on_lethal_zone_entered"):
		body.call(&"on_lethal_zone_entered")
	elif body.has_method(&"on_kill_zone_entered"):
		body.call(&"on_kill_zone_entered")


func _on_box_size_changed(box_size: Vector3) -> void:
	# size setter bỏ qua khi bằng nhau nên không lặp vô hạn giữa hai chiều
	size = box_size
