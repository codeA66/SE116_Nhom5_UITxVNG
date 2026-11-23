extends Node
## Unit test nâng cấp trang Bùa (giai đoạn 2). Viết TRƯỚC khi code: chưa có code thì FAIL, code xong phải PASS hết.
## Chạy: mở tests/ui/inventory/test_charms_page_layout.tscn rồi F6. Tiến trình giả trong bộ nhớ, không ghi save thật.
## Kết quả: từng dòng PASS / FAIL, cuối cùng "RESULT fails=N".
##
## ===== USE CASE =====
## UC1 Trang Bùa không vẽ khung hộp quanh nội dung (chỉ còn nét trang trí góc màn).
## UC2 Lưới hiện ĐỦ mọi bùa trong danh mục (kiểu Hollow Knight): bùa đã có trước, xếp theo độ hiếm; bùa chưa có ở sau, kín tên.
## UC3 Tiêu đề bộ sưu tập ghi "đã có / tổng".
## UC4 Hàng "Đang đeo": đúng số bùa đang đeo + 1 ô trống khi còn khấc; đầy khấc thì không có ô trống.
## UC5 Ô "Đang đeo" vẽ dạng huy hiệu tròn như lưới (không còn kiểu treo dây), ô trống là vòng tròn mờ.
## UC6 Ô khắc vẽ hình tròn.
##
## ===== TEST CASE =====
## TC1 (UC1) page.get_body_panel_style() == null và khung Body của màn Tab là StyleBoxEmpty khi đang ở trang Bùa.
## TC2 (UC2) Danh mục 4 bùa (có 3): lưới 4 ô; 3 ô đầu owned, ô cuối không owned; ô cuối hiện tên "Bùa chưa tìm thấy".
## TC3 (UC2) Bùa hiếm (sort_priority cao) đứng trước bùa thường dù nằm sau trong danh mục.
## TC4 (UC3) Tiêu đề = "BỘ SƯU TẬP  3 / 4".
## TC5 (UC4) Đeo 1 bùa 1 khấc (còn 2): hàng đang đeo 2 ô (1 bùa + 1 trống). Đeo đủ 3 khấc: không còn ô trống.
## TC6 (UC5) Ô đang đeo dùng kiểu huy hiệu: tile.uses_pendant() == false; ô trống cũng không vẽ giá treo.
## TC7 (UC6) NotchRow vẽ tròn: notch_row.uses_round_notches() == true.

const MENU := "res://ui/menus/inventory/inventory_menu.tscn"

var _fails: int = 0
var _menu: InventoryMenu


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	var saved := GameState.progress
	var original_catalog: Array[CharmData] = GameState.ITEMS.charms.duplicate()
	GameState.replace_progress(PlayerProgress.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	_menu = (load(MENU) as PackedScene).instantiate() as InventoryMenu
	layer.add_child(_menu)
	await _frames(3)

	var common := _make(&"t_common", "Bùa Thường Thử", 1)
	var second := _make(&"t_second", "Bùa Hai Thử", 1)
	var late_rare := _make(&"t_rare", "Bùa Hiếm Thử", 1)
	late_rare.rarity = load("res://resources/player/items/charms/_rarity/rare.tres")
	var hidden := _make(&"t_hidden", "Bùa Giấu Thử", 1)
	GameState.ITEMS.charms.assign([common, second, late_rare, hidden])
	for charm: CharmData in [common, second, late_rare]:
		GameState.add_charm(charm)
	GameState.charms_changed.emit()
	_menu.open_to_page_type(CharmsPage)
	await _frames(4)
	var page := _menu.get_current_page() as CharmsPage
	_check(page != null, "chuẩn bị: mở được trang Bùa")
	if page == null:
		_finish(saved, original_catalog)
		return

	# TC1
	var body_box := (_menu.get_node(^"Body") as PanelContainer).get_theme_stylebox(&"panel")
	_check(page.get_body_panel_style() == null and body_box is StyleBoxEmpty, "TC1 trang Bùa không vẽ khung hộp (%s)" % body_box)

	# TC2 + TC3
	var tiles := page._grid_tiles
	_check(tiles.size() == 4, "TC2 lưới đủ 4 ô theo danh mục (%d)" % tiles.size())
	if tiles.size() == 4:
		_check(tiles[0].owned and tiles[1].owned and tiles[2].owned and not tiles[3].owned, "TC2 bùa đã có trước, bùa chưa có ở cuối")
		_check(tiles[3].get_detail().title == _menu.style.charm_hidden_text, "TC2 ô chưa có giữ kín tên ('%s')" % tiles[3].get_detail().title)
		_check(tiles[0].charm == late_rare, "TC3 bùa hiếm đứng đầu (%s)" % (tiles[0].charm.id if tiles[0].charm else &"null"))

	# TC4
	_check(page._collection_heading.text == "BỘ SƯU TẬP  3 / 4", "TC4 tiêu đề bộ sưu tập ('%s')" % page._collection_heading.text)

	# TC5
	GameState.enter_charm_station()
	GameState.equip_charm(&"t_common")
	await _frames(3)
	page.refresh()
	_check(page._equipped_tiles.filter(func(t: CharmTile) -> bool: return t.visible).size() == 2,
		"TC5 đeo 1/3 khấc: hàng đang đeo 2 ô (1 bùa + 1 trống)")
	GameState.equip_charm(&"t_second")
	GameState.equip_charm(&"t_rare")
	await _frames(3)
	page.refresh()
	var visible_tiles := page._equipped_tiles.filter(func(t: CharmTile) -> bool: return t.visible)
	_check(visible_tiles.size() == 3 and visible_tiles.all(func(t: CharmTile) -> bool: return t.mode == CharmTile.Mode.EQUIPPED),
		"TC5 đầy 3/3 khấc: 3 bùa, không còn ô trống")

	# TC6
	_check(visible_tiles.size() > 0 and visible_tiles.all(func(t: CharmTile) -> bool: return t.has_method(&"uses_pendant") and not t.uses_pendant()),
		"TC6 ô đang đeo vẽ dạng huy hiệu, không treo dây")

	# TC7
	_check(page._notches.has_method(&"uses_round_notches") and page._notches.uses_round_notches(), "TC7 ô khắc vẽ hình tròn")

	for id: StringName in GameState.progress.equipped_charms.duplicate():
		GameState.unequip_charm(id)
	GameState.exit_charm_station()
	_finish(saved, original_catalog)


func _make(id: StringName, title: String, cost: int) -> CharmData:
	var charm := CharmData.new()
	charm.id = id
	charm.display_name = title
	charm.notch_cost = cost
	charm.description = "Bùa thử cho test."
	return charm


func _finish(saved: PlayerProgress, original_catalog: Array[CharmData]) -> void:
	_menu.close()
	GameState.ITEMS.charms.assign(original_catalog)
	GameState.replace_progress(saved)
	print("RESULT fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
