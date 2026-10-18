class_name TeleportPointFinder
extends Node
## Chọn điểm dịch chuyển hợp lệ quanh một mục tiêu cho quái bay / boss.
## Chạy một lần mỗi lần dịch chuyển (không chạy mỗi frame). Cha phải là CollisionObject3D có CollisionShape3D
## đầu tiên là hình thân (dùng để kiểm tra điểm không kẹt khối).
## Điều kiện: đủ xa chỗ cũ, trong vùng canh, có đất bên dưới, không kẹt khối/rào/quái khác,
## có đường bắn tới mục tiêu, nằm trong khung nhìn camera. Không có điểm hợp lệ thì trả về chỗ cũ.

## Góc vàng (rad): các ứng viên rải đều quanh vòng dù chỉ có vài ứng viên
const GOLDEN_ANGLE := 2.399963

## Chọn điểm đứng cách mặt đất bao nhiêu (m); do quái đặt
var hover_height: float = 0.5
var leash_range: float = INF
## Độ cao nòng bắn trên gốc thân và độ cao ngực mục tiêu trên gốc: tia đường bắn nối hai điểm này (m)
var muzzle_height: float = 1.1
var target_height: float = 1.0

## Lần tìm gần nhất có ra điểm hợp lệ không
var has_found: bool = false
## Số ứng viên bị loại ở lần tìm gần nhất, theo từng điều kiện (để kiểm thử / chỉnh)
var reject_counts: Dictionary[StringName, int] = {}

var _body: CollisionObject3D
var _shape: Shape3D
var _shape_offset: Vector3
var _ray: PhysicsRayQueryParameters3D
var _shape_query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	_body = get_parent() as CollisionObject3D
	assert(_body != null, "TeleportPointFinder phải là con của CollisionObject3D")
	for child in _body.get_children():
		if child is CollisionShape3D:
			_shape = (child as CollisionShape3D).shape
			_shape_offset = (child as CollisionShape3D).position
			break
	assert(_shape != null, "TeleportPointFinder: thân chưa có CollisionShape3D")
	_ray = PhysicsRayQueryParameters3D.new()
	_shape_query = PhysicsShapeQueryParameters3D.new()
	_shape_query.shape = _shape
	_shape_query.exclude = [_body.get_rid()]
	_shape_query.collide_with_areas = false
	_shape_query.collide_with_bodies = true


## around: vị trí mục tiêu (gốc chân); home: tâm vùng canh; current: chỗ đứng hiện tại (trả về nếu thất bại)
func find_point(around: Vector3, home: Vector3, current: Vector3, data: TeleportData) -> Vector3:
	has_found = false
	reject_counts.clear()
	var space := _body.get_world_3d().direct_space_state
	var ring_low := minf(data.ring_min, data.ring_max)
	var ring_high := maxf(data.ring_min, data.ring_max)
	var base_angle := randf() * TAU
	var camera := _body.get_viewport().get_camera_3d() if data.require_on_screen else null
	for i in data.candidate_count:
		var angle := base_angle + i * GOLDEN_ANGLE
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(ring_low, ring_high)
		var candidate := _try_candidate(space, around, home, current, around + offset, camera, data)
		if candidate.is_finite():
			has_found = true
			return candidate
	return current


## Trả Vector3.INF nếu ứng viên bị loại
func _try_candidate(space: PhysicsDirectSpaceState3D, around: Vector3, home: Vector3, current: Vector3, flat: Vector3, camera: Camera3D, data: TeleportData) -> Vector3:
	# 2. đủ xa chỗ cũ
	if Vector2(flat.x - current.x, flat.z - current.z).length() < data.min_jump_distance:
		return _reject(&"too_near")
	# 3. trong vùng canh
	if Vector2(flat.x - home.x, flat.z - home.z).length() > maxf(leash_range - data.leash_margin, 0.0):
		return _reject(&"outside_leash")
	# 4. có đất bên dưới trong max_ground_drop
	_ray.collision_mask = data.world_mask
	_ray.from = Vector3(flat.x, around.y + data.ground_probe_up, flat.z)
	_ray.to = Vector3(flat.x, around.y - data.max_ground_drop, flat.z)
	var ground := space.intersect_ray(_ray)
	if ground.is_empty():
		return _reject(&"no_ground")
	var point := Vector3(flat.x, (ground["position"] as Vector3).y + hover_height, flat.z)
	# 5. không kẹt trong khối / rào / quái khác
	_shape_query.collision_mask = data.blocked_mask
	_shape_query.transform = Transform3D(Basis.IDENTITY, point + _shape_offset)
	if not space.intersect_shape(_shape_query, 1).is_empty():
		return _reject(&"blocked")
	# 6. có đường bắn tới ngực mục tiêu
	_ray.from = point + Vector3.UP * muzzle_height
	_ray.to = around + Vector3.UP * target_height
	if not space.intersect_ray(_ray).is_empty():
		return _reject(&"no_line_of_sight")
	# 7. trên màn hình (không có camera thì bỏ qua)
	if camera != null and not camera.is_position_in_frustum(point + Vector3.UP * muzzle_height):
		return _reject(&"off_screen")
	return point


func _reject(reason: StringName) -> Vector3:
	reject_counts[reason] = reject_counts.get(reason, 0) + 1
	return Vector3.INF
