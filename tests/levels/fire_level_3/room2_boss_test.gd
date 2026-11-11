extends Node
## Trận 2 Nhện Lửa phòng 2 (thay mini-boss) → cổng khóa đầu lối đi hướng tây (va chạm, input và node thật):
## 1. Hai cổng tây (8 m) chặn đường từ quảng trường đầu cầu sang lối đi hướng tây.
## 2. Chưa vào phòng 2: không còn mini-boss, hai nhện ngủ yên, trận chưa chạy.
## 3. Bước vào phòng (hộp kích hoạt phủ cả phòng, không cần chạm bệ thờ): trận bắt đầu, cả hai nhện nhắm player;
##    hạ một con chưa xong trận (cờ chưa đặt, cổng tây còn đóng).
## 4. Hạ hết nhện: lưu cờ, rơi chìa; hai cổng tây vẫn đóng cho tới khi nhặt chìa và bấm tương tác ở ổ khóa giữa lối.
## 5. Chưa có chìa mà bấm ổ khóa: hộp thoại báo cần chìa. Có chìa: hai cổng tây chìm xuống, đi qua được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room2_boss_test.tscn (-- --capture để chụp ảnh)

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
	# Đường vào phòng 2 đã mở (rào gỗ đã đốt, trận phòng 3 đã xong): có test riêng
	GameState.set_flag(&"level_3.ignite_chain_barrier")
	GameState.set_flag(&"level_3.room3_encounter")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var gates: Array[StoneGate] = [_level.get_node("WestGates/WestGateSouth") as StoneGate, _level.get_node("WestGates/WestGateNorth") as StoneGate]
	var encounter: Encounter = _level.get_node("Room2/Room2BossEncounter") as Encounter
	var spiders: Array[FireSpider] = []
	for child: Node in encounter.get_node("Enemies").get_children():
		if child is FireSpider:
			spiders.append(child as FireSpider)
	# 1. Cổng tây chặn cả hai làn
	for z: float in [50.0, 54.0]:
		await _walk_from(Vector3(59, 4.4, z), Vector3(70, 4, z))
		_check(_player.global_position.x < 64.0, "cổng tây chặn làn z = %.0f (x = %.2f)" % [z, _player.global_position.x])
	# 2. Chưa vào phòng 2
	_check(encounter.get_node("Enemies").get_node_or_null("MiniBoss") == null, "phòng 2 không còn mini-boss")
	_check(spiders.size() == 2, "phòng 2 có đúng 2 Nhện Lửa (%d)" % spiders.size())
	_check(not encounter.is_running() and spiders.all(func(sp: FireSpider) -> bool: return not sp.is_dead() and sp.target == null), "chưa vào phòng 2: hai nhện ngủ yên, trận chưa chạy")
	# 3. Bước vào phòng (không chạm bệ thờ)
	_player.teleport(Vector3(26, 0.4, 28))
	await _frames(60)
	_check(encounter.is_running(), "bước vào phòng 2: trận bắt đầu (không cần chạm bệ thờ)")
	_check(spiders.all(func(sp: FireSpider) -> bool: return sp.target == _player), "cả hai nhện nhắm player")
	await _frames(40)
	await _capture("room2_spider_fight.png")
	spiders[0].health.take_damage(9999)
	await _frames(30)
	_check(spiders[0].is_dead() and not spiders[1].is_dead() and not GameState.has_flag(encounter.persistent_id), "hạ một nhện: trận chưa xong, chưa đặt cờ")
	_check(not gates[0].is_open and not gates[1].is_open, "chưa hạ hết nhện: cổng tây vẫn đóng")
	# 4. Hạ nốt con còn lại
	spiders[1].health.take_damage(9999)
	await _frames(150)
	_check(GameState.has_flag(encounter.persistent_id), "hạ hết nhện: lưu cờ %s" % encounter.persistent_id)
	var drop: KeyDrop = _level.get_node("Room2/WestKeyDrop") as KeyDrop
	var key: KeyPickup = _find_key(_level.get_node("Room2"))
	_check(key != null and key.key_id == drop.key_id and not GameState.has_flag(drop.key_id), "hạ hết nhện: chìa rơi, chưa nhặt")
	_check(not gates[0].is_open and not gates[1].is_open, "hạ hết nhện mà chưa có chìa: hai cổng tây vẫn đóng")
	# 5a. Chưa có chìa, bấm ổ khóa
	var lock: KeyLock = _level.get_node("WestGates/WestKeyLock") as KeyLock
	_player.teleport(lock.global_transform * Vector3(0, 0.1, 1.3), -lock.global_basis.z)
	await _frames(25)
	await _press(&"interact")
	await _frames(10)
	var dialog: DialogBox = _find_dialog(lock)
	_check(dialog != null and dialog.is_open and not lock.is_active(), "chưa có chìa: ổ khóa báo cần chìa, cổng vẫn khóa")
	if dialog:
		dialog.choose(true)
	await _frames(40)
	# 5b. Nhặt chìa rồi mở ổ
	_player.teleport(key.global_position + Vector3(0, 0.2, 0.9), Vector3.FORWARD)
	await _frames(25)
	await _press(&"interact")
	await _frames(30)
	_check(GameState.has_flag(drop.key_id), "nhặt chìa: có cờ %s" % drop.key_id)
	_player.teleport(lock.global_transform * Vector3(0, 0.1, 1.3), -lock.global_basis.z)
	await _frames(25)
	await _press(&"interact")
	await _frames(150)
	_check(lock.is_active() and gates[0].is_open and gates[1].is_open, "bấm ổ khóa có chìa: hai cổng tây mở")
	for z: float in [50.0, 54.0]:
		await _walk_from(Vector3(59, 4.4, z), Vector3(70, 4, z))
		_check(_player.global_position.x > 67.0, "đi qua cổng tây làn z = %.0f (x = %.2f)" % [z, _player.global_position.x])
	await _capture("west_gate_open.png")
	print("ROOM2 SPIDERS RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _find_key(room: Node) -> KeyPickup:
	for c: Node in room.get_children():
		if c is KeyPickup:
			return c as KeyPickup
	return null


func _find_dialog(host: Node) -> DialogBox:
	for c: Node in host.get_children():
		if c is DialogBox:
			return c as DialogBox
	return null


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


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
