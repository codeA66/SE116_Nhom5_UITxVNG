class_name SmallShadowFilter
extends Node
## Tắt bóng đổ của mesh nhỏ (decor, đồ vặt) một lần lúc nạp khu. Ở Tier1, bóng nắng chiếm khoảng 75% draw call;
## mesh nhỏ đổ bóng gần như không thấy nhưng vẫn tốn một lượt vẽ trong pass bóng.
## Lọc ở runtime thay vì sửa file phòng: phòng lưu nhị phân .scn, sửa thẳng thì git diff không đọc được.
## Không chạy mỗi frame. Nhân vật (mọi thứ dưới CharacterBody3D) giữ nguyên bóng.
## Đặt node này sau các nhánh cần lọc trong cây, để chạy trước ShaderWarmup của ZoneRoot.

@export var enabled: bool = true
## Mesh có cạnh dài nhất (kích thước thật trong thế giới) nhỏ hơn ngưỡng này thì tắt bóng
@export_range(0.0, 20.0, 0.05, "or_greater", "suffix:m") var max_size: float = 1.5
## Các nhánh cần lọc; để trống thì lọc nhánh cha của node này
@export var targets: Array[Node] = []

## Số mesh đã tắt bóng ở lần lọc gần nhất
var filtered_count: int = 0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not enabled:
		return
	var roots: Array[Node] = targets.duplicate()
	if roots.is_empty():
		roots.append(get_parent())
	filtered_count = 0
	for root in roots:
		if is_instance_valid(root):
			filtered_count += _filter(root)
	print("SmallShadowFilter: tắt bóng %d mesh nhỏ hơn %.2f m" % [filtered_count, max_size])


func _filter(root: Node) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		# Nhân vật cần bóng thật để đọc dáng; số lượng ít nên không đáng kể
		if node is CharacterBody3D:
			continue
		stack.append_array(node.get_children())
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var size := (mesh_instance.global_transform * mesh_instance.get_aabb()).size
		if maxf(size.x, maxf(size.y, size.z)) < max_size:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			count += 1
	return count
