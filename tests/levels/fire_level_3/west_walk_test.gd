extends Node
## Lối tây (quảng trường đầu cầu → điểm thắt 06), đo bằng va chạm và input thật:
## 1. Sói canh: ngủ trước khi player bước lên, bước lên thì trận bắt đầu (3 Sói Bóng); hạ hết thì lưu cờ.
## 2. Bẫy lửa đuổi: đứng giữa lối thì sau first_delay bị phun trúng, mất máu.
## 3. Đi liên tục từ quảng trường tới điểm thắt: lửa đuổi theo nhưng vẫn qua được.
## 4. Đứng trên quảng trường / trong phòng 06 (ngoài vùng bẫy): không bị phun.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/west_walk_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_1/tier_1.tscn")
const WALK_MID: Vector3 = Vector3(80, 4, 52)

var _player: Player
var _level: Node
var _failed: int = 0
var _triggers: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.bridge_guards")
	# Cổng khoá tây (chìa ở phòng 2) đo riêng ở west_gate_key_test: coi như đã mở
	for f: StringName in [&"level_3.west_gate_unlocked", &"level_3.west_gate_south", &"level_3.west_gate_north"]:
		GameState.set_flag(f)
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	var trap: LingerLavaTrap = _level.get_node("WestWalk/WestWalkTrap") as LingerLavaTrap
	var guards: Encounter = _level.get_node("WestWalk/WestWalkGuards") as Encounter
	trap.geyser_triggered.connect(func(_at: Vector3) -> void: _triggers += 1)
	# 1. Sói canh
	var wolves: int = 0
	for e: Node in guards.get_node("Enemies").get_children():
		if e is ShadowWolf:
			wolves += 1
	_check(wolves == 3 and not guards.is_running(), "lối tây có 3 Sói Bóng canh, ngủ trước khi player vào")
	_teleport(Vector3(68, 4, 52))
	await _frames(20)
	_check(guards.is_running(), "bước lên lối tây: sói canh thức dậy")
	for e: Node in guards.get_node("Enemies").get_children():
		if e is Enemy and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	await _frames(90)
	_check(GameState.has_flag(&"level_3.west_walk_guards"), "hạ hết sói canh: lưu cờ")
	# 2. Đứng giữa lối (chờ ngoài vùng bẫy cho bẫy nghỉ hẳn)
	_teleport(Vector3(58, 4, 52))
	_player.health.heal_full()
	await _frames(200)
	_triggers = 0
	_teleport(WALK_MID)
	var hp: int = _player.health.current_health
	var t: float = 0.0
	var first: float = -1.0
	while t < trap.first_delay + trap.geyser_warning_time + 2.0 and _player.health.current_health == hp:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if _triggers > 0 and first < 0.0:
			first = t
	_check(first > 0.0 and absf(first - trap.first_delay) <= 0.2, "đứng giữa lối: kích hoạt sau first_delay %.2f s (%.2f s)" % [trap.first_delay, first])
	_check(_player.health.current_health < hp, "bị phun trúng, máu %d → %d" % [hp, _player.health.current_health])
	# Ra khỏi vùng bẫy ngay (đứng lâu trong bẫy sẽ bị phun tới chết, đúng thiết kế)
	_teleport(Vector3(58, 4, 52))
	await _frames(200)
	# 3. Đi liên tục qua lối (chỉ đếm lượt phun: bất tử để bị hất không chết giữa chừng)
	_player.health.heal_full()
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	# Đi làn z 50: cột khoá chìa đứng giữa lối (z 52) ngay sau quảng trường
	_teleport(Vector3(60, 4, 50))
	await _frames(5)
	_triggers = 0
	var target: Vector3 = Vector3(100, 4, 50)
	t = 0.0
	while t < 15.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.8:
			break
		_press_towards(Vector3(flat.x, 0.0, flat.y).normalized())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release()
	var arrived: bool = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z).length() < 0.8
	_check(_triggers >= 1 and arrived and _player.health.current_health > 0, "đi liên tục qua lối (%.1f s): lửa đuổi %d lượt, tới phòng 06 (đứng ở %s)" % [t, _triggers, _player.global_position])
	# 4. Ngoài vùng bẫy
	for spot: Vector3 in [Vector3(58, 4, 52), Vector3(102, 4, 54)]:
		_teleport(spot)
		await _frames(30)
		_triggers = 0
		await _frames(180)
		_check(_triggers == 0, "đứng 3 s ở (%d, %d) ngoài lối: không bị phun" % [spot.x, spot.z])
	print("WEST WALK RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _teleport(p: Vector3) -> void:
	_player.global_position = p + Vector3(0.0, 0.3, 0.0)
	_player.velocity = Vector3.ZERO


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])


## Quy đổi hướng thế giới ra input theo camera
func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_set_axis(&"move_right", &"move_left", world_dir.dot(right))
	_set_axis(&"move_back", &"move_forward", -world_dir.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)
