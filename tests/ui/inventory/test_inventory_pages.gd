extends Node
## Unit test nâng cấp màn Tab giai đoạn 3 (trang Nguyên tố, Vũ khí, Vật phẩm, Hướng dẫn, bảng chi tiết).
## Viết TRƯỚC khi code: chưa có code thì FAIL, code xong phải PASS hết.
## Chạy có cửa sổ (đo điểm ảnh), APPDATA riêng; không ghi save thật. Kết quả: PASS / FAIL từng dòng, cuối "RESULT fails=N".
##
## ===== USE CASE =====
## UC1 Màn Tab có 4 trang theo thứ tự Bùa, Vật phẩm, Nguyên tố, Vũ khí.
## UC2 Trang Nguyên tố chỉ hiện nguyên tố đã mở khóa, thẻ không có hộp nền như bùa, không còn ô ghép vũ khí.
## UC3 Chi tiết nguyên tố: tên + mô tả ngắn của CẤP ĐANG CÓ, chấm cấp; không lộ tên / mô tả cấp sau, không có nút
##     nâng cấp hay ghép vũ khí (Enter / phím phụ trên thẻ không làm gì).
## UC4 Lên cấp (nhặt Ấn) thì thẻ và chi tiết đổi theo cấp mới, vẫn không lộ cấp sau.
## UC5 Trang Vũ khí chia nhóm Cận chiến / Đánh xa; mỗi nhóm hiện mọi vũ khí đã có (kể cả đang không trang bị),
##     đánh dấu cái đang trang bị; nhóm trống ghi "chưa có".
## UC6 Enter trên vũ khí chưa trang bị -> trang bị vào nhóm đó (ở đâu cũng được). Đang cầm nhóm đó thì đổi vũ khí trên tay;
##     đang cầm nhóm khác thì giữ nguyên tay. Vũ khí cũ vẫn còn trong danh sách.
## UC7 Chi tiết vũ khí có chỉ số và dòng hướng dẫn một dòng có ô phím ngay trong bảng.
## UC8 Lưu / đọc giữ danh sách vũ khí đã có; save cũ không có trường mới vẫn đọc được.
## UC9 Vật phẩm: ô không có hộp nền; không có gì thì hiện dòng trống.
## UC10 Hướng dẫn: gom theo phân loại có tiêu đề; mục đang chọn có vạch vàng bên trái, mục khác không có nền xám.
## UC11 Bảng chi tiết có thanh cuộn mỏng.
## UC12 Cực đoan: 7 kiếm, tên rất dài, không có vũ khí nào -> không lỗi, ô không đè lên bảng chi tiết.
##
## ===== TEST CASE =====
## TC1 (UC1) Tên các trang Tab đang hiện = [Bùa, Vật phẩm, Nguyên tố, Vũ khí].
## TC2 (UC2) Chỉ có Gió: 1 thẻ; trang không còn WeaponSocket; điểm ảnh trong mép thẻ ~ điểm ảnh nền ngoài thẻ.
## TC3 (UC3) Chi tiết Gió cấp 1: có "Thổi gió" + "Đẩy lùi kẻ địch"; không có "Lốc xoáy", "Chữ tạm", "LỘ TRÌNH", "ghép",
##     "Enter"; chấm cấp (1, 3).
## TC4 (UC3) Có 5 Ấn Gió: Enter và phím phụ trên thẻ -> cấp vẫn 1, không ghép, thẻ không bị "cầm".
## TC5 (UC4) Lên cấp 2: thẻ cấp 2; chi tiết có "Lốc xoáy" + "Cơn lốc hút"; không có "Thổi gió III", "Chữ tạm"; chấm (2, 3).
## TC6 (UC2) Chưa có nguyên tố: 0 thẻ, dòng trống hiện.
## TC7 (UC5) Thêm kiếm thứ hai vào danh sách: nhóm Cận chiến 2 ô, Đánh xa 1 ô; tiêu đề hai nhóm đúng; ô kiếm gốc
##     là đang trang bị.
## TC8 (UC6) Enter trên kiếm thứ hai (đang cầm kiếm): ô kiếm = kiếm 2, tay = kiếm 2, weapon_changed phát 1 lần;
##     nhóm vẫn 2 ô. Enter lại trên ô đang trang bị: không phát thêm.
## TC9 (UC6) Đang cầm cung, trang bị lại kiếm gốc: ô kiếm đổi, tay vẫn cung, weapon_changed không phát.
## TC10 (UC7) Chi tiết vũ khí chưa trang bị có "SÁT THƯƠNG" và ô phím Enter hiện; vũ khí đang trang bị không có ô phím.
## TC11 (UC8) weapons = [cung], danh sách = [kiếm] -> to_dict / from_dict giữ kiếm trong danh sách; dict cũ -> rỗng.
## TC12 (UC9) Ô vật phẩm: điểm ảnh trong mép ~ nền; bỏ hết vật phẩm -> dòng trống hiện.
## TC13 (UC10) Mở 2 phân loại: số tiêu đề = 2, thẻ cùng loại liền nhau; thẻ đang chọn: điểm ảnh mép trái gần màu accent;
##     thẻ khác: mép trái ~ nền.
## TC14 (UC11) Thanh cuộn dọc bảng chi tiết rộng <= style.detail_scrollbar_width + 1.
## TC15 (UC12) 7 kiếm tên dài: đủ 7 ô, ô cuối không đè lên bảng chi tiết; không có vũ khí -> 2 nhóm đều ghi trống.

const MENU := "res://ui/menus/inventory/inventory_menu.tscn"
const WIND := "res://abilities/wind_blast/wind_blast.tres"
const SWORD := "res://resources/combat/weapons/sword.tres"
const BOW := "res://resources/combat/weapons/bow.tres"
const SEAL := "res://resources/player/items/upgrades/wind_seal.tres"
## Sai khác màu tối đa để coi hai điểm ảnh là "cùng nền"
const SAME_COLOR := 0.035

var _fails: int = 0
var _menu: InventoryMenu
var _shots: String = ""
var _weapon_signals: int = 0
var _sword: WeaponData
var _bow: WeaponData
var _spare: WeaponData


func _ready() -> void:
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var saved := GameState.progress
	_sword = load(SWORD) as WeaponData
	_bow = load(BOW) as WeaponData
	_spare = _sword.duplicate() as WeaponData
	_spare.display_name = "Kiếm Thử"
	_spare.description = "Kiếm dùng để thử."
	GameState.replace_progress(_fixture())
	GameState.weapon_changed.connect(func(_w: WeaponData) -> void: _weapon_signals += 1)
	var scene_fill := ColorRect.new()
	scene_fill.color = Color(0.27, 0.36, 0.4)
	scene_fill.size = get_viewport().get_visible_rect().size
	add_child(scene_fill)
	var layer := CanvasLayer.new()
	add_child(layer)
	_menu = (load(MENU) as PackedScene).instantiate() as InventoryMenu
	layer.add_child(_menu)
	await _frames(3)
	_menu.open()
	await _wait(0.4)
	_tc1_order()
	await _tc2_elements_cards()
	await _tc3_element_detail()
	await _tc4_no_actions()
	await _tc5_level_two()
	await _tc6_no_elements()
	await _tc7_weapon_groups()
	await _tc8_equip_held()
	await _tc9_equip_other_slot()
	await _tc10_weapon_detail()
	_tc11_save()
	await _tc12_items()
	await _tc13_tutorials()
	_tc14_scrollbar()
	await _tc15_extreme()
	_menu.close()
	await _wait(0.3)
	GameState.replace_progress(saved)
	print("RESULT fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _fixture() -> PlayerProgress:
	var progress := PlayerProgress.new()
	progress.weapons.append(_sword)
	progress.weapons.append(_bow)
	progress.weapon = _sword
	progress.abilities.append(load(WIND) as AbilityData)
	progress.items[&"wind_seal"] = 5
	return progress


func _tc1_order() -> void:
	var titles := PackedStringArray()
	for page: MenuPage in _menu._tab_pages:
		if page.is_available():
			titles.append(page.page_title)
	_check(titles == PackedStringArray(["Bùa", "Vật phẩm", "Nguyên tố", "Vũ khí"]), "TC1 thứ tự trang (%s)" % ", ".join(titles))


func _elements() -> ElementsPage:
	return _menu.find_child("ElementsPage", true, false) as ElementsPage


func _weapons() -> MenuPage:
	return _menu.find_child("WeaponsPage", true, false) as MenuPage


func _tc2_elements_cards() -> void:
	await _go_to(ElementsPage)
	var page := _elements()
	_check(page != null and page._cards.size() == 1, "TC2 chỉ có Gió -> 1 thẻ (%d)" % (page._cards.size() if page else -1))
	_check(page != null and page.find_children("*", "WeaponSocket", true, false).is_empty(), "TC2 trang Nguyên tố không còn ô ghép vũ khí")
	if page and not page._cards.is_empty():
		_check(await _no_box(page._cards[0]), "TC2 thẻ nguyên tố không có hộp nền")
	await _shot("p3_elements")


func _tc3_element_detail() -> void:
	var page := _elements()
	if page == null or page._cards.is_empty():
		_check(false, "TC3 không có thẻ")
		return
	page._cards[0].grab_focus()
	await _frames(3)
	var text := _detail_text()
	_check(text.contains("Thổi gió") and text.contains("Đẩy lùi kẻ địch"), "TC3 tên + mô tả ngắn cấp 1 ('%s')" % text.left(160))
	for banned: String in ["Lốc xoáy", "Chữ tạm", "LỘ TRÌNH", "ghép", "Enter"]:
		_check(not text.to_lower().contains(banned.to_lower()), "TC3 không có '%s'" % banned)
	_check(_pips() == Vector2i(1, 3), "TC3 chấm cấp (1, 3) (%s)" % _pips())


func _tc4_no_actions() -> void:
	var page := _elements()
	if page == null or page._cards.is_empty():
		return
	var wind := load(WIND) as AbilityData
	page._cards[0].grab_focus()
	await _key(KEY_ENTER)
	await _action(&"interact")
	await _wait(0.2)
	_check(GameState.get_ability_level(wind) == 1, "TC4 Enter / phím phụ không nâng cấp (cấp %d)" % GameState.get_ability_level(wind))
	_check(GameState.progress.fusions.is_empty(), "TC4 không ghép (%s)" % GameState.progress.fusions)
	_check(not page._cards[0].held, "TC4 thẻ không bị cầm")


func _tc5_level_two() -> void:
	var wind := load(WIND) as AbilityData
	_check(GameState.upgrade_ability(wind), "TC5 chuẩn bị: lên cấp 2")
	await _frames(3)
	var page := _elements()
	page._cards[0].grab_focus()
	await _frames(3)
	var text := _detail_text()
	_check(page._cards[0].level == 2, "TC5 thẻ cấp 2")
	_check(text.contains("Lốc xoáy") and text.contains("Cơn lốc hút"), "TC5 tên + mô tả cấp 2 ('%s')" % text.left(160))
	_check(not text.contains("Thổi gió III") and not text.contains("Chữ tạm"), "TC5 không lộ cấp 3")
	_check(_pips() == Vector2i(2, 3), "TC5 chấm cấp (2, 3) (%s)" % _pips())
	await _shot("p3_elements_l2")


func _tc6_no_elements() -> void:
	var keep := GameState.progress.abilities.duplicate()
	GameState.progress.abilities.clear()
	GameState.progress_changed.emit()
	await _frames(3)
	var page := _elements()
	var empty := page.get_node_or_null(^"Layout/Empty") as Label if page else null
	_check(page != null and page._cards.is_empty(), "TC6 chưa có nguyên tố -> 0 thẻ")
	_check(empty != null and empty.is_visible_in_tree(), "TC6 dòng trống hiện")
	GameState.progress.abilities.assign(keep)
	GameState.progress_changed.emit()
	await _frames(3)


func _tc7_weapon_groups() -> void:
	GameState.progress.weapon_collection.append(_spare)
	GameState.progress_changed.emit()
	await _go_to(_weapons_type())
	var page := _weapons()
	_check(page != null and _menu.get_current_page() == page, "TC7 tới trang Vũ khí")
	if page == null:
		return
	var melee: Array = page.get_group_tiles(WeaponData.Slot.SWORD)
	var ranged: Array = page.get_group_tiles(WeaponData.Slot.BOW)
	_check(melee.size() == 2 and ranged.size() == 1, "TC7 Cận chiến 2 ô, Đánh xa 1 ô (%d, %d)" % [melee.size(), ranged.size()])
	var heading_a: String = page.get_group_heading(WeaponData.Slot.SWORD).text
	var heading_b: String = page.get_group_heading(WeaponData.Slot.BOW).text
	_check(heading_a.to_upper().contains("CẬN CHIẾN") and heading_b.to_upper().contains("ĐÁNH XA"), "TC7 tiêu đề nhóm ('%s', '%s')" % [heading_a, heading_b])
	var original := _tile_of(melee, _sword)
	_check(original != null and original.equipped and not _tile_of(melee, _spare).equipped, "TC7 kiếm gốc đang trang bị, kiếm 2 thì không")
	await _shot("p3_weapons")


func _tc8_equip_held() -> void:
	var page := _weapons()
	if page == null:
		return
	_weapon_signals = 0
	_tile_of(page.get_group_tiles(WeaponData.Slot.SWORD), _spare).grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	await _frames(3)
	_check(GameState.get_weapon_in_slot(WeaponData.Slot.SWORD) == _spare, "TC8 ô kiếm = kiếm 2")
	_check(GameState.get_weapon() == _spare, "TC8 đang cầm kiếm -> tay đổi sang kiếm 2")
	_check(_weapon_signals == 1, "TC8 weapon_changed phát 1 lần (%d)" % _weapon_signals)
	var melee: Array = page.get_group_tiles(WeaponData.Slot.SWORD)
	_check(melee.size() == 2 and _tile_of(melee, _spare).equipped and not _tile_of(melee, _sword).equipped, "TC8 vẫn 2 ô, dấu trang bị đổi sang kiếm 2")
	_tile_of(melee, _spare).grab_focus()
	await _key(KEY_ENTER)
	await _frames(2)
	_check(_weapon_signals == 1, "TC8 Enter trên ô đang trang bị không phát thêm (%d)" % _weapon_signals)


func _tc9_equip_other_slot() -> void:
	var page := _weapons()
	if page == null:
		return
	GameState.set_weapon(_bow)
	await _frames(2)
	_weapon_signals = 0
	_tile_of(page.get_group_tiles(WeaponData.Slot.SWORD), _sword).grab_focus()
	await _key(KEY_ENTER)
	await _frames(3)
	_check(GameState.get_weapon_in_slot(WeaponData.Slot.SWORD) == _sword, "TC9 ô kiếm đổi về kiếm gốc")
	_check(GameState.get_weapon() == _bow and _weapon_signals == 0, "TC9 tay vẫn cầm cung, không phát weapon_changed (%d)" % _weapon_signals)
	GameState.set_weapon(_sword)


func _tc10_weapon_detail() -> void:
	var page := _weapons()
	if page == null:
		return
	_tile_of(page.get_group_tiles(WeaponData.Slot.SWORD), _spare).grab_focus()
	await _frames(3)
	var text := _detail_text()
	var key := _hint_key()
	_check(text.to_upper().contains("SÁT THƯƠNG"), "TC10 chi tiết có chỉ số ('%s')" % text.left(200))
	_check(key != null and key.is_visible_in_tree() and key.text == PageTabs.key_name(&"ui_accept"), "TC10 dòng hướng dẫn có ô phím Enter")
	await _shot("p3_weapon_detail")
	_tile_of(page.get_group_tiles(WeaponData.Slot.SWORD), _sword).grab_focus()
	await _frames(3)
	key = _hint_key()
	_check(key == null or not key.is_visible_in_tree(), "TC10 vũ khí đang trang bị không có ô phím")


func _tc11_save() -> void:
	var progress := PlayerProgress.new()
	progress.weapons.append(_bow)
	progress.weapon = _bow
	progress.weapon_collection.append(_sword)
	var copy := SaveManager.from_dict(JSON.parse_string(JSON.stringify(SaveManager.to_dict(progress))))
	_check(copy.weapon_collection.has(_sword), "TC11 danh sách vũ khí giữ kiếm (%s)" % copy.weapon_collection)
	_check(copy.get_weapon_in_slot(WeaponData.Slot.SWORD) == null, "TC11 kiếm không tự thành đang trang bị")
	var old := SaveManager.from_dict({"version": 6, "weapon": BOW, "weapons": [BOW]})
	_check(old.weapon_collection.is_empty() and old.weapon == _bow, "TC11 save cũ đọc được, danh sách rỗng")


func _tc12_items() -> void:
	await _go_to(ItemsPage)
	var page := _menu.get_current_page() as ItemsPage
	_check(page != null and not page._tiles.is_empty(), "TC12 trang Vật phẩm có ô")
	if page == null or page._tiles.is_empty():
		return
	page._tiles[0].grab_focus()
	await _frames(3)
	_check(await _no_box(page._tiles[0]), "TC12 ô vật phẩm không có hộp nền")
	await _shot("p3_items")
	var keep := GameState.progress.items.duplicate()
	GameState.progress.items.clear()
	GameState.progress_changed.emit()
	await _frames(3)
	_check(page._empty.is_visible_in_tree(), "TC12 hết vật phẩm -> dòng trống hiện")
	GameState.progress.items.merge(keep)
	GameState.progress_changed.emit()
	await _frames(2)


func _tc13_tutorials() -> void:
	var picked: Array[TutorialData] = []
	var categories: Array[String] = []
	for tutorial: TutorialData in GameState.TUTORIALS.tutorials:
		if tutorial == null:
			continue
		if not categories.has(tutorial.category) and categories.size() < 2:
			categories.append(tutorial.category)
		if categories.has(tutorial.category) and picked.size() < 4:
			picked.append(tutorial)
	# Xen kẽ thứ tự mở để kiểm tra trang tự gom
	picked.sort_custom(func(a: TutorialData, b: TutorialData) -> bool: return a.category < b.category)
	var mixed: Array[TutorialData] = []
	while not picked.is_empty():
		mixed.append(picked.pop_front())
		if not picked.is_empty():
			mixed.append(picked.pop_back())
	for tutorial in mixed:
		GameState.unlock_tutorial(tutorial, false)
	_menu.close()
	await _wait(0.3)
	_menu.open_to_page_type(TutorialsPage)
	await _wait(0.4)
	var page := _menu.get_current_page() as TutorialsPage
	_check(page != null, "TC13 mở trang Hướng dẫn")
	if page == null:
		return
	var headings: Array = page.get_category_headings()
	_check(headings.size() == categories.size(), "TC13 số tiêu đề phân loại = %d (%d)" % [categories.size(), headings.size()])
	var order: Array[String] = []
	for card: TutorialCard in page._cards:
		if order.is_empty() or order.back() != card.tutorial.category:
			order.append(card.tutorial.category)
	_check(order.size() == categories.size(), "TC13 thẻ cùng loại liền nhau (%s)" % ", ".join(order))
	if page._cards.size() >= 2:
		page._cards[0].grab_focus()
		await _wait(0.3)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var focus_rect := page._cards[0].get_global_rect()
		var other_rect := page._cards[1].get_global_rect()
		var marker := image.get_pixelv(Vector2i(int(focus_rect.position.x) + 1, int(focus_rect.get_center().y)))
		var accent := _menu.style.accent
		_check(_distance(marker, accent) < 0.25, "TC13 thẻ đang chọn có vạch vàng bên trái (%s)" % marker)
		var edge := image.get_pixelv(Vector2i(int(other_rect.position.x) + 4, int(other_rect.position.y) + 3))
		var outside := image.get_pixelv(Vector2i(int(other_rect.position.x) - 6, int(other_rect.position.y) + 3))
		_check(_distance(edge, outside) < SAME_COLOR, "TC13 thẻ khác không có nền (%s / %s)" % [edge, outside])
	await _shot("p3_tutorials")
	_menu.close()
	await _wait(0.3)
	_menu.open()
	await _wait(0.4)


func _tc14_scrollbar() -> void:
	var detail := _menu.find_child("Detail", true, false)
	var scroll := detail.find_child("Scroll", true, false) as ScrollContainer if detail else null
	var width := scroll.get_v_scroll_bar().get_combined_minimum_size().x if scroll else 999.0
	_check(scroll != null and width <= _menu.style.detail_scrollbar_width + 1.0, "TC14 thanh cuộn mỏng (%.1f px)" % width)


func _tc15_extreme() -> void:
	var extras: Array[WeaponData] = []
	for index in 6:
		var weapon := _sword.duplicate() as WeaponData
		weapon.display_name = "Kiếm có cái tên rất rất dài để xem chữ có tràn ra ngoài ô không số %d" % index
		extras.append(weapon)
	GameState.progress.weapon_collection.append_array(extras)
	GameState.progress_changed.emit()
	await _go_to(_weapons_type())
	var page := _weapons()
	if page == null:
		_check(false, "TC15 không có trang Vũ khí")
		return
	var melee: Array = page.get_group_tiles(WeaponData.Slot.SWORD)
	_check(melee.size() == 8, "TC15 đủ 8 ô cận chiến (%d)" % melee.size())
	var detail := (_menu.find_child("Detail", true, false) as Control).get_global_rect()
	var last := (melee.back() as Control)
	last.grab_focus()
	await _wait(0.3)
	_check(last.get_global_rect().end.x <= detail.position.x + 1.0, "TC15 ô cuối không đè bảng chi tiết (%s / %s)" % [last.get_global_rect(), detail.position.x])
	await _shot("p3_weapons_many")
	var bare := PlayerProgress.new()
	GameState.replace_progress(bare)
	await _frames(3)
	var empty_a: Control = page.get_group_empty(WeaponData.Slot.SWORD)
	var empty_b: Control = page.get_group_empty(WeaponData.Slot.BOW)
	_check(empty_a.is_visible_in_tree() and empty_b.is_visible_in_tree(), "TC15 không có vũ khí -> 2 nhóm ghi trống")
	_check(page.get_group_tiles(WeaponData.Slot.SWORD).is_empty(), "TC15 không có vũ khí -> 0 ô")


func _weapons_type() -> Variant:
	var page := _weapons()
	return page.get_script() if page else MenuPage


func _tile_of(tiles: Array, weapon: WeaponData) -> Control:
	for tile: Variant in tiles:
		if tile.weapon == weapon:
			return tile as Control
	return null


func _pips() -> Vector2i:
	var detail := _menu.find_child("Detail", true, false) as DetailPanel
	return detail.get_pips() if detail and detail.has_method(&"get_pips") else Vector2i(-1, -1)


func _hint_key() -> KeyGlyph:
	var detail := _menu.find_child("Detail", true, false)
	var keys := detail.find_children("*", "KeyGlyph", true, false) if detail else []
	return keys[0] as KeyGlyph if not keys.is_empty() else null


## Ô không có hộp nền: điểm ảnh ngay trong mép ô gần như trùng điểm ảnh nền ngay ngoài ô
func _no_box(tile: Control) -> bool:
	if DisplayServer.get_name() == "headless":
		print("SKIP đo điểm ảnh (headless)")
		return true
	await _wait(0.3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var rect := tile.get_global_rect()
	# Góc dưới trái: xa hình vẽ ở giữa ô và xa ngoặc chọn ở góc trên
	var inside := image.get_pixelv(Vector2i(int(rect.position.x + rect.size.x * 0.5), int(rect.end.y) - 3))
	var outside := image.get_pixelv(Vector2i(int(rect.position.x + rect.size.x * 0.5), int(rect.end.y) + 6))
	var ok := _distance(inside, outside) < SAME_COLOR
	if not ok:
		print("  điểm ảnh trong %s / ngoài %s" % [inside, outside])
	return ok


func _distance(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


func _detail_text() -> String:
	var parts := PackedStringArray()
	for label in _menu.get_node("Body/Columns/Detail").find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			parts.append((label as Label).text)
	return " | ".join(parts)


func _go_to(page_type: Variant) -> void:
	for _i: int in range(6):
		if is_instance_of(_menu.get_current_page(), page_type):
			return
		await _action(&"menu_next_page")
		await _wait(0.3)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _frames(2)


func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _frames(2)


func _shot(name_: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join("%s.png" % name_))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
