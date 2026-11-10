@tool
extends EditorScenePostImport
## Gán vật liệu dùng chung cho các bộ model map Lửa (fire_kit, inferno_kit, lavaplant_kit).
## Vật liệu glTF xuất từ Blender không bật vertex color trong Godot nên phải thay sau import.

const BASE_MATERIAL: Material = preload("res://assets/models/map_fire/fire_vertex_color.tres")
const EMISSION_MATERIAL: Material = preload("res://assets/models/map_fire/fire_vertex_color_emission.tres")
const LAVA_MATERIAL: Material = preload("res://assets/materials/map_fire/lava_material.tres")
const BASE_NAME: String = "Fire_VertexColor"
const EMISSION_NAME: String = "Fire_VertexColor_Emission"
## File có tên bắt đầu bằng các tiền tố này: mặt phát sáng là dung nham, dùng shader dung nham động
const LAVA_FILE_PREFIXES: PackedStringArray = ["lava_", "lavafall_", "puddle_"]


func _post_import(scene: Node) -> Object:
	var file_name: String = get_source_file().get_file()
	var is_lava: bool = false
	for prefix: String in LAVA_FILE_PREFIXES:
		if file_name.begins_with(prefix):
			is_lava = true
			break
	_apply_materials(scene, LAVA_MATERIAL if is_lava else EMISSION_MATERIAL)
	return scene


func _apply_materials(node: Node, glow_material: Material) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		var only_emission: bool = true
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: Material = instance.mesh.surface_get_material(surface)
			if material == null:
				only_emission = false
				continue
			# Kiểm tra tên dài trước vì tên ngắn là tiền tố của nó
			if material.resource_name.begins_with(EMISSION_NAME):
				instance.mesh.surface_set_material(surface, glow_material)
			elif material.resource_name.begins_with(BASE_NAME):
				instance.mesh.surface_set_material(surface, BASE_MATERIAL)
				only_emission = false
			else:
				only_emission = false
		# Mặt dung nham, mặt cổng chỉ phát sáng: đổ bóng vô nghĩa mà tốn chi phí vẽ bóng
		if only_emission:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_apply_materials(child, glow_material)
