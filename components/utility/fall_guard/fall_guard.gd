class_name FallGuard
extends Node3D
## Rào chống rơi vô hình: lúc nạp map, dựng một dải va chạm bám theo mỗi lan can / cột lan can (theo scene của prop).
## Đầu lan can được nối dài thêm khi: chạm một lan can khác chạy theo hướng khác (góc rẽ), hoặc ngay phía trước đầu đó
## là vực (không có sàn). Đầu lan can ở cửa đi (phía trước có sàn) / nối thẳng hàng không nối dài, để lối đi không hẹp lại.
## Đặt 1 node trong level; thêm loại prop mới chỉ cần thêm đường dẫn scene vào guarded_scenes.
## Hiệu năng: chỉ quét cây một lần lúc _ready, gom mọi khối vào một StaticBody3D; không có _process.

## Scene prop cần rào (so với scene_file_path của node trong level)
@export var guarded_scenes: Array[String] = [
	"res://assets/models/map_fire/fire_kit/fence_rail_2m.glb",
	"res://assets/models/map_fire/fire_kit/fence_post.glb",
]
## Gốc để tìm prop. Để trống = node cha (cả level)
@export var search_root: NodePath
## Chiều cao dải chặn tính từ chân prop (m)
@export_range(0.5, 20.0, 0.05) var guard_height: float = 2.0
## Bề dày tối thiểu của dải chặn (m): lan can mỏng vẫn chặn được thân nhân vật
@export_range(0.05, 2.0, 0.05) var min_thickness: float = 0.4
## Nối dài đầu lan can ở góc rẽ (m) để hai dải gặp nhau không chừa khe
@export_range(0.0, 2.0, 0.05) var end_extension: float = 0.25
## Đầu lan can coi là chạm lan can khác khi đầu của đoạn kia cách trong khoảng này (m)
@export_range(0.1, 3.0, 0.05) var corner_reach: float = 0.8
## Hai lan can coi là cùng hướng (không phải góc) khi |cos góc giữa hai trục| lớn hơn ngưỡng này
@export_range(0.0, 1.0, 0.01) var parallel_threshold: float = 0.9
## Dò vực phía trước đầu lan can: cách đầu bao xa (m) và sâu bao nhiêu thì coi là không có sàn (m)
@export_range(0.1, 2.0, 0.05) var void_probe_ahead: float = 0.4
@export_range(0.5, 20.0, 0.1) var void_probe_depth: float = 3.0
## Mặc định player_blocker (layer 9): chặn player và quái, không chặn camera / tia nhìn của đạn bắn vào tường
@export_flags_3d_physics var guard_layer: int = 256

var _body: StaticBody3D


func _ready() -> void:
	# Chờ cả level vào cây xong (prop là anh em / con cháu của node cha)
	_build.call_deferred()


## Số khối đã dựng (để test đo)
func get_guard_count() -> int:
	return _body.get_child_count() if _body else 0


func _build() -> void:
	# Chờ một frame vật lý để va chạm sàn của level đã vào không gian vật lý (dò vực bằng tia)
	await get_tree().physics_frame
	var root: Node = get_node_or_null(search_root) if not search_root.is_empty() else get_parent()
	if root == null:
		push_warning("%s: không tìm thấy search_root" % get_path())
		return
	_body = StaticBody3D.new()
	_body.name = &"GuardBody"
	_body.collision_layer = guard_layer
	_body.collision_mask = 0
	add_child(_body)
	# Khối đặt theo toạ độ thế giới: cho body đứng yên ở gốc toàn cục
	_body.top_level = true
	_body.global_transform = Transform3D.IDENTITY
	var pieces: Array[Dictionary] = []
	for node: Node in root.find_children("*", "Node3D", true, false):
		if not (node.scene_file_path in guarded_scenes):
			continue
		var prop := node as Node3D
		var local := _local_bounds(prop)
		if local.size == Vector3.ZERO:
			continue
		pieces.append(_describe(prop, local))
	for piece: Dictionary in pieces:
		_add_guard(piece, pieces)


## Khung bao các mesh của prop trong toạ độ cục bộ của prop
func _local_bounds(prop: Node3D) -> AABB:
	var inv: Transform3D = prop.global_transform.affine_inverse()
	var box := AABB()
	var first: bool = true
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var b: AABB = inv * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Thông tin một đoạn theo toạ độ thế giới: tâm chân, trục dọc (X cục bộ), dài, dày, hai đầu
func _describe(prop: Node3D, local: AABB) -> Dictionary:
	var scale_v: Vector3 = prop.global_basis.get_scale()
	var prop_basis := prop.global_basis.orthonormalized()
	var length: float = local.size.x * scale_v.x
	var depth: float = local.size.z * scale_v.z
	var center_local: Vector3 = local.get_center()
	var foot: Vector3 = prop.global_transform * Vector3(center_local.x, local.position.y, center_local.z)
	var axis: Vector3 = prop_basis.x
	return {
		"basis": prop_basis, "foot": foot, "axis": axis, "length": length, "depth": depth,
		"is_post": length < 1.0 and depth < 1.0,
		"ends": [foot - axis * length * 0.5, foot + axis * length * 0.5],
	}


## Đầu `end` của đoạn `piece` có chạm một lan can khác chạy theo hướng khác (góc rẽ) không
func _is_corner(piece: Dictionary, end: Vector3, pieces: Array[Dictionary]) -> bool:
	for other: Dictionary in pieces:
		if other == piece or other.is_post:
			continue
		if absf((piece.axis as Vector3).dot(other.axis)) > parallel_threshold:
			continue
		for e: Vector3 in other.ends:
			if Vector2(e.x - end.x, e.z - end.z).length() <= corner_reach and absf(e.y - end.y) < 1.0:
				return true
	return false


func _needs_extension(piece: Dictionary, end: Vector3, outward: Vector3, pieces: Array[Dictionary]) -> bool:
	return _is_corner(piece, end, pieces) or _opens_to_void(end, outward)


## Ngay phía trước đầu lan can không có sàn (va chạm world) trong void_probe_depth m
func _opens_to_void(end: Vector3, outward: Vector3) -> bool:
	var probe: Vector3 = end + outward * void_probe_ahead
	var query := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.5, probe + Vector3.DOWN * void_probe_depth, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _add_guard(piece: Dictionary, pieces: Array[Dictionary]) -> void:
	var piece_basis: Basis = piece.basis
	var axis: Vector3 = piece.axis
	var side: Vector3 = piece_basis.z
	var length: float = piece.length
	var depth: float = maxf(piece.depth, min_thickness)
	var shift := Vector3.ZERO
	# Nối dài riêng từng đầu; dời tâm theo phần nối thêm để đầu kia giữ nguyên
	var grow_a: float = end_extension if _needs_extension(piece, piece.ends[0], -axis, pieces) else 0.0
	var grow_b: float = end_extension if _needs_extension(piece, piece.ends[1], axis, pieces) else 0.0
	length += grow_a + grow_b
	shift += axis * (grow_b - grow_a) * 0.5
	if piece.is_post:
		# Cột ở góc: nối thêm cả theo hai phía bên nếu phía đó là vực
		var foot: Vector3 = piece.foot
		var half: float = depth * 0.5
		var grow_l: float = end_extension if _opens_to_void(foot - side * half, -side) else 0.0
		var grow_r: float = end_extension if _opens_to_void(foot + side * half, side) else 0.0
		depth += grow_l + grow_r
		shift += side * (grow_r - grow_l) * 0.5
	var box := BoxShape3D.new()
	box.size = Vector3(length, guard_height, depth)
	var shape := CollisionShape3D.new()
	shape.shape = box
	_body.add_child(shape)
	var center: Vector3 = (piece.foot as Vector3) + shift + piece_basis.y * (guard_height * 0.5)
	shape.global_transform = Transform3D(piece_basis, center)
