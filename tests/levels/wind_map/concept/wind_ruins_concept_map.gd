extends Node3D
## Map mới theo ảnh concept. Chỉ xây nhánh RuinsWorld, không sửa scene gameplay cũ.

const LIBRARY: Script = preload("res://tests/levels/wind_map/model_library.gd")
const WIND_ZONE: PackedScene = preload("res://objects/wind_puzzle/wind_zone/wind_zone.tscn")
const UPDRAFT: Resource = preload("res://resources/world/wind/wind/wind_updraft.tres")

@export var start_in_overview: bool = true
@export var player_spawn: Vector3 = Vector3(-18.0, 0.1, 35.0)
@export var overview_target: Vector3 = Vector3(5.0, 3.0, -17.0)
@export var used_models: PackedStringArray = PackedStringArray()

var _library: LIBRARY
var _world: Node3D
var _batches: Array[Node3D] = []
var _overview: bool = true
var _boat: AnimatableBody3D
var _boat_tween: Tween
var _boat_north: bool = false
var _boat_busy: bool = false
var _caption: Label
var _rotors: Array[Node3D] = []
var _spawn_count: int = 0

@onready var _player: Player = $Player
@onready var _camera: Camera3D = $OverviewCamera


func _ready() -> void:
	if not has_node("RuinsWorld"):
		_library = LIBRARY.new()
		_build_map()
		_batch_repeated_models()
		_library.dispose()
		_library = null
	_world = get_node("RuinsWorld")
	_boat = _world.get_node_or_null("Sailboat") as AnimatableBody3D
	for node: Node in _world.find_children("*", "Node3D", true, false):
		if String(node.name).ends_with("_Rotor"):
			_rotors.append(node as Node3D)
	(_player.get_node("HUD") as CanvasLayer).hide()
	_player.teleport(player_spawn, Vector3.FORWARD)
	_player.play_anim(Player.ANIM_IDLE)
	(_player.get_node("AnimationPlayer") as AnimationPlayer).process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.position = overview_target + Vector3(67.0, 79.0, 93.0)
	_camera.look_at(overview_target)
	_build_ui()
	set_overview(start_in_overview)
	print("WIND_CONCEPT_MAP_READY models=", used_models.size())


func _build_map() -> void:
	_world = Node3D.new()
	_world.name = "RuinsWorld"
	add_child(_world)
	_world.owner = self
	_environment()
	_platform("EntryTerrace", Vector2(-18, 28), Vector2(24, 20), 0.0)
	_platform("WindWellIsland", Vector2(-14, -1), Vector2(36, 24), 3.6, Rect2(-24, -5, 8, 8))
	_platform("GuardianCourt", Vector2(26, -2), Vector2(24, 20), 3.6)
	_platform("ArchiveTerrace", Vector2(-10, -24), Vector2(24, 16), 7.2)
	_platform("SanctuaryTerrace", Vector2(28, -56), Vector2(36, 24), 7.2, Rect2(25.5, -52.5, 5, 8.5))
	_stairs(Vector3(-18, 0, 19), 2)
	_stairs(Vector3(-10, 3.6, -7.2), 2)
	_stairs(Vector3(28, 3.6, -43.7), 2)
	_place("L01", Vector3(-18, 0, 30), "damaged", true)
	_place("L02", Vector3(-20, 3.6, -1), "damaged", true)
	_place("L03", Vector3(-12, 7.2, -26), "damaged", true)
	# L04 đã có mặt sân riêng tại pivot. Tách khỏi lớp T03 bên dưới để tránh z-fighting.
	_place("L04", Vector3(28, 7.24, -60), "damaged", true)
	_place("L05", Vector3(26, 3.6, 0), "broken", true)
	# Cầu gãy chính nằm giữa vực; đường đi hoàn chỉnh vòng qua thư điện và hồ.
	_bridge(Vector3(6, 3.6, 1), 0.0)
	_place("I01", Vector3(14, 3.6, 1), "broken", true)
	_place("I01", Vector3(10, -3.5, 1), "broken", false, Vector3(0.35, 0.15, 1.1))
	_place("I02", Vector3(4.7, -1.8, 1), "intact", false)
	_place("I02", Vector3(15.3, -1.8, 1), "broken", false)
	var start: Vector3 = Vector3(-2, 7.2, -30)
	var direction: Vector3 = Vector3(16, 0, -17).normalized()
	var yaw: float = atan2(-direction.z, direction.x)
	for i: int in 6:
		var point: Vector3 = start + direction * (2.0 + i * 4.0)
		_bridge(point, yaw)
		if i % 2 == 0:
			_place("I02", point - Vector3.UP * 5.4, "intact", false)
	_reservoir()
	_details()
	_background_islands()
	var updraft: WindZone = WIND_ZONE.instantiate() as WindZone
	updraft.name = "WindWellUpdraft"
	updraft.scene_file_path = ""
	# Flatten cả scene con VFX: nếu giữ instance và đồng thời lưu con của nó,
	# editor sẽ tạo hai bộ Ground/Mist/Strokes/Motes/ScreenNotifier trùng tên.
	for nested: Node in updraft.find_children("*", "", true, false):
		nested.scene_file_path = ""
	updraft.data = UPDRAFT.duplicate() as WindData
	updraft.size = Vector3(6, 6, 10)
	updraft.rotation_degrees.x = -90.0
	updraft.position = Vector3(-20, 6.6, -1)
	updraft.fade_toward_end = true
	_world.add_child(updraft)
	for child: Node in _world.get_children():
		_own(child)


func _environment() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.name = "Environment"
	environment.environment = Environment.new()
	var env: Environment = environment.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.37, 0.42, 0.49)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.77, 0.84, 0.94)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.70, 0.76)
	env.fog_density = 0.0012
	_world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SunsetKey"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.85, 0.68)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	_world.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40, 150, 0)
	fill.light_color = Color(0.62, 0.73, 0.88)
	fill.light_energy = 0.3
	_world.add_child(fill)
	var clouds: MeshInstance3D = MeshInstance3D.new()
	clouds.name = "CloudSea"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(420, 420)
	clouds.mesh = plane
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/environment/sky/cloud_sea_prototype.gdshader")
	clouds.material_override = material
	clouds.position = Vector3(0, -9.0, -25)
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(clouds)
	var cloud_mesh: PlaneMesh = PlaneMesh.new()
	cloud_mesh.size = Vector2(2, 2)
	var cloud_material: ShaderMaterial = ShaderMaterial.new()
	cloud_material.shader = preload("res://assets/shaders/environment/sky/cloud_puff.gdshader")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 50116
	for i: int in 34:
		var puff: MeshInstance3D = MeshInstance3D.new()
		puff.name = "LowCloud"
		puff.mesh = cloud_mesh
		puff.material_override = cloud_material
		puff.position = Vector3(rng.randf_range(-55,60), rng.randf_range(-10,-7), rng.randf_range(-85,45))
		puff.scale = Vector3(rng.randf_range(10,20), 1, rng.randf_range(7,15))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(puff)


func _platform(title: String, center: Vector2, size: Vector2, height: float, hole: Rect2 = Rect2()) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = title + "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	_world.add_child(body)
	var left: float = center.x - size.x * 0.5
	var front: float = center.y - size.y * 0.5
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 0.3, 4)
	for x: int in int(size.x / 4.0):
		for z: int in int(size.y / 4.0):
			var point: Vector2 = Vector2(left + 2 + x * 4, front + 2 + z * 4)
			if (x == 0 or x == int(size.x/4.0)-1) and (z == 0 or z == int(size.y/4.0)-1):
				continue
			if hole.has_area() and hole.has_point(point):
				continue
			var variant: String = "sealed" if (x * 3 + z) % 13 == 0 else "intact"
			_place("T03", Vector3(point.x, height, point.y), variant, false, Vector3.ZERO, true)
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.shape = shape
			collision.position = Vector3(point.x, height - 0.15, point.y)
			body.add_child(collision)
	# Các mảng vách dùng lại T01 thay vì kéo giãn một model khổng lồ.
	var layers: int = maxi(1, int(ceil((height + 7.0) / 6.0)))
	for layer: int in layers:
		# Vách kết thúc dưới đáy tấm sàn 0.30 m, tránh hai mặt trên đồng phẳng.
		var y: float = height - 0.31 - 6.0 * (layer + 1)
		for x: int in int(size.x / 4.0):
			var px: float = left + 2 + x * 4
			if x == 0 or x == int(size.x/4.0)-1:
				continue
			var variation: float = sin(float(x * 7 + layer * 3)) * 0.55
			if not (hole.has_area() and hole.has_point(Vector2(px, front + 1))):
				_place("T01", Vector3(px, y, front + 1.4 + variation), "intact", false, Vector3(0,variation*0.1,0), true)
			_place("T01", Vector3(px, y, front + size.y - 1.4 + variation), "diagonal" if x % 4 == 0 else "intact", false, Vector3(0,-variation*0.1,0), true)
		for z: int in maxi(0, int(size.y / 4.0) - 1):
			var pz: float = front + 4 + z * 4
			_place("T01", Vector3(left + 1.4, y, pz), "intact", false, Vector3(0, PI / 2, 0), true)
			_place("T01", Vector3(left + size.x - 1.4, y, pz), "missing", false, Vector3(0, PI / 2, 0), true)
	_place("T02", Vector3(left+3, height-6.31, front+3), "broken", false, Vector3.ZERO, true)
	# Các khối đá chân vách làm silhouette thuôn, che chỗ ghép module thẳng.
	for i: int in 4:
		var rock: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.8
		mesh.bottom_radius = 2.1
		mesh.height = 8.0
		mesh.radial_segments = 5
		rock.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.16,0.18,0.18)
		material.roughness = 1.0
		rock.material_override = material
		rock.position = Vector3(left + 4 + i * (size.x-8)/3.0, height-6.0, front+size.y-0.5)
		rock.rotation.y = float(i)
		_world.add_child(rock)


func _stairs(at: Vector3, flights: int) -> void:
	for i: int in flights:
		var point: Vector3 = at + Vector3(0, i * 1.8, -i * 4.4)
		_place("T05", point, "intact", false)
		_place("T05", point + Vector3(0, 1.64, -3.6), "separate", false)
		var ramp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		ramp.points = PackedVector3Array([Vector3(-2.25,-0.15,0),Vector3(2.25,-0.15,0),Vector3(-2.25,-0.15,-3.6),Vector3(2.25,-0.15,-3.6),Vector3(-2.25,0,0),Vector3(2.25,0,0),Vector3(-2.25,1.8,-3.6),Vector3(2.25,1.8,-3.6)])
		_shape_body("StairRamp", ramp, Transform3D(Basis.IDENTITY, point))
		_box("StairLanding", Vector3(4.5, 0.2, 0.8), point + Vector3(0, 1.7, -4.0))


func _bridge(point: Vector3, yaw: float) -> void:
	_place("I01", point, "intact", false, Vector3(0, yaw, 0))
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 0.3, 4.5)
	_shape_body("BridgeFloor", shape, Transform3D(Basis(Vector3.UP, yaw), point - Vector3.UP * 0.15))
	for side: float in [-1.0, 1.0]:
		var offset: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0, 0, side * 2.13)
		_place("A05", point + offset, "intact", true, Vector3(0, yaw, 0))


func _reservoir() -> void:
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "ContainedReservoir"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(32, 30)
	water.mesh = plane
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/environment/water/reservoir_water.gdshader")
	water.material_override = material
	water.position = Vector3(28, 3.04, -28)
	_world.add_child(water)
	for i: int in 8:
		for z: float in [-43.0, -13.0]:
			_place("P02", Vector3(14 + i * 4, 0.8, z), "straight", true)
	for i: int in 7:
		for x: float in [12.0, 44.0]:
			_place("P02", Vector3(x, 0.8, -40 + i * 4), "straight", true, Vector3(0, PI/2, 0))
	_place("P02", Vector3(12, 0.8, -43), "corner", false)
	_place("I05", Vector3(28, 3.0, -13.6), "intact", true)
	_place("I05", Vector3(28, 3.0, -41.7), "intact", true)
	_box("NorthDockSupport", Vector3(8, 0.5, 4), Vector3(28, 3.35, -41.7))
	for z: float in [-13.6, -41.7]:
		for x: float in [25.4, 30.6]:
			_place("I07", Vector3(x, 3.6, z), "upright", true)
	_boat = AnimatableBody3D.new()
	_boat.name = "Sailboat"
	_boat.collision_layer = 1
	_boat.collision_mask = 0
	_boat.position = Vector3(28, 2.8, -17)
	_world.add_child(_boat)
	var boat_model: Node3D = _library.make("I06", "intact")
	if boat_model:
		_boat.add_child(boat_model)
		_record("I06")
	var deck: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.2, 0.16, 4.0)
	deck.shape = box
	deck.position.y = 0.92
	_boat.add_child(deck)
	_place("I06", Vector3(40, 2.9, -20), "capsized", false, Vector3(0, 0.4, 0))
	_place("I08", Vector3(32, 3.6, -10.0), "broken", true)
	_place("I05", Vector3(40, 3.0, -33), "collapsed", false)


func _details() -> void:
	var flags: Array[Vector3] = [Vector3(-26,0,31),Vector3(-10,0,31),Vector3(-23,0,20),Vector3(-13,0,20),Vector3(-28,3.6,2),Vector3(-11,3.6,5),Vector3(1,3.6,2),Vector3(18,3.6,5),Vector3(35,3.6,5),Vector3(-20,7.2,-23),Vector3(1,7.2,-29),Vector3(15,7.2,-56),Vector3(40,7.2,-56)]
	for i: int in flags.size():
		_place("F02" if i % 4 == 1 else "F01", flags[i], "", false, Vector3(0, 0.15, 0))
	_place("F03", Vector3(-27, 0.03, 21), "", false, Vector3(0, 0.5, 0))
	_place("F04", Vector3(-8, 0, 24), "", false)
	for point: Vector3 in [Vector3(-28,0,27),Vector3(-28,3.6,-8),Vector3(36,3.6,5),Vector3(42,7.2,-67)]:
		_place("I03", point, "damaged" if point.x > 30 else "intact", true)
	_place("I03", Vector3(38,7.2,-51), "collapsed", false)
	for point: Vector3 in [Vector3(-9,0,22),Vector3(-6,3.6,4),Vector3(18,3.6,-7)]:
		_place("I04", point, "intact", true)
	for x: float in [18,26,34]:
		_place("A01", Vector3(x,3.6,7), "broken" if x == 26 else "intact", true)
	for x: float in [18.6,23.4]:
		for z: float in [-1.4,1.4]:
			_place("A01", Vector3(x,3.6,z), "intact", true)
	_place("A02", Vector3(21,7.8,1.4), "intact", false)
	_place("A04", Vector3(21,7.8,0), "damaged", false)
	for point: Vector3 in [Vector3(-27,3.6,-8),Vector3(-6,3.6,-9),Vector3(16,3.6,7),Vector3(37,3.6,0),Vector3(15,7.2,-58),Vector3(41,7.2,-59),Vector3(18,7.2,-66),Vector3(38,7.2,-66)]:
		_place("A01", point, "broken" if int(point.x)%2==0 else "intact", true)
	for x: float in [-28,-24,-12,-8]:
		_place("A03", Vector3(x,0,37), "broken" if x == -12 else "intact", true)
	_place("T04", Vector3(2,3.6,5), "center", false)
	_place("D01", Vector3(43,-2.0,-64), "", false, Vector3(0,0.3,0))
	for point: Vector3 in [Vector3(-25,0,24),Vector3(2,3.6,-8),Vector3(33,3.6,6),Vector3(38,7.2,-52),Vector3(-20,7.2,-32)]:
		_place("D02", point, "medium", false, Vector3(0,point.x*0.13,0))
	_place("D03", Vector3(33,3.6,-1), "tipped", true)
	_place("D04", Vector3(34,3.6,-5), "rack_intact", true)
	_place("D04", Vector3(35,3.6,-2), "open_hollow", true)
	_place("D05", Vector3(17,7.2,-57), "missing", true)
	_place("P03", Vector3(-19,7.2,-25), "chipped", true)
	_place("P04", Vector3(-25,0,34), "activated", false)
	for point: Vector3 in [Vector3(-21,0,28),Vector3(-15,0,28),Vector3(-13,3.6,7),Vector3(16,3.6,3),Vector3(-7,7.2,-23),Vector3(21,7.2,-55),Vector3(35,7.2,-55)]:
		_place("P01", point, "lit", false)
	for point: Vector3 in [Vector3(-29,0,35),Vector3(-29,3.6,7),Vector3(-30,3.6,-9),Vector3(-22,7.2,-20),Vector3(2,7.2,-31),Vector3(37,3.6,7),Vector3(44,7.2,-47),Vector3(13,7.2,-70)]:
		_place("N01", point, "living" if point.x < 10 else "dry", false, Vector3(0,-0.2,0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11605
	for i: int in 36:
		var zone: int = i % 4
		var centers: Array[Vector3] = [Vector3(-27,0,25),Vector3(-29,3.6,-3),Vector3(-21,7.2,-30),Vector3(42,7.2,-62)]
		var point: Vector3 = centers[zone] + Vector3(rng.randf_range(-1.2,1.2),0,rng.randf_range(-6,6))
		_place("N02", point, "grass" if i % 3 == 0 else "lowhorizontal", false, Vector3(0,rng.randf_range(-1,1),0), true)
	_place("N03", Vector3(-29,3.6,0), "hanging", false)
	_place("N03", Vector3(-23,7.2,-30), "corner", false)


func _background_islands() -> void:
	for i: int in 9:
		var point: Vector3 = Vector3(-65 + i * 16, -17, -99 - (i % 3) * 11)
		var mountain: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.height = 26.0 + i%4*5.0
		mesh.bottom_radius = 10.0
		mesh.top_radius = 0.4
		mesh.radial_segments = 6
		mountain.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.2,0.25,0.3)
		material.roughness = 1.0
		mountain.material_override = material
		mountain.position = point
		mountain.rotation = Vector3(0.08*sin(float(i)), float(i), 0.12*cos(float(i)))
		_world.add_child(mountain)
		if i % 3 == 0:
			_place("L05", point + Vector3(0,mesh.height/2.0,0), "broken", false)


func _place(code: String, position_at: Vector3, variant: String = "intact", solid: bool = false, rotation_at: Vector3 = Vector3.ZERO, batch: bool = false) -> Node3D:
	var model: Node3D = _library.make(code, variant)
	if model == null:
		return null
	_spawn_count += 1
	model.name = "%s_%03d" % [code, _spawn_count]
	model.position = position_at
	model.rotation = rotation_at
	_world.add_child(model)
	_record(code)
	if batch:
		_batches.append(model)
	if solid:
		var meshes: Array[MeshInstance3D] = []
		LIBRARY.collect_meshes(model, meshes)
		for mesh: MeshInstance3D in meshes:
			var body: StaticBody3D = StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			mesh.add_child(body)
	return model


func _record(code: String) -> void:
	if not used_models.has(code):
		used_models.append(code)


func _shape_body(title: String, shape: Shape3D, transform_at: Transform3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = title
	body.transform = transform_at
	body.collision_layer = 1
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)


func _box(title: String, size: Vector3, point: Vector3) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_shape_body(title, shape, Transform3D(Basis.IDENTITY, point))


func _batch_repeated_models() -> void:
	var groups: Dictionary = {}
	for root: Node3D in _batches:
		var meshes: Array[MeshInstance3D] = []
		LIBRARY.collect_meshes(root, meshes)
		for mesh: MeshInstance3D in meshes:
			var material: Material = mesh.get_active_material(0)
			var key: String = "%d:%d" % [mesh.mesh.get_instance_id(), material.get_instance_id()]
			if not groups.has(key):
				groups[key] = {"mesh": mesh.mesh, "material": material, "transforms": []}
			groups[key].transforms.append(mesh.global_transform)
		root.get_parent().remove_child(root)
		root.free()
	for key: String in groups:
		var data: Dictionary = groups[key]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = data.mesh
		multimesh.instance_count = data.transforms.size()
		for i: int in data.transforms.size():
			multimesh.set_instance_transform(i, data.transforms[i])
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "TerrainBatch"
		instance.multimesh = multimesh
		instance.material_override = data.material
		_world.add_child(instance)
		_own(instance)
	_batches.clear()


func _own(node: Node) -> void:
	node.owner = self
	for child: Node in node.get_children():
		_own(child)


func set_overview(enabled: bool) -> void:
	_overview = enabled
	_player.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_INHERIT
	if enabled:
		_camera.make_current()
	else:
		(_player.get_node("CameraRig/Camera3D") as Camera3D).make_current()
	if _caption:
		_caption.text = "TAB: toàn cảnh / khám phá     WASD: đi     Space: nhảy     E: đi thuyền     R: về cổng"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			set_overview(not _overview)
		elif event.keycode == KEY_R:
			_player.velocity = Vector3.ZERO
			_player.teleport(player_spawn, Vector3.FORWARD)
		elif event.keycode == KEY_E and not _overview and _boat and _player.global_position.distance_to(_boat.global_position) < 4.8:
			depart_boat()


func depart_boat() -> void:
	if _boat_busy or _boat == null:
		return
	_boat_busy = true
	_boat_north = not _boat_north
	_boat_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_boat_tween.tween_property(_boat, "position:z", -39.0 if _boat_north else -17.0, 12.0)
	_boat_tween.finished.connect(_on_boat_arrived)


func _on_boat_arrived() -> void:
	_boat_busy = false


func _physics_process(delta: float) -> void:
	for rotor: Node3D in _rotors:
		rotor.rotate_z(delta * 0.35)
	if _player.position.y < -12.0:
		_player.velocity = Vector3.ZERO
		_player.teleport(player_spawn, Vector3.FORWARD)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MapPreviewUI"
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = "PHẾ TÍCH GIÓ  •  MAP CONCEPT MỚI"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 13)
	column.add_child(_caption)
	var button: Button = Button.new()
	button.text = "Toàn cảnh / Khám phá bằng cáo"
	button.pressed.connect(_toggle_camera)
	column.add_child(button)


func _toggle_camera() -> void:
	set_overview(not _overview)
	get_viewport().gui_release_focus()
