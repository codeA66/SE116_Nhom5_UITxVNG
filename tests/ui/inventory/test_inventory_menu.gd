extends Node
## Test màn Tab mới. Bấm phím / chuột thật (Input.parse_input_event), tiến trình giả trong bộ nhớ, không ghi save thật.
## Chạy: mở test_inventory_menu.tscn rồi F6, hoặc headless (chụp ảnh chỉ khi có cửa sổ).
##
## ===== USE CASE =====
## UC1  Tab mở màn, trang Nguyên tố, con trỏ ở thẻ đầu; bảng chi tiết ghi tên, cấp 1/3, yêu cầu nâng cấp (thiếu -> cảnh báo).
## UC2  Ghép bằng phím: Enter trên thẻ Gió (cầm) -> con trỏ sang Kiếm -> Enter -> Gió ghép vào Kiếm, thẻ báo đang ghép.
## UC3  Enter trên vũ khí đang ghép (không cầm gì) -> tháo.
## UC4  Ghép bằng chuột: kéo thẻ Lửa thả vào Cung -> ghép.
## UC5  Esc khi đang cầm nguyên tố chỉ bỏ cầm, không đóng; Esc lần nữa mới đóng.
## UC6  C / Z đổi trang: Vật phẩm hiện chìa khóa (theo cờ) và Ấn Gió x2; trang Bùa ẩn khi chưa có bùa.
## UC7  Bùa: có bùa thì trang Bùa hiện; ngoài khu đổi bùa không đeo được; trong khu: đeo bùa 1 ô được, bùa 3 ô báo thiếu; tháo được.
## UC8  NPC nâng cấp: đủ Ấn Gió -> lên cấp 2, vật phẩm bị trừ, tên thành "Thổi gió II", chấm cấp đổi; thiếu thì không đổi.
## UC9  Lưu / đọc: vật phẩm, cấp kỹ năng, bùa, bùa đang đeo, số ô khắc giữ nguyên qua to_dict / from_dict.
## UC10 Cực đoan: chưa có nguyên tố nào (thẻ "???"), 12 loại vật phẩm, tên vật phẩm rất dài -> không lỗi, vẫn chọn được.

const MENU := "res://ui/menus/inventory/inventory_menu.tscn"
const WIND := "res://abilities/wind_blast/wind_blast.tres"
const FIRE := "res://abilities/flame_breath/flame_breath.tres"
const SWORD := "res://resources/combat/weapons/sword.tres"
const BOW := "res://resources/combat/weapons/bow.tres"
const SEAL := "res://resources/player/items/upgrades/wind_seal.tres"

var _fails: int = 0
var _menu: InventoryMenu
var _shots: String = ""
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var saved := GameState.progress
	GameState.replace_progress(_fixture())
	# Nền giả cảnh game phía sau màn Tab
	var scene_fill := ColorRect.new()
	scene_fill.color = Color(0.27, 0.36, 0.4)
	scene_fill.size = get_viewport().get_visible_rect().size
	add_child(scene_fill)
	var layer := CanvasLayer.new()
	add_child(layer)
	_menu = (load(MENU) as PackedScene).instantiate() as InventoryMenu
	layer.add_child(_menu)
	await _frames(3)
	await _uc1_open()
	await _uc2_keyboard_fuse()
	await _uc3_unfuse()
	await _uc4_mouse_fuse()
	await _uc5_cancel()
	await _uc6_pages()
	await _uc7_charms()
	await _uc8_upgrade()
	_uc9_save()
	await _uc10_extreme()
	GameState.replace_progress(saved)
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _fixture() -> PlayerProgress:
	var progress := PlayerProgress.new()
	progress.weapons.append(load(SWORD) as WeaponData)
	progress.weapons.append(load(BOW) as WeaponData)
	progress.weapon = progress.weapons[0]
	progress.abilities.append(load(WIND) as AbilityData)
	progress.abilities.append(load(FIRE) as AbilityData)
	progress.flags[&"hub.wind_key"] = true
	progress.currencies[&"soul_jade"] = 120
	return progress


func _elements() -> ElementsPage:
	return _menu.get_node("Body/Pages/ElementsPage") as ElementsPage


func _detail_text() -> String:
	var parts := PackedStringArray()
	for label in _menu.get_node("Body/Detail").find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			parts.append((label as Label).text)
	return " | ".join(parts)


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _uc1_open() -> void:
	await _key(KEY_TAB)
	_check(_menu.visible and _menu.get_current_page() is ElementsPage, "UC1: Tab mở màn, trang Nguyên tố")
	var card := _focused() as ElementCard
	_check(card != null and card.element.id == &"wind", "UC1: con trỏ ở thẻ Gió (%s)" % _focused())
	var text := _detail_text()
	_check(text.contains("Thổi gió") and text.contains("Cấp 1 / 3"), "UC1: chi tiết có tên + cấp ('%s')" % text.left(120))
	_check(text.contains("Cần: 2 Ấn Gió (đang có 0)"), "UC1: chi tiết ghi yêu cầu nâng cấp")
	await _shot("elements")


func _uc2_keyboard_fuse() -> void:
	await _action(&"ui_accept")
	var card := _elements()._cards[0]
	_check(card.held, "UC2: Enter -> cầm thẻ Gió")
	var socket := _focused() as WeaponSocket
	_check(socket != null and socket.slot == WeaponData.Slot.SWORD, "UC2: con trỏ nhảy sang Kiếm")
	await _shot("held")
	await _action(&"ui_accept")
	_check(GameState.progress.fusions.get(WeaponData.Slot.SWORD) == &"wind", "UC2: Gió đã ghép vào Kiếm")
	_check(not card.held and card.fused_slot == WeaponData.Slot.SWORD, "UC2: thẻ hết cầm, báo đang ghép")
	card.grab_focus()
	await _frames(2)
	_check(_detail_text().contains("tạm khóa"), "UC2: chi tiết cảnh báo kỹ năng tạm khóa")


func _uc3_unfuse() -> void:
	_elements()._sockets[0].grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	_check(not GameState.progress.fusions.has(WeaponData.Slot.SWORD), "UC3: Enter trên Kiếm đang ghép -> tháo")


func _uc4_mouse_fuse() -> void:
	var card := _elements()._cards[1]
	var socket := _elements()._sockets[1]
	# Tọa độ giao diện -> tọa độ cửa sổ (cửa sổ lớn hơn khung thiết kế thì giao diện được phóng)
	var to_window := get_viewport().get_final_transform()
	var from := to_window * card.get_global_rect().get_center()
	var to := to_window * socket.get_global_rect().get_center()
	_last_mouse = from
	await _mouse_move(from)
	await _mouse_button(from, true)
	for step in 12:
		await _mouse_move(from.lerp(to, float(step + 1) / 12.0))
	await _mouse_button(to, false)
	await _frames(3)
	_check(GameState.progress.fusions.get(WeaponData.Slot.BOW) == &"fire", "UC4: kéo Lửa thả vào Cung -> ghép (%s)" % GameState.progress.fusions)
	await _shot("fused")


func _uc5_cancel() -> void:
	_elements()._cards[0].grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	await _action(&"ui_cancel")
	_check(_menu.visible and not _elements()._cards[0].held, "UC5: Esc khi đang cầm chỉ bỏ cầm, không đóng")
	await _action(&"ui_cancel")
	await _wait(0.3)
	_check(not _menu.visible, "UC5: Esc lần nữa đóng màn")
	await _key(KEY_TAB)


func _uc6_pages() -> void:
	GameState.add_item(load(SEAL) as ItemData, 2)
	var titles := PackedStringArray()
	for page: MenuPage in _menu._available_pages():
		titles.append(page.page_title)
	_check(not titles.has("Bùa"), "UC6: chưa có bùa -> không có trang Bùa (%s)" % ", ".join(titles))
	await _action(&"menu_next_page")
	await _wait(0.3)
	_check(_menu.get_current_page() is ItemsPage, "UC6: C -> trang Vật phẩm")
	var tiles := (_menu.get_current_page() as ItemsPage)._tiles
	var names := PackedStringArray()
	for tile: ItemTile in tiles:
		names.append("%s x%d" % [tile.item.display_name, tile.count])
	_check(names.has("Ấn Gió x2") and names.has("Chìa Khóa Gió x1"), "UC6: có Ấn Gió x2 và chìa khóa (%s)" % ", ".join(names))
	_check(_detail_text().contains("Đang có"), "UC6: chi tiết vật phẩm ghi số lượng ('%s')" % _detail_text().left(100))
	await _shot("items")
	await _action(&"menu_prev_page")
	await _wait(0.3)
	_check(_menu.get_current_page() is ElementsPage, "UC6: Z -> về Nguyên tố")


func _make_charm(id: StringName, title: String, cost: int) -> CharmData:
	var charm := CharmData.new()
	charm.id = id
	charm.display_name = title
	charm.notch_cost = cost
	charm.description = "Bùa thử cho test."
	return charm


func _uc7_charms() -> void:
	var light := _make_charm(&"test_light", "Lông Vũ Thử", 1)
	var heavy := _make_charm(&"test_heavy", "Tim Bão Thử", 3)
	GameState.ITEMS.charms.append(light)
	GameState.ITEMS.charms.append(heavy)
	GameState.add_charm(light)
	GameState.add_charm(heavy)
	await _frames(2)
	await _action(&"menu_next_page")
	await _action(&"menu_next_page")
	await _wait(0.3)
	var page := _menu.get_current_page() as CharmsPage
	_check(page != null, "UC7: có bùa -> trang Bùa hiện (%s)" % _menu.get_current_page())
	if page == null:
		return
	var first := page._tiles[0]
	first.grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	_check(not GameState.is_charm_equipped(&"test_light"), "UC7: ngoài khu đổi bùa -> không đeo được")
	GameState.enter_charm_station()
	await _frames(2)
	await _action(&"ui_accept")
	_check(GameState.is_charm_equipped(&"test_light") and GameState.get_used_notches() == 1, "UC7: trong khu -> đeo bùa 1 ô")
	page._tiles[1].grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	_check(not GameState.is_charm_equipped(&"test_heavy") and _detail_text().contains("Không đủ ô khắc"), "UC7: bùa 3 ô báo thiếu ô khắc")
	await _shot("charms")
	page._tiles[0].grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	_check(not GameState.is_charm_equipped(&"test_light"), "UC7: tháo bùa")
	GameState.exit_charm_station()
	GameState.ITEMS.charms.erase(light)
	GameState.ITEMS.charms.erase(heavy)


func _uc8_upgrade() -> void:
	var wind := load(WIND) as AbilityData
	var seal := load(SEAL) as ItemData
	_check(GameState.can_upgrade_ability(wind), "UC8: đủ 2 Ấn Gió -> nâng cấp được")
	_check(GameState.upgrade_ability(wind) and GameState.get_ability_level(wind) == 2, "UC8: lên cấp 2")
	_check(GameState.get_item_count(seal) == 0, "UC8: Ấn Gió bị lấy đi (còn %d)" % GameState.get_item_count(seal))
	_check(not GameState.upgrade_ability(wind) and GameState.get_ability_level(wind) == 2, "UC8: thiếu Ấn Gió -> không lên cấp 3")
	_check(wind.get_level_name(2) == "Thổi gió II", "UC8: tên cấp 2 = '%s'" % wind.get_level_name(2))
	_menu.close()
	await _wait(0.3)
	await _key(KEY_TAB)
	await _wait(0.3)
	# Màn mở lại đúng trang xem lần trước: về trang Nguyên tố như người chơi bấm Z
	for attempt in 3:
		if _menu.get_current_page() is ElementsPage:
			break
		await _action(&"menu_prev_page")
		await _wait(0.3)
	var card := _elements()._cards[0]
	_check(card.level == 2, "UC8: thẻ Gió hiện cấp 2 (%d)" % card.level)


func _uc9_save() -> void:
	var progress := GameState.progress
	progress.items[&"wind_seal"] = 4
	progress.charms.append(&"save_charm")
	progress.equipped_charms.append(&"save_charm")
	progress.charm_notches = 5
	var copy := SaveManager.from_dict(JSON.parse_string(JSON.stringify(SaveManager.to_dict(progress))))
	_check(copy.items.get(&"wind_seal", 0) == 4, "UC9: số vật phẩm giữ nguyên")
	_check(copy.ability_levels.get(&"wind_blast", 0) == 2, "UC9: cấp kỹ năng giữ nguyên")
	_check(copy.charms.has(&"save_charm") and copy.equipped_charms.has(&"save_charm"), "UC9: bùa + bùa đang đeo giữ nguyên")
	_check(copy.charm_notches == 5, "UC9: số ô khắc giữ nguyên")
	var old := SaveManager.from_dict({"version": 5})
	_check(old.items.is_empty() and old.charm_notches == -1, "UC9: save cũ (v5) không có trường mới -> mặc định")


func _uc10_extreme() -> void:
	var bare := PlayerProgress.new()
	GameState.replace_progress(bare)
	var extras: Array[ItemData] = []
	for index in 12:
		var item := ItemData.new()
		item.id = StringName("test_item_%d" % index)
		item.display_name = "Vật phẩm thử có cái tên rất rất dài số %d để xem chữ có tràn không" % index
		item.description = "Mô tả."
		GameState.ITEMS.items.append(item)
		extras.append(item)
		GameState.add_item(item, index + 1)
	_menu.close()
	await _wait(0.3)
	await _key(KEY_TAB)
	await _wait(0.3)
	var cards := _elements()._cards
	_check(cards.size() > 0 and not cards[0].owned, "UC10: chưa có nguyên tố -> thẻ '???'")
	await _action(&"menu_next_page")
	await _wait(0.3)
	var page := _menu.get_current_page() as ItemsPage
	_check(page != null and page._tiles.size() == 12, "UC10: 12 loại vật phẩm hiện đủ")
	await _shot("items_many")
	for item: ItemData in extras:
		GameState.ITEMS.items.erase(item)
	_menu.close()
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


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	# Đưa thẳng vào viewport: tọa độ trùng tọa độ giao diện (không qua tỉ lệ cửa sổ)
	get_viewport().push_input(event)
	await get_tree().process_frame


func _mouse_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.relative = at - _last_mouse
	_last_mouse = at
	get_viewport().push_input(event)
	await get_tree().process_frame


func _shot(name_: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join("inventory_%s.png" % name_))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
