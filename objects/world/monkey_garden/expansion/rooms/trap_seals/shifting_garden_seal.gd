class_name ShiftingGardenSeal
extends Node
## Ba điểm đặt sẵn tránh vùng đất; Timer chỉ chạy khi thử thách bắt đầu.
@export var seal: GardenSwitch
@export var anchors: Array[Marker3D] = []
@export_range(1, 20, 1) var interval: int = 2
@export_range(1.0, 8.0, 0.1) var minimum_spacing: float = 3.8
@export_range(0.3, 2.0, 0.1) var obstacle_clearance: float = 1.1
var _timer: Timer
var _label: Label3D
var _remaining: int
var _index: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _neighbors: Array[GardenSwitch] = []
var _hazard_bounds: Array[AABB] = []
var _clearance_query: PhysicsShapeQueryParameters3D

func _ready() -> void:
	_rng.randomize()
	_label = Label3D.new(); _label.name = "TeleportCountdown"; _label.font_size = 56; _label.pixel_size = 0.012
	_label.outline_size = 8; _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	seal.add_child(_label); _label.position.y = 2; _label.hide()
	_timer = Timer.new(); _timer.wait_time = 1; _timer.timeout.connect(_tick); add_child(_timer)
	seal.activated.connect(stop)
	var volume: CylinderShape3D = CylinderShape3D.new()
	volume.height = 1.2; volume.radius = obstacle_clearance
	_clearance_query = PhysicsShapeQueryParameters3D.new()
	_clearance_query.shape = volume; _clearance_query.collision_mask = 1
	_clearance_query.exclude = [seal.get_rid()]
	set_process(false); set_physics_process(false)

func configure_clearance(neighbors: Array[GardenSwitch], hazards: Array[GardenTimedSpikes]) -> void:
	_neighbors = neighbors
	_hazard_bounds.clear()
	for hazard: GardenTimedSpikes in hazards:
		if not is_instance_valid(hazard): continue
		for child: Node in hazard.get_children():
			var collision: CollisionShape3D = child as CollisionShape3D
			if collision and collision.shape and not collision.disabled:
				_hazard_bounds.append((collision.global_transform * collision.shape.get_debug_mesh().get_aabb()).grow(obstacle_clearance))

func can_place_at(point: Vector3) -> bool:
	for neighbor: GardenSwitch in _neighbors:
		if is_instance_valid(neighbor) and neighbor != seal:
			var offset: Vector3 = neighbor.global_position-point; offset.y = 0
			if offset.length_squared() < minimum_spacing*minimum_spacing: return false
	for bounds: AABB in _hazard_bounds:
		if point.x > bounds.position.x and point.x < bounds.end.x and point.z > bounds.position.z and point.z < bounds.end.z: return false
	_clearance_query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*0.9)
	return seal.get_world_3d().direct_space_state.intersect_shape(_clearance_query,1).is_empty()

func begin() -> void:
	if anchors.size()<2 or seal.is_active(): return
	_remaining = maxi(interval,1); _label.text = str(_remaining); _label.show(); _timer.start()

func stop() -> void:
	_timer.stop(); _label.hide()

func set_interval_seconds(seconds: int) -> void:
	var next_interval: int = maxi(seconds,1)
	if interval == next_interval: return
	interval = next_interval
	if not is_instance_valid(_timer) or _timer.is_stopped() or seal.is_active(): return
	# Mỗi mốc tiến độ cho người chơi đủ trọn thời gian mới để tới bệ còn lại.
	_remaining = interval
	_label.text = str(_remaining)
	_timer.start()

func _tick() -> void:
	_remaining -= 1
	if _remaining<=0:
		# Duyệt hữu hạn; nếu người sửa map chặn hết điểm thì chờ lượt sau, không chồng lên bẫy/bệ khác.
		var first: int = _rng.randi_range(1,anchors.size()-1)
		for step: int in anchors.size()-1:
			var candidate: int = (_index+1+(first-1+step)%(anchors.size()-1))%anchors.size()
			if not is_instance_valid(anchors[candidate]) or not can_place_at(anchors[candidate].global_position): continue
			_index = candidate
			seal.global_position = anchors[_index].global_position
			seal.reset_physics_interpolation()
			seal.play_teleport_pop()
			break
		_remaining = maxi(interval,1)
	_label.text = str(_remaining)
