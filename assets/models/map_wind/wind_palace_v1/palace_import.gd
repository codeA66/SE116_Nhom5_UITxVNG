@tool
extends EditorScenePostImport
## Vật liệu dùng chung cho bộ cung điện; màu lấy từ vertex đã xuất ở linear.

const VERTEX_MATERIAL: Material = preload("res://assets/models/map_wind/wind_palace_v1/palace_vertex_color.tres")

func _post_import(scene: Node) -> Object:
	var small_lantern: bool = get_source_file().get_file().get_basename() in ["standing_lantern", "wall_lantern"]
	_apply_materials(scene, small_lantern)
	return scene

func _apply_materials(node: Node, small_lantern: bool) -> void:
	if String(node.name).begins_with("AssemblyAnchor"):
		node.name = "AssemblyAnchor"
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		# Đèn đặt trong chụp nhỏ không bị chính chụp che thành mảng bóng lớn trên sàn.
		if small_lantern or String(instance.name).begins_with("Cloth") or String(instance.name).begins_with("Sail"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: Material = instance.mesh.surface_get_material(surface)
			if material and material.resource_name.begins_with("WindPalace_VertexColor"):
				instance.mesh.surface_set_material(surface, VERTEX_MATERIAL)
	for child: Node in node.get_children():
		_apply_materials(child, small_lantern)
