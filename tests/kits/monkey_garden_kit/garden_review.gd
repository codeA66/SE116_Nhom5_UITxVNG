extends Node3D
## Cảnh QA độc lập: không gọi builder hoặc sửa scene gameplay.
const KIT := "res://assets/models/map_wind/tier_3_monkey_garden/"
const OUTPUT := "C:/Code/UITxVNG/output/tier_3_monkey_garden/"
var camera: Camera3D
var display: Node3D
var records: Array = []
var materials_checked := 0
var errors: Array[String] = []
var character_scales: Array[Dictionary] = []

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("242a30")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c3ccd0")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 30
	camera.position = Vector3(0, 24.51, 20.57)
	camera.rotation_degrees.x = -50
	camera.current = true
	add_child(camera)
	display = Node3D.new()
	add_child(display)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT + "manifest.json"))
	records = manifest.assets
	run.call_deferred()

func spawn_model(asset_name: String, at: Vector3, turn: float = 0) -> Node3D:
	for entry: Dictionary in records:
		if str(entry.name) == asset_name:
			var model := (load(KIT + str(entry.file)) as PackedScene).instantiate() as Node3D
			display.add_child(model)
			model.set_meta("garden_asset", asset_name)
			model.position = at
			model.rotation.y = turn
			audit(model)
			return model
	return null

func audit(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			materials_checked += 1
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat == null or (not mat.emission_enabled and (not mat.vertex_color_use_as_albedo or mat.resource_path != KIT + "garden_vertex_color.tres")):
				errors.append(str(node.name) + ": shared vertex material missing")
			var arrays := mi.mesh.surface_get_arrays(i)
			if (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty():
				errors.append(str(node.name) + ": COLOR_0 missing")
	for child in node.get_children():
		audit(child)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var group := "corner"
	for arg in args:
		if arg.begins_with("--group="):
			group = arg.trim_prefix("--group=")
	if group == "corner":
		for z in [-4, 0, 4]:
			for x in [-4, 0, 4]:
				spawn_model("floor_dirt_4m" if x <= 0 else "floor_stone_broken_4m", Vector3(x, 0, z))
		for x in [-4, 0, 4]:
			spawn_model("wall_garden_4m", Vector3(x, 0, -6))
		for z in [-4, 0, 4]:
			spawn_model("wall_garden_4m", Vector3(-6, 0, z), PI / 2)
		spawn_model("wall_garden_corner", Vector3(-6, 0, -6))
		spawn_model("wall_garden_arch_4m", Vector3(4, 0, -2))
	elif group in ["composition", "scale", "motion"]:
		if group == "composition":
			camera.position = Vector3(0, 24.51 * 1.2 + 2.3, 20.57 * 1.2)
			var layout: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/kits/monkey_garden_kit/composition_layout.json"))
			for item: Array in layout:
				spawn_model(str(item[0]), Vector3(float(item[1]), 0, float(item[2])), float(item[3]))
		else:
			for z in [-4, 0, 4]:
				for x in [-4, 0, 4]:
					spawn_model("floor_dirt_4m", Vector3(x, 0, z))
			spawn_model("garden_gate", Vector3(-4, 0, -3))
			spawn_model("pavilion_small", Vector3(2, 0, -3))
			spawn_model("chieftain_throne", Vector3(4, 0, 1))
			spawn_model("chest_garden", Vector3(-3, 0, 2))
			spawn_model("territory_totem", Vector3(-5, 0, 1))
		if group == "motion":
			rotate_parts(display)
		await spawn_character("res://assets/characters/foxy/foxy.glb", 1.8, Vector3(-1.3, 0, 2.5))
		await spawn_character("res://assets/models/enemies/blenderimport/monkey_grunt/Monkey_Grunt.glb", 1.8, Vector3(0.8, 0, 0.6))
		await spawn_character("res://assets/models/enemies/blenderimport/monkey_chieftain/Monkey_Chieftain.glb", 2.35, Vector3(3.6, 0, 3.0))
		make_slash(Vector3(-0.2, 0.85, 2.6))
	else:
		var list: Array = records.filter(func(e: Dictionary) -> bool: return str(e.file).begins_with(group + "/"))
		var spacing := 6.0 if group != "plants" else 12.0
		for i in range(list.size()):
			var rows := ceilf(float(list.size()) / 3.0)
			var p := Vector3((i % 3 - 1) * spacing, 0, (floorf(float(i) / 3.0) - (rows - 1) * 0.5) * 8.0)
			spawn_model(str(list[i].name), p)
			var label := Label3D.new()
			label.text = str(list[i].name)
			label.position = p + Vector3(0, -0.2, 2.65)
			label.no_depth_test = true
			label.font_size = 64
			label.pixel_size = 0.006
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			display.add_child(label)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 26 if group == "ground" else 28 if group == "plants" else 10 if group == "interactive" else 21 if group == "monkey_props" else 17
		camera.position = Vector3(0, 31.5, 25.17)
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUTPUT + group + "_color.png")
	var report := {"group": group, "renderer": RenderingServer.get_current_rendering_method(), "materials_checked": materials_checked, "errors": errors, "camera_pitch_degrees": 50, "camera_fov": 30}
	if not character_scales.is_empty():
		report.character_scales = character_scales
	if group == "corner":
		var floor_values: Array[float] = []
		var wall_values: Array[float] = []
		for x in range(-45, 15, 2):
			for z in range(-35, 46, 2):
				var pixel := camera.unproject_position(Vector3(x / 10.0, 0, z / 10.0))
				floor_values.append(img.get_pixelv(Vector2i(pixel)).get_luminance())
		for x in range(-45, 16, 2):
			for y in range(8, 25, 2):
				var pixel := camera.unproject_position(Vector3(x / 10.0, y / 10.0, -5.739))
				wall_values.append(img.get_pixelv(Vector2i(pixel)).get_luminance())
		report.dirt_grid_luminance = average(floor_values)
		report.wall_grid_luminance = average(wall_values)
		var floor_mask: Dictionary = await measure_mask(img, "floor")
		var wall_mask: Dictionary = await measure_mask(img, "wall")
		report.floor_luminance = floor_mask.mean
		report.wall_luminance = wall_mask.mean
		report.floor_samples = floor_mask.pixels
		report.wall_samples = wall_mask.pixels
		report.measurement = "All visible floor pixels (dirt + stone + shadows), selected by unshaded ID mask; screenshot Color.get_luminance. Wall mask covers straight walls and corner post."
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y).get_luminance()
			img.set_pixel(x, y, Color(c, c, c, 1))
	img.save_png(OUTPUT + group + "_grayscale.png")
	var file := FileAccess.open(OUTPUT + group + "_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("GARDEN_QA ", JSON.stringify(report))
	get_tree().quit()

func average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

func gather_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		gather_meshes(child, out)

func measure_mask(original: Image, kind: String) -> Dictionary:
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	var restore: Array = []
	for model in display.get_children():
		var asset := str(model.get_meta("garden_asset", ""))
		var selected := asset.begins_with("floor_") if kind == "floor" else asset in ["wall_garden_4m", "wall_garden_corner"]
		var meshes: Array[MeshInstance3D] = []
		gather_meshes(model, meshes)
		for mi in meshes:
			restore.append([mi, mi.material_override])
			mi.material_override = white if selected else black
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var mask := get_viewport().get_texture().get_image()
	mask.save_png(OUTPUT + "corner_" + kind + "_mask.png")
	var total := 0.0
	var count := 0
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			if mask.get_pixel(x, y).r > 0.98:
				total += original.get_pixel(x, y).get_luminance()
				count += 1
	for pair: Array in restore:
		(pair[0] as MeshInstance3D).material_override = pair[1]
	return {"mean": total / maxf(count, 1), "pixels": count}

func spawn_character(path: String, height: float, at: Vector3) -> void:
	var visual := (load(path) as PackedScene).instantiate() as Node3D
	display.add_child(visual)
	for i in range(3):
		await get_tree().process_frame
	var meshes: Array[MeshInstance3D] = []
	gather_meshes(visual, meshes)
	var bounds := AABB()
	var first := true
	for mi in meshes:
		var local_bounds := mi.get_aabb()
		if mi.skin != null and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
			var posed := mi.bake_mesh_from_current_skeleton_pose()
			if posed != null:
				local_bounds = posed.get_aabb()
		var box: AABB = mi.global_transform * local_bounds
		bounds = box if first else bounds.merge(box)
		first = false
	var factor := height / bounds.size.y
	visual.scale *= factor
	visual.position = at - Vector3((bounds.position.x + bounds.size.x * 0.5) * factor, bounds.position.y * factor, (bounds.position.z + bounds.size.z * 0.5) * factor)
	character_scales.append({"source": path, "rest_aabb_height_m": bounds.size.y, "qa_scale": factor, "display_height_m": height})

func make_slash(at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a := deg_to_rad(-70 + i * 17.5)
		var b := deg_to_rad(-70 + (i + 1) * 17.5)
		var v0 := Vector3(cos(a) * 1.2, 0, sin(a) * 1.2)
		var v1 := Vector3(cos(b) * 1.2, 0, sin(b) * 1.2)
		var v2 := Vector3(cos(b) * 0.94, 0, sin(b) * 0.94)
		var v3 := Vector3(cos(a) * 0.94, 0, sin(a) * 0.94)
		for vertex: Vector3 in [v0, v2, v1, v0, v3, v2]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = tool.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f4efd9")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = at
	display.add_child(mi)

func rotate_parts(node: Node) -> void:
	if str(node.name).begins_with("DoorLeaf"):
		(node as Node3D).rotation.y = deg_to_rad(-75 if str(node.name).contains("Left") else 75)
	if str(node.name).begins_with("ChestLid"):
		(node as Node3D).rotation.x = deg_to_rad(-105)
	for child in node.get_children():
		rotate_parts(child)
