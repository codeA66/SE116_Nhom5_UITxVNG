extends Node3D
## Sân thử nối cầu thang và gallery. --verify dùng Input Map thật để điều khiển Player.

const OUTPUT: String = "res://output/wind_palace/qa/"
const PREVIEW_PLACEMENT: Script = preload("res://tests/wind_palace_kit/palace_preview_placement.gd")
var _player: Player
var _camera: Camera3D
var _checks: Array[Dictionary] = []
var _failed: bool = false
var _player_camera_review: bool = false
var _camera_reviews: Array[Dictionary] = []

func _ready() -> void:
	_setup_world()
	_place("res://tests/wind_palace_kit/palace_stair_turn.tscn", Vector3.ZERO)
	_place("res://tests/wind_palace_kit/palace_gallery_entry.tscn", Vector3(4.5, 1.76, -1.2))
	_place("res://tests/wind_palace_kit/palace_chest_collision.tscn", Vector3(6.3, 2.0, 0.8))
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.position = Vector3(-1.5, 0.05, 3.2)
	add_child(_player)
	_player_camera_review = "--player-camera-review" in OS.get_cmdline_user_args()
	if _player_camera_review:
		_decorate_camera_review()
		_camera = _player.get_node("CameraRig/Camera3D") as Camera3D
	_camera.current = true
	if "--verify" in OS.get_cmdline_user_args():
		_verify.call_deferred()

func _place(path: String, position: Vector3) -> Node3D:
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	PREVIEW_PLACEMENT.place(model, position, path)
	add_child(model)
	return model

func _verify() -> void:
	for frame: int in range(20):
		await get_tree().physics_frame
	_check(_player.is_on_floor(), "start settled on ground")
	await _capture("palace_route_start.png")
	if _player_camera_review:
		await _review_occlusion("start")
	var destinations: Array[Vector3] = [Vector3(-1.5, 1.0, -1.2), Vector3(2.5, 2.0, -1.2), Vector3(2.5, 2.0, 0.8), Vector3(5.2, 2.0, 0.8)]
	for index: int in range(destinations.size()):
		var target: Vector3 = destinations[index]
		var reached: bool = false
		for frame: int in range(300):
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
		_check(reached, "walk reaches waypoint %d without jumping" % (index + 1))
		_check(absf(_player.position.y - target.y) < 0.12, "waypoint %d feet match floor height" % (index + 1))
		print("ROUTE_POSITION ", index, " ", _player.position)
		if _player_camera_review:
			await _capture("palace_route_waypoint_%d.png" % (index + 1))
			await _review_occlusion("waypoint_%d" % (index + 1))
		if not reached:
			await _capture("palace_route_blocked.png")
			break
	var distance: float = Vector2(_player.position.x - 6.3, _player.position.z - 0.8).length()
	_check(distance < 1.5 and _player.position.y > 1.9, "treasure chest is reachable from ground via both flights and gallery")
	await _capture("palace_route_end.png")
	if not _failed:
		var back: Array[Vector3] = [Vector3(2.5, 2.0, 0.8), Vector3(2.5, 2.0, -1.2), Vector3(-1.5, 1.0, -1.2), Vector3(-1.5, 0.0, 3.2)]
		for index: int in range(back.size()):
			var reached: bool = false
			for frame: int in range(300):
				var delta: Vector3 = back[index] - _player.global_position
				delta.y = 0.0
				if delta.length() < 0.12:
					reached = true
					break
				_drive_input(delta)
				await get_tree().physics_frame
			_release_input()
			for frame: int in range(15):
				await get_tree().physics_frame
			_check(reached, "return route reaches waypoint %d" % (index + 1))
			_check(absf(_player.position.y - back[index].y) < 0.12, "return waypoint %d remains on correct floor" % (index + 1))
			if not reached:
				break
		_check(_player.is_on_floor() and _player.position.y < 0.12, "returns safely to ground without teleporting or jumping")
	_release_input()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var report_name: String = "route_player_camera_report.json" if _player_camera_review else "route_report.json"
	var file: FileAccess = FileAccess.open(OUTPUT + report_name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not _failed, "checks": _checks, "end_position": var_to_str(_player.position), "camera_reviews": _camera_reviews}, "\t"))
	file.close()
	print("PALACE_ROUTE ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)

func _drive_input(delta: Vector3) -> void:
	var direction: Vector3 = delta.normalized()
	var camera: Camera3D = _player.get_node("CameraRig/Camera3D") as Camera3D
	var right: Vector3 = Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	var forward: Vector3 = Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
	# Giữ tín hiệu cao hơn deadzone của Input Map khi đi gần mục tiêu.
	var strength: float = clampf(delta.length() / 0.6, 0.4, 1.0)
	var horizontal: float = right.dot(direction) * strength
	var vertical: float = forward.dot(direction) * strength
	Input.action_press("move_right", maxf(horizontal, 0.0))
	Input.action_press("move_left", maxf(-horizontal, 0.0))
	Input.action_press("move_forward", maxf(vertical, 0.0))
	Input.action_press("move_back", maxf(-vertical, 0.0))

func _release_input() -> void:
	for action: String in ["move_right", "move_left", "move_forward", "move_back"]:
		Input.action_release(action)

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if _player_camera_review:
		filename = filename.replace("palace_route_", "palace_route_player_camera_")
	get_viewport().get_texture().get_image().save_png(OUTPUT + filename)

func _review_occlusion(label: String, file_prefix: String = "palace_visibility") -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rig: Node = _player.get_node("CameraRig")
	var rig_running: bool = rig.is_physics_processing()
	rig.set_physics_process(false)
	var player_running: bool = _player.is_physics_processing()
	_player.set_physics_process(false)
	var animator: AnimationPlayer = _player.get_node("AnimationPlayer") as AnimationPlayer
	var previous_speed: float = animator.speed_scale
	animator.speed_scale = 0.0
	var marker: StandardMaterial3D = StandardMaterial3D.new()
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color = Color.MAGENTA
	var materials: Dictionary[MeshInstance3D, Material] = {}
	var hidden: Array[MeshInstance3D] = []
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if _player.is_ancestor_of(mesh):
			materials[mesh] = mesh.material_override
			mesh.material_override = marker
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var visible_image: Image = get_viewport().get_texture().get_image()
	visible_image.save_png(OUTPUT + "%s_%s_visible.png" % [file_prefix, label])
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if not _player.is_ancestor_of(mesh) and mesh.visible:
			mesh.hide()
			hidden.append(mesh)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var full_image: Image = get_viewport().get_texture().get_image()
	full_image.save_png(OUTPUT + "%s_%s_full.png" % [file_prefix, label])
	var visible_pixels: int = _count_marker(visible_image)
	var full_pixels: int = _count_marker(full_image)
	_camera_reviews.append({"pose": label, "visible_pixels": visible_pixels, "unobstructed_pixels": full_pixels, "visible_fraction": float(visible_pixels) / maxi(full_pixels, 1), "camera_fov": _camera.fov, "player_position": var_to_str(_player.position)})
	for mesh: MeshInstance3D in hidden:
		mesh.show()
	for mesh: MeshInstance3D in materials:
		mesh.material_override = materials[mesh]
	animator.speed_scale = previous_speed
	_player.set_physics_process(player_running)
	rig.set_physics_process(rig_running)
	await get_tree().process_frame
	await get_tree().process_frame

func _count_marker(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r > 0.9 and pixel.g < 0.1 and pixel.b > 0.9:
				count += 1
	return count

func _decorate_camera_review() -> void:
	for x: int in [-6, 0, 6]:
		_place("res://assets/models/wind_palace_v1/wall_window_open_6m.glb", Vector3(x, 0.0, -5.0))
	_place("res://assets/models/wind_palace_v1/banner_hanging.glb", Vector3(6.8, 0.4, -4.5))
	for point: Vector3 in [Vector3(-3.6, 0.0, -2.7), Vector3(6.8, 2.0, 0.0)]:
		_place("res://tests/wind_palace_kit/palace_standing_lantern.tscn", point)
	# Slab dày 0.24m: đặt đỉnh kết cấu dưới mặt đáy slab, tránh hai mặt trên đồng phẳng.
	var foundation: Node3D = _place("res://assets/models/wind_palace_v1/lower_arch_foundation_6m.glb", Vector3(4.5, -5.26, 6.0))
	for node: Node in foundation.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = load("res://assets/models/wind_palace_v1/palace_lower_fog.tres") as Material

func _check(condition: bool, label: String) -> void:
	_checks.append({"test": label, "passed": condition})
	_failed = _failed or not condition
	print("PASS " if condition else "FAIL ", label)

func _setup_world() -> void:
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
	for x: int in range(-1, 3):
		for z: int in range(-1, 2):
			_place("res://assets/models/wind_palace_v1/floor_4m.glb", Vector3(x * 4.0, -0.24, z * 4.0))
	var floor: StaticBody3D = StaticBody3D.new()
	add_child(floor)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(24.0, 0.2, 20.0)
	collider.shape = shape
	collider.position = Vector3(2.0, -0.1, 0.0)
	floor.add_child(collider)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 18.0
	_camera.position = Vector3(12.0, 15.0, 15.0)
	add_child(_camera)
	_camera.look_at(Vector3(1.5, 1.0, 0.0))
	_camera.current = true
