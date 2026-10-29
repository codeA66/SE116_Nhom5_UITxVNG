extends Node
## Autoload "SaveManager": ghi/đọc tiến trình ra file JSON. Chỉ tự lưu khi chạm checkpoint (GameState.progress_committed):
## thoát game giữa chừng thì lần sau vào lại đúng trạng thái ở checkpoint gần nhất.
## Lưu đường dẫn res:// thay vì file .tres: đọc .tres từ bên ngoài có thể chạy script nhúng trong đó.
## Phải đứng sau GameState trong danh sách autoload.

signal saved
signal loaded

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.json.tmp"
## Tăng khi đổi định dạng file, kèm xử lý chuyển đổi trong _deserialize
const SAVE_VERSION := 4


func _ready() -> void:
	load_game()
	GameState.progress_committed.connect(save_game)


func _unhandled_input(event: InputEvent) -> void:
	# Phím xóa save chỉ có trong bản debug, bản export không bị ảnh hưởng
	if OS.is_debug_build() and event.is_action_pressed(&"debug_reset_save"):
		reset_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: không ghi được file tạm (lỗi %d)" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(_serialize(GameState.progress), "\t"))
	file.close()

	# Ghi file tạm xong mới thay file chính: crash giữa chừng không làm hỏng save cũ
	var dir := DirAccess.open("user://")
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	var error := dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if error != OK:
		push_error("SaveManager: không đổi tên file save (lỗi %d)" % error)
		return false
	saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("SaveManager: file save hỏng hoặc sai định dạng, bỏ qua")
		return false
	GameState.replace_progress(_deserialize(parsed as Dictionary))
	loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Xóa save, về tiến trình trống và tải lại scene hiện tại
func reset_game() -> void:
	delete_save()
	GameState.replace_progress(PlayerProgress.new())
	get_tree().reload_current_scene()


func _serialize(progress: PlayerProgress) -> Dictionary:
	var weapon_paths: Array[String] = []
	for weapon in progress.weapons:
		weapon_paths.append(weapon.resource_path)
	var ability_paths: Array[String] = []
	for ability in progress.abilities:
		ability_paths.append(ability.resource_path)
	var flag_ids: Array[String] = []
	for flag in progress.flags:
		flag_ids.append(String(flag))
	return {
		"version": SAVE_VERSION,
		"weapon": progress.weapon.resource_path if progress.weapon else "",
		"weapons": weapon_paths,
		"abilities": ability_paths,
		"flags": flag_ids,
		# Từ version 4: nguyên tố đang ghép ở từng ô vũ khí (ô -> id nguyên tố)
		"fusions": _serialize_fusions(progress),
		"checkpoint": {"zone": progress.checkpoint_zone, "spawn": String(progress.checkpoint_spawn_id)},
	}


func _deserialize(data: Dictionary) -> PlayerProgress:
	var progress := PlayerProgress.new()
	if int(data.get("version", 0)) > SAVE_VERSION:
		push_warning("SaveManager: file save được tạo từ phiên bản game mới hơn")

	progress.weapon = _load_resource(str(data.get("weapon", ""))) as WeaponData
	var weapon_paths: Variant = data.get("weapons", [])
	if weapon_paths is Array:
		for path: Variant in weapon_paths:
			var weapon := _load_resource(str(path)) as WeaponData
			if weapon and progress.get_weapon_in_slot(weapon.slot) == null:
				progress.weapons.append(weapon)
	# Save v1/v2: vũ khí đang cầm cũng là vũ khí đã sở hữu.
	if progress.weapon:
		var owned := progress.get_weapon_in_slot(progress.weapon.slot)
		if owned == null:
			progress.weapons.append(progress.weapon)
		else:
			progress.weapon = owned

	var ability_paths: Variant = data.get("abilities", [])
	if ability_paths is Array:
		for path: Variant in ability_paths:
			var ability := _load_resource(str(path)) as AbilityData
			if ability:
				progress.abilities.append(ability)

	var flag_ids: Variant = data.get("flags", [])
	if flag_ids is Array:
		for flag: Variant in flag_ids:
			progress.flags[StringName(str(flag))] = true

	var fusions: Variant = data.get("fusions", {})
	if fusions is Dictionary:
		for slot: Variant in fusions:
			if str(slot).is_valid_int():
				progress.fusions[int(str(slot))] = StringName(str((fusions as Dictionary)[slot]))

	# Từ version 2. Save version 1 không có checkpoint: bắt đầu ở khu đầu tiên
	var checkpoint: Variant = data.get("checkpoint", {})
	if checkpoint is Dictionary:
		var zone := str((checkpoint as Dictionary).get("zone", ""))
		if _is_valid_scene_path(zone):
			progress.checkpoint_zone = zone
			progress.checkpoint_spawn_id = StringName(str((checkpoint as Dictionary).get("spawn", "")))
	return progress


func _serialize_fusions(progress: PlayerProgress) -> Dictionary:
	var result := {}
	for slot: int in progress.fusions:
		result[str(slot)] = String(progress.fusions[slot])
	return result


## Chỉ nạp tài nguyên nằm trong project; kiểu dữ liệu được kiểm tra ở nơi gọi bằng "as"
func _load_resource(path: String) -> Resource:
	if path.is_empty():
		return null
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		push_warning("SaveManager: bỏ qua đường dẫn không hợp lệ '%s'" % path)
		return null
	return load(path)


func _is_valid_scene_path(path: String) -> bool:
	return path.begins_with("res://") and path.ends_with(".tscn") and ResourceLoader.exists(path)
