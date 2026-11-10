extends Node
## Thử thách phòng 3 → cổng tới phòng 2 (va chạm, input và node thật):
## 1. Ba cổng (hai cửa phòng 2, cửa tây phòng 3) chặn đường lúc đầu.
## 2. Thắp 3/4 đuốc góc phòng 3: phòng chưa sáng, quái chưa xuất hiện.
## 3. Thắp đủ 4 đuốc: đèn phòng 3 sáng lên, lưu cờ; player trong phòng thì quái xuất hiện.
## 4. Hạ hết quái: trận xong, cả ba cổng chìm xuống, đi qua được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room3_trial_test.tscn (-- --capture để chụp ảnh)

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
	GameState.set_flag(&"level_3.ignite_chain_barrier")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var gates: Array[StoneGate] = []
	for n: String in ["Room2EastGate", "Room2NorthGate", "Room3WestGate"]:
		gates.append(_level.get_node("Room2Gates/" + n) as StoneGate)
	var group: BrazierGroup = _level.get_node("Room3/Room3Braziers") as BrazierGroup
	var encounter: Encounter = _level.get_node("Room3/Room3Encounter") as Encounter
	var light: OmniLight3D = _level.get_node("Room3/Room3Light1")
	# 1. Ba cổng chặn
	await _walk_from(Vector3(40, 0.4, 30), Vector3(28, 0, 30))
	_check(_player.global_position.x > 36.0, "cửa đông phòng 2 chặn (x = %.2f)" % _player.global_position.x)
	await _walk_from(Vector3(22, 0.4, 18), Vector3(22, 0, 30))
	_check(_player.global_position.z < 24.0, "cửa bắc phòng 2 chặn (z = %.2f)" % _player.global_position.z)
	await _walk_from(Vector3(36, 0.4, 14), Vector3(26, 0, 14))
	_check(_player.global_position.x > 32.5, "cửa tây phòng 3 chặn (x = %.2f)" % _player.global_position.x)
	# 2. Thắp 3/4 đuốc khi đang đứng trong phòng 3
	_player.teleport(Vector3(42, 0.4, 20))
	await _frames(20)
	for i: int in [5, 6, 7]:
		_ignite(i)
	await _frames(60)
	_check(group.lit_count() == 3 and not group.is_complete and not light.visible and not encounter.is_running(), "thắp 3/4 đuốc: phòng chưa sáng, quái chưa ra")
	await _capture("room3_dark.png")
	# 3. Đuốc thứ 4
	_ignite(8)
	await _frames(100)
	_check(group.is_complete and light.visible and light.light_energy > 2.5 and GameState.has_flag(group.persistent_id), "thắp đủ 4 đuốc: đèn phòng sáng (%.2f), lưu cờ" % light.light_energy)
	var enemies: Array[Node] = encounter.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n is Enemy)
	_check(encounter.is_running() and enemies.size() == 3, "quái xuất hiện (%d con)" % enemies.size())
	await _capture("room3_lit_enemies.png")
	_check(not gates[0].is_open and not gates[1].is_open and not gates[2].is_open, "chưa hạ quái: cổng vẫn đóng")
	# 4. Hạ hết quái
	for e: Node in enemies:
		(e as Enemy).health.take_damage(9999)
	await _frames(150)
	_check(not encounter.is_running() and GameState.has_flag(encounter.persistent_id), "hạ hết quái: trận xong, lưu cờ")
	_check(gates[0].is_open and gates[1].is_open and gates[2].is_open, "cả ba cổng mở")
	await _walk_from(Vector3(40, 0.4, 30), Vector3(28, 0, 30))
	_check(_player.global_position.x < 31.0, "đi qua cửa đông vào phòng 2 (x = %.2f)" % _player.global_position.x)
	await _walk_from(Vector3(36, 0.4, 14), Vector3(26, 0, 14))
	_check(_player.global_position.x < 29.0, "đi qua cửa tây phòng 3 (x = %.2f)" % _player.global_position.x)
	await _walk_from(Vector3(22, 0.4, 18), Vector3(22, 0, 30))
	_check(_player.global_position.z > 27.0, "đi qua cửa bắc vào phòng 2 (z = %.2f)" % _player.global_position.z)
	print("ROOM3 TRIAL RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _ignite(index: int) -> void:
	var t: IgnitableBrazier = _level.get_node("CellarTorches/CellarTorch%02d" % index) as IgnitableBrazier
	(t.get_node("BurnableComponent") as BurnableComponent).ignite()


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
