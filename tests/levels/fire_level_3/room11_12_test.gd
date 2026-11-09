extends Node
## Phòng 11 (lồng quái + rương) và phòng 12 (cứu con tin) → cổng nam Hub (va chạm, input và node thật):
## 1. Phòng 11: lối bắc không còn cửa một chiều; rương ẩn; vào phòng thì lồng sinh quái.
## 2. Phá lồng + hạ hết quái: rương hiện, bấm interact mở được.
## 3. Phòng 12 (ròng rọc): chưa vào thì lồng đứng yên, cổng nam Hub đóng. Vào phòng: quái canh thức dậy, lồng bị hạ dần.
## 4. Hết giờ (lower_time ngắn): lồng chạm mức đứt dây, rơi xuống dung nham. Ra rồi vào lại: treo lại từ đầu.
## 5. Còn quái: giữ interact ở tời không kéo được. Hạ hết quái: thả tay lồng tuột chậm, giữ interact thì lồng lên.
## 6. Lồng lên tới đỉnh: khoá ngang cầu gỗ, chưa tự thả con tin. Leo bậc thang (đi bộ thật) lên sàn gỗ,
##    ra cuối cầu, bấm interact (MỞ LỒNG): con tin bước ra sàn, lưu cờ, cổng nam Hub mở, đi qua được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room11_12_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	# 1. Phòng 11
	var cage: SpawnerCage = _level.get_node("Room11/Room11Cage") as SpawnerCage
	var reveal: FlagReveal = _level.get_node("Room11/Room11ChestReveal") as FlagReveal
	_check(_level.find_child("OneWayGateDoor", true, false) == null and _level.find_child("OneWayGateFrame", true, false) == null, "phòng 11: đã bỏ cửa một chiều ở lối bắc")
	_check(reveal.get_child_count() == 0, "rương phòng 11 ẩn")
	_player.teleport(Vector3(68, 0.4, 74))
	await _frames(20)
	_check(cage.alive_count() == 1, "vào phòng 11: lồng sinh quái (%d)" % cage.alive_count())
	await _capture("room11_cage.png")
	# 2. Phá lồng + hạ quái
	(cage.get_node("HealthComponent") as HealthComponent).take_damage(999)
	await _frames(5)
	for e: Node in cage.get_node("Enemies").get_children():
		if e is Enemy and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	await _frames(30)
	_check(cage.is_cleared and reveal.get_child_count() == 1, "phá lồng + hạ quái: rương hiện")
	var chest: AbilityChest = reveal.get_node("Room11Chest") as AbilityChest
	_player.teleport(chest.global_position + Vector3(0, 0.1, -1.3), Vector3.BACK)
	await _frames(15)
	await _press(&"interact")
	await _frames(40)
	_check(chest.is_opened and GameState.has_flag(chest.persistent_id), "bấm interact: rương mở, lưu cờ")
	# 3. Phòng 12
	var rescue: HostageRescue = _level.get_node("Room12HostageRescue") as HostageRescue
	var gate: StoneGate = _level.get_node("HubSouthGate") as StoneGate
	var label: Label3D = rescue.get_node("Cage/TimeLabel")
	var cage_node: Node3D = rescue.get_node("Cage")
	var guards: Encounter = rescue.guards
	_check(rescue.phase == HostageRescue.Phase.WAITING and not label.visible and is_equal_approx(rescue.cage_height(), rescue.start_height) and not gate.is_open, "phòng 12 chưa vào: lồng treo yên, cổng nam Hub đóng")
	# 4. Thất bại khi hết giờ
	var keep: float = rescue.lower_time
	rescue.lower_time = 1.5
	_player.teleport(Vector3(94, 0.4, 80))
	await _frames(10)
	_check(rescue.phase == HostageRescue.Phase.RUNNING and label.visible and guards.is_running(), "vào phòng 12: quái canh thức dậy, đồng hồ hiện (%s)" % label.text)
	await _seconds(2.5)
	_check(rescue.phase == HostageRescue.Phase.FAILED and not cage_node.visible, "hết giờ: dây đứt, lồng rơi xuống dung nham")
	_player.teleport(Vector3(86, 0.4, 78))
	await _frames(15)
	rescue.lower_time = keep
	_player.teleport(Vector3(94, 0.4, 80))
	await _frames(15)
	var h0: float = rescue.cage_height()
	_check(rescue.phase == HostageRescue.Phase.RUNNING and cage_node.visible and h0 > rescue.start_height - 0.2, "ra rồi vào lại: lồng treo lại (cao %.2f)" % h0)
	# 5. Còn quái: giữ tời không kéo được
	var winch: Node3D = rescue.get_node("Winch")
	_player.teleport(winch.global_position + Vector3(1.0, 0.1, 0.6), Vector3.LEFT)
	await _frames(5)
	var h1: float = rescue.cage_height()
	Input.action_press(&"interact")
	await _seconds(1.0)
	Input.action_release(&"interact")
	_check(rescue.cage_height() < h1 and not rescue.guards_down, "còn quái: giữ tời không kéo được, lồng vẫn bị hạ (%.2f → %.2f)" % [h1, rescue.cage_height()])
	await _capture("room12_pulley_guards.png")
	for e: Node in guards.get_node("Enemies").get_children():
		if e is Enemy and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	await _frames(60)
	var h2: float = rescue.cage_height()
	await _seconds(1.0)
	var slip: float = h2 - rescue.cage_height()
	_check(rescue.guards_down and not label.visible and slip > 0.1 and slip < 0.5, "hạ hết quái: ẩn đồng hồ, thả tay lồng tuột chậm (%.2f m/s)" % slip)
	# 6. Giữ tời kéo lên tới đỉnh
	_player.teleport(winch.global_position + Vector3(1.0, 0.1, 0.6), Vector3.LEFT)
	await _frames(5)
	var h3: float = rescue.cage_height()
	Input.action_press(&"interact")
	await _seconds(0.5)
	_check(rescue.cage_height() > h3 and rescue.is_cranking, "giữ interact ở tời: lồng lên (%.2f → %.2f)" % [h3, rescue.cage_height()])
	await _capture("room12_pulley_cranking.png")
	var t: float = 0.0
	while rescue.phase == HostageRescue.Phase.RUNNING and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release(&"interact")
	await _frames(30)
	var hostage: Node3D = rescue.get_node("Cage/Hostage")
	_check(rescue.phase == HostageRescue.Phase.LIFTED and is_equal_approx(rescue.cage_height(), rescue.rescue_height) and not GameState.has_flag(rescue.persistent_id), "lồng lên đỉnh sau %.1f s: khoá lại, chưa thả con tin" % t)
	# Leo bậc thang lên sàn gỗ rồi ra cuối cầu
	var root: Vector3 = rescue.global_position
	# Đi bộ thật từ sàn phòng trước chân thang (không đặt sẵn lên bậc)
	await _walk_from(root + Vector3(-7.3, 0.1, -6), root + Vector3(0.5, 0, -6))
	_check(absf(_player.global_position.y - (root.y + 2.0)) < 0.15, "leo bậc thang lên sàn gỗ (y = %.2f)" % _player.global_position.y)
	await _walk_from(_player.global_position, root + Vector3(0, 0, -0.9))
	_check(_player.global_position.z > root.z - 1.6 and absf(_player.global_position.y - (root.y + 2.0)) < 0.15, "ra cuối cầu gỗ sát lồng (z = %.2f)" % _player.global_position.z)
	await _capture("room12_cage_open_prompt.png")
	await _press(&"interact")
	await _seconds(rescue.free_time + 0.3)
	var shore: Vector3 = (rescue.get_node("Shore") as Marker3D).global_position
	_check(rescue.phase == HostageRescue.Phase.RESCUED and hostage.global_position.distance_to(shore) < 0.05 and GameState.has_flag(rescue.persistent_id), "bấm MỞ LỒNG: con tin ra sàn gỗ, lưu cờ")
	await _capture("room12_rescued.png")
	await _frames(120)
	_check(gate.is_open, "cứu được con tin: cổng nam Hub mở")
	await _walk_from(Vector3(122, 4.4, 56), Vector3(122, 4, 66))
	_check(_player.global_position.z > 61.0, "đi qua cửa nam Hub (z = %.2f)" % _player.global_position.z)
	print("ROOM11 12 RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout


func _walk_from(start: Vector3, target: Vector3) -> void:
	_player.teleport(start)
	await _frames(10)
	var t: float = 0.0
	while t < 3.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.6:
			break
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var d: Vector3 = Vector3(flat.x, 0.0, flat.y).normalized()
		_axis(&"move_right", &"move_left", d.dot(right))
		_axis(&"move_back", &"move_forward", -d.dot(forward))
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
