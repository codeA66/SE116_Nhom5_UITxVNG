extends Node
## Test khu trung tâm (Đền Tứ Linh). Chạy: mở test_hub.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1  Chơi mới -> xuất hiện ở chiếu nghỉ chân cầu thang phía nam (START_ZONE = hub).
## UC2  Cổng Gió mở sẵn (không cần chìa). Cổng Lửa / Băng / Sét khóa: đẩy vào cổng Lửa không lọt qua, không chuyển khu.
## UC3  Đi bộ thật: chân cầu thang -> lên sân; ép vào lan can mép sân không rơi ra ngoài; ép vào bệ tâm không leo lên.
## UC4  Chưa thắng boss Gió: cổng Lửa đóng, bảng ghi "Đánh bại boss Khu Gió", hub không còn chìa Lửa.
##      Thắng boss Gió (cờ zone.wind.cleared) -> dấu Gió sáng, cổng Lửa mở 1 lần (dẫn tới map lửa, điểm "start"); cổng Băng còn khóa.
## UC6  Lưu / nạp lại -> cổng Gió + cổng Lửa vẫn mở.
## UC7  Bước vào cổng Gió đã mở -> chờ vào đúng khu Gió rồi mới kiểm tra cổng tiếp theo.
## UC8  Quay lại hub, bước vào cổng Lửa -> nạp tier 1 Lửa và đứng ở điểm spawn phòng 1.
## UC9  Vào map lửa với tay trắng: có sẵn kiếm (đang cầm, hiện trên tay), cung, kỹ năng Gió; chưa dung hợp.
##      Bù lại lần nữa (hồi sinh): không nhân đôi vũ khí / kỹ năng.

const HUB: String = "res://levels/temple_center/hub/hub.tscn"
const WIND: String = "res://levels/zone_1_wind/level_1/level_1.tscn"
const FIRE: String = "res://levels/zone_3_fire/tier_1/tier_1.tscn"
## Chừa thời gian cho các ca kiểm tra trước UC7 trong giới hạn 240 giây của CI.
const PORTAL_BUDGET_MS: int = 180_000

var _fails: int = 0
var _hub: ZoneRoot
var _p: Player
var _portal_deadline_ms: int


func _ready() -> void:
	SaveManager.block_saving()
	_run.call_deferred()


func _run() -> void:
	_grant_fire_password()
	GameState.replace_progress(PlayerProgress.new())
	# Bỏ đoạn camera giới thiệu (khóa điều khiển ~8 s); đoạn này kiểm tra riêng bằng ảnh chụp
	GameState.set_flag(&"hub.intro_seen")
	# Bỏ lễ thức khu (camera cắt cảnh khóa điều khiển); lễ thức kiểm tra riêng trong test_sector_awaken
	for id in [&"hub.awaken.fire", &"hub.awaken.ice", &"hub.awaken.thunder"]:
		GameState.set_flag(id)
	_check(SceneManager.START_ZONE == HUB, "UC1: START_ZONE là khu trung tâm")
	await _load_hub()
	_uc1_spawn()
	await _uc2_locked()
	await _uc3_walk()
	await _uc4_wind_cleared()
	await _capture("hub_fire_open.png")
	await _uc6_reload()
	_portal_deadline_ms = Time.get_ticks_msec() + PORTAL_BUDGET_MS
	if await _enter_gate("WindGate", "UC7", WIND):
		await _uc8_enter_fire_gate()
	print("RESULT fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _load_hub() -> void:
	if is_instance_valid(_hub):
		_hub.queue_free()
		await get_tree().process_frame
	var hub: ZoneRoot = (load(HUB) as PackedScene).instantiate() as ZoneRoot
	get_tree().root.add_child(hub)
	# Để SceneManager dọn đúng map khi qua cổng. Node chạy test nằm riêng ở root.
	get_tree().current_scene = hub
	if not hub.is_combat_ready():
		await hub.combat_ready
	_use_hub(hub)


func _use_hub(hub: ZoneRoot) -> void:
	_hub = hub
	_p = _hub.get_node(^"Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)


func _gate(name_: String) -> ZoneGate:
	return _hub.get_node("Gates/" + name_) as ZoneGate


func _uc1_spawn() -> void:
	var d := _p.global_position.distance_to(Vector3(0, -3, 38.6))
	_check(d < 1.0, "UC1: player ở điểm start (lệch %.2f m)" % d)


func _uc2_locked() -> void:
	_check(_gate("WindGate").is_open(), "UC2: cổng Gió mở sẵn")
	var gate := _gate("FireGate")
	_check(not gate.is_open(), "UC2: cổng Lửa đang khóa")
	# Va chạm thật: đứng trước cổng, đẩy vào trong 1.2 s, không được lọt qua mặt cổng
	var inward := -gate.global_basis.z
	_p.teleport(gate.global_position - inward * 3.0, inward)
	await _wait(0.2)
	await _push(inward, 1.2)
	var depth := (_p.global_position - gate.global_position).dot(inward)
	_check(depth < 0.0 and not SceneManager.is_busy(), "UC2: đẩy vào cổng Lửa khóa bị chặn (vị trí so với mặt cổng %.2f m, chuyển khu=%s)" % [depth, SceneManager.is_busy()])
	for n in ["IceGate", "ThunderGate"]:
		_check(not _gate(n).is_open(), "UC2: %s khóa" % n)


func _uc3_walk() -> void:
	# Từ chiếu nghỉ đi thẳng lên bắc qua cầu thang tới sân
	_p.teleport(Vector3(0, -3, 38.6), Vector3(0, 0, -1))
	await _wait(0.3)
	await _push(Vector3(0, 0, -1), 4.0)
	var pos := _p.global_position
	_check(pos.z < 24.0 and absf(pos.y) < 0.4, "UC3: đi bộ lên cầu thang tới sân (vị trí %s)" % pos)
	# Lan can: ép ra mép phía đông (giữa hai cổng) 2 s
	_p.teleport(Vector3(22, 0.1, 0), Vector3(1, 0, 0))
	await _wait(0.3)
	await _push(Vector3(1, 0, 0), 2.0)
	var r := Vector2(_p.global_position.x, _p.global_position.z).length()
	_check(r < 27.3 and _p.global_position.y > -0.3, "UC3: lan can giữ player trong sân (cách tâm %.2f m, cao %.2f)" % [r, _p.global_position.y])
	# Lan can phía bắc (giữa cổng Gió và cổng Lửa)
	_p.teleport(Vector3(0, 0.1, -22), Vector3(0, 0, -1))
	await _wait(0.3)
	await _push(Vector3(0, 0, -1), 2.0)
	r = Vector2(_p.global_position.x, _p.global_position.z).length()
	_check(r < 27.3 and _p.global_position.y > -0.3, "UC3: lan can phía bắc giữ player (cách tâm %.2f m)" % r)
	# Bệ tâm: ép vào từ phía nam
	_p.teleport(Vector3(0, 0.1, 10), Vector3(0, 0, -1))
	await _wait(0.3)
	await _push(Vector3(0, 0, -1), 2.0)
	r = Vector2(_p.global_position.x, _p.global_position.z).length()
	_check(r > 5.9 and _p.global_position.y < 0.5, "UC3: bệ tâm chặn player (cách tâm %.2f m, cao %.2f)" % [r, _p.global_position.y])


## Giữ phím di chuyển thật theo hướng thế giới trong một khoảng thời gian
func _push(dir: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not SceneManager.is_busy():
		_hold_move(dir)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release_move()


func _uc4_wind_cleared() -> void:
	var fire := _gate("FireGate")
	var label := fire.get_node("Label") as Label3D
	_check(not fire.is_open() and label.text.contains("Đánh bại boss Khu Gió"), "UC4: chưa thắng boss Gió -> cổng Lửa đóng ('%s')" % label.text.replace("
", " / "))
	_check(not _hub.has_node("FireKeyPedestal"), "UC4: hub không còn bệ chìa Lửa")
	var opened := [0]
	fire.opened.connect(func() -> void: opened[0] += 1)
	GameState.set_flag(&"zone.wind.cleared")
	await get_tree().process_frame
	var portal := fire.get_node("Portal") as Portal
	_check(fire.is_open() and opened[0] == 1 and portal.target_zone == FIRE and portal.target_portal_id == &"start", "UC4: thắng boss Gió -> cổng Lửa mở (opened %d lần), dẫn tới map lửa / start" % opened[0])
	_check(not _gate("IceGate").is_open(), "UC4: cổng Băng còn khóa")


func _uc6_reload() -> void:
	var data := SaveManager.to_dict(GameState.progress)
	var restored := SaveManager.from_dict(data)
	# Bỏ cờ phá khu để cổng Gió quay lại trạng thái chỉ phụ thuộc chìa
	GameState.replace_progress(restored)
	await _load_hub()
	_check(_gate("WindGate").is_open(), "UC6: nạp lại -> cổng Gió vẫn mở")
	_check(_gate("FireGate").is_open(), "UC6: nạp lại -> cổng Lửa vẫn mở")


func _enter_gate(gate_name: String, use_case: String, expected_zone: String) -> bool:
	if SceneManager.is_busy():
		_check(false, "%s: lần chuyển khu trước chưa xong khi thử %s" % [use_case, gate_name])
		return false
	var gate: ZoneGate = _gate(gate_name)
	var inward: Vector3 = -gate.global_basis.z
	_p.teleport(gate.global_position - inward * 3.0, inward)
	await _wait(0.2)
	await _push(inward, 1.5)
	var started: bool = SceneManager.is_busy()
	_check(started, "%s: bước qua %s bắt đầu chuyển khu" % [use_case, gate_name])
	if not started:
		return false
	return await _wait_for_zone(expected_zone, use_case)


func _uc8_enter_fire_gate() -> void:
	SceneManager.change_zone(HUB)
	if not await _wait_for_zone(HUB, "UC8: quay về hub"):
		return
	_use_hub(get_tree().current_scene as ZoneRoot)
	if not await _enter_gate("FireGate", "UC8", FIRE):
		return
	var scene: ZoneRoot = get_tree().current_scene as ZoneRoot
	var fire_player: Player = scene.get_node_or_null(^"Player") as Player
	var spawn: SpawnPoint = SpawnPoint.find_in(scene, &"start")
	var d: float = fire_player.global_position.distance_to(spawn.global_position) if fire_player and spawn else -1.0
	_check(d >= 0.0 and d < 1.5, "UC8: player ở điểm spawn tier 1 Lửa (lệch %.2f m)" % d)
	_uc9_starter_kit(scene, fire_player)
	await _capture("hub_to_fire.png")


func _uc9_starter_kit(scene: Node, player: Player) -> void:
	if scene == null or player == null:
		_check(false, "UC9: không có map lửa / player")
		return
	var sword := GameState.get_weapon_in_slot(WeaponData.Slot.SWORD)
	var bow := GameState.get_weapon_in_slot(WeaponData.Slot.BOW)
	# Foxy hiện kiếm bằng mesh kiếm có sẵn trong model (FoxyPlayer._update_sword_visibility), đo đúng mesh đó
	var sword_name: StringName = player.get(&"sword_node_name") if player.get(&"sword_node_name") != null else &"Sword"
	var mesh := player.get_node("Model").find_child(String(sword_name), true, false) as Node3D
	_check(sword != null and GameState.get_weapon() == sword and mesh != null and mesh.is_visible_in_tree(), "UC9: có kiếm, đang cầm, kiếm hiện trên tay (%s)" % (mesh.get_path() if mesh else "không thấy mesh"))
	_check(bow != null and GameState.has_ability(&"wind_blast"), "UC9: có cung và kỹ năng Gió")
	_check(GameState.get_fused_element(WeaponData.Slot.SWORD) == null and GameState.get_fused_element(WeaponData.Slot.BOW) == null, "UC9: chưa dung hợp nguyên tố")
	var kit: StarterKit = scene.get_node_or_null(^"StarterKit") as StarterKit
	_check(kit != null, "UC9: tier 1 Lửa có StarterKit")
	if kit == null:
		return
	var counts := [GameState.progress.weapons.size(), GameState.get_abilities().size()]
	kit.apply(player)
	_check(GameState.progress.weapons.size() == counts[0] and GameState.get_abilities().size() == counts[1], "UC9: bù lần 2 không nhân đôi (%d vũ khí, %d kỹ năng)" % counts)


func _wait_for_zone(expected_zone: String, use_case: String) -> bool:
	# Chờ cả lần chuyển và bước mở điều khiển để ca sau không chạy trên scene cũ.
	while Time.get_ticks_msec() < _portal_deadline_ms:
		var zone: ZoneRoot = get_tree().current_scene as ZoneRoot
		if not SceneManager.is_busy() and (zone == null or zone.scene_file_path != expected_zone):
			break
		if not SceneManager.is_busy() and zone.is_combat_ready():
			_check(true, "%s: đã vào %s" % [use_case, expected_zone])
			return true
		await _wait(0.1)
	var active_scene: Node = get_tree().current_scene
	var active_path: String = active_scene.scene_file_path if active_scene else "chưa có scene"
	_check(false, "%s: chưa sẵn sàng ở %s (scene hiện tại: %s, đang chuyển khu: %s)" % [use_case, expected_zone, active_path, SceneManager.is_busy()])
	return false


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


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


## Giữ phím di chuyển thật theo hướng thế giới (quy đổi qua góc camera giống Player.get_move_direction)
func _hold_move(dir: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var x := dir.dot(right)
	var y := -dir.dot(forward)
	_release_move()
	if x > 0.0: Input.action_press(&"move_right", x)
	elif x < 0.0: Input.action_press(&"move_left", -x)
	if y > 0.0: Input.action_press(&"move_back", y)
	elif y < 0.0: Input.action_press(&"move_forward", -y)


func _release_move() -> void:
	for a in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)
