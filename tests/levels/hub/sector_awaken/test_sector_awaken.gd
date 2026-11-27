extends Node
## Test khu nguyên tố ở Đền Tứ Linh (SectorAwaken) trên hub thật. Chạy headless; tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1 Chơi mới: khu Gió thức sẵn (cung không phủ tối, mạch năng lượng sáng, không có màn chắn cổng).
##     Lửa, Băng, Sét ngủ: mọi mesh của cung phủ lớp tối, mạch tắt, màn chắn cổng hiện.
## UC2 Đang đứng ở hub, thắng boss Gió (cờ) -> khu Lửa thức: phát awaken_started đúng 1 lần, camera quay sang cung Lửa,
##     hết thời gian thì bỏ lớp tối, mạch sáng, màn chắn tắt, lưu cờ đã xem; trả điều khiển cho player.
##     Khu Băng không bị ảnh hưởng (nhiều bản sao trong một map không lẫn nhau).
## UC3 Nạp lại hub (đã xem) -> khu Lửa thức ngay, không chiếu lại.
## UC4 Đã phá khu Gió nhưng chưa xem lễ thức (ví dụ thắng boss rồi tắt game) -> vào hub thì chiếu lễ thức 1 lần.
## UC5 Thông số cực đoan: awaken_delay = 0, awaken_time = 0 -> thức ngay trong vài khung hình, không lỗi.
## UC6 Khu chưa có scene (Sét) vẫn ngủ dù khu trước đã phá.
##
## ===== TEST CASE =====
## TC1 (UC1)  Hub mới: Gió is_awake, Lửa / Băng / Sét không; đếm mesh phủ tối, mạch, màn chắn từng khu.
## TC2 (UC2)  Đặt zone.wind.cleared: awaken_started Lửa = 1, Băng = 0; sau delay + time: Lửa thức, cờ hub.awaken.fire,
##            cutscene Lửa đã chạy và xong, player điều khiển lại được.
## TC3 (UC3)  Nạp lại: Lửa thức ngay ở khung đầu, awaken_started = 0.
## TC4 (UC4)  Xoá cờ đã xem rồi nạp lại: awaken_started = 1 sau khi khu sẵn sàng, cuối cùng thức.
## TC5 (UC5)  Delay 0, time 0: thức sau tối đa 3 khung hình.
## TC6 (UC6)  Có zone.ice.cleared: Sét vẫn ngủ.

const HUB := "res://levels/temple_center/hub/hub.tscn"
const SECTORS := ["Wind", "Fire", "Ice", "Thunder"]

var _fails: int = 0
var _hub: Node3D


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	var stand_in := Node.new()
	stand_in.name = "StandIn"
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	_grant_fire_password()
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"hub.intro_seen")
	await _load_hub()
	_tc1_fresh()
	await _tc2_awaken_live()
	await _tc3_reload_seen()
	await _tc4_reload_unseen()
	await _tc5_extreme()
	_tc6_no_scene()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _load_hub(tweak: Callable = Callable()) -> void:
	if is_instance_valid(_hub):
		_hub.queue_free()
		await get_tree().process_frame
	_hub = (load(HUB) as PackedScene).instantiate() as Node3D
	if tweak.is_valid():
		tweak.call(_hub)
	get_tree().root.add_child(_hub)
	await _wait(1.0)


func _sector(n: String) -> Node:
	return _hub.get_node_or_null("Sectors/" + n)


func _awake(n: String) -> bool:
	var s := _sector(n)
	return s != null and s.has_method(&"is_awake") and s.call(&"is_awake")


## [số mesh có lớp tối, tổng mesh của cung, mạch đang hiện, màn chắn đang hiện]
func _look(n: String) -> Array:
	var palace := _hub.get_node_or_null("HubScenery/Palace" + n) as Node3D
	var veil := palace.find_child("Gate_*_Veil", true, false) as Node3D if palace else null
	var dark := 0
	var total := 0
	if palace:
		for m: Node in palace.find_children("*", "MeshInstance3D", true, false):
			if m == veil:
				continue
			total += 1
			if (m as MeshInstance3D).material_overlay != null:
				dark += 1
	var conduit := _hub.get_node_or_null("HubScenery/Platform/Conduit_" + n.to_lower()) as Node3D
	return [dark, total, conduit != null and conduit.is_visible_in_tree(), veil != null and veil.is_visible_in_tree()]


func _tc1_fresh() -> void:
	for n: String in SECTORS:
		_check(_sector(n) != null, "TC1: có node Sectors/%s" % n)
	var wind := _look("Wind")
	_check(_awake("Wind") and wind[1] > 0 and wind[0] == 0 and wind[2] and not wind[3], "TC1: Gió thức sẵn (tối %d/%d mesh, mạch %s, màn %s)" % wind)
	for n: String in ["Fire", "Ice", "Thunder"]:
		var look := _look(n)
		_check(not _awake(n) and look[1] > 0 and look[0] == look[1] and not look[2] and look[3], "TC1: %s ngủ (tối %d/%d mesh, mạch %s, màn %s)" % ([n] + look))


func _tc2_awaken_live() -> void:
	var fire := _sector("Fire")
	var ice := _sector("Ice")
	if fire == null or ice == null or not fire.has_signal(&"awaken_started"):
		_check(false, "TC2: thiếu SectorAwaken Lửa / Băng")
		return
	var counts := {"fire": 0, "ice": 0, "cut": 0, "cut_done": 0}
	fire.connect(&"awaken_started", func() -> void: counts.fire += 1)
	ice.connect(&"awaken_started", func() -> void: counts.ice += 1)
	var cut := _hub.get_node_or_null("Sectors/FireAwakenCut")
	if cut:
		cut.connect(&"started", func() -> void: counts.cut += 1)
		cut.connect(&"finished", func() -> void: counts.cut_done += 1)
	GameState.set_flag(&"zone.wind.cleared")
	await get_tree().process_frame
	_check(counts.fire == 1 and not _awake("Fire"), "TC2: thắng boss Gió -> Lửa bắt đầu thức (awaken_started %d lần), chưa thức xong ngay" % counts.fire)
	var total_time: float = fire.get(&"awaken_delay") + fire.get(&"awaken_time")
	await _wait(total_time + 0.6)
	var look := _look("Fire")
	_check(_awake("Fire") and look[0] == 0 and look[2] and not look[3], "TC2: hết %.1f s -> Lửa thức (tối %d/%d mesh, mạch %s, màn %s)" % ([total_time] + look))
	_check(GameState.has_flag(&"hub.awaken.fire"), "TC2: lưu cờ đã xem hub.awaken.fire")
	_check(counts.ice == 0 and not _awake("Ice") and _look("Ice")[0] == _look("Ice")[1], "TC2: Băng không bị ảnh hưởng (awaken_started %d)" % counts.ice)
	var player := _hub.get_node("Player") as Player
	var t := 0.0
	while counts.cut_done == 0 and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(counts.cut == 1 and counts.cut_done == 1 and player.controls_enabled, "TC2: camera quay sang cung Lửa rồi trả về (bắt đầu %d, xong %d), player điều khiển lại được" % [counts.cut, counts.cut_done])


func _tc3_reload_seen() -> void:
	var started := [0]
	await _load_hub(func(hub: Node) -> void:
		var fire := hub.get_node_or_null("Sectors/Fire")
		if fire and fire.has_signal(&"awaken_started"):
			fire.connect(&"awaken_started", func() -> void: started[0] += 1))
	_check(_awake("Fire") and started[0] == 0 and _look("Fire")[0] == 0, "TC3: nạp lại -> Lửa thức ngay, không chiếu lại (awaken_started %d)" % started[0])


func _tc4_reload_unseen() -> void:
	GameState.progress.flags.erase(&"hub.awaken.fire")
	var started := [0]
	await _load_hub(func(hub: Node) -> void:
		var fire := hub.get_node_or_null("Sectors/Fire")
		if fire and fire.has_signal(&"awaken_started"):
			fire.connect(&"awaken_started", func() -> void: started[0] += 1))
	var fire := _sector("Fire")
	var total_time: float = fire.get(&"awaken_delay") + fire.get(&"awaken_time") if fire else 0.0
	await _wait(total_time + 0.6)
	_check(started[0] == 1 and _awake("Fire") and GameState.has_flag(&"hub.awaken.fire"), "TC4: chưa xem -> vào hub chiếu lễ thức 1 lần (%d) rồi thức" % started[0])


func _tc5_extreme() -> void:
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"hub.intro_seen")
	await _load_hub(func(hub: Node) -> void:
		var fire := hub.get_node_or_null("Sectors/Fire")
		if fire:
			fire.set(&"awaken_delay", 0.0)
			fire.set(&"awaken_time", 0.0))
	GameState.set_flag(&"zone.wind.cleared")
	for i in 3:
		await get_tree().process_frame
	_check(_awake("Fire") and _look("Fire")[0] == 0, "TC5: delay 0, time 0 -> thức sau 3 khung hình")


func _tc6_no_scene() -> void:
	GameState.set_flag(&"zone.fire.cleared")
	GameState.set_flag(&"zone.ice.cleared")
	_check(not _awake("Thunder") and _look("Thunder")[3], "TC6: Sét chưa có scene -> vẫn ngủ dù đã phá Băng")


## Cổng Lửa còn cần mật khẩu (bản cho người test): ghi sẵn "đã nhập đúng" vào file mật khẩu của thư mục dữ liệu test,
## để test này chỉ kiểm luật phá khu / lễ thức. Luồng nhập mật khẩu kiểm riêng trong test_password_gate
func _grant_fire_password() -> void:
	var hub := (load(HUB) as PackedScene).instantiate()
	for c in (hub.get_node("Gates/FireGate") as ZoneGate).conditions:
		if c is PasswordUnlock:
			var cfg := ConfigFile.new()
			cfg.load(PasswordUnlock.store_path)
			cfg.set_value(PasswordUnlock.SECTION, String((c as PasswordUnlock).access_id), (c as PasswordUnlock).password_sha256)
			cfg.save(PasswordUnlock.store_path)
	hub.free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
