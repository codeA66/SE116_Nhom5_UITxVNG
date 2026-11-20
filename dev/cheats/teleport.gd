extends DevCheat
## Dịch chuyển: danh sách gồm các khu (scene gốc là ZoneRoot, tự tìm trong levels/) và các checkpoint của khu đang
## đứng. Chọn khu thì đổi khu (vào điểm xuất hiện mặc định); chọn checkpoint thì dịch chuyển trong khu, không tải lại.

const LEVELS_DIR := "res://levels/"
const ZONE_SCRIPT := "res://levels/_base/zone_root.gd"
## Chỉ đọc chừng này byte đầu file .tscn để tìm script gốc (ext_resource nằm ở đầu file)
const HEADER_BYTES := 8192

var _zones: PackedStringArray = []
var _checkpoints: Array[Checkpoint] = []


func _init() -> void:
	title = "Dịch chuyển"
	group = "4. Di chuyển"
	kind = Kind.CHOICE
	order = 0


func get_choices(console: DevConsole) -> PackedStringArray:
	if _zones.is_empty():
		_zones = _find_zones(LEVELS_DIR)
	_checkpoints.clear()
	var choices := PackedStringArray()
	var scene := console.get_tree().current_scene
	if scene:
		for node in scene.find_children("*", "Checkpoint", true, false):
			var checkpoint := node as Checkpoint
			if not checkpoint.checkpoint_id.is_empty():
				_checkpoints.append(checkpoint)
				choices.append("Checkpoint: %s" % checkpoint.checkpoint_id)
	for zone in _zones:
		choices.append("Khu: %s" % zone.trim_prefix(LEVELS_DIR))
	return choices


func choose(console: DevConsole, index: int) -> void:
	if index < _checkpoints.size():
		var checkpoint := _checkpoints[index]
		var player := console.find_player()
		if not is_instance_valid(checkpoint) or player == null:
			return
		var spawn := SpawnPoint.find_in(console.get_tree().current_scene, checkpoint.checkpoint_id)
		var target := spawn.global_position if spawn else checkpoint.global_position
		SceneManager.warp_player(player, target)
		return
	var zone_index := index - _checkpoints.size()
	if zone_index >= 0 and zone_index < _zones.size():
		SceneManager.change_zone(_zones[zone_index])


func _find_zones(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	for file in dir.get_files():
		if file.ends_with(".tscn") and _is_zone(root.path_join(file)):
			result.append(root.path_join(file))
	for sub in dir.get_directories():
		result.append_array(_find_zones(root.path_join(sub)))
	return result


## Scene khu = file .tscn có tham chiếu script ZoneRoot. Đọc phần đầu file thay vì load cả scene (nhanh hơn nhiều)
func _is_zone(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var header := file.get_buffer(HEADER_BYTES).get_string_from_utf8()
	return header.contains(ZONE_SCRIPT)
