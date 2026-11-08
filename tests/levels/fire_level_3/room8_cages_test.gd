extends Node
## Phòng 8: 4 lồng sinh quái bọc rào gỗ → cổng cửa tây (va chạm, input và node thật):
## 1. Cổng cửa tây chặn đường sang phòng 9.
## 2. Vào phòng: các lồng sinh quái (ngoài vòng rào).
## 3. Còn rào: chém lồng bằng kiếm (bấm attack thật) không mất máu, không đi xuyên rào được.
## 4. Phun lửa (bấm skill_fire thật) vào rào: rào cháy tan, lồng chém được; chém vỡ từng lồng.
## 5. Còn lồng chưa vỡ: cổng vẫn đóng. Vỡ đủ 4 + hạ hết quái: cổng chìm, cất cả khung, đi qua được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room8_cages_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")

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
	_player.unlock_ability(FLAME_BREATH)
	_player.equip_weapon(load("res://resources/combat/weapons/sword.tres") as WeaponData)
	var cages: Array[SpawnerCage] = []
	for i: int in range(1, 5):
		cages.append(_level.get_node("Room8/Room8Cage%d" % i) as SpawnerCage)
	var gate: StoneGate = _level.get_node("Room8/Room8WestGate") as StoneGate
	# 1. Cổng chặn
	await _walk_from(Vector3(103, 8.4, 14), Vector3(94, 8, 14))
	_check(_player.global_position.x > 100.0, "cổng cửa tây phòng 8 chặn (x = %.2f)" % _player.global_position.x)
	# 2. Lồng sinh quái
	_player.teleport(Vector3(114, 8.4, 14))
	await _frames(30)
	var alive: int = 0
	var outside: bool = true
	for c: SpawnerCage in cages:
		alive += c.alive_count()
		for e: Node in _enemies(c):
			outside = outside and Vector2((e as Node3D).global_position.x - c.global_position.x, (e as Node3D).global_position.z - c.global_position.z).length() > 2.6
	_check(alive == 4 and outside, "vào phòng: 4 lồng mỗi lồng sinh 1 quái, ngoài vòng rào (%d)" % alive)
	await _capture("room8_cages_shielded.png")
	# 3. Còn rào: chém không mất máu, không vào được trong rào
	var c0: SpawnerCage = cages[0]
	_kill_all(cages)
	await _attack(c0, Vector3(0, 0, 3.0), 6)
	_check(c0.is_shielded() and (c0.get_node("HealthComponent") as HealthComponent).current_health == 10, "còn rào: chém lồng không mất máu")
	await _walk_from(c0.global_position + Vector3(0, 0.1, 4.0), c0.global_position)
	_check(_player.global_position.z > c0.global_position.z + 2.2, "không đi xuyên rào được (z = %.2f)" % _player.global_position.z)
	# 4. Đốt rào rồi chém từng lồng
	for i: int in range(cages.size()):
		var c: SpawnerCage = cages[i]
		_kill_all(cages)
		await _burn(c)
		_kill_all(cages)
		await _attack(c, Vector3(0, 0, 1.7), 40)
		_check(c.is_broken, "lồng %d vỡ sau khi đốt rào" % (i + 1))
		if i == 2:
			_kill_all(cages)
			await _frames(30)
			_check(not gate.is_open, "mới vỡ 3/4 lồng: cổng vẫn đóng")
	_kill_all(cages)
	await _frames(150)
	var all_clear: bool = true
	for c: SpawnerCage in cages:
		all_clear = all_clear and c.is_cleared
	_check(all_clear and gate.is_open, "vỡ đủ 4 lồng + hạ hết quái: cổng mở")
	var frame: Node3D = gate.get_node("Visual/Frame")
	_check(not frame.is_visible_in_tree(), "cổng mở: cất cả khung cổng")
	await _walk_from(Vector3(103, 8.4, 14), Vector3(94, 8, 14))
	_check(_player.global_position.x < 98.0, "đi qua cửa tây sang phòng 9 (x = %.2f)" % _player.global_position.x)
	print("ROOM8 CAGES RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _burn(c: SpawnerCage) -> void:
	var shield: BurnableBarrier = c.shield
	var stand: Vector3 = c.global_position + Vector3(0, 0.1, 3.4)
	_player.teleport(stand, Vector3.FORWARD)
	await _frames(10)
	_player.energy.set_current(_player.energy.get_max())
	if DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(c.global_position + Vector3(0, 1.0, 0)))
		await _frames(2)
	Input.action_press(_dir_action(Vector3.FORWARD))
	await _frames(2)
	await _press(&"skill_fire")
	Input.action_release(_dir_action(Vector3.FORWARD))
	var t: float = 0.0
	while not shield.is_burned and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _frames(20)
	_check(shield.is_burned and not c.is_shielded(), "Phun lửa vào rào lồng %s: rào cháy tan sau %.1f s" % [c.name, t])
	if c == _level.get_node("Room8/Room8Cage1"):
		await _capture("room8_shield_burned.png")


func _attack(c: SpawnerCage, offset: Vector3, presses: int) -> void:
	var dir: Vector3 = -offset.normalized()
	for _i: int in range(presses):
		if c.is_broken:
			return
		_player.energy.set_current(_player.energy.get_max())
		_player.teleport(c.global_position + offset + Vector3(0, 0.1, 0), dir)
		if DisplayServer.get_name() != "headless":
			get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(c.global_position + Vector3(0, 1.0, 0)))
		await _press(&"attack")
		await _frames(24)


func _enemies(c: SpawnerCage) -> Array[Node]:
	return c.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n is Enemy and not (n as Enemy).is_dead())


func _kill_all(cages: Array[SpawnerCage]) -> void:
	for c: SpawnerCage in cages:
		for e: Node in _enemies(c):
			(e as Enemy).health.take_damage(9999)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## Hướng thế giới → action theo camera chéo 45° là phức tạp; dùng hướng gần nhất của input thật
func _dir_action(world_dir: Vector3) -> StringName:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var best: StringName = &"move_forward"
	var best_dot: float = -2.0
	for pair: Array in [[&"move_right", right], [&"move_left", -right], [&"move_forward", forward], [&"move_back", -forward]]:
		var d: float = world_dir.dot(pair[1])
		if d > best_dot:
			best_dot = d
			best = pair[0]
	return best


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
