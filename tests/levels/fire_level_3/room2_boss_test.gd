extends Node
## Mini-boss phòng 2 → cổng khóa đầu lối đi hướng tây (va chạm, input và node thật):
## 1. Hai cổng tây (8 m) chặn đường từ quảng trường đầu cầu sang lối đi hướng tây.
## 2. Vào phòng 2 nhưng chưa chạm bệ thờ: boss vẫn ngủ yên.
## 3. Đi tới bệ thờ: trận bắt đầu, boss nhắm player; boss trâu hơn quái thường (3 đòn chưa chết).
## 4. Hạ boss: lưu cờ, hai cổng tây chìm xuống, đi qua được.
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
	var boss: Enemy = encounter.get_node("Enemies/MiniBoss") as Enemy
	# 1. Cổng tây chặn cả hai làn
	for z: float in [50.0, 54.0]:
		await _walk_from(Vector3(59, 4.4, z), Vector3(70, 4, z))
		_check(_player.global_position.x < 64.0, "cổng tây chặn làn z = %.0f (x = %.2f)" % [z, _player.global_position.x])
	# 2. Vào phòng 2, chưa chạm bệ thờ
	_player.teleport(Vector3(19, 0.4, 37))
	await _frames(60)
	_check(not encounter.is_running() and not boss.is_dead(), "vào phòng 2 chưa chạm bệ thờ: boss còn ngủ")
	_check(boss.health.max_health == 15 and is_equal_approx(boss.scale.x, 1.4), "boss dùng dữ liệu mini-boss (%d máu, scale %.1f)" % [boss.health.max_health, boss.scale.x])
	# 3. Đi tới bệ thờ
	await _walk_from(Vector3(22, 0.4, 36), Vector3(25.2, 0, 33.2))
	await _frames(20)
	_check(encounter.is_running() and boss.target == _player, "chạm bệ thờ: trận bắt đầu, boss nhắm player")
	await _frames(40)
	await _capture("room2_boss_fight.png")
	for _i: int in range(3):
		boss.health.take_damage(1)
	_check(not boss.is_dead(), "boss trâu hơn quái thường: 3 đòn chưa chết (còn %d)" % boss.health.current_health)
	_check(not gates[0].is_open and not gates[1].is_open, "chưa hạ boss: cổng tây vẫn đóng")
	# 4. Hạ boss
	boss.health.take_damage(9999)
	await _frames(150)
	_check(GameState.has_flag(encounter.persistent_id), "hạ boss: lưu cờ %s" % encounter.persistent_id)
	_check(gates[0].is_open and gates[1].is_open, "hai cổng tây mở")
	for z: float in [50.0, 54.0]:
		await _walk_from(Vector3(59, 4.4, z), Vector3(70, 4, z))
		_check(_player.global_position.x > 67.0, "đi qua cổng tây làn z = %.0f (x = %.2f)" % [z, _player.global_position.x])
	await _capture("west_gate_open.png")
	print("ROOM2 BOSS RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


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
