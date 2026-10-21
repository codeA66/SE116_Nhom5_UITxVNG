extends Node
## Kiểm tra đường đi và lưu map mới có thể mở trực tiếp trong editor.

const MAP: PackedScene = preload("res://tests/wind_map/wind_ruins_concept_map.tscn")
const MAP_SCRIPT: Script = preload("res://tests/wind_map/wind_ruins_concept_map.gd")
var _failed: bool = false
var _map: MAP_SCRIPT


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--built" in args:
		_map = (load("res://tests/wind_map/wind_ruins_concept_map_built.tscn") as PackedScene).instantiate() as MAP_SCRIPT
		_check(_map.has_node("RuinsWorld"), "built scene contains saved map geometry before ready")
		var wind_vfx: Node = _map.get_node("RuinsWorld/WindWellUpdraft/WindZoneVfx")
		_check(wind_vfx.scene_file_path.is_empty(), "saved wind VFX is flattened without a nested scene instance")
		_check(wind_vfx.get_child_count() == 5, "wind VFX contains exactly one set of five child nodes")
	else:
		_map = MAP.instantiate() as MAP_SCRIPT
	add_child(_map)
	await _frames(5)
	var player: Player = _map.get_node("Player") as Player
	if not "--capture-only" in args:
		_check(_map.used_models.size() == 39, "all 39 model categories placed")
	_check(_map.has_node("RuinsWorld/ContainedReservoir"), "water reservoir exists")
	if "--surface-diagnose" in args:
		_map.set_overview(false)
		player.teleport(Vector3(28, 7.3, -55), Vector3.FORWARD)
		await _frames(45)
		await _capture("sanctuary_surface_before")
		var sun: DirectionalLight3D = _map.get_node("RuinsWorld/SunsetKey") as DirectionalLight3D
		sun.shadow_enabled = false
		await _capture("sanctuary_surface_no_shadow")
		for node: Node in _map.get_node("RuinsWorld").get_children():
			if node is MultiMeshInstance3D:
				var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
				print("SURFACE_MESH ", batch.multimesh.mesh.resource_name)
				if "T01_" in batch.multimesh.mesh.resource_name or "T02_" in batch.multimesh.mesh.resource_name:
					batch.visible = false
		await _capture("sanctuary_surface_no_cliffs")
		for node: Node in _map.get_node("RuinsWorld").get_children():
			if node is MultiMeshInstance3D:
				var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
				if "T03_" in batch.multimesh.mesh.resource_name:
					var positions: Dictionary = {}
					for i: int in batch.multimesh.instance_count:
						var point: Vector3 = batch.multimesh.get_instance_transform(i).origin
						positions[point] = int(positions.get(point, 0)) + 1
					print("SURFACE_FLOOR ", batch.multimesh.instance_count, " unique=", positions.size())
					batch.visible = false
		await _capture("sanctuary_surface_no_floor")
		_map.queue_free()
		await _frames(2)
		Input.set_custom_mouse_cursor(null)
		get_tree().quit()
		return
	if "--bake" in args:
		if DisplayServer.get_name() == "headless":
			push_error("Bake requires the rendering backend to save MultiMesh transform buffers. Run without --headless.")
			get_tree().quit(1)
			return
		var packed: PackedScene = PackedScene.new()
		_check(packed.pack(_map) == OK, "pack new map")
		_check(ResourceSaver.save(packed, "res://tests/wind_map/wind_ruins_concept_map_built.tscn") == OK, "save new editable map scene")
	if "--capture" in args and DisplayServer.get_name() != "headless":
		await _capture("overview")
	if "--capture-only" in args:
		_map.queue_free()
		await get_tree().process_frame
		Input.set_custom_mouse_cursor(null)
		get_tree().quit()
		return
	_map.set_overview(false)
	if "--capture" in args and DisplayServer.get_name() != "headless":
		player.teleport(Vector3(31, 3.7, -3), Vector3.FORWARD)
		await _frames(45)
		await _capture("dock_surface_fixed")
	player.teleport(Vector3(-18, 0.1, 21), Vector3.FORWARD)
	await _frames(12)
	Input.action_press(&"move_forward")
	await _frames(200)
	Input.action_release(&"move_forward")
	await _frames(8)
	print("MAP_ROUTE entry ", player.position)
	_check(player.position.y > 3.1 and player.position.z < 11.0, "entry stairs reach wind-well terrace")
	player.velocity = Vector3.ZERO
	player.teleport(Vector3(-10, 3.7, -5), Vector3.FORWARD)
	await _frames(10)
	Input.action_press(&"move_forward")
	await _frames(140)
	Input.action_release(&"move_forward")
	await _frames(8)
	print("MAP_ROUTE archive ", player.position)
	_check(player.position.y > 6.8 and player.position.z < -16.0, "archive stairs reach upper terrace")
	if "--capture" in args and DisplayServer.get_name() != "headless":
		await _capture("archive_walk")
	player.velocity = Vector3.ZERO
	player.teleport(Vector3(-2,7.3,-30), Vector3.FORWARD)
	await _frames(10)
	Input.action_press(&"move_forward")
	Input.action_press(&"move_right")
	await _frames(240)
	Input.action_release(&"move_forward")
	Input.action_release(&"move_right")
	await _frames(8)
	print("MAP_ROUTE upper_bridge ", player.position)
	_check(player.position.x > 10.0 and player.position.y > 6.8, "upper bridge reaches sanctuary terrace")
	var boat: AnimatableBody3D = _map.get_node("RuinsWorld/Sailboat") as AnimatableBody3D
	player.velocity = Vector3.ZERO
	player.teleport(boat.position + Vector3.UP * 1.1, Vector3.FORWARD)
	await _frames(45)
	_check(player.is_on_floor(), "boat deck supports fox")
	var before: float = player.position.z
	_map.depart_boat()
	await _frames(90)
	print("MAP_ROUTE boat ", player.position, " boat=", boat.position)
	_check(player.position.z < before - 1.0, "moving boat carries real character")
	if "--capture" in args and DisplayServer.get_name() != "headless":
		await _capture("reservoir_walk")
	print("WIND_CONCEPT_MAP %s used=%d" % ["FAILED" if _failed else "PASSED", _map.used_models.size()])
	_map.queue_free()
	await get_tree().process_frame
	Input.set_custom_mouse_cursor(null)
	get_tree().quit(1 if _failed else 0)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _capture(title: String) -> void:
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# Ảnh kiểm tra ghi ra user:// để không sinh file rác trong project
	DirAccess.make_dir_recursive_absolute("user://wind_map_verification")
	get_viewport().get_texture().get_image().save_png("user://wind_map_verification/%s.png" % title)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("CONCEPT_MAP: %s" % message)
