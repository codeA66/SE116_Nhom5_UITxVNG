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
## UC11 Vật phẩm dùng phím: có TNT thì nằm trong trang Vật phẩm (loại Dụng cụ); Enter chọn dùng (phím T) / bỏ chọn.

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
	await _uc11_quick_items()
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
	_check(text.contains("LỘ TRÌNH NÂNG CẤP") and text.contains("Ấn Gió   0 / 2") and text.contains("Thổi gió III"), "UC1: chi tiết có lộ trình nâng cấp + vật phẩm cần ('%s')" % text.left(260))
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
	_check(titles.has("Bùa"), "UC6: trang Bùa luôn hiện kể cả chưa có bùa (%s)" % ", ".join(titles))
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


## Bùa thử chỉ có trong test (không vào danh mục thật); dùng lại icon có sẵn để thấy hình
func _make_charm(id: StringName, title: String, cost: int, icon_path: String = "") -> CharmData:
	var charm := CharmData.new()
	charm.id = id
	charm.display_name = title
	charm.notch_cost = cost
	charm.description = "Bùa thử cho test."
	charm.lore = "Câu truyện thử."
	if not icon_path.is_empty():
		charm.icon = load(icon_path) as Texture2D
	return charm


func _charms_page() -> CharmsPage:
	return _menu.get_node("Body/Pages/CharmsPage") as CharmsPage


func _uc7_charms() -> void:
	# Chưa có bùa nào (danh mục thật đang trống): trang vẫn hiện, có ô trống + dòng "chưa có bùa"
	await _action(&"menu_next_page")
	await _action(&"menu_next_page")
	await _wait(0.4)
	var page := _menu.get_current_page() as CharmsPage
	_check(page != null, "UC7: C C -> trang Bùa (%s)" % _menu.get_current_page())
	if page == null:
		return
	_check(page._empty.visible and page._equipped_tiles.size() == 1 and page._equipped_tiles[0].mode == CharmTile.Mode.EMPTY_SLOT, "UC7: chưa có bùa -> dòng trống + 1 ô trống")
	_check(page._notch_label.text == "Ô KHẮC  0 / 3", "UC7: ô khắc 0 / 3 ('%s')" % page._notch_label.text)
	await _shot("charms_empty")
	var light := _make_charm(&"test_light", "Lông Vũ Thử", 1, "res://ui/hud/icons/wind.svg")
	var heavy := _make_charm(&"test_heavy", "Tim Bão Thử", 3, "res://ui/hud/icons/fire.svg")
	var mid := _make_charm(&"test_mid", "Lưỡi Gió Thử", 2, "res://ui/hud/icons/sword.svg")
	var hidden := _make_charm(&"test_hidden", "Bùa Giấu Thử", 1)
	for charm: CharmData in [light, heavy, mid, hidden]:
		GameState.ITEMS.charms.append(charm)
	for charm: CharmData in [light, heavy, mid]:
		GameState.add_charm(charm)
	await _frames(3)
	_check(page._grid_tiles.size() == 4, "UC7: lưới đủ 4 ô theo danh mục (%d)" % page._grid_tiles.size())
	_check(page._collection_heading.text == "BỘ SƯU TẬP  3 / 4", "UC7: tiêu đề bộ sưu tập ('%s')" % page._collection_heading.text)
	page._grid_tiles[3].grab_focus()
	await _frames(2)
	_check(not page._grid_tiles[3].owned and _detail_text().contains("???"), "UC7: bùa chưa tìm thấy -> bóng tối '???'")
	# Ngoài khu đổi bùa: rung + trạng thái đỏ, không đeo
	page._grid_tiles[0].grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	_check(not GameState.is_charm_equipped(&"test_light"), "UC7: ngoài khu đổi bùa -> không đeo được")
	_check(page._grid_tiles[0]._shake > 0.0 or page._grid_tiles[0]._fx_tween.is_running(), "UC7: ô rung khi bị từ chối")
	_check(page._status.get_theme_color(&"font_color") == _menu.style.warning and page._status.text.contains("khu đổi bùa"), "UC7: dòng trạng thái đỏ ghi lý do")
	GameState.enter_charm_station()
	await _wait(0.4)
	await _action(&"ui_accept")
	_check(GameState.is_charm_equipped(&"test_light") and GameState.get_used_notches() == 1, "UC7: trong khu -> đeo bùa 1 ô")
	await _frames(3)
	_check(page._ghost.visible, "UC7: bùa đang bay lên hàng đang đeo")
	await _wait(_menu.style.charm_fly_time + 0.3)
	_check(not page._ghost.visible, "UC7: bay xong -> bóng biến mất")
	var worn := page._find_tile(page._equipped_tiles, &"test_light")
	_check(worn != null and worn.modulate.a == 1.0, "UC7: ô đang đeo hiện bùa vừa đeo")
	_check(is_equal_approx(page._notches.used, 1.0), "UC7: hạt ô khắc sáng lên 1 (%.2f)" % page._notches.used)
	await _shot("charms_equipped")
	# Bùa 3 ô khi còn 2 ô: từ chối
	page._grid_tiles[1].grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	_check(not GameState.is_charm_equipped(&"test_heavy") and page._status.text.contains("Không đủ ô khắc"), "UC7: bùa 3 ô báo thiếu ô khắc")
	# Tháo từ hàng đang đeo: con trỏ về ô của bùa đó trong lưới
	worn.grab_focus()
	await _frames(2)
	await _action(&"ui_accept")
	await _frames(3)
	_check(not GameState.is_charm_equipped(&"test_light"), "UC7: tháo bùa từ hàng đang đeo")
	_check(get_viewport().gui_get_focus_owner() == page._grid_tiles[0], "UC7: tháo xong con trỏ về ô bùa trong lưới")
	await _wait(_menu.style.charm_fly_time + 0.3)
	_check(not page._ghost.visible and is_equal_approx(page._notches.used, 0.0), "UC7: bay về xong, ô khắc tắt hết")
	GameState.exit_charm_station()
	for charm: CharmData in [light, heavy, mid, hidden]:
		GameState.ITEMS.charms.erase(charm)
	GameState.progress.charms.clear()


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
	_check(card._flash > 0.0, "UC8: vừa lên cấp -> thẻ Gió lóe sáng khi mở Tab (%.2f)" % card._flash)
	card.grab_focus()
	await _frames(2)
	var text := _detail_text()
	_check(text.contains("ĐANG DÙNG") and text.contains("ĐÃ MỞ") and text.contains("Ấn Gió   0 / 3"), "UC8: lộ trình: cấp II đang dùng, cấp I đã mở, cấp III cần 3 Ấn ('%s')" % text.left(300))
	await _shot("upgrade_path")
	_menu.close()
	await _wait(0.3)
	await _key(KEY_TAB)
	await _wait(0.5)
	_check(card._flash <= 0.0 or not card.is_visible_in_tree(), "UC8: mở lại lần nữa -> không lóe lại")


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
	# Bùa cực đoan: 30 bùa, 12 ô khắc, đeo kín, tên rất dài
	var many: Array[CharmData] = []
	for index in 30:
		var charm := _make_charm(StringName("test_many_%d" % index), "Bùa thử có cái tên rất rất dài số %d" % index, 1 + index % 3, "res://ui/hud/icons/wind.svg" if index % 2 == 0 else "")
		GameState.ITEMS.charms.append(charm)
		many.append(charm)
		GameState.add_charm(charm)
	GameState.progress.charm_notches = 12
	GameState.enter_charm_station()
	for index in 6:
		GameState.equip_charm(many[index * 2].id)
	await _action(&"menu_next_page")
	await _wait(0.5)
	var charms := _menu.get_current_page() as CharmsPage
	_check(charms != null and charms._grid_tiles.size() == 30, "UC10: 30 bùa hiện đủ trong lưới")
	if charms:
		var used := GameState.get_used_notches()
		_check(charms._notch_label.text == "Ô KHẮC  %d / 12" % used, "UC10: 12 ô khắc ('%s')" % charms._notch_label.text)
		var footer_top := get_viewport().get_visible_rect().size.y - 64.0
		var scroll_rect := charms._scroll.get_global_rect()
		_check(scroll_rect.end.y <= footer_top, "UC10: vùng lưới bùa không tràn xuống dòng hướng dẫn (đáy %.0f / %.0f)" % [scroll_rect.end.y, footer_top])
		# Chọn bùa cuối: vùng cuộn tự cuộn tới, ô nằm trọn trong vùng nhìn thấy
		charms._grid_tiles[29].grab_focus()
		await _wait(0.3)
		var last_rect := charms._grid_tiles[29].get_global_rect()
		_check(scroll_rect.encloses(last_rect), "UC10: chọn bùa cuối -> tự cuộn tới, thấy trọn ô (%s trong %s)" % [last_rect, scroll_rect])
		var row_rect := charms._equipped_row.get_global_rect()
		_check(row_rect.end.x <= _menu.get_node("Body/Detail").get_global_rect().position.x, "UC10: hàng đang đeo không đè lên bảng chi tiết")
	await _shot("charms_many")
	GameState.exit_charm_station()
	for charm: CharmData in many:
		GameState.ITEMS.charms.erase(charm)
	GameState.progress.charms.clear()
	GameState.progress.equipped_charms.clear()
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


func _uc11_quick_items() -> void:
	GameState.replace_progress(_fixture())
	GameState.set_flag(&"level_3.tnt")
	await _key(KEY_TAB)
	for _i: int in range(4):
		if _menu.get_current_page() is ItemsPage:
			break
		await _action(&"menu_next_page")
	var page := _menu.get_current_page() as ItemsPage
	var tile: ItemTile = null
	if page:
		for candidate: ItemTile in page._tiles:
			if candidate.item.id == &"tnt":
				tile = candidate
	_check(tile != null, "UC11: có TNT -> nằm trong trang Vật phẩm")
	if tile == null:
		_menu.close()
		await _frames(40)
		return
	tile.grab_focus()
	await _frames(2)
	_check(not tile.is_selected_item() and _detail_text().contains("Dụng cụ") and _detail_text().contains("Chưa dùng"), "UC11: TNT chưa chọn dùng, chi tiết ghi loại Dụng cụ ('%s')" % _detail_text().left(80))
	await _action(&"ui_accept")
	_check(GameState.get_selected_item() != null and GameState.get_selected_item().id == &"tnt" and tile.is_selected_item() and _detail_text().contains("Đang dùng"), "UC11: Enter -> chọn dùng TNT (phím T), chi tiết cập nhật")
	await _action(&"ui_accept")
	_check(GameState.get_selected_item() == null and not tile.is_selected_item(), "UC11: Enter lần nữa -> bỏ chọn")
	var seal_tile: ItemTile = null
	for candidate: ItemTile in page._tiles:
		if candidate.item.id != &"tnt":
			seal_tile = candidate
	if seal_tile:
		seal_tile.grab_focus()
		await _action(&"ui_accept")
		_check(GameState.get_selected_item() == null, "UC11: Enter trên vật phẩm thường (%s) không chọn gì" % seal_tile.item.display_name)
	tile.grab_focus()
	await _action(&"ui_accept")
	await _shot("items_tnt")
	_menu.close()
	await _frames(40)


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
