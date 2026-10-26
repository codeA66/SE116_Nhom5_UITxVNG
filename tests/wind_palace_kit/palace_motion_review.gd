extends Node3D
## Kiểm tra khớp xuất GLB bằng biến đổi phần hình, không thay gameplay hoặc save.

const KIT: String = "res://assets/models/wind_palace_v1/"
const OUTPUT: String = "res://output/wind_palace/qa/"
const PREVIEW_PLACEMENT: Script = preload("res://tests/wind_palace_kit/palace_preview_placement.gd")
var _checks: Array[Dictionary] = []
var _failed: bool = false
var _camera: Camera3D
var _models: Dictionary[String, Node3D] = {}

func _ready() -> void:
	_setup()
	_run.call_deferred()

func _run() -> void:
	var names: Array[String] = ["door_double", "treasure_chest", "lever_wind", "bridge_rotating_visual", "shortcut_grille", "wind_charger_visual"]
	for i: int in range(names.size()):
		var root: Node3D = (load(KIT + names[i] + ".glb") as PackedScene).instantiate() as Node3D
		PREVIEW_PLACEMENT.place(root, Vector3(float(i % 3 - 1) * 6.0, 0.0, float(i / 3) * 7.0 - 3.5), KIT + names[i] + ".glb")
		add_child(root)
		_models[names[i]] = root
	await _frames(3)
	await _capture("palace_motion_rest.png")
	var door: Node3D = _models["door_double"]
	var left: Node3D = _find(door, "DoorLeft")
	var right: Node3D = _find(door, "DoorRight")
	_check(left != null and right != null, "both door leaves remain separate after import")
	if left and right:
		var left_pivot: Vector3 = left.global_position
		var right_pivot: Vector3 = right.global_position
		var initial: Vector3 = _bounds(left).get_center()
		left.rotate_object_local(Vector3.UP, PI * 0.5)
		right.rotate_object_local(Vector3.UP, -PI * 0.5)
		_check(left.global_position.distance_to(left_pivot) < 0.001 and right.global_position.distance_to(right_pivot) < 0.001, "door hinge positions remain fixed while opening")
		_check(_bounds(left).get_center().distance_to(initial) > 0.7, "door leaf swings around side hinge rather than center")
		_check(_bounds(left).size.x < 0.5 and _bounds(right).size.x < 0.5, "opened leaves clear the width of the doorway")
		_check(_bounds(left).size.z < 1.6 and _bounds(right).size.z < 1.6, "metal fittings stay within each opened door leaf")
	var chest: Node3D = _models["treasure_chest"]
	var lid: Node3D = _find(chest, "Lid")
	_check(lid != null, "chest lid remains a separate mesh")
	if lid:
		var pivot: Vector3 = lid.global_position
		var center: Vector3 = _bounds(lid).get_center()
		lid.rotate_object_local(Vector3.RIGHT, deg_to_rad(-100.0))
		_check(lid.global_position.distance_to(pivot) < 0.001, "chest rear hinge stays fixed")
		_check(_bounds(lid).get_center().y > center.y + 0.2, "chest lid lifts above its closed position")
		_check(_bounds(lid).size.y > 0.8, "chest lid reaches visibly open pose")
		await _check_chest_cavity(chest)
		await _capture_detail(chest, "palace_chest_open.png", 4.0)
	var lever: Node3D = _find(_models["lever_wind"], "Handle")
	_check(lever != null, "lever handle imported separately")
	if lever:
		var pivot: Vector3 = lever.global_position
		var center: Vector3 = _bounds(lever).get_center()
		lever.rotate_object_local(Vector3.RIGHT, deg_to_rad(-40.0))
		_check(lever.global_position.distance_to(pivot) < 0.001, "lever rotates at its base pivot")
		_check(_bounds(lever).get_center().distance_to(center) > 0.15, "lever grip travels with handle")
	var bridge: Node3D = _models["bridge_rotating_visual"]
	var deck: Node3D = _find(bridge, "Deck")
	_check(deck != null, "bridge deck remains separate")
	if deck:
		var initial: AABB = _bounds(deck)
		var pivot: Vector3 = deck.global_position
		deck.rotate_object_local(Vector3.UP, PI * 0.5)
		var turned: AABB = _bounds(deck)
		_check(deck.global_position.distance_to(pivot) < 0.001, "bridge rotates at central pier")
		_check(absf(turned.size.x - initial.size.z) < 0.01 and absf(turned.size.z - initial.size.x) < 0.01, "bridge turns 90 degrees with both edge rails attached")
	var grille: Node3D = _models["shortcut_grille"]
	var panel: Node3D = _find(grille, "GatePanel")
	_check(panel != null, "shortcut grille has separate sliding panel")
	if panel:
		var before: AABB = _bounds(panel)
		var frame: Node3D = _find(grille, "shortcut_grille_Static")
		var frame_position: Vector3 = frame.global_position
		panel.position.y += 3.4
		_check(absf(_bounds(panel).position.y - before.position.y - 3.4) < 0.001, "all grille bars rise together")
		_check(frame.global_position.distance_to(frame_position) < 0.001, "grille posts remain stationary")
	var rotor: Node3D = _find(_models["wind_charger_visual"], "Rotor")
	_check(rotor != null, "wind rotor pivot imported")
	if rotor:
		var sail: Node3D = _find(rotor, "Sail")
		var pivot: Vector3 = rotor.global_position
		var before: Vector3 = _bounds(sail).get_center()
		rotor.rotate_object_local(Vector3.BACK, PI * 0.5)
		var after: Vector3 = _bounds(sail).get_center()
		_check(rotor.global_position.distance_to(pivot) < 0.001, "rotor hub remains at pivot")
		_check(after.distance_to(before) > 0.3 and absf(after.z - before.z) < 0.001, "wind sails rotate in their face plane around correct axis")
	await _capture("palace_motion_active.png")
	var file: FileAccess = FileAccess.open(OUTPUT + "motion_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not _failed, "checks": _checks}, "\t"))
	file.close()
	print("PALACE_MOTION ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)

func _find(root: Node3D, prefix: String) -> Node3D:
	for child: Node in root.get_children():
		if child is Node3D and String(child.name).begins_with(prefix):
			return child as Node3D
		if child is Node3D:
			var found: Node3D = _find(child as Node3D, prefix)
			if found:
				return found
	return null

func _check_chest_cavity(chest: Node3D) -> void:
	var body_mesh: MeshInstance3D = _find(chest, "treasure_chest_Static") as MeshInstance3D
	if body_mesh == null:
		_check(false, "chest static body imported")
		return
	# Tam giác chỉ dùng để đo phần hình trong QA; wrapper gameplay vẫn dùng collider đơn giản.
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	body.global_transform = body_mesh.global_transform
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = body_mesh.mesh.create_trimesh_shape()
	body.add_child(collision)
	for frame: int in range(3):
		await get_tree().physics_frame
	var start: Vector3 = chest.global_position + Vector3.UP * 2.0
	var end: Vector3 = chest.global_position + Vector3.UP * 0.05
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_check(not hit.is_empty() and absf((hit.get("position", Vector3.ZERO) as Vector3).y - chest.global_position.y - 0.15) < 0.02, "opened chest has a real cavity down to its inner floor")
	body.queue_free()

func _bounds(root: Node3D) -> AABB:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	var result: AABB
	var first: bool = true
	for node: Node in meshes:
		var mesh: MeshInstance3D = node as MeshInstance3D
		var local: AABB = mesh.get_aabb()
		for corner: int in range(8):
			var point: Vector3 = mesh.global_transform * local.get_endpoint(corner)
			if first:
				result = AABB(point, Vector3.ZERO)
				first = false
			else:
				result = result.expand(point)
	return result

func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	get_viewport().get_texture().get_image().save_png(OUTPUT + filename)

func _capture_detail(model: Node3D, filename: String, size: float) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args():
		return
	var pose: Transform3D = _camera.transform
	var previous_size: float = _camera.size
	var hidden: Array[Node3D] = []
	for other: Node3D in _models.values():
		if other != model and other.visible:
			other.hide()
			hidden.append(other)
	var target: Vector3 = _bounds(model).get_center()
	_camera.size = size
	_camera.position = target + Vector3(3.0, 3.0, 4.0)
	_camera.look_at(target)
	await _frames(2)
	await _capture(filename)
	_camera.transform = pose
	_camera.size = previous_size
	for other: Node3D in hidden:
		other.show()

func _check(condition: bool, label: String) -> void:
	_checks.append({"test": label, "passed": condition})
	_failed = _failed or not condition
	print("PASS " if condition else "FAIL ", label)

func _setup() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("252c36")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b3c0ce")
	world.environment.ambient_light_energy = 0.9
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 0.8
	add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 22.0
	_camera.position = Vector3(18.0, 20.0, 23.0)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.0, 0.0))
	_camera.current = true
