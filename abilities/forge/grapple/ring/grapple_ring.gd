class_name GrappleRing
extends Node3D
## Vòng móc treo trong map: kỹ năng Móc kéo bám vào đây rồi kéo player tới. Chỉ là điểm neo + hình, không có va chạm.
## Tự vào group để kỹ năng tìm khi bấm phím (một lần mỗi lần bấm, không quét mỗi frame).

const GROUP := &"grapple_rings"

## Tắt thì kỹ năng bỏ qua vòng này (vòng bị khoá theo câu đố...)
@export var enabled: bool = true
## Player được kéo tới chỗ chân thấp hơn tâm vòng bấy nhiêu mét (tay nắm vòng, không đâm đầu vào vòng)
@export_range(0.0, 3.0, 0.05) var hang_offset: float = 1.1


func _ready() -> void:
	add_to_group(GROUP)


## Điểm chân player cần tới khi móc vào vòng
func get_pull_target() -> Vector3:
	return global_position + Vector3.DOWN * hang_offset


## Vòng gần nhất trong tầm, nằm trong cung trước mặt, không bị tường chắn; null nếu không có.
## eye: điểm bắn móc; forward: hướng ngang; cos_half_arc: cos(nửa cung nhắm); exclude: RID không tính là vật chắn
static func find_best(tree: SceneTree, space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3,
		max_range: float, cos_half_arc: float, wall_mask: int, exclude: Array[RID]) -> GrappleRing:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var best: GrappleRing
	var best_distance := INF
	var query := PhysicsRayQueryParameters3D.create(eye, eye, wall_mask, exclude)
	for node: Node in tree.get_nodes_in_group(GROUP):
		var ring := node as GrappleRing
		if ring == null or not ring.enabled or not ring.is_inside_tree():
			continue
		var offset := ring.global_position - eye
		var distance := offset.length()
		if distance > max_range or distance >= best_distance:
			continue
		var flat := Vector3(offset.x, 0.0, offset.z)
		if not flat.is_zero_approx() and flat.normalized().dot(flat_forward) < cos_half_arc:
			continue
		query.to = ring.global_position
		if not space.intersect_ray(query).is_empty():
			continue
		best = ring
		best_distance = distance
	return best
