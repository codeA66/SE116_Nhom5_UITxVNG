@tool
extends EditorScenePostImport
## GLB COLOR_0 lưu màu linear; dùng chung vật liệu, giữ backface culling để lộ lỗi normal.
const SHARED: Material = preload("res://assets/models/map_wind/tier_3_monkey_garden/garden_vertex_color.tres")

func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene

func _apply(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var original := instance.mesh.surface_get_material(surface)
			if original != null and original.resource_name.begins_with("Garden_Interactive"):
				var glow := StandardMaterial3D.new()
				glow.resource_name = "Garden_Interactive"
				glow.albedo_color = Color("3fe0d0")
				glow.emission_enabled = true
				glow.emission = Color("3fe0d0")
				glow.emission_energy_multiplier = 0.8
				glow.roughness = 0.9
				instance.mesh.surface_set_material(surface, glow)
			else:
				instance.mesh.surface_set_material(surface, SHARED)
	for child in node.get_children():
		_apply(child)
