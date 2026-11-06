extends Node
## Test menu chính + 4 ô hồ sơ. Bấm phím thật (Input.parse_input_event), save ghi vào thư mục test riêng,
## không bao giờ đụng save thật. Chạy: mở test_main_menu.tscn rồi F6, hoặc headless.
##
## ===== USE CASE =====
## UC1  Mở menu -> màn "Nhấn phím bất kỳ"; phím bất kỳ -> menu chính, chọn sẵn "Bắt đầu".
## UC2  Cài đặt -> Esc quay về menu chính, con trỏ đứng lại ở "Cài đặt".
## UC3  Hồ sơ: ô trống ghi "Hành trình mới"; ô có dữ liệu ghi nơi đang đứng, tiền, hạt khu đã phá; ô trống không có nút Xóa.
## UC4  Xóa: hộp xác nhận chọn sẵn "Không" -> Enter không xóa; chọn "Xóa" -> file mất, ô thành trống; ô khác không đổi.
## UC5  Esc lùi từng màn: hồ sơ -> menu -> tiêu đề.
## UC6  Save cũ (1 file) tự chuyển sang ô 1; ô 1 đã có thì không ghi đè.
## UC7  Chọn ô trống -> hành trình mới: tiến trình trống, ô đang dùng = ô đó, bắt đầu chuyển cảnh; bấm tiếp không gọi lần 2.

const MENU := "res://ui/menus/main/main_menu.tscn"
const TEST_DIR := "user://test_main_menu_saves/"
const WIND_LEVEL := "res://levels/zone_1_wind/level_1/level_1.tscn"

var _fails: int = 0
var _menu: MainMenu
var _real_dir: String
var _real_slot: int


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_real_dir = SaveManager.storage_dir
	_real_slot = SaveManager.current_slot
	_run.call_deferred()


func _run() -> void:
	_uc6_migrate()
	_clear_dir()
	SaveManager.use_storage_dir(TEST_DIR)
	_write_fixture(2)
	_write_fixture(4)
	_menu = (load(MENU) as PackedScene).instantiate() as MainMenu
	get_tree().root.add_child(_menu)
	await _wait(0.6)
	await _uc1_title()
	await _uc2_settings()
	await _uc3_profiles()
	await _uc4_delete()
	await _uc5_back()
	await _uc7_new_game()
	_clear_dir()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
	SaveManager.storage_dir = _real_dir
	SaveManager.current_slot = _real_slot
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _state() -> StringName:
	return (_menu.get_node("StateMachine") as StateMachine).current_state.name


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _uc1_title() -> void:
	_check(_state() == &"Title" and _menu.title_screen.visible, "UC1: mở menu ở màn tiêu đề")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await _wait(0.5)
	_check(_state() == &"Home", "UC1: phím bất kỳ -> menu chính (%s)" % _state())
	_check(_focused() == _menu.get_node("UI/Root/HomeScreen/Items/Start"), "UC1: chọn sẵn 'Bắt đầu' (%s)" % _focused())


func _uc2_settings() -> void:
	await _action(&"ui_down")
	_check(_focused() == _menu.get_node("UI/Root/HomeScreen/Items/Settings"), "UC2: mũi tên xuống -> Cài đặt")
	await _action(&"ui_accept")
	_check(_state() == &"Settings", "UC2: vào Cài đặt")
	await _action(&"ui_cancel")
	_check(_state() == &"Home" and _focused() == _menu.get_node("UI/Root/HomeScreen/Items/Settings"), "UC2: Esc về menu, con trỏ ở Cài đặt (%s)" % _focused())
	await _action(&"ui_up")


func _uc3_profiles() -> void:
	await _action(&"ui_accept")
	_check(_state() == &"Profiles", "UC3: Bắt đầu -> chọn hồ sơ")
	var slots := _slots()
	_check(_label(slots[0], "Main/Row/Info/Name") == "Hành trình mới", "UC3: ô 1 trống ghi 'Hành trình mới'")
	_check(_label(slots[1], "Main/Row/Info/Name") == "Khu Gió", "UC3: ô 2 ghi nơi đang đứng ('%s')" % _label(slots[1], "Main/Row/Info/Name"))
	_check(_label(slots[1], "Main/Row/Info/Detail").contains("120"), "UC3: ô 2 ghi số tiền ('%s')" % _label(slots[1], "Main/Row/Info/Detail"))
	_check(not slots[0].get_delete_button().focus_mode == Control.FOCUS_ALL and slots[1].get_delete_button().focus_mode == Control.FOCUS_ALL, "UC3: ô trống không có nút Xóa, ô có dữ liệu có")
	_check(_focused() == slots[0].get_main_button(), "UC3: chọn sẵn ô 1")


func _uc4_delete() -> void:
	var slots := _slots()
	slots[1].get_delete_button().grab_focus()
	await get_tree().process_frame
	await _action(&"ui_accept")
	_check(_state() == &"ConfirmDelete", "UC4: Xóa -> hộp xác nhận")
	_check(_focused() == _menu.get_node("UI/Root/ConfirmScreen/Box/Buttons/No"), "UC4: chọn sẵn 'Không' (%s)" % _focused())
	await _action(&"ui_down")
	_check(_focused() == _menu.get_node("UI/Root/ConfirmScreen/Box/Buttons/No"), "UC4: mũi tên xuống không lạc ra khỏi hộp")
	await _action(&"ui_accept")
	_check(_state() == &"Profiles" and SaveManager.slot_has_save(2), "UC4: Enter ở 'Không' -> giữ hồ sơ 2")
	slots[1].get_delete_button().grab_focus()
	await get_tree().process_frame
	await _action(&"ui_accept")
	await _action(&"ui_right")
	_check(_focused() == _menu.get_node("UI/Root/ConfirmScreen/Box/Buttons/Yes"), "UC4: mũi tên phải -> 'Xóa'")
	await _action(&"ui_accept")
	_check(not SaveManager.slot_has_save(2) and SaveManager.slot_has_save(4), "UC4: xóa ô 2, ô 4 còn nguyên")
	_check(_label(slots[1], "Main/Row/Info/Name") == "Hành trình mới", "UC4: ô 2 hiện lại là ô trống")
	_check(_focused() == slots[1].get_main_button(), "UC4: con trỏ về ô vừa xóa")


func _uc5_back() -> void:
	await _action(&"ui_cancel")
	_check(_state() == &"Home", "UC5: Esc ở hồ sơ -> menu chính")
	await _action(&"ui_cancel")
	_check(_state() == &"Title", "UC5: Esc ở menu chính -> màn tiêu đề")


func _uc6_migrate() -> void:
	var dir := "user://test_main_menu_migrate/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	SaveManager.use_storage_dir(dir)
	var legacy := dir.path_join("legacy.json")
	var file := FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveManager.to_dict(_fixture())))
	file.close()
	SaveManager.migrate_legacy_save(legacy)
	_check(SaveManager.slot_has_save(1) and not FileAccess.file_exists(legacy), "UC6: save cũ chuyển sang ô 1")
	var peek := SaveManager.peek_slot(1)
	_check(peek != null and peek.currencies.get(&"soul_jade", 0) == 120, "UC6: dữ liệu ô 1 đúng sau khi chuyển")
	file = FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	SaveManager.migrate_legacy_save(legacy)
	_check(SaveManager.peek_slot(1).currencies.get(&"soul_jade", 0) == 120, "UC6: ô 1 đã có -> không ghi đè")
	for name_ in ["legacy.json", "save_1.json", "save_meta.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(name_)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func _uc7_new_game() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await _wait(0.5)
	await _action(&"ui_accept")
	await _action(&"ui_down")
	await _action(&"ui_down")
	_check(_focused() == _slots()[2].get_main_button(), "UC7: mũi tên xuống 2 lần -> ô 3")
	# Chỉ chờ 1 frame: SceneManager mờ màn 0.25 s rồi thay scene (test bị thay theo), phải kiểm tra trước đó
	await _action_quick(&"ui_accept")
	_check(SaveManager.current_slot == 3 and GameState.progress.flags.is_empty(), "UC7: ô 3 trống -> hành trình mới, tiến trình trống")
	_check(_menu.is_launching() and SceneManager.is_busy(), "UC7: bắt đầu chuyển cảnh")
	# Gọi lại ngay (như bấm liên tục): không được đổi ô / gọi chuyển cảnh lần 2
	_menu.start_profile(1)
	_check(SaveManager.current_slot == 3, "UC7: bấm thêm không gọi chuyển cảnh lần 2")


func _slots() -> Array[ProfileSlot]:
	var result: Array[ProfileSlot] = []
	for child in _menu.get_node("UI/Root/ProfilesScreen/List").get_children():
		result.append(child as ProfileSlot)
	return result


func _label(slot: ProfileSlot, path: String) -> String:
	return (slot.get_node(path) as Label).text


func _fixture() -> PlayerProgress:
	var progress := PlayerProgress.new()
	progress.checkpoint_zone = WIND_LEVEL
	progress.checkpoint_spawn_id = &"start"
	progress.flags[&"zone.wind.cleared"] = true
	progress.currencies[&"soul_jade"] = 120
	progress.abilities.append(load("res://abilities/wind_blast/wind_blast.tres") as AbilityData)
	return progress


func _write_fixture(slot: int) -> void:
	var file := FileAccess.open(SaveManager.get_slot_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveManager.to_dict(_fixture())))
	file.close()


func _clear_dir() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


func _action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _wait(0.45)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


func _action_quick(action: StringName) -> void:
	# Nút nhận ui_accept lúc NHẢ phím: phải gửi cả nhấn và nhả
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
