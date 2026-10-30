extends Node3D
## Cùng một góc máy/ánh sáng cho góc mẫu trước và sau art R2; không sửa map đang dựng.
const KIT: String = "res://assets/models/map_wind/wind_palace_v1/"
const BACKUP: String = "C:/Code/UITxVNG/Foxy_Art_Source/wind_palace_v1/before_art_r2/"
const OUTPUT: String = "res://output/wind_palace/qa/"
var _display: Node3D

func _ready() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("252c36")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b3c0ce")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var warm: OmniLight3D = OmniLight3D.new()
	warm.position = Vector3(-2.5, 3.4, 0.6)
	warm.light_color = Color("F2B45A")
	warm.light_energy = 1.8
	warm.omni_range = 7.0
	add_child(warm)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.position = Vector3(10, 9, 13)
	add_child(camera)
	camera.look_at(Vector3(0, 1.3, -0.9))
	camera.current = true
	var fox: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	fox.position = Vector3(0.8, 0, 0.6)
	add_child(fox)
	fox.set_controls_enabled(false)
	fox.set_physics_process(false)
	fox.get_node("HUD").hide()
	camera.current = true
	_capture_pair.call_deferred()

func _capture_pair() -> void:
	for old: bool in [true, false]:
		if is_instance_valid(_display):
			_display.queue_free()
			await get_tree().process_frame
		_display = Node3D.new()
		add_child(_display)
		for x: int in [-2, 2]:
			for z: int in [-2, 2]:
				_add("floor_4m", Vector3(x, -0.32, z), old)
		_add("wall_straight_4m", Vector3(-2, 0, -4), old)
		_add("pillar_square_4m", Vector3(-3.1, 0, -2.6), old)
		_add("arch_doorway_3m", Vector3(2, 0, -4), old)
		_add("balustrade_4m", Vector3(1.4, 0, 2.9), old)
		for frame: int in range(10):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var suffix: String = "before" if old else "after"
		get_viewport().get_texture().get_image().save_png(OUTPUT + "art_corner_" + suffix + ".png")
	print("ART_CORNER_PAIR_DONE")
	get_tree().quit()

func _add(asset: String, at: Vector3, old: bool) -> void:
	var model: Node3D
	if old:
		var document: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		var result: Error = document.append_from_file(BACKUP + asset + ".glb", state)
		assert(result == OK, "Missing art baseline " + asset)
		model = document.generate_scene(state) as Node3D
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			for surface: int in range(mesh.mesh.get_surface_count()):
				var material: Material = mesh.mesh.surface_get_material(surface)
				if material and material.resource_name.begins_with("WindPalace_VertexColor"):
					mesh.mesh.surface_set_material(surface, load(KIT + "palace_vertex_color.tres"))
	else:
		model = (load(KIT + asset + ".glb") as PackedScene).instantiate() as Node3D
	model.position = at
	_display.add_child(model)
