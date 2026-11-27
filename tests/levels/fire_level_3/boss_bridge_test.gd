extends Node
## Cầu gạch Nether (lửa đuổi + quái canh) và phòng 10 (người chèo đò) (va chạm, input và node thật):
## 1. Quái canh đứng sẵn trên cầu; bước lên cầu thì chúng thức dậy.
## 2. Chạm mặt cầu: chờ first_delay rồi vòng cảnh báo hiện dưới chân (không chờ đứng yên), rồi lửa phụt (cột lửa shader mới);
##    đứng yên thì trúng lửa mất máu; vẫn tiếp tục phun theo nhịp vào chỗ đang đứng.
## 3. Phòng 10: không còn boss; người chèo đò đứng chờ, cổng sang đấu trường hổ ẩn tới khi đeo Bùa Đoạt Tiễn.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/boss_bridge_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_1/tier_1.tscn")

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
	# 1. Quái canh cầu
	var guards: Encounter = _level.get_node("BridgeGuards") as Encounter
	var guard_list: Array[Node] = guards.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n is Enemy)
	_check(guard_list.size() == 3 and not guards.is_running(), "3 quái đứng canh trên cầu, chưa thức")
	# 2. Lửa trên cầu: chạm là cảnh báo ngay
	var trap: Node = _level.find_child("LingerLavaTrap", true, false)
	var fired: Array[Vector3] = []
	trap.connect(&"geyser_triggered", func(at: Vector3) -> void: fired.append(at))
	var on_bridge: Vector3 = Vector3(40, 4.4, 70)
	_player.teleport(on_bridge)
	var hp0: int = _player.health.current_health
	# Nhịp đọc từ chính bẫy: chỉnh thông số trong scene thì test không phải sửa
	var first_delay: float = float(trap.get(&"first_delay"))
	var interval: float = float(trap.get(&"follow_interval"))
	var warning: float = float((trap.get_node("Geyser1") as LavaGeyser).warning_time)
	await _frames(6)
	_check(fired.is_empty() if first_delay > 0.1 else fired.size() == 1, "vừa chạm cầu: chờ %.2f s mới phun lần đầu (đã phun %d lần)" % [first_delay, fired.size()])
	_check(guards.is_running(), "bước lên cầu: quái canh thức dậy")
	await _seconds(first_delay)
	_check(fired.size() == 1 and Vector2(fired[0].x - on_bridge.x, fired[0].z - on_bridge.z).length() < 0.6, "sau %.2f s: cảnh báo ngay dưới chân" % first_delay)
	await _capture("bridge_warning.png")
	await _seconds(warning + 0.3)
	await _capture("bridge_flame.png")
	_check(_player.health.current_health < hp0, "đứng yên: trúng lửa, mất máu (%d → %d)" % [hp0, _player.health.current_health])
	await _seconds(interval - warning)
	_check(fired.size() >= 2, "vẫn phun tiếp theo nhịp %.2f s vào chỗ đang đứng (%d lần)" % [interval, fired.size()])
	for e: Node in guard_list:
		if is_instance_valid(e) and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	_player.health.heal_full()
	# 3. Phòng 10: nay là phòng người chèo đò (boss hổ ở đấu trường riêng, test trong tiger_arena/test_tiger_arena)
	_check(_level.get_node_or_null("Room10BossFight") == null and _level.get_node_or_null("Room10Keeper") is Npc, "phòng 10: không còn boss, có người chèo đò")
	var tiger_portal: FlagReveal = _level.get_node("Room10TigerPortal") as FlagReveal
	_check(tiger_portal.get_child_count() == 0, "phòng 10: chưa đeo Bùa Đoạt Tiễn thì cổng sang đấu trường hổ ẩn")
	_player.teleport(Vector3(152, 4.4, 50))
	await _frames(30)
	await _capture("room10_keeper.png")
	print("BOSS BRIDGE RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


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
