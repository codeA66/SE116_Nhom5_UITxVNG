class_name WindReactiveFlag
extends WindReactiveProp
## Vải cờ được dựng riêng vì GLB chỉ chứa cột.

const FLAG_SHADER: Shader = preload("res://assets/shaders/wind_react_flag.gdshader")

@export var cloth_width: float = 1.7
@export var cloth_height: float = 0.8
@export var cloth_bottom: float = 2.45
@export_range(2, 32) var width_segments: int = 12

var _cloth_material: ShaderMaterial


func _setup_visual() -> void:
	var cloth := MeshInstance3D.new()
	cloth.name = "FlagCloth"
	cloth.mesh = _build_cloth()
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloth_material = ShaderMaterial.new()
	_cloth_material.shader = FLAG_SHADER
	_cloth_material.set_shader_parameter(&"recovery_seconds", data.recovery_seconds)
	_cloth_material.set_shader_parameter(&"flutter_speed", data.flutter_speed)
	cloth.material_override = _cloth_material
	add_child(cloth)


func _on_reacted(direction: Vector3, strength: float) -> void:
	var gust_started: float = WindReactiveClock.arm(get_tree(), data.recovery_seconds)
	_cloth_material.set_shader_parameter(&"gust_direction", global_basis.inverse() * direction)
	_cloth_material.set_shader_parameter(&"gust_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
	_cloth_material.set_shader_parameter(&"gust_time", gust_started)


func _on_wind_changed(direction: Vector3, strength: float) -> void:
	_cloth_material.set_shader_parameter(&"hold_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
	if strength > 0.0:
		_cloth_material.set_shader_parameter(&"hold_direction", global_basis.inverse() * direction)


func _build_cloth() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in 3:
		for column in width_segments + 1:
			var across: float = float(column) / float(width_segments)
			var up: float = float(row) * 0.5
			vertices.append(Vector3(0.07 + across * cloth_width, cloth_bottom + up * cloth_height, 0.0))
			uvs.append(Vector2(across, up))
	for row in 2:
		for column in width_segments:
			var corner: int = row * (width_segments + 1) + column
			indices.append_array(PackedInt32Array([corner, corner + width_segments + 1, corner + 1, corner + 1, corner + width_segments + 1, corner + width_segments + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
