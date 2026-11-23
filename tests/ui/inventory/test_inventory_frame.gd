extends "res://tests/ui/hud/hud_preview.gd"
## Unit test nâng cấp khung màn Tab (giai đoạn 1). Viết TRƯỚC khi code: chưa có code thì FAIL, code xong phải PASS hết.
## Chạy: mở tests/ui/inventory/test_inventory_frame.tscn rồi F6 (có cửa sổ để đo ảnh). Không ghi save thật.
## Kết quả: từng dòng PASS / FAIL, cuối cùng "RESULT fails=N".
##
## ===== USE CASE =====
## UC1 Màn Tab nằm trên lớp riêng (MenuLayer): trên chữ tên khu và gợi ý hướng dẫn, dưới hộp thoại và menu tạm dừng.
## UC2 Mở màn Tab thì HUD (tim, năng lượng, tiền, ô kỹ năng, gợi ý tương tác) ẩn hẳn; đóng thì hiện lại.
##     HUD đã bị thứ khác ẩn trước (cắt cảnh) thì đóng màn Tab không được bật HUD lên.
## UC3 Nền phía sau là cảnh game làm mờ và tối, che kín (không lộ chi tiết sắc nét phía sau).
## UC4 Tiền (Soul Jade) chỉ hiện một chỗ, ở góc dưới phải của màn Tab.
## UC5 Hàng icon trang trên cùng: số icon bằng số trang đang có, icon sáng đúng trang đang xem, đổi trang bằng Q / E thì
##     icon sáng đổi theo và quay vòng.
## UC6 Thanh phím dưới cùng: mỗi phím có ô viền (KeyGlyph), đủ Đóng / Đổi trang / Xác nhận / Quay lại.
##
## ===== TEST CASE =====
## TC1 (UC1) InventoryMenu nằm dưới CanvasLayer "MenuLayer"; layer > AreaTitle, > TutorialPopup, < DialogBox (50), < PauseMenu.
## TC2 (UC2) Mở: HUD.visible = false, menu hiện. Đóng: HUD.visible = true.
## TC3 (UC2) Ẩn HUD trước rồi mở / đóng: HUD vẫn ẩn.
## TC4 (UC2) Mở / đóng liên tục 10 lần: cuối cùng HUD hiện, menu ẩn, không lỗi.
## TC5 (UC3) Ảnh thật: độ tương phản chi tiết ở vùng giữa màn sau khi mở giảm còn < 50% lúc chưa mở.
## TC6 (UC4) Nhãn tiền hiện, có số, tâm nằm ở góc dưới phải (x > 60% rộng, y > 75% cao); HUD tiền không hiện.
## TC7 (UC5) PageIconBar: số icon = số trang; icon sáng = trang hiện tại; bấm next 1 lần -> +1; bấm đủ vòng -> về lại.
## TC8 (UC6) Footer có >= 4 KeyGlyph.

const DIALOG_LAYER := 50
const BLUR_RATIO := 0.5

var _fails: int = 0
var _menu: InventoryMenu
var _hud: CanvasLayer


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	configure_storage()
	await build_world(false)
	_hud = actor.get_node_or_null(^"HUD") as CanvasLayer
	var layer := actor.get_node_or_null(^"MenuLayer") as CanvasLayer
	_menu = layer.get_node_or_null(^"InventoryMenu") as InventoryMenu if layer else null
	_check(layer != null and _menu != null, "TC1 InventoryMenu nằm dưới CanvasLayer MenuLayer")
	if _menu == null:
		_finish()
		return
	await _tc1_layers(layer)
	await _tc2_hide_hud()
	await _tc3_respect_hidden()
	await _tc4_spam()
	await _tc5_blur()
	await _tc6_currency()
	await _tc7_page_icons()
	_tc8_footer()
	_finish()


func _tc1_layers(layer: CanvasLayer) -> void:
	var area := get_tree().root.get_node_or_null(^"AreaTitle") as CanvasLayer
	var pause := get_tree().root.get_node_or_null(^"PauseMenu") as CanvasLayer
	var popup := actor.get_node_or_null(^"HUD/TutorialPopup") as CanvasLayer
	_check(area != null and layer.layer > area.layer, "TC1 MenuLayer (%d) trên chữ tên khu (%s)" % [layer.layer, area.layer if area else "?"])
	_check(popup != null and layer.layer > popup.layer, "TC1 MenuLayer trên gợi ý hướng dẫn (%s)" % [popup.layer if popup else "?"])
	_check(layer.layer < DIALOG_LAYER, "TC1 MenuLayer dưới hộp thoại (%d)" % DIALOG_LAYER)
	_check(pause != null and layer.layer < pause.layer, "TC1 MenuLayer dưới menu tạm dừng (%s)" % [pause.layer if pause else "?"])


func _tc2_hide_hud() -> void:
	_check(_hud.visible, "TC2 chuẩn bị: HUD đang hiện")
	_menu.open()
	await wait_seconds(0.4)
	_check(_menu.visible and not _hud.visible, "TC2 mở màn Tab: HUD ẩn")
	var area := get_tree().root.get_node_or_null(^"AreaTitle") as CanvasLayer
	_check(area != null and not area.visible, "TC2 mở màn Tab: chữ tên khu ẩn (không đọc được qua lớp mờ)")
	_menu.close()
	await wait_seconds(0.4)
	_check(not _menu.visible and _hud.visible, "TC2 đóng màn Tab: HUD hiện lại")
	_check(area != null and area.visible, "TC2 đóng màn Tab: lớp chữ tên khu bật lại")


func _tc3_respect_hidden() -> void:
	_hud.hide()
	_menu.open()
	await wait_seconds(0.3)
	_menu.close()
	await wait_seconds(0.4)
	_check(not _hud.visible, "TC3 HUD bị ẩn từ trước: đóng màn Tab không bật HUD")
	_hud.show()


func _tc4_spam() -> void:
	for i in 10:
		_menu.open()
		await get_tree().process_frame
		_menu.close()
		await get_tree().process_frame
	await wait_seconds(0.5)
	_check(not _menu.visible and _hud.visible, "TC4 mở / đóng 10 lần: menu ẩn, HUD hiện")


func _tc5_blur() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP TC5 (headless không có ảnh)")
		return
	# Cảnh thử là sàn phẳng, gần như không có chi tiết: đặt ô bàn cờ tương phản cao phía sau (dưới MenuLayer) để đo
	var checker_layer := CanvasLayer.new()
	checker_layer.layer = 5
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			image.set_pixel(x, y, Color.WHITE if (x / 4 + y / 4) % 2 == 0 else Color.BLACK)
	var checker := TextureRect.new()
	checker.texture = ImageTexture.create_from_image(image)
	checker.stretch_mode = TextureRect.STRETCH_TILE
	checker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	checker.set_anchors_preset(Control.PRESET_FULL_RECT)
	checker_layer.add_child(checker)
	add_child(checker_layer)
	await wait_seconds(0.2)
	await RenderingServer.frame_post_draw
	var before := _detail(get_viewport().get_texture().get_image())
	_menu.open()
	await wait_seconds(0.5)
	# Chỉ đo lớp nền: tạm ẩn mọi thứ của màn Tab vẽ trên nền (chữ, khung, ô)
	var hidden: Array[CanvasItem] = []
	for child in _menu.get_children():
		var item := child as CanvasItem
		if item and item.name != &"Backdrop" and item.visible:
			item.visible = false
			hidden.append(item)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after := _detail(get_viewport().get_texture().get_image())
	for item in hidden:
		item.visible = true
	_menu.close()
	await wait_seconds(0.4)
	checker_layer.queue_free()
	_check(before > 0.0 and after < before * BLUR_RATIO, "TC5 nền mờ: chi tiết %.4f -> %.4f (cần < %.0f%%)" % [before, after, BLUR_RATIO * 100.0])


func _tc6_currency() -> void:
	_menu.open()
	await wait_seconds(0.4)
	var label := _menu.get_node_or_null(^"Currency") as Control
	if label == null:
		label = _menu.get_node_or_null(^"Header/Currency") as Control
	var size := get_viewport().get_visible_rect().size
	var center := label.get_global_rect().get_center() if label else Vector2.ZERO
	_check(label != null and label.is_visible_in_tree(), "TC6 nhãn tiền hiện")
	_check(label != null and (label as Label).text.strip_edges().right(1).is_valid_int(), "TC6 nhãn tiền có số")
	_check(center.x > size.x * 0.6 and center.y > size.y * 0.75, "TC6 tiền ở góc dưới phải (tâm %s / màn %s)" % [center, size])
	var counter := actor.get_node_or_null(^"HUD/CurrencyCounter") as CanvasItem
	_check(counter == null or not counter.is_visible_in_tree(), "TC6 không còn tiền thứ hai từ HUD")
	_menu.close()
	await wait_seconds(0.4)


func _tc7_page_icons() -> void:
	_menu.open()
	await wait_seconds(0.4)
	var bar := _menu.find_child("PageIcons", true, false) as PageIconBar
	_check(bar != null, "TC7 có hàng icon trang (PageIconBar tên PageIcons)")
	if bar == null:
		_menu.close()
		await wait_seconds(0.4)
		return
	var count := bar.get_icon_count()
	_check(count >= 1, "TC7 có icon trang (%d)" % count)
	var start := bar.get_selected()
	_check(start >= 0 and start < count, "TC7 có icon đang sáng (%d)" % start)
	await _press(&"menu_next_page")
	_check(count < 2 or bar.get_selected() == (start + 1) % count, "TC7 bấm trang sau: icon sáng %d -> %d" % [start, bar.get_selected()])
	for i in count - 1:
		await _press(&"menu_next_page")
	_check(bar.get_selected() == start, "TC7 bấm đủ vòng quay lại icon đầu")
	_menu.close()
	await wait_seconds(0.4)


func _tc8_footer() -> void:
	var footer := _menu.get_node_or_null(^"Footer")
	var glyphs := footer.find_children("*", "KeyGlyph", true, false).size() if footer else 0
	_check(glyphs >= 4, "TC8 thanh phím có ô viền cho từng phím (%d)" % glyphs)


## Độ tương phản chi tiết vùng giữa màn: trung bình chênh sáng giữa hai điểm ảnh cạnh nhau
func _detail(image: Image) -> float:
	var size := image.get_size()
	var area := Rect2i(Vector2i(size * 0.3), Vector2i(size * 0.4))
	var total := 0.0
	var count := 0
	for y in range(area.position.y, area.end.y, 2):
		for x in range(area.position.x, area.end.x - 2, 2):
			total += absf(image.get_pixel(x, y).get_luminance() - image.get_pixel(x + 2, y).get_luminance())
			count += 1
	return total / float(maxi(count, 1))


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await wait_seconds(0.3)


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _finish() -> void:
	GameState.replace_progress(saved_progress)
	print("RESULT fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
