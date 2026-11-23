extends Node
## Unit test 3 bùa mới: Phẫn Nộ, Linh Khí, Ưng Nhãn. Viết TRƯỚC khi code (TDD): chưa có bùa thì FAIL, code xong phải
## PASS hết. Đo hành vi thật trong sân thử (máu hình nộm, năng lượng tối đa, HUD, thời gian kéo cung theo frame).
## Chạy: mở tests/player/game/charms/combat/test_combat_charms.tscn rồi F6. Tự ngắt tự lưu, không ghi save thật.
## Kết quả: từng dòng PASS / FAIL, cuối cùng "RESULT fails=N" (0 là đạt).
##
## ===== USE CASE =====
## UC1 Ba bùa có ở đúng file, đã đăng ký catalog, đúng tên và số khấc (Phẫn Nộ 2, Linh Khí 1, Ưng Nhãn 1).
## UC2 Phẫn Nộ: sau khi player nhận sát thương, KIẾM và CUNG được +1 sát thương trong 2,5 giây.
##     Bị đánh lại giữa chừng thì tính lại 2,5 giây từ đầu (chỉ cộng 1 sát thương).
##     Kỹ năng nguyên tố (Thổi Gió) không được cộng. Chưa đeo bùa thì bị đánh vẫn chỉ 1.
##     Tháo bùa giữa lúc đang hiệu lực: mất ngay. Dựng lại scene (đổi khu / hồi sinh) giữa lúc hiệu lực: không sót.
##     Đòn bị bất tử chặn (không mất máu) không kích hoạt.
## UC3 Linh Khí: năng lượng tối đa +2, HUD vẽ đúng số ô mới. Tháo khi đang đầy: năng lượng hiện tại kẹp về mức cũ,
##     HUD về số ô cũ. Dựng lại scene khi đang đeo: vẫn +2, không thành +4.
## UC4 Ưng Nhãn: mỗi lần nhả dây bắn hai mũi liên tiếp cách 0,20 s, tổng tốn 1 năng lượng; mỗi mũi giữ sát thương gốc.
##     Chỉ mũi đầu có fusion. Không đổi thời gian kéo/hồi cung. Tháo bùa thì lại bắn một mũi.
##
## ===== TEST CASE =====
## TC1  (UC1) Load 3 file .tres, là CharmData, có trong GameState.ITEMS, tên chứa "Phẫn Nộ" / "Linh Khí" / "Ưng Nhãn", khấc 2 / 1 / 1.
## TC2  (UC2) Không đeo: bị đánh rồi chém Dummy1 -> mất 1.
## TC3  (UC2) Đeo Phẫn Nộ, chưa bị đánh: chém -> mất 1.
## TC4  (UC2) Bị đánh (đòn khựng bình thường) rồi chém -> mất 2.
## TC5  (UC2) Bị đánh (đòn không khựng) rồi bắn cung trúng Dummy2 -> sát thương cung gốc +1.
## TC6  (UC2) Bị đánh, chém lúc ~2,15 s -> mất 2; chém lúc ~2,85 s -> mất 1.
## TC7  (UC2) Bị đánh, 1,0 s sau bị đánh lại, chém lúc ~3,15 s (2,15 s sau lần 2) -> mất 2 (đã tính lại giờ);
##            chém lúc ~3,85 s -> mất 1. Bị đánh 3 lần liền rồi chém -> mất 2 (chỉ cộng 1 sát thương).
## TC8  (UC2) Thổi Gió vào Dummy3 không buff và có buff: mất máu bằng nhau.
## TC9  (UC2) Bị đánh, tháo bùa ngay, chém -> mất 1.
## TC10 (UC2) Bị đánh, dựng lại scene, chém -> mất 1; số node con của player không tăng so với trước.
## TC11 (UC2) Đòn bị chặn bởi bất tử (không trừ máu) rồi chém -> mất 1.
## TC12 (UC3) Năng lượng tối đa cơ bản N; đeo Linh Khí -> N+2, HUD hiện N+2.
## TC13 (UC3) Đầy năng lượng N+2, tháo -> tối đa N, hiện tại <= N, HUD N.
## TC14 (UC3) Đeo, dựng lại scene -> tối đa N+2 (không N+4), hiện tại <= tối đa.
## TC15 (UC4) Đeo: hai đạn thật, tổng tốn 1 năng lượng, sát thương từng mũi giữ nguyên, không đổi frame kéo.
##     Phẫn Nộ cộng cho cả hai mũi gốc; bắn lại không tạo thêm đạn ngoài pool đã làm nóng.
## TC16 (UC4) Thả sớm/thiếu năng lượng không bắn; Gió/Lửa chỉ có một vệt fusion cho hai mũi.
##     Tháo bùa: lại một mũi, tốn 1 năng lượng, thời gian kéo không đổi.
##     Dash/Hurt sau phát đầu vẫn đủ hai phát; clip cung không ghi đè hành động đang diễn ra.
##     Chết, tháo bùa, đổi khu hoặc khóa điều khiển phải hủy Timer của phát chờ.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const STORAGE: String = "user://test_combat_charms_unit/"
## Đường dẫn theo kế hoạch đã duyệt của bùa mới
const WRATH := "res://resources/player/items/charms/combat/wrath_charm.tres"
const KEEN_EYE := "res://resources/player/items/charms/combat/keen_eye_charm.tres"
const SPIRIT := "res://resources/player/items/charms/utility/spirit_charm.tres"
const BUFF_TIME: float = 2.5
const BUFF_CHECK_BEFORE: float = 2.15
const BUFF_CHECK_AFTER: float = 2.85
const ENERGY_BONUS := 2
## Chém: chờ nhát ra đòn rồi mới đọc máu; nghỉ cho combo về đầu trước lượt sau
const SLASH_HIT_WAIT := 0.3
const COMBO_RESET := 0.7
## Thời gian chém trước khi chạm (để chém "lúc t" thì bấm sớm hơn chừng này)
const SLASH_LEAD := 0.15
const BOW_HOLD := 0.45
const ARROW_FLIGHT := 0.5
## Khung tìm frame kéo cung
const MAX_HOLD_FRAMES := 60

var _fails: int = 0
var _lv: Node
var _p: Player
var _wrath: CharmData
var _keen: CharmData
var _spirit: CharmData
var _test_view: SubViewport
var _aim_target: Node3D
var _aim_motion: InputEventMouseMotion = InputEventMouseMotion.new()
var _bow_actions: int = 0
var _arrow_events: int = 0
var _first_arrow_frame: int = -1
var _second_arrow_frame: int = -1
var _arrows_before_followup: int = 0
var _followup_state: StringName
var _followup_clip: StringName


func _ready() -> void:
	SaveManager.use_storage_dir(STORAGE)
	# Mở bài hướng dẫn cũng kích hoạt lưu; F6 phải giữ cả đường này trong hồ sơ thử.
	if GameState.tutorials_changed.is_connected(SaveManager.save_game):
		GameState.tutorials_changed.disconnect(SaveManager.save_game)
	# Viewport riêng nhận chuột giả lập mà không di chuyển con trỏ thật của người dùng.
	_test_view = SubViewport.new()
	_test_view.size = Vector2i(get_viewport().get_visible_rect().size)
	_test_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_test_view)
	_test_view.notify_mouse_entered()
	var display: TextureRect = TextureRect.new()
	display.texture = _test_view.get_texture()
	display.size = Vector2(_test_view.size)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	set_physics_process(false)
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	# Cùng nhịp với player để FPS thấp không làm hướng chuột trễ nhiều bước vật lý.
	if not is_instance_valid(_aim_target) or not is_instance_valid(_p):
		return
	var camera: Camera3D = _test_view.get_camera_3d()
	if camera == null:
		return
	var point: Vector3 = _aim_target.global_position
	point.y = _p.global_position.y
	_aim_motion.position = camera.unproject_position(point)
	_aim_motion.global_position = _aim_motion.position
	_test_view.push_input(_aim_motion, true)


func _run() -> void:
	if not _tc1_registered():
		print("RESULT fails=%d (dừng: chưa có đủ 3 bùa)" % _fails)
		get_tree().quit(1)
		return
	GameState.replace_progress(PlayerProgress.new())
	for c: CharmData in [_wrath, _keen, _spirit]:
		GameState.add_charm(c)
	if not GameState.can_change_charms():
		GameState.enter_charm_station()
	await _open()
	await _tc2_not_worn()
	await _tc3_to_tc11_wrath()
	await _tc12_to_tc14_spirit()
	await _tc15_tc16_keen_eye()
	_close()
	GameState.exit_charm_station()
	print("RESULT fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# ===== UC1 =====
func _tc1_registered() -> bool:
	_wrath = _load_charm(WRATH, "Phẫn Nộ", 2)
	_keen = _load_charm(KEEN_EYE, "Ưng Nhãn", 1)
	_spirit = _load_charm(SPIRIT, "Linh Khí", 1)
	return _wrath != null and _keen != null and _spirit != null


func _load_charm(path: String, name_part: String, notches: int) -> CharmData:
	var label := "TC1 [%s]" % name_part
	var ok := ResourceLoader.exists(path)
	_check(ok, label + " có file " + path)
	if not ok:
		return null
	var charm := load(path) as CharmData
	_check(charm != null, label + " là CharmData")
	if charm == null:
		return null
	_check(GameState.ITEMS.get_charm(charm.id) == charm, label + " đã đăng ký trong catalog")
	_check(charm.display_name.contains(name_part), label + " tên chứa \"%s\" (đang \"%s\")" % [name_part, charm.display_name])
	_check(charm.notch_cost == notches, label + " %d khấc (đang %d)" % [notches, charm.notch_cost])
	return charm


# ===== UC2: Phẫn Nộ =====
func _tc2_not_worn() -> void:
	await _hurt(true)
	await _wait(0.5)
	_check(await _slash_loss("Dummy1") == 1, "TC2 không đeo Phẫn Nộ: bị đánh rồi chém vẫn mất 1")


func _tc3_to_tc11_wrath() -> void:
	_check(GameState.equip_charm(_wrath.id), "TC3 đeo Phẫn Nộ")
	await _f(2)
	_check(await _slash_loss("Dummy1") == 1, "TC3 chưa bị đánh: chém mất 1")

	await _hurt(true)
	await _wait(0.5)
	_check(await _slash_loss("Dummy1") == 2, "TC4 bị đánh (khựng) rồi chém: mất 2")
	await _wait(BUFF_TIME)

	var bow_plain: int = await _bow_loss("Dummy2")
	_check(bow_plain > 0, "TC5 chuẩn bị: cung không buff thực sự trúng mục tiêu")
	await _hurt(false)
	var bow_buffed: int = await _bow_loss("Dummy2")
	_check(bow_buffed == bow_plain + 1, "TC5 cung được +1: %d -> %d" % [bow_plain, bow_buffed])
	await _wait(BUFF_TIME)

	await _hurt(false)
	await _wait(BUFF_CHECK_BEFORE - SLASH_LEAD)
	_check(await _slash_loss("Dummy1") == 2, "TC6 chém lúc ~2,15 s sau khi bị đánh: vẫn mất 2")
	await _hurt(false)
	await _wait(BUFF_CHECK_AFTER - SLASH_LEAD)
	_check(await _slash_loss("Dummy1") == 1, "TC6 chém lúc ~2,85 s sau khi bị đánh: hết hiệu lực, mất 1")

	await _hurt(false)
	await _wait(1.0)
	await _hurt(false)
	await _wait(BUFF_CHECK_BEFORE - SLASH_LEAD)
	_check(await _slash_loss("Dummy1") == 2, "TC7 chém ~2,15 s sau lần bị đánh cuối: vẫn mất 2 (tính lại giờ)")
	await _wait(BUFF_TIME)
	await _hurt(false)
	await _wait(1.0)
	await _hurt(false)
	await _wait(BUFF_CHECK_AFTER - SLASH_LEAD)
	_check(await _slash_loss("Dummy1") == 1, "TC7 chém ~2,85 s sau lần bị đánh cuối: mất 1")
	for i in 3:
		await _hurt(false)
		await _f(2)
	_check(await _slash_loss("Dummy1") == 2, "TC7 bị đánh 3 lần liền rồi chém: mất 2 (không cộng dồn)")
	await _wait(BUFF_TIME)

	var plain := await _skill_loss("Dummy3")
	# Chờ ngoài khoảng đo buff để lần bấm sau không bị hồi chiêu gió chặn.
	await _wait((_p.get_ability(&"wind_blast") as WindBlastData).get_lockout())
	await _hurt(false)
	var buffed := await _skill_loss("Dummy3")
	_check(plain > 0 and buffed > 0, "TC8 chuẩn bị: cả hai lần Thổi Gió đều trúng mục tiêu")
	_check(plain == buffed, "TC8 Thổi Gió không được cộng (không buff mất %d, có buff mất %d)" % [plain, buffed])
	await _wait(BUFF_TIME)

	await _hurt(false)
	GameState.unequip_charm(_wrath.id)
	await _f(2)
	_check(await _slash_loss("Dummy1") == 1, "TC9 tháo bùa giữa lúc hiệu lực: mất ngay, chém mất 1")

	GameState.equip_charm(_wrath.id)
	await _f(2)
	var nodes_before := _p.find_children("*", "", true, false).size()
	await _hurt(false)
	_close()
	await _open()
	_check(_p.find_children("*", "", true, false).size() == nodes_before, "TC10 dựng lại scene: không sót node của buff")
	_check(await _slash_loss("Dummy1") == 1, "TC10 dựng lại scene giữa lúc hiệu lực: chém mất 1")

	# Đòn bị chặn: bật bất tử dài rồi đánh bằng đòn thường (không xuyên bất tử)
	var hurtbox := _p.get_node("HurtboxComponent") as HurtboxComponent
	var hp := _p.health.current_health
	hurtbox.set_invincible(3.0)
	hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null))
	await _f(2)
	_check(_p.health.current_health == hp, "TC11 chuẩn bị: đòn bị bất tử chặn, không mất máu")
	_check(await _slash_loss("Dummy1") == 1, "TC11 đòn bị chặn không kích hoạt Phẫn Nộ: chém mất 1")
	await _wait(3.0)
	GameState.unequip_charm(_wrath.id)


# ===== UC3: Linh Khí =====
func _tc12_to_tc14_spirit() -> void:
	var base := _p.energy.get_max()
	var bar := _energy_bar()
	_check(bar != null, "TC12 tìm thấy thanh năng lượng HUD")
	GameState.equip_charm(_spirit.id)
	await _f(3)
	_check(_p.energy.get_max() == base + ENERGY_BONUS, "TC12 đeo Linh Khí: tối đa %d -> %d (đang %d)" % [base, base + ENERGY_BONUS, _p.energy.get_max()])
	if bar:
		_check(bar.get_displayed_max() == base + ENERGY_BONUS, "TC12 HUD hiện %d ô (đang %d)" % [base + ENERGY_BONUS, bar.get_displayed_max()])

	_p.energy.set_current(_p.energy.get_max())
	await _f(2)
	_check(_p.energy.current == base + ENERGY_BONUS, "TC13 chuẩn bị: năng lượng đầy %d" % (base + ENERGY_BONUS))
	GameState.unequip_charm(_spirit.id)
	await _f(3)
	_check(_p.energy.get_max() == base, "TC13 tháo: tối đa về %d (đang %d)" % [base, _p.energy.get_max()])
	_check(_p.energy.current <= base, "TC13 tháo khi đầy: năng lượng hiện tại kẹp <= %d (đang %d)" % [base, _p.energy.current])
	if bar:
		_check(bar.get_displayed_max() == base, "TC13 HUD về %d ô (đang %d)" % [base, bar.get_displayed_max()])

	GameState.equip_charm(_spirit.id)
	await _f(2)
	_close()
	await _open()
	_check(_p.energy.get_max() == base + ENERGY_BONUS, "TC14 dựng lại scene: tối đa %d, không cộng hai lần (đang %d)" % [base + ENERGY_BONUS, _p.energy.get_max()])
	_check(_p.energy.current <= _p.energy.get_max(), "TC14 năng lượng hiện tại không vượt tối đa")
	var bar2 := _energy_bar()
	if bar2:
		_check(bar2.get_displayed_max() == base + ENERGY_BONUS, "TC14 HUD vẫn %d ô" % (base + ENERGY_BONUS))
	GameState.unequip_charm(_spirit.id)
	await _f(2)


# ===== UC4: Ưng Nhãn =====
func _tc15_tc16_keen_eye() -> void:
	var f0 := await _min_hold_frames()
	var single: Vector2i = await _probe_volley(f0 + 2)
	_check(single == Vector2i(1, 1), "TC15 không đeo: 1 mũi, tốn 1 năng lượng (đang %s)" % single)
	var plain_damage: int = await _bow_loss("Dummy2")
	_check(plain_damage > 0, "TC15 chuẩn bị: cung gốc thực sự trúng mục tiêu")
	GameState.equip_charm(_keen.id)
	await _f(2)
	var f1 := await _min_hold_frames()
	_check(f0 > 0 and f1 > 0 and absi(f1 - f0) <= 1, "TC15 giữ nguyên thời gian kéo (%d -> %d frame)" % [f0, f1])
	var pool: ObjectPool = _bow_pool()
	var prepared: int = pool.get_total_created()
	# Phép đo số đạn giữ dư hai frame; phép đo ngưỡng kéo đã được kiểm riêng bên trên.
	var full_hold: int = maxi(f0, f1) + 2
	var twin: Vector2i = await _probe_volley(full_hold)
	_check(twin == Vector2i(2, 1), "TC15 đeo: 2 mũi, tổng 1 năng lượng (đang %s)" % twin)
	_check(_arrows_before_followup == 1, "TC15 ngay sau nhả dây chỉ có một mũi, không bắn đồng thời")
	var gap: float = float(_second_arrow_frame - _first_arrow_frame) / float(Engine.physics_ticks_per_second)
	_check(is_equal_approx(gap, 0.20), "TC15 hai phát cách nhau %.3f s" % gap)
	_check(pool.get_active_count() == 2, "TC15 cả hai mũi thực sự đang hoạt động trong pool")
	_check(_bow_actions == 1, "TC15 một lượt chỉ báo hành động dùng cung một lần")
	var twin_damage: int = await _bow_loss("Dummy2")
	_check(twin_damage == plain_damage * 2, "TC15 hai mũi cùng trúng: %d, mong đợi %d" % [twin_damage, plain_damage * 2])
	GameState.equip_charm(_wrath.id)
	await _hurt(false)
	_check(await _bow_loss("Dummy2") == (plain_damage + 1) * 2, "TC15 Phẫn Nộ: cả hai mũi gốc đều được +1")
	GameState.unequip_charm(_wrath.id)
	await _probe_volley(full_hold)
	_check(pool.get_total_created() == prepared, "TC15 pool dùng lại, không tạo thêm tên trong các lượt bắn")
	_check(await _probe_volley(maxi(f1 - 2, 0)) == Vector2i.ZERO, "TC16 thả sớm: không tạo mũi tên và không trừ năng lượng")
	_check(await _probe_volley(full_hold, 0) == Vector2i.ZERO, "TC16 thiếu năng lượng: không bắn cả hai mũi")
	await _stand_before("Dummy2", 12.0)
	for element: StringName in [&"wind", &"fire"]:
		_check(GameState.fuse(element, WeaponData.Slot.BOW), "TC16 ghép cung " + String(element))
		_check(await _probe_volley(full_hold) == Vector2i(2, 1), "TC16 cung ghép vẫn bắn 2 mũi, tốn 1 năng lượng")
		var fusion: FusionData = GameState.FUSIONS.get_fusion(WeaponData.Slot.BOW, element)
		for effect: FusionEffect in fusion.effects:
			var scene: PackedScene = effect.get(&"flight_scene") as PackedScene
			if scene:
				var flight_pool: ObjectPool = _p.get_fusion_pool(effect, scene, int(effect.get(&"flight_pool_size")))
				_check(flight_pool.get_active_count() == 1, "TC16 chỉ một mũi có vệt fusion " + String(element))
		GameState.unfuse(WeaponData.Slot.BOW)
	GameState.unequip_charm(_keen.id)
	await _f(2)
	_check(await _probe_volley(full_hold) == Vector2i(1, 1), "TC16 tháo Ưng Nhãn: trở lại một mũi, tốn 1 năng lượng")
	var f2 := await _min_hold_frames()
	_check(absi(f2 - f0) <= 1, "TC16 tháo bùa: thời gian kéo giữ nguyên (%d frame, ban đầu %d)" % [f2, f0])
	GameState.equip_charm(_keen.id)
	await _tc16_interruptions(full_hold)
	await _tc16_extremes(full_hold)
	await _begin_volley(full_hold)
	_check(_arrow_events == 1 and _p.has_pending_bow_shots(), "TC16 chuẩn bị phát chờ trước khi chết")
	# Hurtbox của cáo giới hạn mỗi đòn mất một máu; phát died thật để thử hủy khi chết.
	_p.health.take_damage(_p.health.current_health)
	await _wait(0.2)
	_check(_p.health.is_dead() and _arrow_events == 1 and not _p.has_pending_bow_shots(), "TC16 chết hủy phát chưa bắn")
	GameState.unequip_charm(_keen.id)


func _bow_pool() -> ObjectPool:
	for child: Node in _p.get_children():
		if child is ObjectPool and (child as ObjectPool).scene == _p.get_bow().projectile_scene:
			return child as ObjectPool
	return null


func _probe_volley(frames: int, energy: int = -1) -> Vector2i:
	var before: int = await _begin_volley(frames, energy)
	_arrows_before_followup = _bow_pool().get_active_count()
	var interval: float = maxf(_p.bow_volley_interval, 1.0 / float(Engine.physics_ticks_per_second))
	await _wait(interval * float(maxi(_p.get_bow_projectile_count() - 1, 1)) + 0.04)
	return Vector2i(_arrow_events, before - _p.energy.current)


func _begin_volley(frames: int, energy: int = -1) -> int:
	# Đợi cả vệt tắt để số đạn đo được chỉ thuộc lượt đang thử.
	await _wait(1.0)
	await _stand_before("Dummy2", 12.0)
	_p.energy.set_current(energy if energy >= 0 else _p.energy.get_max())
	var before: int = _p.energy.current
	_bow_actions = 0
	_arrow_events = 0
	_first_arrow_frame = -1
	_second_arrow_frame = -1
	_followup_state = &""
	_followup_clip = &""
	Input.action_press(&"aim")
	await _f(frames)
	Input.action_release(&"aim")
	await _f(2)
	return before


func _on_bow_projectile(primary: bool) -> void:
	_arrow_events += 1
	if primary:
		_first_arrow_frame = Engine.get_physics_frames()
	elif _second_arrow_frame < 0:
		_second_arrow_frame = Engine.get_physics_frames()
		_followup_state = _p.state_machine.current_state.name
		_followup_clip = (_p.get_node("AnimationPlayer") as AnimationPlayer).current_animation


func _tc16_interruptions(frames: int) -> void:
	for interruption: StringName in [&"dash", &"hurt", &"unequip", &"controls"]:
		var energy_before: int = await _begin_volley(frames)
		_check(_arrow_events == 1 and _p.has_pending_bow_shots(), "TC16 chuẩn bị phát chờ trước " + String(interruption))
		match interruption:
			&"dash":
				await _press(&"dash")
			&"hurt":
				await _hurt(true)
			&"unequip":
				GameState.unequip_charm(_keen.id)
			&"controls":
				_p.set_controls_enabled(false)
		var action_clip: StringName = (_p.get_node("AnimationPlayer") as AnimationPlayer).current_animation
		await _wait(0.3)
		if interruption == &"dash" or interruption == &"hurt":
			_check(_arrow_events == 2 and not _p.has_pending_bow_shots(), "TC16 vẫn đủ hai phát khi " + String(interruption))
			var expected_state: StringName = PlayerState.DASH if interruption == &"dash" else PlayerState.HURT
			_check(_followup_state == expected_state, "TC16 phát thứ hai ngay trong state " + String(expected_state))
			_check(_followup_clip == action_clip, "TC16 không ghi đè clip " + String(interruption))
		else:
			_check(_arrow_events == 1 and not _p.has_pending_bow_shots(), "TC16 hủy phát thứ hai khi " + String(interruption))
		_check(energy_before - _p.energy.current == 1, "TC16 ngắt hành động vẫn chỉ trừ một năng lượng")
		_p.set_controls_enabled(true)
		if interruption == &"unequip":
			GameState.equip_charm(_keen.id)
	await _begin_volley(frames)
	var old_player: WeakRef = weakref(_p)
	_close()
	await _f(2)
	await _open()
	_check(old_player.get_ref() == null and not _p.has_pending_bow_shots(), "TC16 đổi khu hủy Timer và không giữ player cũ")


func _tc16_extremes(frames: int) -> void:
	var interval: float = _p.bow_volley_interval
	var limit: int = _p.bow_volley_limit
	_p.bow_volley_interval = 0.0
	_check(await _probe_volley(frames) == Vector2i(2, 1), "TC16 khoảng cách 0: vẫn bắn đủ hai phát, không vòng lặp tức thời")
	_check(_second_arrow_frame - _first_arrow_frame == 1, "TC16 khoảng cách 0: hai phát ở hai bước vật lý liên tiếp")
	_p.bow_volley_interval = 1000.0
	await _begin_volley(frames)
	await _wait(0.3)
	_check(_arrow_events == 1 and _p.has_pending_bow_shots(), "TC16 khoảng cách rất lớn: không bắn sớm")
	_p.set_controls_enabled(false)
	await _f(2)
	_p.set_controls_enabled(true)
	_p.bow_volley_interval = 0.0
	_p.bow_volley_limit = 0
	_check(await _probe_volley(frames) == Vector2i(1, 1), "TC16 giới hạn 0: kẹp về một phát")
	_p.bow_volley_limit = 999999
	_p.stats.set_bonus(&"bow_extra_projectiles", &"test_volley", 999999.0)
	_check(await _probe_volley(frames) == Vector2i(8, 1), "TC16 chỉ số rất lớn: kẹp tám phát, tổng một năng lượng")
	_p.stats.set_bonus(&"bow_extra_projectiles", &"test_volley", -999999.0)
	_check(await _probe_volley(frames) == Vector2i(1, 1), "TC16 chỉ số âm: vẫn một phát")
	_p.stats.remove_bonus(&"bow_extra_projectiles", &"test_volley")
	_p.bow_volley_interval = interval
	_p.bow_volley_limit = limit


func _on_bow_action(_element: StringName, _skill: StringName) -> void:
	_bow_actions += 1


## Số frame giữ ngắm ít nhất để bắn ra tên (tìm tuyến tính, mỗi lần một phát)
func _min_hold_frames() -> int:
	for frames in range(4, MAX_HOLD_FRAMES):
		if await _fires_after(frames):
			return frames
	return -1


## Giữ ngắm đúng frames frame rồi thả; bắn được thì năng lượng giảm
func _fires_after(frames: int) -> bool:
	_p.energy.set_current(_p.energy.get_max())
	await _f(3)
	var before := _p.energy.current
	Input.action_press(&"aim")
	await _f(frames)
	Input.action_release(&"aim")
	await _f(6)
	var fired := _p.energy.current < before
	# Chờ thu tay xong trước lượt sau
	await _wait(0.4)
	return fired


# ===== Đo sát thương =====
## Đứng trước mục tiêu, chém một nhát, trả về số máu mục tiêu mất
func _slash_loss(target: String) -> int:
	await _stand_before(target, 1.4)
	_refill(target)
	var hp := _hp(target)
	await _press(&"attack")
	await _wait(SLASH_HIT_WAIT)
	var loss := hp - _hp(target)
	await _wait(COMBO_RESET)
	return loss


func _bow_loss(target: String) -> int:
	# Tên thứ hai của lượt đếm đạn có thể còn bay; không để nó cộng lẫn vào phép đo sát thương mới.
	var pool: ObjectPool = _bow_pool()
	var clean_deadline: int = Engine.get_physics_frames() + Engine.physics_ticks_per_second * 2
	while pool.get_active_count() > 0 and Engine.get_physics_frames() < clean_deadline:
		await _f(1)
	_check(pool.get_active_count() == 0, "chuẩn bị: tên từ lượt trước đã trở về pool")
	await _stand_before(target, 5.0)
	_refill(target)
	_p.energy.set_current(_p.energy.get_max())
	var hp := _hp(target)
	Input.action_press(&"aim")
	# Lượt đo trước có thể vừa nhả dây; chờ vào state thật thay vì tính hồi chiêu vào thời gian kéo.
	var deadline: int = Engine.get_physics_frames() + Engine.physics_ticks_per_second * 2
	while _p.state_machine.current_state.name != PlayerState.BOW_AIM and Engine.get_physics_frames() < deadline:
		await _f(1)
	_check(_p.state_machine.current_state.name == PlayerState.BOW_AIM, "chuẩn bị: cung đã vào state kéo dây")
	await _wait(BOW_HOLD)
	Input.action_release(&"aim")
	await _wait(ARROW_FLIGHT)
	return hp - _hp(target)


func _skill_loss(target: String) -> int:
	await _stand_before(target, 1.6)
	_refill(target)
	_p.energy.set_current(_p.energy.get_max())
	var hp := _hp(target)
	await _press(&"skill")
	await _wait(0.6)
	return hp - _hp(target)


## Player nhận 1 sát thương thật (xuyên bất tử để không phụ thuộc i-frame của lần trước); hồi máu để không chết
func _hurt(staggers: bool) -> void:
	var info := DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	info.ignores_invincibility = true
	info.staggers = staggers
	var hp := _p.health.current_health
	_p.get_node("HurtboxComponent").receive_hit(info)
	if _p.health.current_health >= hp:
		_check(false, "chuẩn bị: player không mất máu khi bị đánh thử (hp %d)" % hp)
	_p.health.heal_full()
	await _f(1)


# ===== Tiện ích =====
func _open() -> void:
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	_test_view.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.combat_action_committed.connect(_on_bow_action)
	_p.bow_projectile_fired.connect(_on_bow_projectile)
	for n: Node in _lv.get_children():
		if n is Enemy:
			n.set_physics_process(false)
			n.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED


func _close() -> void:
	set_physics_process(false)
	_aim_target = null
	Input.action_release(&"aim")
	if is_instance_valid(_lv):
		_lv.get_parent().remove_child(_lv)
		_lv.queue_free()
	_lv = null
	_p = null


func _energy_bar() -> EnergyBar:
	var found := _p.find_children("*", "EnergyBar", true, false)
	return found[0] as EnergyBar if not found.is_empty() else null


func _stand_before(target: String, dist: float) -> void:
	_aim_target = _lv.get_node(NodePath(target)) as Node3D
	set_physics_process(true)
	_p.teleport((_lv.get_node(target) as Node3D).global_position + Vector3(0, 0.2, dist), Vector3.FORWARD)
	await _f(8)
	_p.face_instantly(Vector3.FORWARD)


func _refill(target: String) -> void:
	var h := _lv.get_node(target).get_node("HealthComponent") as HealthComponent
	h.set_max_health(99, true)
	h.heal_full()


func _hp(target: String) -> int:
	return (_lv.get_node(target).get_node("HealthComponent") as HealthComponent).current_health


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _f(2)
	Input.action_release(action)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
