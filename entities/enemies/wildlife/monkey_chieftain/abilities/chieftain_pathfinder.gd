class_name ChieftainPathfinder
extends Node
## Lưới địa hình dựng một lần; chỉ tìm lại đường theo nhịp Timer khi đang truy đuổi.
@export_range(0.5, 2.0, 0.1) var cell_size: float = 1.0
@export_range(0.1, 1.0, 0.05) var repath_interval: float = 0.35
@export_range(0.05, 1.0, 0.05) var body_margin: float = 0.35
var _actor: WildEnemy
var _grid: AStarGrid2D
var _origin: Vector3
var _waypoints: PackedVector2Array = []
var _waypoint: int = 0
var _direct_clear: bool = true
var _ready_grid: bool = false
var _timer: Timer

func _ready() -> void:
	_actor = get_parent() as WildEnemy
	_timer = Timer.new(); _timer.wait_time = repath_interval
	_timer.timeout.connect(_repath); add_child(_timer)
	_actor.engaged.connect(_engaged)
	_build.call_deferred()
	set_process(false); set_physics_process(false)

func clear_attack_path() -> bool:
	return not _ready_grid or _direct_clear

func steer(direction: Vector3) -> Vector3:
	if not _ready_grid or not _actor.has_target() or _direct_clear: return direction
	while _waypoint < _waypoints.size():
		var next: Vector2 = _waypoints[_waypoint]
		var offset: Vector3 = Vector3(next.x+_origin.x-_actor.global_position.x,0,next.y+_origin.z-_actor.global_position.z)
		if offset.length_squared() > cell_size*cell_size*0.16: return offset.normalized()*maxf(direction.length(),0.65)
		_waypoint += 1
	return direction

func _engaged(_target: Node3D) -> void:
	if _ready_grid: _repath()
	_timer.start()

func _build() -> void:
	await get_tree().physics_frame
	var room: Node3D = _actor.get_parent() as Node3D
	while room and not room.has_meta("room_size_m"): room = room.get_parent() as Node3D
	if room == null: return
	var size: Vector2 = room.get_meta("room_size_m")
	_origin = room.global_position-Vector3(size.x*0.5,0,size.y*0.5)+Vector3(cell_size*0.5,0,cell_size*0.5)
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0,0,int(size.x/cell_size),int(size.y/cell_size))
	_grid.cell_size = Vector2.ONE*cell_size
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var capsule: CapsuleShape3D = (_actor.get_node("CollisionShape3D") as CollisionShape3D).shape.duplicate() as CapsuleShape3D
	capsule.radius += body_margin
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule; query.collision_mask = 1; query.exclude = [_actor.get_rid()]
	var space: PhysicsDirectSpaceState3D = _actor.get_world_3d().direct_space_state
	var pavilion_bounds: Array[AABB] = []
	for node: Node3D in room.find_children("*","Node3D",true,false):
		if not str(node.get_meta("garden_asset","")).contains("pavilion"): continue
		var bounds: AABB
		var first: bool = true
		for collision: CollisionShape3D in node.find_children("*","CollisionShape3D",true,false):
			if collision.disabled or collision.shape == null: continue
			var part: AABB = collision.global_transform*collision.shape.get_debug_mesh().get_aabb()
			bounds = part if first else bounds.merge(part); first = false
		if not first: pavilion_bounds.append(bounds.grow(capsule.radius))
	for x: int in _grid.region.size.x:
		for z: int in _grid.region.size.y:
			var at: Vector3 = _origin+Vector3(x*cell_size,0,z*cell_size)
			var blocked: bool = false
			for bounds: AABB in pavilion_bounds:
				if at.x>bounds.position.x and at.x<bounds.end.x and at.z>bounds.position.z and at.z<bounds.end.z: blocked = true; break
			if not blocked:
				query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(capsule.height*0.5+0.08))
				blocked = not space.intersect_shape(query,1).is_empty()
			_grid.set_point_solid(Vector2i(x,z),blocked)
	_ready_grid = true
	if _actor.has_target(): _engaged(_actor.target)

func _cell(at: Vector3) -> Vector2i:
	return Vector2i(roundi((at.x-_origin.x)/cell_size),roundi((at.z-_origin.z)/cell_size)).clamp(_grid.region.position,_grid.region.end-Vector2i.ONE)

func _open_cell(at: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(at): return at
	for radius: int in range(1,9):
		var best: Vector2i = at
		var distance: int = 100000
		for x: int in range(-radius,radius+1):
			for z: int in range(-radius,radius+1):
				if absi(x)!=radius and absi(z)!=radius: continue
				var point: Vector2i = at+Vector2i(x,z)
				if _grid.is_in_boundsv(point) and not _grid.is_point_solid(point) and x*x+z*z<distance:
					best = point; distance = x*x+z*z
		if best != at: return best
	return at

func _repath() -> void:
	if not _actor.has_target() or _actor.is_dead(): _timer.stop(); return
	if not _ready_grid: return
	var start: Vector2i = _cell(_actor.global_position)
	var goal: Vector2i = _cell(_actor.target.global_position)
	var steps: int = maxi(absi(goal.x-start.x),absi(goal.y-start.y))*2+1
	_direct_clear = true
	for step: int in steps+1:
		var point: Vector2i = Vector2i(Vector2(start).lerp(Vector2(goal),float(step)/steps).round())
		if _grid.is_point_solid(point): _direct_clear = false; break
	_waypoints = PackedVector2Array(); _waypoint = 0
	if _direct_clear: return
	start = _open_cell(start); goal = _open_cell(goal)
	if _grid.is_point_solid(start) or _grid.is_point_solid(goal): return
	_waypoints = _grid.get_point_path(start,goal,true)
