extends RefCounted
## Giữ điểm lắp của các scene QA đã dựng trước khi chuẩn hóa origin GLB.
## Khi lắp map mới, đặt GLB bằng đáy giữa hoặc marker AssemblyAnchor; không cần helper này.

static var _loaded: bool = false
static var _offsets: Dictionary[String, Vector3] = {}

static func place(model: Node3D, anchor: Vector3, path: String, rotation_y: float = 0.0) -> void:
	if not _loaded:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/map_wind/wind_palace_v1/manifest.json"))
		for entry: Dictionary in manifest.assets:
			var values: Array = entry.get("legacy_placement_offset_godot", [0.0, 0.0, 0.0])
			_offsets[str(entry.name)] = Vector3(float(values[0]), float(values[1]), float(values[2]))
		_loaded = true
	model.rotation_degrees.y = rotation_y
	var offset: Vector3 = _offsets.get(path.get_file().get_basename(), Vector3.ZERO) if path.ends_with(".glb") else Vector3.ZERO
	model.position = anchor + model.basis * offset
