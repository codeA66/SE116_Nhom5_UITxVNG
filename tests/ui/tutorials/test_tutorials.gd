extends Node
## Test tự động hệ thống Tutorials: Popup 1 lần, Sổ Hướng Dẫn (màn Tab / phím H), và lưu tiến trình.

const TUTORIAL_DATA := preload("res://resources/tutorials/data/tut_movement.tres")
const TUTORIAL_DASH := preload("res://resources/tutorials/data/tut_dash.tres")
const MENU_SCENE := preload("res://ui/menus/inventory/inventory_menu.tscn")
const POPUP_SCENE := preload("res://ui/hud/tutorials/tutorial_popup.tscn")

var _fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("--- BẮT ĐẦU TEST TUTORIALS ---")
	_test_progress_and_snapshot()
	await _test_unlock_once()
	await _test_popup()
	await _test_menu_and_help_key()
	await _test_hub_and_trigger()
	_test_new_tutorials_and_skill_acquire()
	
	if _fails == 0:
		print("=== TẤT CẢ TEST TUTORIALS THÀNH CÔNG! ===")
	else:
		push_error("=== TEST TUTORIALS CÓ %d LỖI ===" % _fails)
	get_tree().quit(_fails)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
	else:
		push_error("  [FAIL] %s" % message)
		_fails += 1


func _test_progress_and_snapshot() -> void:
	print("\nTest 1: PlayerProgress snapshot & lưu trữ")
	var p := PlayerProgress.new()
	p.unlocked_tutorials = [&"movement", &"dash"]
	var snap := p.snapshot()
	_assert(snap.unlocked_tutorials.size() == 2, "Snapshot sao chép đúng số lượng tutorial")
	_assert(snap.unlocked_tutorials[0] == &"movement" and snap.unlocked_tutorials[1] == &"dash", "Thứ tự tutorial giữ nguyên")
	
	# Đảm bảo là bản sao sâu độc lập
	snap.unlocked_tutorials.append(&"combat")
	_assert(p.unlocked_tutorials.size() == 2, "Sửa bản snapshot không ảnh hưởng bản gốc")


func _test_unlock_once() -> void:
	print("\nTest 2: Mở khóa 1 lần duy nhất qua GameState")
	GameState.progress = PlayerProgress.new()
	_assert(not GameState.has_tutorial(&"movement"), "Ban đầu chưa có tutorial movement")
	
	var first_unlock := GameState.unlock_tutorial(TUTORIAL_DATA)
	_assert(first_unlock, "Mở khóa lần đầu trả về true")
	_assert(GameState.has_tutorial(&"movement"), "has_tutorial trả về true")
	_assert(GameState.has_flag(&"tut_movement"), "Cờ thế giới tut_movement được bật")
	
	var second_unlock := GameState.unlock_tutorial(TUTORIAL_DATA)
	_assert(not second_unlock, "Mở khóa lần hai trả về false (không trùng lặp)")
	_assert(GameState.progress.unlocked_tutorials.size() == 1, "Mảng vẫn chỉ có 1 phần tử")


func _test_popup() -> void:
	print("\nTest 3: TutorialPopup hiển thị và đóng")
	var popup: TutorialPopup = POPUP_SCENE.instantiate()
	add_child(popup)
	await get_tree().process_frame
	
	_assert(not popup.visible, "Popup ban đầu ẩn")
	
	# Mở khóa dash để kích hoạt popup
	GameState.unlock_tutorial(TUTORIAL_DASH)
	await get_tree().process_frame
	
	_assert(popup.visible, "Popup hiện lên khi có tutorial mới")
	var key_node: Control = popup.get_first_key_glyph()
	_assert(key_node != null and key_node.get(&"text") == "Shift", "Tự động lấy đúng phím [Shift] từ InputMap action dash")
	var art_box: Control = popup.get_node(^"%ArtBox")
	_assert(not art_box.visible, "ArtBox tự ẩn khi tutorial không có hình ảnh để dồn chữ lên")
	
	popup.dismiss()
	await get_tree().create_timer(0.3).timeout
	_assert(not popup.visible, "Popup đóng lại sau khi dismiss")
	
	# Test nhiều phím trong prompt_template (WASD + H)
	_assert(TUTORIAL_DATA.get_key_at(0) == "W", "Key 1 là W")
	_assert(TUTORIAL_DATA.get_key_at(1) == "A", "Key 2 là A")
	_assert(TUTORIAL_DATA.get_key_at(2) == "S", "Key 3 là S")
	_assert(TUTORIAL_DATA.get_key_at(3) == "D", "Key 4 là D")
	_assert(TUTORIAL_DATA.get_key_at(4) == "H", "Key 5 là H")
	
	popup.queue_free()


func _test_menu_and_help_key() -> void:
	print("\nTest 4: Mở menu Tab và phím H (help)")
	var menu: InventoryMenu = MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	
	_assert(not menu.visible, "Menu ban đầu đóng")
	
	# Giả lập mở thẳng trang TutorialsPage
	menu.open_to_page_type(TutorialsPage)
	await get_tree().process_frame
	
	_assert(menu.visible, "Menu mở ra thành công")
	var current := menu.get_current_page()
	_assert(current is TutorialsPage, "Trang hiện tại là TutorialsPage")
	
	menu.close()
	await get_tree().create_timer(0.25).timeout
	_assert(not menu.visible, "Menu đóng lại thành công")
	menu.queue_free()


func _test_hub_and_trigger() -> void:
	print("\nTest 5: Hub scene và TutorialTrigger chờ cutscene")
	const HUB_SCENE := preload("res://levels/temple_center/hub/hub.tscn")
	var hub := HUB_SCENE.instantiate()
	_assert(hub != null, "Load và instantiate hub.tscn thành công")
	
	var trigger: TutorialTrigger = hub.get_node_or_null(^"IntroTutorialTrigger") as TutorialTrigger
	_assert(trigger != null, "Tìm thấy IntroTutorialTrigger trong Hub")
	_assert(trigger.tutorial != null and trigger.tutorial.id == &"movement", "Trigger gán đúng tutorial movement")
	_assert(trigger.tutorials.size() == 2, "Trigger chứa chuỗi 2 tutorial (movement & dash)")
	_assert(trigger.delay_after_cutscene == 4.0, "delay_after_cutscene là 4.0 giây theo cấu hình")
	_assert(trigger.wait_for_cutscene != null, "Trigger liên kết đúng với IntroCutscene")
	hub.queue_free()


func _test_new_tutorials_and_skill_acquire() -> void:
	print("\nTest 6: Kiểm tra các tutorial mới (sword, bow, inventory, skill)")
	var catalog: TutorialCatalog = GameState.TUTORIALS
	_assert(catalog.get_tutorial(&"sword") != null, "Tìm thấy tutorial sword trong catalog")
	_assert(catalog.get_tutorial(&"bow") != null, "Tìm thấy tutorial bow trong catalog")
	_assert(catalog.get_tutorial(&"inventory") != null, "Tìm thấy tutorial inventory trong catalog")
	_assert(catalog.get_tutorial(&"wind_blast") != null, "Tìm thấy tutorial wind_blast trong catalog")
	_assert(catalog.get_tutorial(&"flame_breath") != null, "Tìm thấy tutorial flame_breath trong catalog")
	
	# Test mở khóa skill âm thầm lưu vào Sổ Hướng Dẫn
	var wind_skill: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
	GameState.unlock_ability(wind_skill)
	_assert(GameState.has_tutorial(&"wind_blast"), "Nhặt skill mới tự động lưu tutorial vào Sổ Hướng Dẫn")
