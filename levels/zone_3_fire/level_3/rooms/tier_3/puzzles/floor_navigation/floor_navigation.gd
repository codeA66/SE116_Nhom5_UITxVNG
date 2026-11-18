class_name FloorNavigation
extends RefCounted
## Dùng mặt trên collider hộp để bake đường đi mà không đọc mesh từ GPU.


static func add_box_top(source: NavigationMeshSourceGeometryData3D, shape_node: CollisionShape3D, region_inverse: Transform3D) -> void:
	var box: BoxShape3D = shape_node.shape as BoxShape3D
	if box == null:
		return
	var half: Vector3 = box.size * 0.5
	var a: Vector3 = Vector3(-half.x, half.y, -half.z)
	var b: Vector3 = Vector3(half.x, half.y, -half.z)
	var c: Vector3 = Vector3(half.x, half.y, half.z)
	var d: Vector3 = Vector3(-half.x, half.y, half.z)
	source.add_faces(PackedVector3Array([a, b, c, a, c, d]), region_inverse * shape_node.global_transform)
