extends Node
## Cầu gạch Nether (lửa đuổi + quái canh) và boss tạm phòng 10 (va chạm, input và node thật):
## 1. Quái canh đứng sẵn trên cầu; bước lên cầu thì chúng thức dậy.
## 2. Vừa chạm mặt cầu: vòng cảnh báo hiện ngay dưới chân (không chờ đứng yên), rồi lửa phụt (cột lửa shader mới);
##    đứng yên thì trúng lửa mất máu; vẫn tiếp tục phun theo nhịp vào chỗ đang đứng.
## 3. Phòng 10: chưa vào thì chưa có boss, cổng ra ẩn. Bước vào: boss xuất hiện, nhắm player.
## 4. Hạ boss: lưu cờ, cổng ra (cổng xoáy có bệ) hiện lên.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/boss_bridge_test.tscn (-- --capture để chụp ảnh)

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
	await _frames(6)
	_check(fired.size() == 1 and Vector2(fired[0].x - on_bridge.x, fired[0].z - on_bridge.z).length() < 0.6, "vừa chạm cầu: cảnh báo ngay dưới chân (sau %d khung)" % 6)
	_check(guards.is_running(), "bước lên cầu: quái canh thức dậy")
	await _capture("bridge_warning.png")
	await _seconds(1.1)
	await _capture("bridge_flame.png")
	_check(_player.health.current_health < hp0, "đứng yên: trúng lửa, mất máu (%d → %d)" % [hp0, _player.health.current_health])
	await _seconds(1.6)
	_check(fired.size() >= 2, "vẫn phun tiếp theo nhịp vào chỗ đang đứng (%d lần)" % fired.size())
	for e: Node in guard_list:
		if is_instance_valid(e) and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	_player.health.heal_full()
	# 3. Phòng 10
	var fight: BossFight = _level.get_node("Room10BossFight") as BossFight
	var exit_reveal: FlagReveal = _level.get_node("Room10ExitReveal") as FlagReveal
	_check(fight.boss == null and exit_reveal.get_child_count() == 0, "chưa vào phòng 10: chưa có boss, cổng ra ẩn")
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	_player.teleport(Vector3(152, 4.4, 50))
	await _frames(20)
	_check(fight.boss != null and fight.boss.get(&"target_player") == _player, "bước vào phòng 10: boss xuất hiện, nhắm player")
	await _seconds(1.5)
	await _capture("room10_boss.png")
	# TNT nổ cạnh boss: mất máu bằng sát thương TNT; boss có khiên: nổ phá khiên (như phản cầu lửa)
	await _tnt_on_boss(fight.boss)
	# 4. Hạ boss
	(fight.boss.get(&"health") as HealthComponent).take_damage(99999)
	var t: float = 0.0
	while not fight.is_defeated and t < 10.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _frames(10)
	_check(fight.is_defeated and GameState.has_flag(fight.persistent_id), "hạ boss: lưu cờ (%.1f s)" % t)
	var exit_portal: Node3D = exit_reveal.get_node_or_null("ExitPortal") as Node3D
	_check(exit_portal != null and exit_portal.get_node_or_null("Pedestal") != null, "cổng ra phòng 10 hiện lên (có bệ đỡ)")
	_player.teleport(Vector3(166, 4.4, 50))
	await _frames(30)
	await _capture("room10_exit.png")
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


func _tnt_on_boss(boss: Node3D) -> void:
	var block: TntBlock = (load("res://objects/combat/hazards/tnt_block/tnt_block.tscn") as PackedScene).instantiate() as TntBlock
	_level.add_child(block)
	var health: HealthComponent = boss.get(&"health") as HealthComponent
	var hurtbox: HurtboxComponent = boss.get(&"hurtbox") as HurtboxComponent
	_player.teleport(boss.global_position + Vector3(-8, 0.1, 0))
	# Đứng yên boss để đo đúng một vụ nổ
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	hurtbox.process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(40)
	var hp: int = health.current_health
	block.place(boss.global_position + Vector3(1.2, 0, 0), 0.0, _player)
	await _frames(2)
	block.explode()
	await _frames(5)
	_check(health.current_health == hp - block.attack.damage, "TNT nổ cạnh boss: mất %d máu (%d → %d / %d)" % [block.attack.damage, hp, health.current_health, health.max_health])
	# Đo riêng việc phá khiên: nổ sát thương 0 để máu không chạm mốc khoá 50% (boss sẽ tự bật khiên mới)
	var full_attack: AttackData = block.attack
	block.attack = full_attack.duplicate() as AttackData
	block.attack.damage = 0
	boss.call(&"activate_invulnerable_shield")
	var stacks: int = boss.get(&"shield_stacks")
	hp = health.current_health
	for i: int in range(stacks):
		await _seconds(1.0)
		block.place(boss.global_position + Vector3(1.2, 0, 0), 0.0, _player)
		await _frames(2)
		block.explode()
		await _frames(5)
	_check(not boss.get(&"is_shielded") and health.current_health == hp, "boss có khiên %d lớp: %d vụ nổ phá khiên (máu %d → %d)" % [stacks, stacks, hp, health.current_health])
	block.attack = full_attack
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	hurtbox.process_mode = Node.PROCESS_MODE_INHERIT
	block.queue_free()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
