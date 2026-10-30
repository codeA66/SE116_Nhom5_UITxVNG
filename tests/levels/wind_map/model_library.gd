extends RefCounted
## Dùng bản sao model, giữ nguyên nguồn GLB và material nhập của project.

const PALACE_PREFIX := "PAL:"
const PALACE_DIR := "res://assets/models/map_wind/wind_palace_v1/"

var paths: Dictionary = {}
var _templates: Dictionary = {}


func _init() -> void:
	for directory: String in DirAccess.get_directories_at("res://assets/models/shared/generated/wind_ruins/gridmap"):
		var folder: String = "res://assets/models/shared/generated/wind_ruins/gridmap/" + directory
		for file: String in DirAccess.get_files_at(folder):
			if file.get_extension().to_lower() == "glb":
				paths[directory.to_upper()] = folder.path_join(file)


func make(code: String, variant: String = "intact") -> Node3D:
	var key: String = code + ":" + variant
	if _templates.has(key):
		return (_templates[key] as Node3D).duplicate() as Node3D
	# Bộ cung điện: dùng bản import của Godot để giữ vật liệu chung do palace_import.gd gán (vertex color, đèn phát sáng)
	if code.begins_with(PALACE_PREFIX):
		var scene := load(PALACE_DIR + code.trim_prefix(PALACE_PREFIX) + ".glb") as PackedScene
		if scene == null:
			push_warning("Map mới: thiếu model cung điện %s" % code)
			return null
		_templates[key] = scene.instantiate() as Node3D
		return (_templates[key] as Node3D).duplicate() as Node3D
	if not paths.has(code):
		push_warning("Map mới: model chưa xuất xong %s" % code)
		return null
	var path: String = paths[code]
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var source: Node3D = document.generate_scene(state) as Node3D
	var candidates: Array[Node3D] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	file.seek(12)
	var size: int = file.get_32()
	file.get_32()
	var doc: Dictionary = JSON.parse_string(file.get_buffer(size).get_string_from_utf8()) as Dictionary
	for index: int in doc.scenes[int(doc.get("scene", 0))].nodes:
		var node_name: String = doc.nodes[index].get("name", "")
		var candidate: Node3D = source if String(source.name) == node_name else source.find_child(node_name, true, false) as Node3D
		if candidate:
			candidates.append(candidate)
	var chosen: Node3D = candidates[0] if not candidates.is_empty() else source
	for candidate: Node3D in candidates:
		if variant.to_lower() in String(candidate.name).to_lower():
			chosen = candidate
			break
	var result: Node3D = chosen.duplicate() as Node3D
	result.position = Vector3.ZERO
	_fix_colors(result)
	source.free()
	_templates[key] = result
	return result.duplicate() as Node3D


func dispose() -> void:
	for node: Node3D in _templates.values():
		node.free()
	_templates.clear()


func _fix_colors(root: Node3D) -> void:
	var copies: Dictionary = {}
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(root, meshes)
	for mesh: MeshInstance3D in meshes:
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				continue
			var original: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
			if original == null:
				continue
			if not copies.has(original):
				var material: BaseMaterial3D = original.duplicate() as BaseMaterial3D
				material.vertex_color_use_as_albedo = true
				copies[original] = material
			mesh.set_surface_override_material(surface, copies[original] as Material)


static func collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		collect_meshes(child, result)

