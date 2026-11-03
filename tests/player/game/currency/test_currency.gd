extends Node
## Unit test hệ tiền dạng chung (CurrencyData + GameState + PlayerProgress + SaveManager). Viết TRƯỚC khi code (TDD).
## Chạy: mở tests/player/game/test_currency.tscn rồi F6, hoặc headless. Không ghi save thật (chỉ dùng to_dict / from_dict).
##
## ===== USE CASE =====
## UC1  Nhặt tiền -> tổng tăng; HUD / âm thanh biết loại tiền nào đổi và tổng mới.
## UC2  Nộp tiền đủ (người gác cổng, cửa hàng) -> trừ tiền, báo thành công.
## UC3  Nộp tiền thiếu -> không trừ, báo thất bại, không ai bị báo là tiền đổi.
## UC4  Hỏi trước "có đủ không" (để hiện nút / thông báo) mà không trừ.
## UC5  Gọi sai (số 0, số âm, id rỗng) -> không đổi tiền, không làm hỏng game.
## UC6  Nhiều loại tiền (sau này) độc lập nhau; loại chưa có thì là 0.
## UC7  Thêm loại tiền mới chỉ cần thêm file .tres CurrencyData, không sửa code.
## UC8  Chạm checkpoint chốt tiền; chết -> tiền về đúng số lúc chốt (sửa sau khi chốt không lây sang bản chốt).
## UC9  Lưu / nạp giữ đủ mọi loại tiền; file save hỏng / sửa tay (số âm, chữ) không làm hỏng tiến trình.
## UC10 Số tiền rất lớn vẫn cộng / trừ đúng.
## UC11 HUD hiện số tiền của đúng loại được gán; loại tiền mới dùng lại cùng bộ đếm (chỉ đổi dữ liệu).
## UC12 Tiền tăng -> số nảy nhẹ; tiền giảm (nộp tiền) / chết / nạp save -> cập nhật, không nảy.
## UC13 Bộ đếm lấy màu / icon từ CurrencyData; quên gán loại tiền -> báo lỗi rõ, không làm hỏng game.
##
## ===== TEST CASE =====
## TC1  (UC1)  add 5 -> get 5; currency_changed phát đúng 1 lần với (soul_jade, 5).
## TC2  (UC2)  có 5, spend 3 -> true, còn 2; phát (soul_jade, 2).
## TC3  (UC3)  có 2, spend 3 -> false, vẫn 2, không phát signal.
## TC4  (UC4)  có 2: can_afford 2 = true, 3 = false, 0 = true; không đổi tiền, không phát signal.
## TC5  (UC5)  add 0 / add -4 / spend -1 / add với id rỗng -> tiền không đổi, không phát signal.
## TC6  (UC6)  add test_gem 7 -> soul_jade không đổi; get id chưa có = 0.
## TC7  (UC7)  soul_jade.tres nạp được, id = soul_jade, có tên hiển thị; CurrencyData mới tạo bằng code dùng được ngay với API.
## TC8  (UC8)  có X, set_checkpoint, add 10 -> X+10; restore_checkpoint -> X; progress_replaced phát.
##             snapshot() rồi sửa bản gốc -> bản chụp không đổi (từ điển chép riêng).
## TC9  (UC9)  to_dict -> JSON -> from_dict giữ đủ 2 loại tiền.
##             Dữ liệu sửa tay: số âm -> 0, chữ -> bỏ qua, "currencies" không phải từ điển -> rỗng, không lỗi.
##             Save cũ có khoá "soul_jade" (bản thử trước) -> chuyển thành currencies[soul_jade].
## TC10 (UC10) add 2_000_000_000 hai lần -> 4_000_000_000; spend 3_999_999_999 -> còn 1.
## TC11 (UC11) Hai bộ đếm (soul_jade, test_gem) cùng lúc: add soul_jade chỉ đổi bộ soul_jade; add test_gem chỉ đổi bộ kia.
## TC12 (UC12) add -> đang nảy (is_popping); spend -> số giảm đúng, không nảy; restore_checkpoint -> số về đúng, không nảy.
## TC13 (UC13) Bộ đếm soul_jade dùng màu của soul_jade.tres; CurrencyData có icon -> bộ đếm hiện icon đó.
##             Bộ đếm không gán currency -> vẫn vào cây được, hiện 0, không văng lỗi script.

const SOUL_JADE := preload("res://resources/player/currency/soul_jade.tres")
const OTHER := &"test_gem"
const COUNTER := "res://objects/core/pickups/currency/hud/currency_counter.tscn"

var _fails: int = 0
var _events: Array = []
var _replaced: int = 0


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.currency_changed.connect(func(id: StringName, total: int) -> void: _events.append([id, total]))
	GameState.progress_replaced.connect(func() -> void: _replaced += 1)
	_run.call_deferred()


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var id: StringName = SOUL_JADE.id
	_tc1_add(id)
	_tc2_spend_ok(id)
	_tc3_spend_short(id)
	_tc4_can_afford(id)
	_tc5_invalid(id)
	_tc6_independent(id)
	_tc7_data(id)
	_tc8_checkpoint(id)
	_tc9_save(id)
	_tc10_large()
	await _tc11_counter_filters()
	await _tc12_counter_pop()
	await _tc13_counter_look()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _tc1_add(id: StringName) -> void:
	_events.clear()
	GameState.add_currency(id, 5)
	_check(GameState.get_currency(id) == 5, "TC1: add 5 -> 5 (%d)" % GameState.get_currency(id))
	_check(_events == [[id, 5]], "TC1: currency_changed phát 1 lần (soul_jade, 5): %s" % [_events])


func _tc2_spend_ok(id: StringName) -> void:
	_events.clear()
	var ok := GameState.spend_currency(id, 3)
	_check(ok and GameState.get_currency(id) == 2, "TC2: spend 3 -> true, còn 2 (%s, %d)" % [ok, GameState.get_currency(id)])
	_check(_events == [[id, 2]], "TC2: phát (soul_jade, 2): %s" % [_events])


func _tc3_spend_short(id: StringName) -> void:
	_events.clear()
	var ok := GameState.spend_currency(id, 3)
	_check(not ok and GameState.get_currency(id) == 2, "TC3: thiếu -> false, vẫn 2 (%s, %d)" % [ok, GameState.get_currency(id)])
	_check(_events.is_empty(), "TC3: không phát signal")


func _tc4_can_afford(id: StringName) -> void:
	_events.clear()
	_check(GameState.can_afford(id, 2), "TC4: đủ đúng bằng -> true")
	_check(not GameState.can_afford(id, 3), "TC4: thiếu 1 -> false")
	_check(GameState.can_afford(id, 0), "TC4: 0 -> true")
	_check(GameState.get_currency(id) == 2 and _events.is_empty(), "TC4: hỏi không làm đổi tiền / không phát signal")


func _tc5_invalid(id: StringName) -> void:
	_events.clear()
	GameState.add_currency(id, 0)
	GameState.add_currency(id, -4)
	var spent_negative := GameState.spend_currency(id, -1)
	GameState.add_currency(&"", 9)
	_check(GameState.get_currency(id) == 2, "TC5: số 0 / âm không đổi tiền (%d)" % GameState.get_currency(id))
	_check(not spent_negative, "TC5: spend số âm -> false")
	_check(GameState.get_currency(&"") == 0, "TC5: id rỗng không được cộng")
	_check(_events.is_empty(), "TC5: không phát signal (%s)" % [_events])


func _tc6_independent(id: StringName) -> void:
	GameState.add_currency(OTHER, 7)
	_check(GameState.get_currency(OTHER) == 7 and GameState.get_currency(id) == 2, "TC6: hai loại tiền độc lập")
	_check(GameState.get_currency(&"never_seen") == 0, "TC6: loại chưa có = 0")


func _tc7_data(id: StringName) -> void:
	_check(SOUL_JADE is CurrencyData, "TC7: soul_jade.tres là CurrencyData")
	_check(id == &"soul_jade" and not SOUL_JADE.display_name.is_empty(), "TC7: id soul_jade, có tên hiển thị '%s'" % SOUL_JADE.display_name)
	var fresh := CurrencyData.new()
	fresh.id = &"made_in_code"
	GameState.add_currency(fresh.id, 3)
	_check(GameState.get_currency(fresh.id) == 3, "TC7: loại tiền mới dùng được ngay, không sửa code")


func _tc8_checkpoint(id: StringName) -> void:
	var before := GameState.get_currency(id)
	GameState.set_checkpoint("res://tests/player/game/currency/test_currency.tscn", &"test")
	GameState.add_currency(id, 10)
	_check(GameState.get_currency(id) == before + 10, "TC8: kiếm thêm sau checkpoint")
	var replaced := _replaced
	GameState.restore_checkpoint()
	_check(GameState.get_currency(id) == before, "TC8: chết -> về số lúc chốt (%d)" % GameState.get_currency(id))
	_check(_replaced == replaced + 1, "TC8: progress_replaced phát để HUD cập nhật")
	var original := PlayerProgress.new()
	original.currencies[id] = 4
	var copy := original.snapshot()
	original.currencies[id] = 99
	_check(copy.currencies.get(id, -1) == 4, "TC8: snapshot chép riêng từ điển tiền (%s)" % copy.currencies.get(id, -1))


func _tc9_save(id: StringName) -> void:
	var progress := PlayerProgress.new()
	progress.currencies[id] = 1234
	progress.currencies[OTHER] = 5
	var back := SaveManager.from_dict(JSON.parse_string(JSON.stringify(SaveManager.to_dict(progress))) as Dictionary)
	_check(back.currencies.get(id, -1) == 1234 and back.currencies.get(OTHER, -1) == 5, "TC9: lưu / nạp giữ đủ 2 loại tiền (%s)" % [back.currencies])
	var dirty := SaveManager.to_dict(PlayerProgress.new())
	dirty["currencies"] = {"soul_jade": -50, "test_gem": "abc", "ok_gem": 8}
	var cleaned := SaveManager.from_dict(dirty)
	_check(cleaned.currencies.get(id, 0) == 0, "TC9: số âm -> 0 (%s)" % [cleaned.currencies])
	_check(not cleaned.currencies.has(OTHER), "TC9: chữ -> bỏ qua")
	_check(cleaned.currencies.get(&"ok_gem", -1) == 8, "TC9: giá trị hợp lệ vẫn giữ")
	var broken := SaveManager.to_dict(PlayerProgress.new())
	broken["currencies"] = "not a dictionary"
	_check(SaveManager.from_dict(broken).currencies.is_empty(), "TC9: currencies sai kiểu -> rỗng, không lỗi")
	var legacy := SaveManager.to_dict(PlayerProgress.new())
	legacy.erase("currencies")
	legacy["soul_jade"] = 77
	_check(SaveManager.from_dict(legacy).currencies.get(id, -1) == 77, "TC9: save cũ có khoá soul_jade -> chuyển sang currencies")


func _tc10_large() -> void:
	var id := &"big_test"
	GameState.add_currency(id, 2_000_000_000)
	GameState.add_currency(id, 2_000_000_000)
	_check(GameState.get_currency(id) == 4_000_000_000, "TC10: cộng số lớn đúng (%d)" % GameState.get_currency(id))
	GameState.spend_currency(id, 3_999_999_999)
	_check(GameState.get_currency(id) == 1, "TC10: trừ số lớn đúng (%d)" % GameState.get_currency(id))


func _tc11_counter_filters() -> void:
	var gem := CurrencyData.new()
	gem.id = OTHER
	var jade_counter := _make_counter(SOUL_JADE)
	var gem_counter := _make_counter(gem)
	await get_tree().process_frame
	var jade0 := jade_counter.get_shown_value()
	var gem0 := gem_counter.get_shown_value()
	_check(jade0 == GameState.get_currency(SOUL_JADE.id) and gem0 == GameState.get_currency(OTHER), "TC11: lúc vào cây hiện đúng số đang có")
	GameState.add_currency(SOUL_JADE.id, 3)
	_check(jade_counter.get_shown_value() == jade0 + 3 and gem_counter.get_shown_value() == gem0, "TC11: add soul_jade chỉ đổi bộ soul_jade")
	GameState.add_currency(OTHER, 4)
	_check(gem_counter.get_shown_value() == gem0 + 4 and jade_counter.get_shown_value() == jade0 + 3, "TC11: add test_gem chỉ đổi bộ test_gem")
	jade_counter.queue_free()
	gem_counter.queue_free()


func _tc12_counter_pop() -> void:
	var counter := _make_counter(SOUL_JADE)
	await get_tree().process_frame
	GameState.add_currency(SOUL_JADE.id, 5)
	_check(counter.is_popping(), "TC12: tiền tăng -> số nảy")
	await get_tree().create_timer(counter.pop_time + 0.1).timeout
	_check(not counter.is_popping(), "TC12: nảy xong thì dừng")
	var before := counter.get_shown_value()
	GameState.spend_currency(SOUL_JADE.id, 2)
	_check(counter.get_shown_value() == before - 2 and not counter.is_popping(), "TC12: nộp tiền -> giảm đúng, không nảy")
	GameState.set_checkpoint("res://tests/player/game/currency/test_currency.tscn", &"test")
	var committed := GameState.get_currency(SOUL_JADE.id)
	GameState.add_currency(SOUL_JADE.id, 9)
	await get_tree().create_timer(counter.pop_time + 0.1).timeout
	GameState.restore_checkpoint()
	_check(counter.get_shown_value() == committed and not counter.is_popping(), "TC12: chết -> về %d, không nảy (%d)" % [committed, counter.get_shown_value()])
	counter.queue_free()


func _tc13_counter_look() -> void:
	var counter := _make_counter(SOUL_JADE)
	await get_tree().process_frame
	_check(counter.get_icon_color() == SOUL_JADE.color, "TC13: màu icon lấy từ soul_jade.tres")
	var with_icon := CurrencyData.new()
	with_icon.id = &"icon_test"
	with_icon.icon = PlaceholderTexture2D.new()
	var iconed := _make_counter(with_icon)
	await get_tree().process_frame
	_check(iconed.get_icon_texture() == with_icon.icon, "TC13: CurrencyData có icon -> bộ đếm dùng icon đó")
	var empty := _make_counter(null)
	await get_tree().process_frame
	_check(is_instance_valid(empty) and empty.get_shown_value() == 0, "TC13: quên gán currency -> vẫn chạy, hiện 0")
	for c: Node in [counter, iconed, empty]:
		c.queue_free()


func _make_counter(kind: CurrencyData) -> CurrencyCounter:
	var counter := (load(COUNTER) as PackedScene).instantiate() as CurrencyCounter
	counter.currency = kind
	add_child(counter)
	return counter


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
