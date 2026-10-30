@tool
class_name BoxShapeSyncComponent
extends Node
## Đồng bộ hai chiều giữa ô Size của một vùng (WindZone, KillZone...) và hộp CollisionShape3D của nó.
## Đổi Size thì hộp đổi theo (node cha gọi apply()); kéo gizmo hộp hoặc sửa Shape > Size
## thì phát size_changed để node cha cập nhật Size và mọi thứ phụ thuộc (VFX...).
## @tool để đồng bộ ngay trong editor.

## Hộp bị sửa trực tiếp; node cha gán lại size của mình theo giá trị này
signal size_changed(size: Vector3)

@export var shape_node: CollisionShape3D:
	set(value):
		shape_node = value
		update_configuration_warnings()

var _box: BoxShape3D


func _ready() -> void:
	if shape_node == null or not (shape_node.shape is BoxShape3D):
		push_error("%s cần shape_node có BoxShape3D" % get_path())
		return
	_box = shape_node.shape as BoxShape3D
	_box.changed.connect(_on_box_changed)


func _get_configuration_warnings() -> PackedStringArray:
	if shape_node == null:
		return ["Chưa gán Shape Node: kéo CollisionShape3D (hình hộp) của vùng vào ô này."]
	return []


## Node cha gọi khi Size đổi. Không ghi lại nếu bằng nhau để hai chiều không gọi nhau vô hạn
func apply(size: Vector3) -> void:
	if _box and _box.size != size:
		_box.size = size


func _on_box_changed() -> void:
	size_changed.emit(_box.size)
