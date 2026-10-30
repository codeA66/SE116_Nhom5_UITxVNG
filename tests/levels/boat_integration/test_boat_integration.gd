extends Node3D
## Kiểm tra va chạm thật và hành khách đi cùng thuyền, không ghi tiến trình.

const BOAT: PackedScene = preload("res://objects/traversal/boat/boat.tscn")
const PLAYER: PackedScene = preload("res://entities/player/player.tscn")

var _failed: bool = false
var _player: Player
var _boat: Boat


func _ready() -> void:
	_run.call_deferred()


func _physics_process(delta: float) -> void:
	if is_instance_valid(_player):
		_player.velocity = Vector3(0.0, _player.velocity.y - 20.0 * delta, 0.0)
		_player.move_and_slide()


func _run() -> void:
	var route: Path3D = Path3D.new()
	route.curve = Curve3D.new()
	route.curve.add_point(Vector3.ZERO)
	route.curve.add_point(Vector3(0, 0, 12))
	add_child(route)
	_boat = BOAT.instantiate() as Boat
	_boat.route = route
	_boat.persistent_id = &"test_boat_integration"
	add_child(_boat)
	await _frames(5)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var deck_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 2, -1), Vector3(0, -1, -1), 1))
	_check(not deck_hit.is_empty() and absf((deck_hit.get("position", Vector3.ZERO) as Vector3).y - 0.4) < 0.03, "boong khớp mặt collider y=0.4")
	var corner: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.95, 2, 1.8), Vector3(0.95, -1, 1.8), 1))
	_check(corner.is_empty(), "không có sàn vô hình ngoài mũi thuyền")
	var mast: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1, 2, 0.62), Vector3(1, 2, 0.62), 1))
	_check(not mast.is_empty(), "cột buồm có collider")
	var visual: BoatVisual = _boat.get_node("BoatVisual") as BoatVisual
	_check(is_zero_approx(visual.deployment), "buồm cụp khi dừng")
	_boat.raise_sail()
	await _frames(40)
	_check(is_equal_approx(visual.deployment, 1.0), "buồm mở")
	_boat.lower_sail()
	await _frames(5)
	_boat.raise_sail()
	await _frames(40)
	_check(is_equal_approx(visual.deployment, 1.0), "đổi animation giữa chừng không tranh tween")
	visual.animate_deployment(0.0, 0.0)
	_check(is_zero_approx(visual.deployment), "thời gian animation bằng 0")
	_player = PLAYER.instantiate() as Player
	_player.position = Vector3(0, 2, -1)
	add_child(_player)
	_player.set_physics_process(false)
	await _frames(90)
	_check(_player.is_on_floor(), "player đáp xuống boong")
	_check(_boat.has_passenger(), "Deck nhận player")
	var start: Vector3 = _boat.position
	var relative_start: Vector3 = _player.global_position - _boat.global_position
	var receiver: WindReceiverComponent = _boat.get_node("WindReceiverComponent") as WindReceiverComponent
	receiver.push(Vector3.BACK * 10.0)
	await _frames(120)
	_check(_boat.position.z > start.z + 2.0, "gió đúng hướng làm thuyền chạy")
	_check(_player.is_on_floor() and ((_player.global_position - _boat.global_position) - relative_start).length() < 0.3, "player được chở theo boong")
	_check(is_equal_approx(visual.deployment, 1.0), "buồm mở khi Sailing")
	await _capture()
	await _frames(250)
	_check(_boat.state_machine.current_state.name == &"Arrived", "thuyền cập bến cuối")
	_check(is_zero_approx(visual.deployment), "buồm cụp khi Arrived")
	GameState.discard_pending_flags()
	print("BOAT_INTEGRATION ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.fov = 30.0
	var target: Vector3 = _boat.global_position + Vector3.UP
	camera.global_position = target + Vector3(0.46, 0.766044, -0.446).normalized() * 32.0
	camera.look_at(target)
	camera.make_current()
	var light: DirectionalLight3D = DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-50, -30, 0)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.4, 0.43, 0.46)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.5
	add_child(environment)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/boat_game_preview.png")


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	_failed = _failed or not condition
