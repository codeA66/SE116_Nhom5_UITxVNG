class_name SpawnPoint
extends Marker3D
## Điểm xuất hiện có tên trong một khu. Player xuất hiện tại đây, quay mặt theo trục -Z (mũi tên xanh dương ngược lại).

const GROUP := &"spawn_point"

## Tên duy nhất trong khu, cổng và checkpoint dùng tên này để chỉ chỗ xuất hiện
@export var spawn_id: StringName


func _ready() -> void:
	add_to_group(GROUP)


func get_facing() -> Vector3:
	var facing := -global_basis.z
	facing.y = 0.0
	return facing.normalized()


## Tìm điểm xuất hiện theo tên trong cây con của root; không có thì trả null
static func find_in(root: Node, id: StringName) -> SpawnPoint:
	if id.is_empty():
		return null
	for node in root.get_tree().get_nodes_in_group(GROUP):
		var spawn := node as SpawnPoint
		if spawn.spawn_id == id and root.is_ancestor_of(spawn):
			return spawn
	return null
