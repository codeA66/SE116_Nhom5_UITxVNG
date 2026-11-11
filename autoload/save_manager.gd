extends Node
## Autoload "SaveManager": ghi/đọc tiến trình ra file JSON. Chỉ tự lưu khi chạm checkpoint (GameState.progress_committed):
## thoát game giữa chừng thì lần sau vào lại đúng trạng thái ở checkpoint gần nhất.
## Có SLOT_COUNT ô hồ sơ, mỗi ô một file; mọi hàm đọc/ghi làm trên ô đang chọn (current_slot).
## Lưu đường dẫn res:// thay vì file .tres: đọc .tres từ bên ngoài có thể chạy script nhúng trong đó.
## Phải đứng sau GameState trong danh sách autoload.

signal saved
signal loaded
signal slot_changed(slot: int)
signal slot_deleted(slot: int)

const SLOT_COUNT := 4
const SLOT_FILE_FORMAT := "save_%d.json"
## Ghi nhớ ô dùng lần cuối: chạy thẳng một khu bằng F6 vẫn nạp đúng hồ sơ đang chơi
const META_FILE := "save_meta.cfg"
## File save trước khi có nhiều ô: tự chuyển sang ô 1 lần đầu chạy bản mới
const LEGACY_PATH := "user://savegame.json"
## Tăng khi đổi định dạng file, kèm xử lý chuyển đổi trong from_dict
const SAVE_VERSION := 6

var current_slot: int = 1
## Thư mục chứa các file hồ sơ. Test đổi sang thư mục riêng để không bao giờ đụng save thật của người chơi
var storage_dir: String = "user://"


func _ready() -> void:
	migrate_legacy_save(LEGACY_PATH)
	current_slot = _read_last_slot()
	load_game()
	GameState.progress_committed.connect(save_game)
	GameState.tutorials_changed.connect(save_game)


func _unhandled_input(event: InputEvent) -> void:
	# Phím xóa save chỉ có trong bản debug, bản export không bị ảnh hưởng
	if OS.is_debug_build() and event.is_action_pressed(&"debug_reset_save"):
		reset_game()


## Đổi thư mục chứa hồ sơ (test dùng thư mục riêng). Đọc lại ô dùng lần cuối trong thư mục đó
func use_storage_dir(dir: String) -> void:
	storage_dir = dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	current_slot = _read_last_slot()


## Chọn ô hồ sơ để đọc/ghi từ giờ (menu chọn hồ sơ gọi). Không tự nạp: nơi gọi quyết định nạp hay bắt đầu mới
func select_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, SLOT_COUNT)
	_write_last_slot(current_slot)
	slot_changed.emit(current_slot)


func get_slot_path(slot: int) -> String:
	return storage_dir.path_join(SLOT_FILE_FORMAT % clampi(slot, 1, SLOT_COUNT))


func slot_has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


## Đọc tiến trình của một ô để hiện trên menu, KHÔNG nạp vào GameState. Ô trống / hỏng trả về null
func peek_slot(slot: int) -> PlayerProgress:
	var data := _read_dict(get_slot_path(slot))
	return from_dict(data) if not data.is_empty() else null


func delete_slot(slot: int) -> void:
	var path := get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	slot_deleted.emit(slot)


func has_save() -> bool:
	return slot_has_save(current_slot)


func save_game() -> bool:
	var path := get_slot_path(current_slot)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: không ghi được file tạm (lỗi %d)" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(to_dict(GameState.progress), "\t"))
	file.close()

	# Ghi file tạm xong mới thay file chính: crash giữa chừng không làm hỏng save cũ
	var dir := DirAccess.open(path.get_base_dir())
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	var error := dir.rename(temp.get_file(), path.get_file())
	if error != OK:
		push_error("SaveManager: không đổi tên file save (lỗi %d)" % error)
		return false
	saved.emit()
	return true


func load_game() -> bool:
	var data := _read_dict(get_slot_path(current_slot))
	if data.is_empty():
		return false
	GameState.replace_progress(from_dict(data))
	loaded.emit()
	return true


func delete_save() -> void:
	delete_slot(current_slot)


## Xóa save, về tiến trình trống và tải lại scene hiện tại
func reset_game() -> void:
	delete_save()
	GameState.replace_progress(PlayerProgress.new())
	get_tree().reload_current_scene()


## Tiến trình -> từ điển ghi file JSON (public để test kiểm định dạng mà không ghi file thật)
func to_dict(progress: PlayerProgress) -> Dictionary:
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
		# Từ version 5: tiền theo loại (CurrencyData.id -> số)
		"currencies": _serialize_currencies(progress),
		# Từ version 6: vật phẩm đếm số lượng, cấp kỹ năng, bùa
		"items": _serialize_counts(progress.items),
		"ability_levels": _serialize_counts(progress.ability_levels),
		"charms": _serialize_ids(progress.charms),
		"equipped_charms": _serialize_ids(progress.equipped_charms),
		"charm_notches": progress.charm_notches,
		# Vật phẩm dùng nút đang chọn (phím use_item)
		"selected_item": String(progress.selected_item),
		# Hướng dẫn đã mở khóa
		"tutorials": _serialize_ids(progress.unlocked_tutorials),
	}


## Từ điển đọc từ file (có thể là save cũ / sửa tay) -> tiến trình hợp lệ
func from_dict(data: Dictionary) -> PlayerProgress:
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
	# Save cũ chưa có tiền: bắt đầu từ 0
	var currencies: Variant = data.get("currencies", {})
	if currencies is Dictionary:
		for id: Variant in currencies:
			_read_currency(progress, StringName(str(id)), (currencies as Dictionary)[id])
	# Save cũ chưa có vật phẩm / cấp / bùa: để trống (cấp 1, chưa có bùa, số ô khắc theo NewGameData)
	_read_counts(data.get("items", {}), progress.items)
	_read_counts(data.get("ability_levels", {}), progress.ability_levels)
	_read_ids(data.get("charms", []), progress.charms)
	_read_ids(data.get("equipped_charms", []), progress.equipped_charms)
	# Hướng dẫn đã mở khóa
	_read_ids(data.get("tutorials", []), progress.unlocked_tutorials)
	for tut: StringName in progress.unlocked_tutorials:
		progress.flags[StringName("tut_" + String(tut))] = true
	# Chỉ nhận vật phẩm dùng nút có trong danh mục (save sửa tay / bản cũ thì bỏ qua)
	var selected := StringName(str(data.get("selected_item", "")))
	if GameState.ITEMS.get_item(selected) is QuickItemData:
		progress.selected_item = selected
	var notches: Variant = data.get("charm_notches", -1)
	if notches is int or notches is float:
		progress.charm_notches = maxi(int(notches), -1)
	# Bản thử trước khi có từ điển tiền lưu riêng khoá "soul_jade"
	if data.has("soul_jade") and not progress.currencies.has(&"soul_jade"):
		_read_currency(progress, &"soul_jade", data["soul_jade"])
	return progress


func _serialize_counts(counts: Dictionary[StringName, int]) -> Dictionary:
	var result := {}
	for id: StringName in counts:
		result[String(id)] = counts[id]
	return result


func _serialize_ids(ids: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for id: StringName in ids:
		result.append(String(id))
	return result


## Từ điển id -> số đọc từ file: chỉ nhận số dương (JSON đọc số thành float), sai kiểu thì bỏ qua
func _read_counts(source: Variant, target: Dictionary[StringName, int]) -> void:
	if not source is Dictionary:
		return
	for key: Variant in source:
		var value: Variant = (source as Dictionary)[key]
		if (value is int or value is float) and int(value) > 0 and not str(key).is_empty():
			target[StringName(str(key))] = int(value)


func _read_ids(source: Variant, target: Array[StringName]) -> void:
	if not source is Array:
		return
	for value: Variant in source:
		var id := StringName(str(value))
		if not id.is_empty() and not target.has(id):
			target.append(id)


func _serialize_currencies(progress: PlayerProgress) -> Dictionary:
	var result := {}
	for id: StringName in progress.currencies:
		result[String(id)] = progress.currencies[id]
	return result


## Một mục tiền đọc từ file: chỉ nhận số (JSON đọc số thành float), âm thì về 0, chữ / sai kiểu thì bỏ qua
func _read_currency(progress: PlayerProgress, id: StringName, value: Variant) -> void:
	if id.is_empty() or not (value is int or value is float):
		return
	progress.currencies[id] = maxi(int(value), 0)


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


## File không có / hỏng / sai định dạng -> từ điển rỗng
func _read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("SaveManager: file save '%s' hỏng hoặc sai định dạng, bỏ qua" % path)
		return {}
	return parsed as Dictionary


## Save trước khi có nhiều ô -> ô 1 (chỉ khi ô 1 còn trống). Public để test chạy với file giả
func migrate_legacy_save(legacy_path: String) -> void:
	if not FileAccess.file_exists(legacy_path) or slot_has_save(1):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_dir))
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy_path), ProjectSettings.globalize_path(get_slot_path(1)))
	if error != OK:
		push_error("SaveManager: không chuyển được save cũ sang ô 1 (lỗi %d)" % error)


func _read_last_slot() -> int:
	var config := ConfigFile.new()
	if config.load(storage_dir.path_join(META_FILE)) != OK:
		return 1
	return clampi(int(config.get_value("slots", "last", 1)), 1, SLOT_COUNT)


func _write_last_slot(slot: int) -> void:
	var config := ConfigFile.new()
	config.load(storage_dir.path_join(META_FILE))
	config.set_value("slots", "last", slot)
	config.save(storage_dir.path_join(META_FILE))
