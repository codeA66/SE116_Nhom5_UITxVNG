extends Node
## Test luồng mini boss hổ tier 1 map Lửa. Chạy headless, save riêng của test (không ghi save thật).
##
## ===== USE CASE =====
## UC1  Phòng 10 tier 1 không còn trận bò tót; có người chèo đò đứng chờ; cổng dịch chuyển chưa hiện.
## UC2  Nói chuyện lần đầu: nghe dặn, Bùa Đoạt Tiễn RƠI RA đất trước mặt người chèo đò (một lần), không hỏi gọi
##      thuyền. Chưa vào túi cho tới khi player đi tới bấm nhặt. Đã có bùa sẵn (lệnh dev mở hết) thì vẫn rơi ra.
## UC3  Nói chuyện lần sau: nhắc đeo bùa, không tặng thêm.
## UC4  Đeo bùa ở checkpoint (chỗ đổi bùa) -> cổng dịch chuyển ở phòng 10 hiện, trỏ tới đấu trường hổ.
##      Tháo bùa thì cổng vẫn mở. Ngoài checkpoint không đeo được.
## UC5  Nạp lại tier 1 sau khi cổng đã mở -> cổng hiện sẵn.
## UC6  Tới đấu trường: song sắt mở, hổ nằm yên trong ổ, cổng ra tier 2 chưa có.
## UC7  Bước vào sân: cắt cảnh nhìn hổ (khoá điều khiển), song sắt sập; cắt cảnh xong thì trận bắt đầu.
## UC8  Hạ hổ: lưu cờ level_3.boss_defeated, song sắt mở, cổng sang tier 2 hiện.
## UC9  Vào lại đấu trường sau khi thắng: không có hổ, song sắt mở, cổng tier 2 hiện sẵn, không chiếu cắt cảnh.
## UC10 Chết rồi vào lại (đã xem cắt cảnh, chưa thắng): bước vào là đánh ngay, không chiếu lại, song sắt vẫn sập.
##
## ===== TEST CASE =====
## TC1 (UC1)  tier_1: không có Room10BossFight, file không tham chiếu boss_1.tscn; Room10Keeper là Npc nằm trong
##            phòng 10; Room10TigerPortal chưa hiện.
## TC2 (UC2)  talk_requested + bấm interact hết câu -> cờ charm_given, bùa CHƯA vào túi, Room10CharmDrop/CharmPickup
##            hiện trên đất trong phòng 10; đứng tại chỗ bùa bấm interact thật -> có arrow_rend_charm, vật nhặt biến mất;
##            không mở hỏi gọi thuyền, trả điều khiển.
## TC2b (UC2) Tiến trình mới đã có sẵn bùa: nói chuyện -> bùa vẫn rơi ra trên đất.
## TC3 (UC3)  Lời chào đổi sang đoạn khác; nói hết lần nữa -> vẫn đúng 1 bùa.
## TC4 (UC4)  equip ngoài checkpoint -> false, cổng ẩn; vào chỗ đổi bùa + equip -> cờ portal_open, Portal trong cây,
##            target_zone = đấu trường; tháo bùa -> Portal vẫn trong cây.
## TC5 (UC5)  Nạp lại tier_1 -> Portal hiện ngay.
## TC6 (UC6)  Nạp đấu trường: player ở mốc vào, song sắt mở (va chạm tắt), trận chưa chạy, cổng ra chưa hiện.
## TC7 (UC7)  Đưa player vào sân -> cắt cảnh chạy, player bị khoá, song sắt sập (va chạm bật); hết cắt cảnh -> trận
##            chạy, boss là FireSabretooth, player điều khiển lại được, cờ intro_seen.
## TC8 (UC8)  Boss phát died -> cờ boss_defeated, song sắt mở, cổng ra trong cây trỏ tier_2 / start.
## TC9 (UC9)  Nạp lại đấu trường -> không boss, song sắt mở, cổng ra hiện, cắt cảnh không chạy khi đi vào.
## TC10 (UC10) Tiến trình chỉ có intro_seen: đi vào -> trận chạy ngay (không cắt cảnh), song sắt sập.

const TIER_1 := "res://levels/zone_3_fire/tier_1/tier_1.tscn"
const ARENA := "res://levels/zone_3_fire/tier_1/tiger_arena/tiger_arena.tscn"
const TIER_2 := "res://levels/zone_3_fire/tier_2/tier_2.tscn"
const CHARM := &"arrow_rend_charm"
const GIFT_FLAG := &"level_3.tiger.charm_given"
const PORTAL_FLAG := &"level_3.tiger.portal_open"
const INTRO_FLAG := &"level_3.tiger.intro_seen"
const BOSS_FLAG := &"level_3.boss_defeated"
## Phòng 10 trong toạ độ thế giới của tier 1 (x, z nhỏ nhất / lớn nhất)
const ROOM_10 := Rect2(148.0, 32.0, 28.0, 28.0)

var _fails: int = 0
var _zone: Node3D
var _player: Player


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	await _load(TIER_1)
	_tc1_room_10()
	await _tc2_gift()
	await _tc3_repeat()
	await _tc4_equip()
	await _load(TIER_1)
	_check(_portal_in_tree(), "TC5: nạp lại tier 1 -> cổng dịch chuyển hiện sẵn")
	await _tc6_to_9_arena()
	await _tc10_retry()
	await _tc2b_owned_still_drops()
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _load(path: String) -> void:
	if is_instance_valid(_zone):
		_zone.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_player = null
	var scene := load(path) as PackedScene
	_check(scene != null, "Nạp được %s" % path)
	if scene == null:
		_finish()
		return
	_zone = scene.instantiate() as Node3D
	(_zone as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	get_tree().root.add_child(_zone)
	var t := 0.0
	while _player == null and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)


# ---------- Tier 1 ----------

func _keeper() -> Npc:
	return _zone.get_node_or_null("Room10Keeper") as Npc


func _portal_in_tree() -> bool:
	var portal := _zone.get_node_or_null("Room10TigerPortal/Portal") as Portal
	return portal != null and portal.is_inside_tree()


func _tc1_room_10() -> void:
	_check(_zone.get_node_or_null("Room10BossFight") == null, "TC1: không còn trận bò tót ở phòng 10")
	_check(not FileAccess.get_file_as_string(TIER_1).contains("boss_1.tscn"), "TC1: tier 1 không tham chiếu boss_1.tscn")
	var keeper := _keeper()
	_check(keeper != null, "TC1: có người chèo đò Room10Keeper")
	if keeper:
		var p := keeper.global_position
		_check(ROOM_10.has_point(Vector2(p.x, p.z)), "TC1: người chèo đò đứng trong phòng 10 (%.1f, %.1f)" % [p.x, p.z])
	_check(_zone.get_node_or_null("Room10TigerPortal") != null and not _portal_in_tree(), "TC1: cổng dịch chuyển chưa hiện")


func _tc2_gift() -> void:
	var keeper := _keeper()
	if keeper == null:
		return
	# Đứng sát người chèo đò như lúc nói chuyện thật: lần bấm đóng câu thoại cuối không được nhặt luôn bùa vừa rơi
	_player.teleport(keeper.global_position + Vector3(0.0, 0.1, 1.2), Vector3.FORWARD)
	await _wait(0.4)
	keeper.talk_requested.emit(_player)
	await _wait(0.3)
	await _finish_lines(keeper)
	await _wait(0.5)
	_check(GameState.has_flag(GIFT_FLAG), "TC2: lưu cờ đã tặng bùa")
	_check(not keeper.get_dialogue_box().is_open(), "TC2: không mở hỏi gọi thuyền / hộp thoại đã đóng")
	_check(_player.controls_enabled, "TC2: nói xong trả điều khiển")
	# Player đứng sát người chèo đò bấm đóng câu thoại cuối: bùa rơi đủ xa nên không bị nhặt luôn
	_check(not GameState.owns_charm(CHARM), "TC2: bùa chưa vào túi khi chưa nhặt (bấm đóng thoại ở chỗ đứng nói chuyện không nhặt luôn)")
	var drop := _charm_drop()
	_check(drop != null and drop.is_inside_tree() and drop.is_visible_in_tree(), "TC2: bùa rơi ra, nằm trên đất")
	if drop == null or not drop.is_inside_tree():
		return
	var p := drop.global_position
	_check(ROOM_10.has_point(Vector2(p.x, p.z)), "TC2: bùa rơi trong phòng 10 (%.1f, %.1f)" % [p.x, p.z])
	# Nhặt thật: đứng ngay chỗ bùa rồi bấm phím tương tác
	_player.teleport(p + Vector3(0.0, 0.1, 0.6), Vector3.FORWARD)
	await _wait(0.5)
	await _press(&"interact")
	await _wait(0.5)
	_check(GameState.owns_charm(CHARM), "TC2: bấm nhặt -> có Bùa Đoạt Tiễn")
	_check(not is_instance_valid(drop) or not drop.is_inside_tree() or not drop.is_visible_in_tree(), "TC2: nhặt xong vật trên đất biến mất")
	var notice := _player.get_node_or_null("HUD/ItemNotice")
	_check(notice != null and notice.call(&"is_showing") and String(notice.call(&"get_current_name")) == "Bùa Đoạt Tiễn", "TC2: hiện banner 'Nhận được Bùa Đoạt Tiễn'")
	_check(GameState.has_tutorial(&"arrow_rend_charm"), "TC2: mở hướng dẫn ra checkpoint đeo Bùa Đoạt Tiễn")


## Bùa rơi trước mặt người chèo đò (nằm trong FlagReveal theo cờ đã tặng)
func _charm_drop() -> Node3D:
	return _zone.get_node_or_null("Room10CharmDrop/CharmPickup") as Node3D


func _tc2b_owned_still_drops() -> void:
	var progress := PlayerProgress.new()
	GameState.replace_progress(progress)
	GameState.add_charm(load("res://resources/player/items/charms/special/arrow_rend_charm.tres") as CharmData)
	await _load(TIER_1)
	var keeper := _keeper()
	if keeper == null:
		return
	keeper.talk_requested.emit(_player)
	await _wait(0.3)
	await _finish_lines(keeper)
	await _wait(0.5)
	var drop := _charm_drop()
	_check(drop != null and drop.is_inside_tree() and drop.is_visible_in_tree(), "TC2b: đã có bùa sẵn -> nói chuyện vẫn rơi bùa ra đất")


func _tc3_repeat() -> void:
	var keeper := _keeper()
	if keeper == null:
		return
	var greeting := keeper.pick_dialogue(Npc.CONTEXT_GREETING)
	_check(greeting != null and not greeting.conditions.is_empty(), "TC3: lần sau đổi sang đoạn nhắc đeo bùa")
	var before := GameState.progress.charms.size()
	keeper.talk_requested.emit(_player)
	await _wait(0.3)
	await _finish_lines(keeper)
	await _wait(0.5)
	_check(GameState.progress.charms.size() == before and GameState.progress.charms.count(CHARM) == 1, "TC3: không tặng thêm bùa")


func _tc4_equip() -> void:
	# Player xuất hiện ở checkpoint đầu map (chỗ đổi bùa): đưa vào giữa phòng 10, xa mọi checkpoint
	_player.teleport(Vector3(162.0, 4.4, 46.0), Vector3.FORWARD)
	await _wait(0.5)
	_check(not GameState.can_change_charms(), "TC4: giữa phòng 10 không phải chỗ đổi bùa")
	_check(not GameState.equip_charm(CHARM), "TC4: ngoài checkpoint không đeo được")
	await _wait(0.2)
	_check(not _portal_in_tree(), "TC4: chưa đeo -> cổng chưa hiện")
	GameState.enter_charm_station()
	_check(GameState.equip_charm(CHARM), "TC4: ở checkpoint đeo được bùa")
	await _wait(0.3)
	_check(GameState.has_flag(PORTAL_FLAG), "TC4: đeo bùa -> lưu cờ mở cổng")
	_check(_portal_in_tree(), "TC4: cổng dịch chuyển hiện")
	var portal := _zone.get_node_or_null("Room10TigerPortal/Portal") as Portal
	_check(portal != null and portal.target_zone == ARENA, "TC4: cổng trỏ tới đấu trường hổ")
	GameState.unequip_charm(CHARM)
	GameState.exit_charm_station()
	await _wait(0.3)
	_check(_portal_in_tree(), "TC4: tháo bùa -> cổng vẫn mở")


# ---------- Đấu trường ----------

func _fight() -> BossFight:
	return _zone.get_node_or_null("TigerFight") as BossFight


func _gate_closed() -> bool:
	var gate := _zone.get_node_or_null("EntryGate")
	return gate != null and gate.call(&"is_closed")


func _exit_in_tree() -> bool:
	var portal := _zone.get_node_or_null("ExitReveal/Portal") as Portal
	return portal != null and portal.is_inside_tree()


func _intro() -> CameraCutscene:
	return _zone.get_node_or_null("TigerIntro") as CameraCutscene


## Đưa player qua song sắt vào giữa sân (vùng kích hoạt trận)
func _enter_arena() -> void:
	var inside := _zone.get_node_or_null("Anchors/ArenaInside") as Node3D
	_player.teleport(inside.global_position, Vector3.RIGHT)
	await _wait(0.3)


func _tc6_to_9_arena() -> void:
	await _load(ARENA)
	var entry := SpawnPoint.find_in(_zone, &"tiger_arena_entry")
	_check(entry != null and _player.global_position.distance_to(entry.global_position) < 0.6, "TC6: player ở mốc vào đấu trường")
	_check(_fight() != null and not _fight().is_running(), "TC6: trận chưa chạy, hổ nằm yên")
	_check(_zone.get_node_or_null("EntryGate") != null and not _gate_closed(), "TC6: song sắt đang mở")
	_check(not _exit_in_tree(), "TC6: cổng ra tier 2 chưa hiện")
	if _fight() == null or _intro() == null:
		return
	await _enter_arena()
	_check(_intro().is_processing() and not _player.controls_enabled, "TC7: bước vào -> cắt cảnh chạy, player bị khoá")
	_check(_gate_closed(), "TC7: song sắt sập sau lưng")
	var t := 0.0
	while _intro().is_processing() and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.3)
	_check(_fight().is_running() and _fight().boss is FireSabretooth, "TC7: cắt cảnh xong -> đánh hổ")
	_check(_player.controls_enabled, "TC7: player điều khiển lại được")
	_check(GameState.has_flag(INTRO_FLAG), "TC7: lưu cờ đã xem cắt cảnh")
	var boss := _fight().boss
	boss.emit_signal(&"died", boss)
	await _wait(1.2)
	_check(GameState.has_flag(BOSS_FLAG), "TC8: hạ hổ -> cờ level_3.boss_defeated")
	_check(not _gate_closed(), "TC8: song sắt mở lại")
	_check(_exit_in_tree(), "TC8: cổng sang tier 2 hiện")
	var exit := _zone.get_node_or_null("ExitReveal/Portal") as Portal
	_check(exit != null and exit.target_zone == TIER_2 and exit.target_portal_id == &"start", "TC8: cổng ra trỏ tier 2 / start")
	await _load(ARENA)
	_check(_fight().boss == null and not _gate_closed() and _exit_in_tree(), "TC9: vào lại sau khi thắng -> không hổ, song sắt mở, cổng ra hiện")
	await _enter_arena()
	_check(not _intro().is_processing() and _player.controls_enabled and not _gate_closed(), "TC9: không chiếu cắt cảnh, không sập song sắt")


func _tc10_retry() -> void:
	var progress := PlayerProgress.new()
	GameState.replace_progress(progress)
	GameState.set_flag(INTRO_FLAG)
	await _load(ARENA)
	if _fight() == null or _intro() == null:
		return
	await _enter_arena()
	await _wait(0.5)
	_check(not _intro().is_processing() and _fight().is_running(), "TC10: đã xem cắt cảnh -> bước vào là đánh ngay")
	_check(_gate_closed(), "TC10: song sắt vẫn sập")


# ---------- Tiện ích ----------

func _finish_lines(npc: Npc) -> void:
	for index in 20:
		var box := npc.get_dialogue_box()
		if not box.is_open() or box._mode != DialogueBox.Mode.LINES:
			break
		box._reveal_all()
		await _press(&"interact")
		await get_tree().process_frame


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
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
