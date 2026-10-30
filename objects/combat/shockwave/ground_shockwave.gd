class_name GroundShockwave
extends Node3D
## Sóng kích hình vòng lan trên mặt đất từ một điểm. Gây sát thương cho hurtbox trong vành sóng, mỗi mục tiêu đúng một lần.
## Dùng lại được cho boss / quái khác: đặt 1 instance làm con (top_level), gọi launch() mỗi lần đập. Không tạo node mới mỗi đòn.
## Hiệu năng: mục tiêu theo dõi bằng signal vào/ra của DetectArea; _physics_process và monitoring chỉ bật khi sóng đang chạy.

signal finished

## Hurtbox không có shape đọc được thì dùng bán kính này (m)
const DEFAULT_HURTBOX_RADIUS := 0.4
## Chặn speed <= 0 làm sóng không bao giờ tắt (m/s)
const MIN_SPEED := 0.01
## Tia kiểm tra tường bắn ở độ cao này so với mặt đất (m): khỏi cắt phải mặt sàn
const RAY_HEIGHT := 0.3
## Nâng vành lên khỏi mặt đất để khỏi z-fight (m)
const RING_LIFT := 0.03
## DetectArea rộng hơn vành va chạm một đoạn để chắc chắn bắt được mục tiêu sắp tới (m)
const DETECT_MARGIN := 0.5
## Phần dư của plane vẽ vành so với đường kính tối đa (m)
const RING_PADDING := 0.2
const MAX_INITIAL_TARGETS := 32

var _data: ShockwaveData
var _source: Node
var _origin: Vector3
var _radius: float = 0.0
var _prev_radius: float = 0.0
var _half_band: float = 0.0
## Bán kính tâm vành khi sóng tắt: mép ngoài vành dừng đúng ở max_radius
var _end_radius: float = 0.0
var _active: bool = false
## Mục tiêu đang chờ vành tới
var _pending: Array[HurtboxComponent] = []
## Mục tiêu đã xử lý trong lần phóng này (trúng hoặc bị bất tử chặn): không xét lại
var _resolved: Array[HurtboxComponent] = []
var _hurt_radius: Dictionary[HurtboxComponent, float] = {}
# Cache để không cấp phát mỗi lần quét
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

@onready var _ring: MeshInstance3D = $Ring
@onready var _dust: GPUParticles3D = $Dust
@onready var _detect: Area3D = $DetectArea
@onready var _detect_shape: CollisionShape3D = $DetectArea/CollisionShape3D
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial


func _ready() -> void:
	set_physics_process(false)
	_ring.visible = false
	_detect.monitoring = false
	_detect.monitorable = false
	_detect.area_entered.connect(_on_area_entered)
	_detect.area_exited.connect(_on_area_exited)
	_ray.collide_with_areas = false
	_shape_query.collide_with_areas = true
	_shape_query.collide_with_bodies = false


func is_active() -> bool:
	return _active


## origin: điểm chạm đất làm tâm sóng; source: quái gây sát thương (có thể đã bị xoá sau đó)
func launch(origin: Vector3, data: ShockwaveData, source: Node) -> void:
	assert(data != null, "GroundShockwave.launch cần ShockwaveData")
	_clear_targets()
	_data = data
	_source = source
	_origin = origin
	global_position = origin
	_prev_radius = data.start_radius
	_radius = data.start_radius
	_half_band = maxf(data.band_width, 0.0) * 0.5
	_end_radius = maxf(data.start_radius, data.max_radius - _half_band)
	_configure_detect_area()
	_configure_ring()
	_active = true
	_detect.set_deferred(&"monitoring", true)
	_collect_initial_targets()
	_dust.restart()
	set_physics_process(true)


func stop() -> void:
	set_physics_process(false)
	_ring.visible = false
	_detect.set_deferred(&"monitoring", false)
	_clear_targets()
	if _active:
		_active = false
		finished.emit()


func _physics_process(delta: float) -> void:
	_prev_radius = _radius
	_radius += maxf(_data.speed, MIN_SPEED) * delta
	_ring_material.set_shader_parameter(&"radius", _radius)
	# Duyệt ngược để gỡ phần tử ngay trong vòng lặp, không cấp phát mảng phụ
	for i in range(_pending.size() - 1, -1, -1):
		var hurtbox := _pending[i]
		if not is_instance_valid(hurtbox):
			_pending.remove_at(i)
			continue
		if _try_hit(hurtbox, _hurt_radius.get(hurtbox, DEFAULT_HURTBOX_RADIUS)):
			_pending.remove_at(i)
			_resolved.append(hurtbox)
	if _radius >= _end_radius:
		stop()


func _configure_detect_area() -> void:
	var cylinder := _detect_shape.shape as CylinderShape3D
	cylinder.radius = _data.max_radius + _half_band + DETECT_MARGIN
	# Phủ từ (đáy - hit_height_below) tới hit_height, có chừa lề để hurtbox cao 1.8 m chạm được
	cylinder.height = _data.hit_height + _data.hit_height_below + DETECT_MARGIN * 2.0
	_detect_shape.position.y = (_data.hit_height - _data.hit_height_below) * 0.5


func _configure_ring() -> void:
	var size := 2.0 * maxf(_data.max_radius, _end_radius + _half_band) + RING_PADDING
	_ring.scale = Vector3(size, 1.0, size)
	_ring.position.y = RING_LIFT
	_ring_material.set_shader_parameter(&"plane_size", size)
	_ring_material.set_shader_parameter(&"band_width", _data.band_width)
	_ring_material.set_shader_parameter(&"max_radius", _end_radius)
	_ring_material.set_shader_parameter(&"radius", _radius)
	_ring.visible = true


## monitoring bật trễ một nhịp nên quét một lần lúc phóng để không sót mục tiêu đang đứng sẵn gần tâm
func _collect_initial_targets() -> void:
	_shape_query.shape = _detect_shape.shape
	_shape_query.transform = _detect_shape.global_transform
	_shape_query.collision_mask = _detect.collision_mask
	for hit in get_world_3d().direct_space_state.intersect_shape(_shape_query, MAX_INITIAL_TARGETS):
		var hurtbox := hit["collider"] as HurtboxComponent
		if hurtbox:
			_track(hurtbox)


func _track(hurtbox: HurtboxComponent) -> void:
	if hurtbox in _resolved or hurtbox in _pending:
		return
	_hurt_radius[hurtbox] = _read_hurtbox_radius(hurtbox)
	_pending.append(hurtbox)


## true = đã xử lý xong mục tiêu này (trúng hoặc bị bất tử chặn)
func _try_hit(hurtbox: HurtboxComponent, hurt_radius: float) -> bool:
	var offset := hurtbox.global_position - _origin
	# Hurtbox đặt ở chân nhân vật nên y chính là độ cao chân so với mặt đất nơi đập
	if offset.y > _data.hit_height or offset.y < -_data.hit_height_below:
		return false
	offset.y = 0.0
	var distance := offset.length()
	# Kiểm tra cả đoạn vành quét qua trong frame này: sóng nhanh / vành mỏng cũng không lọt
	if distance < _prev_radius - _half_band - hurt_radius or distance > _radius + _half_band + hurt_radius:
		return false
	if _data.blocked_by_world and _is_blocked_by_world(hurtbox.global_position):
		return false
	var direction := offset.normalized() if not offset.is_zero_approx() else Vector3.FORWARD
	var source: Node = _source if is_instance_valid(_source) else null
	var info := DamageInfo.new(_data.damage, _data.damage_type, direction * _data.knockback, source)
	info.ignores_invincibility = _data.ignore_invincibility
	hurtbox.receive_hit(info)
	return true


func _is_blocked_by_world(target_position: Vector3) -> bool:
	_ray.from = _origin + Vector3.UP * RAY_HEIGHT
	_ray.to = target_position + Vector3.UP * RAY_HEIGHT
	_ray.collision_mask = _data.world_mask
	return not get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _read_hurtbox_radius(hurtbox: HurtboxComponent) -> float:
	for child in hurtbox.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		var shape := shape_node.shape
		if shape is CapsuleShape3D:
			return (shape as CapsuleShape3D).radius
		if shape is SphereShape3D:
			return (shape as SphereShape3D).radius
		if shape is CylinderShape3D:
			return (shape as CylinderShape3D).radius
		if shape is BoxShape3D:
			var size := (shape as BoxShape3D).size
			return maxf(size.x, size.z) * 0.5
	return DEFAULT_HURTBOX_RADIUS


func _clear_targets() -> void:
	_pending.clear()
	_resolved.clear()
	_hurt_radius.clear()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox and _active:
		_track(hurtbox)


func _on_area_exited(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	_pending.erase(hurtbox)
	_hurt_radius.erase(hurtbox)
