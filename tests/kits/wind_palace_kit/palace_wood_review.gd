extends Node3D
## Duyệt gỗ trên sàn sáng ở camera game; hai mức sáng chỉ thuộc scene QA.

const KIT: String = "res://assets/models/map_wind/wind_palace_v1/"
const OUTPUT: String = "res://output/wind_palace/qa/"
const PREVIEW_PLACEMENT: Script = preload("res://tests/kits/wind_palace_kit/palace_preview_placement.gd")
var _environment: Environment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _player: Player
var _props: Dictionary[String, Node3D] = {}

func _ready() -> void:
	_setup()
	if "--capture" in OS.get_cmdline_user_args():
		_review.call_deferred()

func _setup() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("252c36")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b3c0ce")
	_environment.ambient_light_energy = 0.9
	world.environment = _environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	_sun.light_energy = 0.8
	_sun.shadow_enabled = true
	add_child(_sun)
	for x: int in range(-2, 2):
		for z: int in range(-1, 2):
			_place("floor_4m", Vector3(x * 4.0 + 2.0, -0.24, z * 4.0))
	for x: int in [-6, 0, 6]:
		_place("wall_door_open_6m" if x == 0 else "wall_window_open_6m", Vector3(x, 0.0, -6.0))
	_props["door"] = _place("door_double", Vector3(0.0, 0.0, -6.0))
	_props["bookcase"] = _place("bookcase_tall", Vector3(-5.2, 0.0, -5.4))
	_props["table"] = _place("archive_table", Vector3(-5.0, 0.0, -1.5))
	_props["bench"] = _place("bench_2m", Vector3(-5.0, 0.0, 0.2))
	_props["chest"] = _place("treasure_chest", Vector3(5.0, 0.0, -3.0))
	_props["banner"] = _place("banner_hanging", Vector3(3.3, 0.5, -5.55))
	_place("wind_charger_visual", Vector3(4.0, 0.0, 1.2))
	for position: Vector3 in [Vector3(-2.5, 0.0, -4.5), Vector3(5.0, 0.0, -4.8), Vector3(-6.8, 0.0, -1.8)]:
		var fixture: Node3D = (load("res://tests/kits/wind_palace_kit/palace_standing_lantern.tscn") as PackedScene).instantiate() as Node3D
		fixture.position = position
		add_child(fixture)
	_player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_player.position = Vector3(0.0, 0.0, 2.0)
	add_child(_player)
	_player.set_controls_enabled(false)
	_player.set_physics_process(false)
	_player.get_node("HUD").hide()
	_player.get_node("CameraRig").set_process(false)
	var source: Camera3D = _player.get_node("CameraRig/Camera3D") as Camera3D
	_camera = Camera3D.new()
	_camera.fov = source.fov
	_camera.transform = source.transform
	add_child(_camera)
	_camera.current = true

func _place(model: String, position: Vector3) -> Node3D:
	var result: Node3D = (load(KIT + model + ".glb") as PackedScene).instantiate() as Node3D
	PREVIEW_PLACEMENT.place(result, position, KIT + model + ".glb")
	add_child(result)
	return result

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var tag: String = "after" if "--after" in OS.get_cmdline_user_args() else "before"
	var report: Dictionary = {"renderer": RenderingServer.get_current_rendering_method(), "camera_fov": _camera.fov, "source_camera": "entities/player/player.tscn", "poses": []}
	for mood: String in ["day", "lamplit"]:
		_environment.ambient_light_energy = 0.9 if mood == "day" else 0.32
		_sun.light_energy = 0.8 if mood == "day" else 0.2
		for frame: int in range(20):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = get_viewport().get_texture().get_image()
		screenshot.save_png(OUTPUT + "palace_wood_%s_%s.png" % [tag, mood])
		var samples: Dictionary = {}
		for point: Vector3 in [Vector3(-4.0, 0.02, -1.5), Vector3(0.0, 0.02, 3.0), Vector3(5.0, 0.02, 2.8)]:
			var screen: Vector2 = _camera.unproject_position(point)
			var x: int = clampi(roundi(screen.x), 0, screenshot.get_width() - 1)
			var y: int = clampi(roundi(screen.y), 0, screenshot.get_height() - 1)
			samples[var_to_str(point)] = screenshot.get_pixel(x, y).to_html(false)
		var feet: Vector2 = _camera.unproject_position(_player.position)
		var head: Vector2 = _camera.unproject_position(_player.position + Vector3.UP * 1.8)
		(report.poses as Array).append({"mood": mood, "visible_surface_samples": samples, "capsule_screen_height_fraction": absf(head.y - feet.y) / screenshot.get_height()})
	var file: FileAccess = FileAccess.open(OUTPUT + "wood_review_%s.json" % tag, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PALACE_WOOD_REVIEW_DONE ", tag)
	get_tree().quit()
