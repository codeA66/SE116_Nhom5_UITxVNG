extends Node3D
## Scene duyệt bộ model cung điện Gió; không đọc hoặc thay tiến trình gameplay.

const MODEL_DIR: String = "res://assets/models/wind_palace_v1/"
const OUTPUT_DIR: String = "res://output/wind_palace/qa/"
const PREVIEW_PLACEMENT: Script = preload("res://tests/wind_palace_kit/palace_preview_placement.gd")
var _camera: Camera3D
var _page: int = 0
var _assets: Array[Dictionary] = []
var _display: Node3D
var _environment: Environment
var _lower_tiers: Array[Node3D] = []

func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MODEL_DIR + "manifest.json"))
	for entry: Dictionary in manifest.assets:
		_assets.append(entry)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("252c36")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b3c0ce")
	world.environment.ambient_light_energy = 0.9
	_environment = world.environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_color = Color.WHITE
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 24.0
	_camera.position = Vector3(23.0, 23.0, 28.0)
	add_child(_camera)
	_camera.look_at(Vector3(6.0, 1.0, 7.0))
	_camera.current = true
	if "--exploration" in OS.get_cmdline_user_args() or "--fog-review" in OS.get_cmdline_user_args():
		_show_exploration()
	elif "--room" in OS.get_cmdline_user_args():
		_show_room()
	else:
		_show_page(0)
	if "--lower-fog" in OS.get_cmdline_user_args():
		for part: Node3D in _lower_tiers:
			_apply_lower_fog(part, part.has_meta(&"lower_floor"))
	if "--capture" in OS.get_cmdline_user_args():
		_capture_all.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_show_page((_page + 1) % _page_count())
	elif event.is_action_pressed("ui_left"):
		_show_page((_page + _page_count() - 1) % _page_count())

func _page_count() -> int:
	return ceili(float(_assets.size()) / 9.0)

func _show_page(index: int) -> void:
	_page = index
	if is_instance_valid(_display):
		remove_child(_display)
		_display.queue_free()
	_display = Node3D.new()
	add_child(_display)
	for i: int in range(index * 9, mini(index * 9 + 9, _assets.size())):
		var entry: Dictionary = _assets[i]
		var packed: PackedScene = load(MODEL_DIR + str(entry.name) + ".glb") as PackedScene
		if packed == null:
			push_error("Missing model: " + str(entry.name))
			continue
		var model: Node3D = packed.instantiate() as Node3D
		model.position = Vector3(float((i % 9) % 3) * 6.0, 0.0, float((i % 9) / 3) * 7.0)
		_display.add_child(model)
		var label: Label3D = Label3D.new()
		label.text = str(entry.name)
		label.position = model.position + Vector3(0.0, -0.15, 2.6)
		label.font_size = 30
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_display.add_child(label)
		_audit_materials(model, str(entry.name))
	print("WIND_PALACE_PAGE ", index + 1, " loaded")

func _audit_materials(node: Node, asset_name: String) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				push_error(asset_name + ": material absent")
			elif material.resource_name.begins_with("WindPalace_VertexColor") and not material.vertex_color_use_as_albedo:
				push_error(asset_name + ": vertex colors not enabled")
	for child: Node in node.get_children():
		_audit_materials(child, asset_name)

func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if "--fog-review" in OS.get_cmdline_user_args():
		await _capture_fog_review()
		return
	if "--room" in OS.get_cmdline_user_args() or "--exploration" in OS.get_cmdline_user_args():
		for frame: int in range(20):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var filename: String = "godot_exploration.png" if "--exploration" in OS.get_cmdline_user_args() else "godot_room.png"
		get_viewport().get_texture().get_image().save_png(OUTPUT_DIR + filename)
		print("WIND_PALACE_ROOM_CAPTURE_DONE")
		get_tree().quit()
		return
	for index: int in range(_page_count()):
		_show_page(index)
		for frame: int in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = OUTPUT_DIR + "godot_catalog_%d.png" % (index + 1)
		var result: Error = get_viewport().get_texture().get_image().save_png(path)
		print("WIND_PALACE_CAPTURE ", path, " error=", result)
	print("WIND_PALACE_CAPTURE_DONE assets=", _assets.size())
	get_tree().quit()

func _capture_fog_review() -> void:
	_environment.fog_enabled = false
	for frame: int in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before: Image = get_viewport().get_texture().get_image()
	before.save_png(OUTPUT_DIR + "palace_fog_off.png")
	if "--native-fog" in OS.get_cmdline_user_args():
		_environment.fog_light_color = Color("252c36")
		_environment.fog_light_energy = 1.0
		_environment.fog_sun_scatter = 0.0
		_environment.fog_density = 0.04
		_environment.fog_height = -1.8
		_environment.fog_height_density = 0.6
		_environment.fog_enabled = true
	else:
		for part: Node3D in _lower_tiers:
			_apply_lower_fog(part, part.has_meta(&"lower_floor"))
	for frame: int in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after: Image = get_viewport().get_texture().get_image()
	after.save_png(OUTPUT_DIR + "palace_fog_on.png")
	var samples: Array[Dictionary] = []
	var points: Array[Vector3] = [Vector3(-8.4, -4.5, 10.4), Vector3(2.4, -4.5, 10.4), Vector3(8.4, -4.5, 10.4), Vector3(-1.5, 0.24, 7.5), Vector3(3.0, 0.24, 5.0)]
	for i: int in range(points.size()):
		var pixel: Vector2i = Vector2i(_camera.unproject_position(points[i]))
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= before.get_width() or pixel.y >= before.get_height():
			continue
		var color_before: Color = before.get_pixelv(pixel)
		var color_after: Color = after.get_pixelv(pixel)
		samples.append({"region": "lower" if i < 3 else "playable_floor", "pixel": var_to_str(pixel), "before": color_before.to_html(false), "after": color_after.to_html(false)})
	var report: FileAccess = FileAccess.open(OUTPUT_DIR + "fog_review_report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "native_fog": _environment.fog_enabled, "samples": samples}, "\t"))
	report.close()
	print("PALACE_FOG_AB_CAPTURED renderer=", RenderingServer.get_current_rendering_method(), " native=", _environment.fog_enabled)
	get_tree().quit()

func _place(model_name: String, position: Vector3, rotation_y: float = 0.0) -> Node3D:
	var packed: PackedScene = load(MODEL_DIR + model_name + ".glb") as PackedScene
	var model: Node3D = packed.instantiate() as Node3D
	PREVIEW_PLACEMENT.place(model, position, MODEL_DIR + model_name + ".glb", rotation_y)
	add_child(model)
	return model

func _show_room() -> void:
	_camera.size = 24.0
	_camera.position = Vector3(19.0, 23.0, 27.0)
	_camera.look_at(Vector3(0.0, 1.0, 0.0))
	for x: int in range(-2, 3):
		for z: int in range(-1, 3):
			if x == 0 and z == 0:
				continue
			_place("floor_4m", Vector3(x * 4.0, 0.0, z * 4.0))
	_place("bridge_rotating_visual", Vector3(0.0, -0.7, 0.0))
	for x: int in [-8, -4, 4, 8]:
		_place("wall_straight_4m", Vector3(x, 0.0, -6.0))
	_place("arch_doorway_3m", Vector3(0.0, 0.0, -6.0))
	_place("door_double", Vector3(0.0, 0.0, -6.0))
	for z: int in [-4, 0, 4, 8]:
		_place("wall_straight_4m", Vector3(-10.0, 0.0, z), 90.0)
	for x: int in [-8, -4, 4, 8]:
		_place("wall_low_4m", Vector3(x, 0.0, 10.0))
	for pos: Vector3 in [Vector3(-5.8, 0.0, -4.5), Vector3(5.8, 0.0, -4.5)]:
		_place("pillar_square_4m", pos)
		_place("banner_hanging", pos + Vector3(0.0, 0.6, 0.38))
	_place("stair_straight_3m", Vector3(7.5, 0.0, 3.0))
	_place("balcony_4m", Vector3(7.5, 2.0, -0.1), 180.0)
	_place("treasure_chest", Vector3(7.5, 2.25, -0.3))
	_place("wind_charger_visual", Vector3(-3.2, 0.24, 1.5))
	_place("boulder_socket_visual", Vector3(-6.0, 0.24, 4.0))
	_place("wind_boulder_visual", Vector3(-6.0, 0.24, 7.0))
	_place("bookcase_tall", Vector3(-7.5, 0.24, -5.5))
	_place("archive_table", Vector3(-7.2, 0.24, -2.6))
	_place("cloth_runner_4m", Vector3(0.0, 0.25, 7.5))
	for x: int in [-2, 2]:
		_place("standing_lantern", Vector3(x, 0.24, -4.8))
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = Vector3(x, 2.3, -4.8)
		lamp.light_color = Color("F2B45A")
		lamp.light_energy = 0.8
		lamp.omni_range = 4.0
		add_child(lamp)
	var fox: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	fox.position = Vector3(1.0, 0.24, 7.0)
	fox.rotation_degrees.y = 180.0
	add_child(fox)
	fox.set_controls_enabled(false)
	fox.set_physics_process(false)
	fox.get_node("HUD").hide()
	_camera.current = true
	print("WIND_PALACE_ROOM_READY")

func _show_exploration() -> void:
	_camera.size = 29.0
	_camera.position = Vector3(22.0, 26.0, 31.0)
	_camera.look_at(Vector3(0.0, 0.2, 0.0))
	for x: int in range(-2, 3):
		for z: int in range(-1, 3):
			if x == 0 and z == 0:
				continue
			_place("floor_4m", Vector3(x * 4.0, 0.0, z * 4.0))
	_place("bridge_rotating_visual", Vector3(0.0, -0.7, 0.0))
	for x: int in [-6, 0, 6]:
		_lower_tiers.append(_place("lower_arch_foundation_6m", Vector3(x, -5.0, 9.9)))
	for x: int in [-7, 7]:
		var lower: Node3D = _place("floor_4m", Vector3(x, -4.0, 7.0))
		_dim_lower_tier(lower)
		lower.set_meta(&"lower_floor", true)
		_lower_tiers.append(lower)
	_place("wall_window_open_6m", Vector3(-6.0, 0.0, -6.0))
	_place("wall_door_open_6m", Vector3(0.0, 0.0, -6.0))
	_place("wall_window_open_6m", Vector3(6.0, 0.0, -6.0))
	_place("door_double", Vector3(0.0, 0.0, -6.0))
	for z: int in [-3, 3, 9]:
		_place("wall_window_open_6m", Vector3(-10.0, 0.0, z), 90.0)
	_place("stair_turn_landing", Vector3(6.0, 0.24, 5.0))
	_place("upper_gallery_l_6m", Vector3(6.0, 2.24, -1.0), 180.0)
	_place("treasure_chest", Vector3(6.5, 2.48, -3.0))
	_place("wind_lift_palace_visual", Vector3(-6.0, 0.24, 4.0))
	_place("wind_charger_visual", Vector3(-3.3, 0.24, 4.0))
	_place("bookcase_tall", Vector3(-7.0, 0.24, -5.4))
	_place("archive_table", Vector3(-6.8, 0.24, -2.5))
	_place("shortcut_grille", Vector3(-4.0, 0.24, 0.4), 90.0)
	_place("wind_vent_wall", Vector3(9.8, 0.24, 1.0), 90.0)
	_place("balustrade_corner_2m", Vector3(2.0, 0.24, 1.8), 180.0)
	_place("cloth_runner_4m", Vector3(0.0, 0.25, 7.5))
	for pos: Vector3 in [Vector3(-2.5, 0.24, -5.0), Vector3(2.5, 0.24, -5.0), Vector3(6.5, 2.48, -1.8)]:
		_place("standing_lantern", pos)
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = pos + Vector3.UP * 2.2
		lamp.light_color = Color("F2B45A")
		lamp.light_energy = 0.8
		lamp.omni_range = 4.0
		add_child(lamp)
	for pos: Vector3 in [Vector3(-3.2, 0.0, -5.4), Vector3(3.2, 0.0, -5.4)]:
		_place("pillar_square_4m", pos)
		_place("banner_hanging", pos + Vector3(0.0, 0.6, 0.4))
	var fox: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	fox.position = Vector3(0.6, 0.24, 6.0)
	add_child(fox)
	fox.set_controls_enabled(false)
	fox.set_physics_process(false)
	fox.get_node("HUD").hide()
	_camera.current = true
	print("WIND_PALACE_EXPLORATION_READY visual_only")

func _dim_lower_tier(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		var material: StandardMaterial3D = load("res://assets/models/wind_palace_v1/palace_vertex_color.tres").duplicate() as StandardMaterial3D
		material.albedo_color = Color(0.42, 0.48, 0.58)
		mesh.material_override = material
	for child: Node in node.get_children():
		_dim_lower_tier(child)

func _apply_lower_fog(node: Node, is_floor: bool) -> void:
	if node is MeshInstance3D:
		var path: String = "res://assets/models/wind_palace_v1/palace_lower_floor_fog.tres" if is_floor else "res://assets/models/wind_palace_v1/palace_lower_fog.tres"
		(node as MeshInstance3D).material_override = load(path) as Material
	for child: Node in node.get_children():
		_apply_lower_fog(child, is_floor)
