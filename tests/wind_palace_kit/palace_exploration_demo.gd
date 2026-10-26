extends "res://tests/wind_palace_kit/palace_route_demo.gd"
## Ghép thử bộ model: nhánh thư viện, nhánh rương và vòng về qua cầu thang thứ hai.
## Dùng lại driver/đo che khuất QA; Player và các FSM gameplay giữ nguyên.

const MODELS: String = "res://assets/models/wind_palace_v1/"
const TESTS: String = "res://tests/wind_palace_kit/"
const START: Vector3 = Vector3(-1.5, 0.05, 3.2)
var _overview: Camera3D
var _chest: Node3D
var _minimum_feet_y: float = INF

func _ready() -> void:
	_build_palace()
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.position = START
	add_child(_player)
	_camera = _player.get_node("CameraRig/Camera3D") as Camera3D
	_camera.current = true
	_player_camera_review = true
	if "--verify" in OS.get_cmdline_user_args():
		_verify.call_deferred()
	elif "--capture" in OS.get_cmdline_user_args():
		_capture_only.call_deferred()

func _model(asset: String, at: Vector3, rotation_y: float = 0.0) -> Node3D:
	var model: Node3D = (load(MODELS + asset + ".glb") as PackedScene).instantiate() as Node3D
	model.position = at
	model.rotation_degrees.y = rotation_y
	add_child(model)
	return model

func _box_on(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_mask = 0
	parent.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

func _solid(asset: String, at: Vector3, size: Vector3, rotation_y: float = 0.0) -> Node3D:
	var model: Node3D = _model(asset, at, rotation_y)
	_box_on(model, size, Vector3(0.0, size.y * 0.5, 0.0))
	return model

func _floor_at(size: int, at_surface: Vector3) -> void:
	# Origin GLB mới ở đáy giữa; mặt sàn cách đáy 0.32m.
	_solid("floor_%dm" % size, at_surface - Vector3.UP * 0.32, Vector3(size, 0.32, size))

func _rail(size: int, at: Vector3, rotation_y: float = 0.0) -> void:
	_solid("balustrade_%dm" % size, at, Vector3(size, 1.12, 0.4), rotation_y)

func _low_wall(at: Vector3, rotation_y: float = 0.0) -> void:
	_solid("wall_low_4m", at, Vector3(4.0, 1.25, 0.68), rotation_y)

func _lamp(at: Vector3, energy: float = 2.0, shadows: bool = true) -> void:
	var lamp: Node3D = _place(TESTS + "palace_standing_lantern.tscn", at)
	var light: OmniLight3D = lamp.get_node("WarmLight") as OmniLight3D
	light.light_energy = energy
	light.shadow_enabled = shadows

func _foundation(at: Vector3) -> void:
	var model: Node3D = _model("lower_arch_foundation_6m", at)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = load(MODELS + "palace_lower_fog.tres") as Material

func _build_palace() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("252c36")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b3c0ce")
	world.environment.ambient_light_energy = 0.55
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)
	for x: int in [-4, 0, 4, 8, 12]:
		_floor_at(4, Vector3(x, 0.0, 4.0))
		_low_wall(Vector3(x, 0.0, 6.0))
	for z: int in [-4, 0]:
		_floor_at(4, Vector3(12.0, 0.0, z))
	_floor_at(4, Vector3(-4.0, 0.0, 0.0))
	for z: int in [-4, 0, 4]:
		_low_wall(Vector3(14.0, 0.0, z), 90.0)
	for z: int in [0, 4]:
		_low_wall(Vector3(-6.0, 0.0, z), 90.0)
	_solid("wall_straight_4m", Vector3(-4.0, 0.0, -2.5), Vector3(4.0, 4.0, 0.68))
	for x: float in [-0.5, 5.5, 11.5]:
		_place(TESTS + "palace_wall_window.tscn", Vector3(x, 0.0, -4.55))
	for x: int in [2, 6]:
		_rail(4, Vector3(x, 0.0, 2.0))
	_rail(2, Vector3(10.0, 0.0, -5.0), 90.0)
	_place(TESTS + "palace_stair_turn.tscn", Vector3.ZERO)
	_place(TESTS + "palace_gallery_entry.tscn", Vector3(4.5, 1.76, -1.2))
	var second_stair: Node3D = _place(TESTS + "palace_stair_turn.tscn", Vector3(9.0, 0.0, -0.4))
	second_stair.rotation_degrees.y = 180.0
	for z: float in [-1.2, -3.2]:
		_floor_at(2, Vector3(5.5, 2.0, z))
	for x: float in [4.5, 6.5]:
		_rail(4, Vector3(x, 2.0, -2.2), 90.0)
	_rail(2, Vector3(5.5, 2.0, -4.1))
	_chest = _place(TESTS + "palace_chest_collision.tscn", Vector3(5.5, 2.0, -3.2))
	_solid("bookcase_tall", Vector3(-4.0, 0.0, -1.5), Vector3(2.48, 3.5, 0.76))
	_solid("archive_table", Vector3(-4.7, 0.0, 0.5), Vector3(2.8, 1.13, 1.2), 90.0)
	_model("urn_small", Vector3(-5.25, 0.0, 2.2))
	_place(TESTS + "palace_wind_charger.tscn", Vector3(1.5, 0.0, 3.0))
	for x: float in [1.0, 8.0]:
		_model("banner_hanging", Vector3(x, 2.1, -3.95))
	_lamp(Vector3(-3.0, 0.0, 4.9))
	_lamp(Vector3(-5.3, 0.0, 1.3), 0.7, false)
	_lamp(Vector3(13.2, 0.0, 1.0))
	_lamp(Vector3(13.1, 0.0, -3.6))
	for x: float in [4.0, 7.0]:
		_place(TESTS + "palace_wall_lantern.tscn", Vector3(x, 2.6, -3.67))
	for x: int in [-3, 3, 11]:
		_foundation(Vector3(x, -5.34, 6.0))
	_foundation(Vector3(4.5, -3.26, 0.8))
	var safety: KillZone = (load("res://objects/kill_zone/kill_zone.tscn") as PackedScene).instantiate() as KillZone
	safety.position = Vector3(4.0, -7.0, 0.0)
	safety.size = Vector3(32.0, 2.0, 24.0)
	add_child(safety)
	_overview = Camera3D.new()
	_overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	_overview.size = 23.5
	_overview.position = Vector3(27.0, 27.0, 33.0)
	add_child(_overview)
	_overview.look_at(Vector3(4.0, -0.6, 0.0))

func _capture_overview() -> void:
	_player.get_node("HUD").hide()
	_overview.current = true
	for frame: int in range(3):
		await get_tree().process_frame
	await _capture("palace_exploration_overview.png")
	_camera.current = true
	_player.get_node("HUD").show()

func _capture_only() -> void:
	for frame: int in range(30):
		await get_tree().physics_frame
	await _capture_overview()
	await _capture("palace_exploration_start.png")
	get_tree().quit()

func _verify() -> void:
	for frame: int in range(30):
		await get_tree().physics_frame
	_check(_player.is_on_floor(), "entry settles on real floor")
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var void_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.5, 0.5, 0.0), Vector3(5.5, -0.5, 0.0), 1))
	_check(void_hit.is_empty(), "courtyard void has no invisible ground floor")
	await _capture_overview()
	await _capture("palace_exploration_start.png")
	var route: Array[Dictionary] = [
		{"name": "archive_entry", "at": Vector3(-3.2, 0.0, 2.8)},
		{"name": "archive_nook", "at": Vector3(-3.2, 0.0, -0.3), "photo": true},
		{"name": "archive_return", "at": Vector3(-3.2, 0.0, 2.8)},
		{"name": "first_stair_foot", "at": Vector3(-1.5, 0.0, 3.2)},
		{"name": "first_landing", "at": Vector3(-1.5, 1.0, -1.2)},
		{"name": "upper_entry", "at": Vector3(2.5, 2.0, -1.2), "photo": true},
		{"name": "upper_turn", "at": Vector3(2.5, 2.0, 0.8)},
		{"name": "loot_fork", "at": Vector3(5.5, 2.0, 0.8), "photo": true},
		{"name": "loot_nook", "at": Vector3(5.5, 2.0, -2.15), "photo": true, "visibility": true},
		{"name": "loot_return", "at": Vector3(5.5, 2.0, 0.8)},
		{"name": "second_landing", "at": Vector3(10.5, 1.0, 0.8), "photo": true},
		{"name": "second_stair_foot", "at": Vector3(10.5, 0.0, -3.6), "photo": true, "visibility": true},
		{"name": "outer_lane", "at": Vector3(12.0, 0.0, -3.6)},
		{"name": "front_return", "at": Vector3(12.0, 0.0, 4.0)},
		{"name": "entry_lane", "at": Vector3(-1.5, 0.0, 4.0)},
		{"name": "closed_loop", "at": Vector3(-1.5, 0.0, 3.2), "photo": true}
	]
	for step: Dictionary in route:
		var target: Vector3 = step.at
		var reached: bool = await _walk_to(target)
		_check(reached, str(step.name) + " reached by walking")
		_check(absf(_player.position.y - target.y) < 0.12, str(step.name) + " feet match surface")
		print("EXPLORATION_POSITION ", step.name, " ", _player.position)
		if not reached:
			await _capture("palace_exploration_blocked_" + str(step.name) + ".png")
			break
		if step.get("photo", false):
			await _capture("palace_exploration_" + str(step.name) + ".png")
		if step.get("visibility", false):
			await _review_occlusion(str(step.name), "palace_exploration_visibility")
		if step.name == "loot_nook":
			_check(_player.global_position.distance_to(_chest.global_position) < 1.5, "chest visual is reachable in optional branch")
	_check(not _failed and Vector2(_player.position.x - START.x, _player.position.z - START.z).length() < 0.2, "returns to entry via second staircase and lower lane")
	_release_input()
	var file: FileAccess = FileAccess.open(OUTPUT + "exploration_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not _failed, "checks": _checks, "camera_reviews": _camera_reviews, "minimum_observed_feet_y": _minimum_feet_y, "end_position": var_to_str(_player.position)}, "\t"))
	file.close()
	print("PALACE_EXPLORATION ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)

func _walk_to(target: Vector3) -> bool:
	var reached: bool = false
	for frame: int in range(600):
		_minimum_feet_y = minf(_minimum_feet_y, _player.position.y)
		if _player.position.y < -0.25:
			break
		var delta: Vector3 = target - _player.global_position
		delta.y = 0.0
		if delta.length() < 0.12:
			reached = true
			break
		_drive_input(delta)
		await get_tree().physics_frame
	_release_input()
	for frame: int in range(15):
		await get_tree().physics_frame
	return reached
