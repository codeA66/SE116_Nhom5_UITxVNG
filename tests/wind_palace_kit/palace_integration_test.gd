extends Node3D
## Kiểm tra collider và hành khách thật trên mẫu cung điện trong scene riêng.

const KIT: String = "res://assets/models/wind_palace_v1/"
const OUTPUT: String = "res://output/wind_palace/qa/"
var _failed: bool = false
var _checks: Array[Dictionary] = []
var _player: Player
var _lift: WindLift
var _charger: WindCharger
var _travel: Vector3 = Vector3.ZERO
var _camera: Camera3D

func _ready() -> void:
	_setup_lighting()
	_run.call_deferred()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_player):
		_player.velocity.x = _travel.x
		_player.velocity.z = _travel.z
		_player.velocity.y -= 25.0 * delta
		_player.move_and_slide()

func _run() -> void:
	_charger = (load("res://tests/wind_palace_kit/palace_wind_charger.tscn") as PackedScene).instantiate() as WindCharger
	_charger.position.x = 4.0
	add_child(_charger)
	_lift = (load("res://tests/wind_palace_kit/palace_wind_lift.tscn") as PackedScene).instantiate() as WindLift
	_lift.charger = _charger
	add_child(_lift)
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.position = Vector3(0.0, 2.0, 0.0)
	add_child(_player)
	_player.set_controls_enabled(false)
	_player.set_physics_process(false)
	_player.get_node("HUD").hide()
	_camera.current = true
	await _frames(90)
	_check(_player.is_on_floor(), "player settles on lower platform")
	_check(absf(_player.position.y - 0.56) < 0.04, "feet match visible lower deck top 0.56m")
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var gap: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1.43, 1.2, 0.25), Vector3(1.43, 0.4, 0.25), 1))
	_check(gap.is_empty(), "octagonal collider does not add invisible floor at cropped corner")
	_check(_lift.state_machine.current_state.name == &"Lowered", "initial FSM is Lowered")
	_check(_lift.get_node("Model").find_child("LowerStop", true, false) != null, "lower marker imported")
	_check(_lift.get_node("Model").find_child("UpperStop", true, false) != null, "upper marker imported")
	var lens: MeshInstance3D = _charger.get_node("Model").find_child("Charge_Lens_0", true, false) as MeshInstance3D
	_check(lens != null and not (lens.get_active_material(0) as BaseMaterial3D).emission_enabled, "uncharged lens does not glow")
	await _capture("palace_lift_lowered.png")
	var receiver: WindReceiverComponent = _charger.get_node("WindReceiver") as WindReceiverComponent
	receiver.push(Vector3(0.0, 0.0, 8.0))
	var reached_top: bool = false
	for frame: int in range(600):
		await get_tree().physics_frame
		if _lift.state_machine.current_state.name == &"Raised":
			reached_top = true
			break
	await _frames(3)
	_check(reached_top, "wind receiver charges real FSM and raises lift")
	_check(absf(_lift.get_platform_height() - 4.45) < 0.005, "lift reaches marker 4.45m")
	_check(_player.is_on_floor() and absf(_player.position.y - 4.56) < 0.08, "player rides to upper deck without slipping")
	var visual: Node3D = _lift.get_node("Model").find_child("Platform", true, false) as Node3D
	_check(absf(visual.global_position.y - _lift.platform.global_position.y) < 0.005, "visual Platform follows physics body")
	_check(_charger.lit_count == _charger.data.light_count, "all three charge lenses become lit")
	_check((lens.get_active_material(0) as BaseMaterial3D).emission_enabled, "charged lens actually enables cyan emission")
	await _capture("palace_lift_raised.png")
	var returned: bool = false
	for frame: int in range(1000):
		await get_tree().physics_frame
		if _lift.state_machine.current_state.name == &"Lowered":
			returned = true
			break
	await _frames(60)
	_check(returned, "natural charger discharge lowers lift")
	_check(_player.is_on_floor() and absf(_player.position.y - 0.56) < 0.08, "passenger safely lands after descending")
	_check(not (lens.get_active_material(0) as BaseMaterial3D).emission_enabled, "lens emission turns off after natural discharge")
	await _test_doorway()
	await _test_window()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file: FileAccess = FileAccess.open(OUTPUT + "integration_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not _failed, "checks": _checks}, "\t"))
	file.close()
	print("PALACE_INTEGRATION ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)

func _test_doorway() -> void:
	var at: Vector3 = Vector3(12.0, 0.0, 0.0)
	var visual: Node3D = (load("res://tests/wind_palace_kit/palace_wall_door.tscn") as PackedScene).instantiate() as Node3D
	visual.position = at
	add_child(visual)
	var floor: StaticBody3D = StaticBody3D.new()
	floor.position = at
	add_child(floor)
	_box(floor, Vector3(0.0, -0.1, 0.0), Vector3(10.0, 0.2, 10.0))
	_player.teleport(at + Vector3(0.0, 0.1, 2.0))
	_travel = Vector3(0.0, 0.0, -3.0)
	await _frames(100)
	_check(_player.position.z < -1.0, "character crosses true open doorway")
	_travel = Vector3.ZERO
	_player.teleport(at + Vector3(2.2, 0.1, 2.0))
	_travel = Vector3(0.0, 0.0, -3.0)
	await _frames(100)
	_check(_player.position.z > 0.5, "doorway side pier blocks character")
	_travel = Vector3.ZERO

func _test_window() -> void:
	var body: Node3D = (load("res://tests/wind_palace_kit/palace_wall_window.tscn") as PackedScene).instantiate() as Node3D
	body.position = Vector3(24.0, 0.0, 0.0)
	add_child(body)
	await _frames(3)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hole: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(24.0, 2.0, 2.0), Vector3(24.0, 2.0, -2.0), 1))
	var sill: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(24.0, 0.5, 2.0), Vector3(24.0, 0.5, -2.0), 1))
	_check(hole.is_empty(), "window opening is not filled by collider")
	_check(not sill.is_empty(), "window sill remains solid")

func _box(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position
	parent.add_child(collision)

func _setup_lighting() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("252c36")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b3c0ce")
	environment.environment.ambient_light_energy = 0.9
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 10.0
	_camera.position = Vector3(8.0, 9.0, 12.0)
	add_child(_camera)
	_camera.look_at(Vector3(1.5, 2.0, 0.0))
	_camera.current = true

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	get_viewport().get_texture().get_image().save_png(OUTPUT + filename)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	_checks.append({"test": label, "passed": condition})
	_failed = _failed or not condition
	print("PASS " if condition else "FAIL ", label)
