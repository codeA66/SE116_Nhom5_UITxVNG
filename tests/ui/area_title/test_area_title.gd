extends Node
## Test chữ giới thiệu khu vực (autoload AreaTitle + AreaTitleTrigger). Tự ngắt tự lưu, không ghi save thật.
## Chạy: mở test_area_title.tscn rồi F6, hoặc headless.
##
## ===== USE CASE =====
## UC1  Nơi chưa tới -> bản đầy đủ (tên + nét kẻ + dòng phụ), đánh dấu đã thấy; hết giờ thì ẩn hẳn, tween dừng.
## UC2  Gọi lại đúng khu vừa hiện (chết hồi sinh / nạp lại scene) -> không hiện.
## UC3  Nơi đã thấy -> bản ngắn (không dòng phụ, không nét kẻ), hiện nhanh hơn.
## UC4  Vừa vào khu đã đứng trong vùng con -> chỉ hiện tên khu; vùng con không bị đánh dấu đã thấy.
## UC5  Đang hiện mà tới vùng khác -> chữ cũ tắt nhanh, chữ mới hiện.
## UC6  Thông số cực đoan (thời gian gần 0, tên rất dài, không dòng phụ, chữ to) -> không lỗi, vẫn ẩn hẳn.
## UC7  Map Gió thật: vào khu hiện "Khu Gió" bản đầy đủ, vùng tầng 1 gộp; nạp lại scene không hiện lại;
##      chữ đã vẽ sẵn thì lúc hiện không khựng;
##      đi (dịch chuyển) sang tầng 2 -> hiện "Sân Trong".
## UC8  Khu trung tâm lần đầu: chữ chờ đoạn camera giới thiệu diễn xong mới hiện.

const LEVEL_1 := "res://levels/zone_1_wind/level_1/level_1.tscn"
const HUB := "res://levels/temple_center/hub/hub.tscn"

var _fails: int = 0
var _shown: Array[Dictionary] = []
var _style: AreaTitleStyle


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	AreaTitle.title_shown.connect(func(area: AreaData, full: bool) -> void:
		_shown.append({"id": area.id, "full": full, "msec": Time.get_ticks_msec()}))
	_style = AreaTitle.style
	_run.call_deferred()


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	await _uc1_full()
	await _uc2_same_zone()
	await _uc3_short()
	await _uc4_merge()
	await _uc5_interrupt()
	await _uc6_extreme()
	await _uc7_wind_level()
	await _uc8_hub_intro()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _area(id: StringName, title: String, subtitle: String = "", zone: bool = false) -> AreaData:
	var area: AreaData = ZoneData.new() if zone else AreaData.new()
	area.id = id
	area.display_name = title
	area.subtitle = subtitle
	return area


func _total_full() -> float:
	var s := _style
	var shown := maxf(maxf(s.title_delay + s.title_reveal_time, s.subtitle_delay + s.subtitle_time), s.rule_time)
	return s.start_delay + shown + s.hold_time + s.fade_out_time


func _uc1_full() -> void:
	AreaTitle.reset_history()
	_shown.clear()
	var zone := _area(&"test_zone_a", "Khu Thử", "Dòng phụ thử", true)
	var t0 := Time.get_ticks_msec()
	AreaTitle.announce(zone)
	_check(_shown.size() == 1 and _shown[0].full, "UC1: nơi mới -> bản đầy đủ")
	_check(zone.is_seen(), "UC1: đánh dấu đã thấy")
	await _wait(_style.start_delay + _style.title_delay + _style.title_reveal_time + 0.2)
	var root := AreaTitle.get_node("Root") as Control
	var subtitle := AreaTitle.get_node("Root/Block/Subtitle") as Label
	var rule := AreaTitle.get_node("Root/Block/Rule") as OrnamentDivider
	var reveal := float((AreaTitle.get_node("Root/Block/Title").material as ShaderMaterial).get_shader_parameter(&"reveal"))
	_check(root.visible and root.modulate.a > 0.9, "UC1: đang hiện (alpha %.2f, sau %.2f s, band %.2f)" % [root.modulate.a, (Time.get_ticks_msec() - t0) / 1000.0, (AreaTitle.get_node("Root/Band") as Control).modulate.a])
	_check(reveal >= 0.5, "UC1: chữ đã loang hết (reveal %.2f)" % reveal)
	var zoom := AreaTitle.scale.x
	_check(zoom > 1.0 and zoom < _style.zoom_from, "UC1: khối chữ đang thu dần về cỡ thật (%.4f, từ %.3f)" % [zoom, _style.zoom_from])
	_check(subtitle.visible and subtitle.text == "Dòng phụ thử" and rule.visible and rule.reveal > 0.99, "UC1: có dòng phụ + nét kẻ mở hết")
	await _wait(_total_full() - (_style.start_delay + _style.title_delay + _style.title_reveal_time + 0.2) + 0.3)
	var font := (AreaTitle.get_node("Root/Block/Title") as Label).get_theme_font(&"font") as FontVariation
	_check(not root.visible and not AreaTitle.is_showing(), "UC1: hết giờ -> ẩn hẳn, tween dừng")
	_check(font.spacing_glyph == roundi(_style.letter_spacing), "UC1: khoảng cách chữ cố định %d (đang %d)" % [roundi(_style.letter_spacing), font.spacing_glyph])
	_check(AreaTitle.scale.is_equal_approx(Vector2.ONE), "UC1: lớp chữ trả về cỡ gốc (%s)" % AreaTitle.scale)
	_check(is_zero_approx(AreaTitle.offset.y), "UC1: lớp chữ trả về vị trí gốc sau khi trôi lên")


func _uc2_same_zone() -> void:
	_shown.clear()
	AreaTitle.announce(_area(&"test_zone_a", "Khu Thử", "Dòng phụ thử", true))
	await get_tree().process_frame
	_check(_shown.is_empty() and not AreaTitle.is_showing(), "UC2: cùng khu vừa hiện -> không hiện lại")


func _uc3_short() -> void:
	_shown.clear()
	var seen := _area(&"test_sub_b", "Vùng Đã Tới", "Không được hiện")
	GameState.set_flag(seen.get_seen_flag())
	var started := Time.get_ticks_msec()
	AreaTitle.announce(seen)
	_check(_shown.size() == 1 and not _shown[0].full, "UC3: nơi đã thấy -> bản ngắn")
	_check(not (AreaTitle.get_node("Root/Block/Subtitle") as Label).visible and not (AreaTitle.get_node("Root/Block/Rule") as Control).visible, "UC3: bản ngắn không có dòng phụ, nét kẻ")
	await AreaTitle.title_finished
	var took := (Time.get_ticks_msec() - started) / 1000.0
	var expected := _style.start_delay + _style.short_reveal_time + _style.short_hold_time + _style.short_fade_out_time
	_check(absf(took - expected) < 0.25 and took < _total_full(), "UC3: bản ngắn dài %.2f s (dự kiến %.2f, bản đầy đủ %.2f)" % [took, expected, _total_full()])


func _uc4_merge() -> void:
	_shown.clear()
	var sub := _area(&"test_sub_c", "Vùng Con")
	AreaTitle.announce(_area(&"test_zone_d", "Khu Mới", "", true))
	await get_tree().physics_frame
	AreaTitle.announce(sub)
	_check(_shown.size() == 1 and _shown[0].id == &"test_zone_d", "UC4: chỉ hiện tên khu (%d chữ)" % _shown.size())
	_check(not sub.is_seen(), "UC4: vùng con bị gộp chưa bị đánh dấu đã thấy")
	await AreaTitle.title_finished


func _uc5_interrupt() -> void:
	_shown.clear()
	AreaTitle.announce(_area(&"test_sub_e", "Vùng E", "phụ E"))
	await _wait(_style.merge_window + 0.6)
	AreaTitle.announce(_area(&"test_sub_f", "Vùng F", "phụ F"))
	await get_tree().process_frame
	_check(_shown.size() == 1, "UC5: chữ mới chưa hiện ngay (đang tắt chữ cũ)")
	await _wait(_style.interrupt_fade_time + 0.1)
	var title := AreaTitle.get_node("Root/Block/Title") as Label
	_check(_shown.size() == 2 and _shown[1].id == &"test_sub_f" and title.text == "Vùng F", "UC5: chữ mới hiện sau khi chữ cũ tắt ('%s')" % title.text)
	await AreaTitle.title_finished
	_check(not (AreaTitle.get_node("Root") as Control).visible, "UC5: xong thì ẩn hẳn")


func _uc6_extreme() -> void:
	var original := _style
	var tiny := original.duplicate() as AreaTitleStyle
	for p in ["start_delay", "rule_time", "title_delay", "title_reveal_time", "subtitle_delay", "subtitle_time", "hold_time", "fade_out_time", "interrupt_fade_time"]:
		tiny.set(p, 0.01)
	tiny.title_font_size = 200
	tiny.vertical_anchor = 0.95
	tiny.letter_spacing = 60.0
	tiny.zoom_from = 1.2
	AreaTitle.style = tiny
	AreaTitle.apply_style()
	_shown.clear()
	var long_name := "Cung Điện Ngàn Gió Thổi Qua Những Bậc Thang Đá Cổ Nhất Của Hòn Đảo Foxy"
	AreaTitle.announce(_area(&"test_extreme", long_name))
	await _wait(0.5)
	_check(_shown.size() == 1 and not AreaTitle.is_showing() and not (AreaTitle.get_node("Root") as Control).visible, "UC6: thời gian ~0, tên rất dài, không dòng phụ -> hiện xong và ẩn hẳn")
	AreaTitle.style = original
	AreaTitle.apply_style()


func _uc7_wind_level() -> void:
	AreaTitle.reset_history()
	_shown.clear()
	var level := await _load(LEVEL_1)
	_check(_shown.size() >= 1 and _shown[0].id == &"wind" and _shown[0].full, "UC7: vào Map Gió -> 'Khu Gió' bản đầy đủ (%s)" % str(_shown))
	_check(_shown.size() == 1 and not GameState.has_flag(&"area.wind.tier_1.seen"), "UC7: vùng tầng 1 bị gộp, chưa đánh dấu")
	await _shot("level1_reveal")
	await AreaTitle.title_finished
	_shown.clear()
	level.queue_free()
	await get_tree().process_frame
	level = await _load(LEVEL_1)
	await _wait(1.0)
	_check(_shown.is_empty(), "UC7: nạp lại Map Gió (như chết hồi sinh) -> không hiện lại (%s)" % str(_shown))
	# Nơi mới có chữ chưa từng vẽ (dấu tiếng Việt lạ): đã vẽ sẵn như trigger làm lúc nạp khu -> lúc hiện không khựng
	var fresh := _area(&"test_hitch", "Ửng Ỡ Ặc Ỹ Quẫy", "Ỵ ỷ ẳ ẵ")
	AreaTitle.prepare(fresh)
	await _wait(0.5)
	var idle := await _worst_frame(1.0)
	AreaTitle.announce(fresh)
	var worst := await _worst_frame(_style.start_delay + _style.title_delay + _style.title_reveal_time + 0.2)
	_check(worst < maxf(idle * 1.6, 30.0), "UC7: lúc chữ hiện không khựng (chậm nhất %.1f ms, lúc thường %.1f ms)" % [worst, idle])
	await AreaTitle.title_finished
	_shown.clear()
	var player := level.get_node("Player") as Player
	# Điểm hồi sinh đầu tầng 2 (sàn thật, nằm trong Tier2Zone): dịch chuyển vào chỗ trống thì player rơi mãi
	var tier2 := level.get_node("Rooms/Tier1/Room10Tier2Gate/Tier2Checkpoint/Spawn") as Node3D
	player.teleport(tier2.global_position + Vector3.UP * 0.3, Vector3.FORWARD)
	await _wait(0.6)
	_check(_shown.size() == 1 and _shown[0].id == &"wind.tier_2" and _shown[0].full, "UC7: sang tầng 2 -> 'Sân Trong' bản đầy đủ (%s)" % str(_shown))
	await _wait(_style.start_delay + _style.subtitle_delay + _style.subtitle_time)
	await _shot("level1_tier2")
	await AreaTitle.title_finished
	level.queue_free()
	await get_tree().process_frame


func _uc8_hub_intro() -> void:
	AreaTitle.reset_history()
	_shown.clear()
	var cutscene_done := [-1]
	var hub := (load(HUB) as PackedScene).instantiate() as Node3D
	(hub.get_node("IntroCutscene") as CameraCutscene).finished.connect(func() -> void: cutscene_done[0] = Time.get_ticks_msec())
	get_tree().root.add_child(hub)
	await _wait(2.0)
	_check(_shown.is_empty(), "UC8: đang chạy camera giới thiệu -> chưa hiện chữ")
	var waited := 0.0
	while _shown.is_empty() and waited < 15.0:
		await _wait(0.25)
		waited += 0.25
	_check(cutscene_done[0] > 0 and _shown.size() == 1 and _shown[0].id == &"hub" and _shown[0].msec >= cutscene_done[0], "UC8: camera xong mới hiện 'Khu Trung Tâm' (%s)" % str(_shown))
	await _wait(_style.start_delay + _style.subtitle_delay + _style.subtitle_time)
	await _shot("hub_full")
	await AreaTitle.title_finished
	hub.queue_free()


func _worst_frame(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var last := start
	var worst := 0.0
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	return worst


func _load(path: String) -> Node3D:
	var level := (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(level)
	await _wait(0.4)
	return level


func _shot(name_: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir().path_join("area_title_%s.png" % name_))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
