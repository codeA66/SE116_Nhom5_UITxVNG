extends Node
## Kiểm tra runtime của scene mới, không tải map cũ hoặc ghi tiến trình game.

const GALLERY: PackedScene = preload("res://tests/generated_wind_gallery/wind_model_gallery.tscn")
const GALLERY_SCRIPT: Script = preload("res://tests/generated_wind_gallery/wind_model_gallery.gd")

var _failed: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var gallery: GALLERY_SCRIPT = GALLERY.instantiate() as GALLERY_SCRIPT
	get_tree().root.add_child(gallery)
	await get_tree().process_frame
	_check(gallery.asset_paths.size() > 0, "catalog has models")
	if "--diagnose-color" in OS.get_cmdline_user_args():
		for found: Node in gallery.get_node("ModelStage").find_children("*", "MeshInstance3D", true, false):
			var part: MeshInstance3D = found as MeshInstance3D
			var mat: BaseMaterial3D = part.get_active_material(0) as BaseMaterial3D
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			print("GALLERY_COLOR ", part.name, " ", mat.vertex_color_use_as_albedo, " ", mat.albedo_color, " ", colors[0] if not colors.is_empty() else Color.MAGENTA)
		gallery.queue_free()
		await get_tree().process_frame
		get_tree().quit()
		return
	var variant_count: int = 0
	for index: int in gallery.asset_paths.size():
		_check(gallery.load_asset(index), "load %s" % gallery.asset_paths[index])
		for variant_index: int in gallery.variants.size():
			gallery.select_variant(variant_index)
			var size: Vector3 = gallery.selected_bounds.size
			_check(size.is_finite() and size.x > 0.0 and size.y > 0.0 and size.z > 0.0, "valid bounds")
			_check(gallery.get_node("ModelStage").scale == Vector3.ONE, "actual model scale preserved")
			for found: Node in gallery.variants[variant_index].find_children("*", "MeshInstance3D", true, false):
				var part: MeshInstance3D = found as MeshInstance3D
				for surface: int in part.mesh.get_surface_count():
					var arrays: Array = part.mesh.surface_get_arrays(surface)
					if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
						continue
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
					if not colors.is_empty():
						var material: BaseMaterial3D = part.get_active_material(surface) as BaseMaterial3D
						_check(material != null and material.vertex_color_use_as_albedo, "stored vertex colors are displayed")
			gallery.set_material_mode(1)
			gallery.set_material_mode(0)
			gallery.set_view_mode(1)
			var camera: Camera3D = gallery.get_node("InspectionCamera") as Camera3D
			_check(is_equal_approx(camera.fov, 30.0) and is_equal_approx(camera.rotation_degrees.x, -50.0), "game camera matches")
			gallery.set_view_mode(0)
			variant_count += 1
		await get_tree().process_frame
	var first: int = 0
	for index: int in gallery.asset_paths.size():
		if gallery.asset_paths[index].contains("/f01/"):
			first = index
	gallery.load_asset(first)
	gallery.set_walk_enabled(true)
	var player: Player = gallery.get_node("Player") as Player
	for i: int in 45:
		await get_tree().physics_frame
	_check(player.is_on_floor(), "fox stands on real test-floor collision")
	var before: Vector3 = player.position
	Input.action_press(&"move_right")
	for i: int in 25:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	_check(player.position.distance_to(before) > 0.3, "real player FSM moves in walk mode")
	gallery.set_walk_enabled(false)
	gallery.refresh_catalog()
	_check(gallery.asset_paths.size() > 0, "refresh catalog")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		for wanted: String in ["f01", "a04", "l04"]:
			for index: int in gallery.asset_paths.size():
				if gallery.asset_paths[index].contains("/%s/" % wanted):
					gallery.load_asset(index)
					gallery.set_view_mode(0)
					for i: int in 4:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://output/wind_gallery_verification/gallery_%s.png" % wanted)
	print("WIND_GALLERY %s assets=%d variants=%d" % ["FAILED" if _failed else "PASSED", gallery.asset_paths.size(), variant_count])
	gallery.queue_free()
	await get_tree().process_frame
	Input.set_custom_mouse_cursor(null)
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("GALLERY: %s" % message)

