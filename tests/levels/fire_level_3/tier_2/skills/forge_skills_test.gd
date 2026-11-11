extends Node
## Test đợt 3 tier 2 map Lửa: ba kỹ năng thử nghiệm (Lốc Lửa R, Móc kéo G, Khiên xỉ V) bằng phím, va chạm và quái thật.
## 0. Bộ gắn state: 3 state có trong StateMachine của player; sách trên bệ phòng 11 trao đúng kỹ năng; vòng móc có trong map.
## 1. Lốc Lửa: tốn 2 năng lượng, lốc cháy, trôi đúng tốc độ, đốt thùng gỗ trên đường, hút + đốt quái cạnh đường,
##    gặp tường thì đứng lại; hết năng lượng thì bấm không ra chiêu; cực đoan: tốc độ 0 / 15, sống 0,2 s.
## 2. Móc kéo: bay qua hào phòng 04 tới bờ bên kia; ngoài tầm / bị tường chắn tầm nhìn thì hụt (không bay);
##    tường chắn giữa đường bay thì buông sớm; không có vòng thì kéo quái về; cực đoan: tốc độ 60 / 3, cung 1°.
## 3. Khiên xỉ: chặn + dội cầu lửa thật của Quỷ Xương Lửa phía trước (quái mất máu), sau lưng thì vẫn trúng;
##    tốn năng lượng theo thời gian, hết thì hạ khiên; nhả phím thì trả hurtbox gốc; cực đoan: cung 0 / 360, không dội.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/skills/forge_skills_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
var _cyclone: FireCycloneData = preload("res://abilities/forge/fire_cyclone/fire_cyclone.tres")
var _grapple: GrappleData = preload("res://abilities/forge/grapple/grapple.tres")
var _shield: SlagShieldData = preload("res://abilities/forge/slag_shield/slag_shield.tres")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/palace/enemy_1/enemy_1.tscn")
const CASTER_SCENE: PackedScene = preload("res://entities/enemies/volcano/fire_caster/fire_caster.tscn")
const CRATE_SCENE: PackedScene = preload("res://objects/fire_puzzle/flammables/wooden_crate/wooden_crate.tscn")

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	# Lỗi script giữa chừng làm coroutine dừng: tự thoát để không treo máy chạy test
	get_tree().create_timer(240.0, true, true).timeout.connect(func() -> void:
		print("FORGE SKILLS RESULT: TIMEOUT")
		get_tree().quit(2))
	# Sách chỉ hiện khi hạ xong trận của khu (FlagReveal): đặt cờ để sách có trong cây (hiện / giấu đo ở skills_checkpoints_test)
	for flag: StringName in [&"level_3.boss_defeated", &"level_3.t2_exit_vines", &"level_3.t2_slime_hall", &"level_3.t2_dark_forge_pack", &"level_3.t2_wisps_cleared"]:
		GameState.set_flag(flag)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 30
	_player.health.heal_full()
	_player.energy.data = _player.energy.data.duplicate()
	_player.energy.data.max_energy = 20
	await _t_install()
	await _t_cyclone()
	await _t_grapple()
	await _t_shield()
	print("FORGE SKILLS RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 0. Gắn state, vòng ----------

func _t_install() -> void:
	var machine := _player.state_machine
	for state: StringName in [&"FireCyclone", &"Grapple", &"SlagShield"]:
		_check(machine.has_state(state), "player có state %s (gắn lúc chạy, không sửa player.tscn)" % state)
	# Bản 2 bỏ sách kỹ năng khỏi tier 2: không còn AbilityPickup trao kỹ năng lò rèn trong map
	var forge_books: int = 0
	for pickup: Node in _level.find_children("*", "Node3D", true, false):
		if pickup is AbilityPickup and (pickup as AbilityPickup).ability in [_cyclone, _grapple, _shield]:
			forge_books += 1
	_check(forge_books == 0, "không còn sách kỹ năng lò rèn trong map (%d)" % forge_books)
	_check(get_tree().get_nodes_in_group(GrappleRing.GROUP).size() == 1, "có 1 vòng móc trong map (phòng 04)")
	for skill: SkillData in [_cyclone, _grapple, _shield]:
		GameState.unlock_ability(skill)


# ---------- 1. Lốc Lửa ----------

func _t_cyclone() -> void:
	_player.energy.set_current(10)
	var crate := CRATE_SCENE.instantiate() as Flammable
	_level.add_child(crate)
	crate.global_position = Vector3(279.5, 0.32, 86)
	var enemy := _spawn(ENEMY_SCENE, Vector3(277.5, 0.42, 87.8)) as Enemy
	enemy.health.max_health = 200
	enemy.health.heal_full()
	_teleport(Vector3(273, 0.42, 86), Vector3.RIGHT)
	await _frames(5)
	var enemy_start := enemy.global_position
	await _press(&"skill_cyclone")
	_check(_player.state_machine.current_state.name == &"FireCyclone", "bấm R: vào state Lốc Lửa")
	await _frames(int(_cyclone.cast_time * 60.0) + 3)
	_check(_player.energy.current == 8, "tốn 2 năng lượng (còn %d)" % _player.energy.current)
	var cyclone := _active_cyclone()
	_check(cyclone != null and cyclone.is_lit(), "lốc xuất hiện và đang cháy ngay")
	if cyclone == null:
		return
	var p0 := cyclone.get_vortex_position()
	await _frames(60)
	var moved := cyclone.get_vortex_position().x - p0.x
	_check(absf(moved - _cyclone.speed) < 0.15, "lốc trôi %.2f m trong 1 s (đặt %.1f m/s)" % [moved, _cyclone.speed])
	var enemy_burnable := enemy.get_node(^"BurnableComponent") as BurnableComponent
	var enemy_burned := false
	var crate_burned := false
	var closest := INF
	for _i: int in range(int(_cyclone.lifetime * 60.0)):
		await get_tree().physics_frame
		enemy_burned = enemy_burned or enemy_burnable.is_burning()
		crate_burned = crate_burned or crate.is_burning or crate.is_burned
		if is_instance_valid(cyclone) and cyclone.is_physics_processing():
			closest = minf(closest, Vector2(enemy.global_position.x - cyclone.get_vortex_position().x,
					enemy.global_position.z - cyclone.get_vortex_position().z).length())
	_check(crate_burned, "thùng gỗ trên đường lốc bắt lửa")
	_check(enemy_burned, "quái cạnh đường bị lốc đốt")
	_check(enemy.global_position.distance_to(enemy_start) > 1.0 and closest < 1.5,
			"quái bị hút vào lốc (đi %.1f m, sát tâm lốc nhất %.2f m)" % [enemy.global_position.distance_to(enemy_start), closest])
	enemy.queue_free()
	await _frames(60)
	# Gặp tường đông phòng 08 (x = 292, đo ở z = 90 để tránh ô cửa đông z 84..88) thì đứng lại
	_player.energy.set_current(10)
	_teleport(Vector3(286, 0.42, 90), Vector3.RIGHT)
	await _frames(int(_cyclone.get_lockout() * 60.0))
	await _press(&"skill_cyclone")
	await _frames(int(_cyclone.cast_time * 60.0) + 3)
	cyclone = _active_cyclone()
	await _frames(150)
	var stop_x := cyclone.get_vortex_position().x
	await _frames(20)
	_check(stop_x < 291.8 and stop_x > 288.0 and absf(cyclone.get_vortex_position().x - stop_x) < 0.01,
			"lốc gặp tường thì đứng lại ở x = %.2f (tường x = 292)" % stop_x)
	await _frames(int(_cyclone.lifetime * 60.0))
	# Hết năng lượng: bấm không ra chiêu
	_player.energy.set_current(1)
	await _press(&"skill_cyclone")
	_check(_player.state_machine.current_state.name != &"FireCyclone" and _player.energy.current == 1, "chỉ còn 1 năng lượng: bấm R không ra chiêu")
	# Cực đoan
	for setting: Array in [[0.0, 1.0], [15.0, 1.0], [2.0, 0.2]]:
		_cyclone.speed = setting[0]
		_cyclone.lifetime = setting[1]
		_player.energy.set_current(10)
		_teleport(Vector3(280, 0.42, 90), Vector3.RIGHT)
		await _frames(int(_cyclone.get_lockout() * 60.0) + 5)
		await _press(&"skill_cyclone")
		await _frames(int(_cyclone.cast_time * 60.0) + 3)
		cyclone = _active_cyclone()
		var start := cyclone.get_vortex_position() if cyclone else Vector3.INF
		await _frames(int(setting[1] * 60.0) + 40)
		var gone := not is_instance_valid(cyclone) or not cyclone.visible or not cyclone.is_lit()
		var travel := (cyclone.get_vortex_position() - start).length() if is_instance_valid(cyclone) else -1.0
		var expect := minf(setting[0] * setting[1], 291.4 - start.x)
		_check(cyclone != null and gone and travel < expect + 0.3 and travel > expect - 1.2,
				"tốc độ %.0f, sống %.1f s: trôi %.2f m (mong ~%.2f), hết giờ thì tan" % [setting[0], setting[1], travel, expect])
	_cyclone.speed = 2.0
	_cyclone.lifetime = 3.0


# ---------- 2. Móc kéo ----------

func _t_grapple() -> void:
	var ring := _level.get_node(^"Tier2Mechanics/GrappleRings/Room4Ring") as GrappleRing
	# Qua hào phòng 04
	var end := await _grapple_from(Vector3(284, 8.42, 12))
	_check(end.z > 20.3 and end.z < 24.0 and absf(end.y - 8.32) < 0.3 and not _player.health.is_dead(),
			"móc vòng phòng 04: bay qua hào, đáp bờ nam (%.1f, %.2f, %.1f)" % [end.x, end.y, end.z])
	# Ngoài tầm
	_grapple.ring_range = 8.0
	end = await _grapple_from(Vector3(284, 8.42, 12))
	_check(end.z < 13.0, "tầm 8 m (vòng cách ~10 m): móc hụt, không bay (z = %.1f)" % end.z)
	_grapple.ring_range = 12.0
	# Tường chắn tầm nhìn
	var wall := _wall(Vector3(284, 10.5, 17), Vector3(4, 4.5, 0.4))
	end = await _grapple_from(Vector3(284, 8.42, 12))
	_check(end.z < 13.0, "tường chắn giữa tay và vòng: móc hụt (z = %.1f)" % end.z)
	wall.free()
	# Tường thấp chắn đường bay (không chắn tầm nhìn): buông sớm, không xuyên tường
	wall = _wall(Vector3(284, 9.06, 17), Vector3(4, 1.5, 0.4))
	# Lambda chụp biến cục bộ theo giá trị: dùng mảng để nhận số frame
	var frames := [0]
	end = await _grapple_from(Vector3(284, 8.42, 12), func(n: int) -> void: frames[0] = n)
	_check(end.z < 17.0 and frames[0] < 60, "tường thấp chắn đường bay: buông sau %d frame, dừng trước tường (z = %.1f)" % [frames[0], end.z])
	wall.free()
	# Cực đoan tốc độ
	for speed: float in [60.0, 3.0]:
		_grapple.pull_speed = speed
		end = await _grapple_from(Vector3(284, 8.42, 12))
		_check(end.z > 20.3 and end.z < 24.0 and absf(end.y - 8.32) < 0.3, "tốc độ kéo %.0f m/s: vẫn tới bờ nam (z = %.1f)" % [speed, end.z])
	_grapple.pull_speed = 16.0
	# Cung nhắm 1°: vòng thẳng trước mặt vẫn móc; quay ngang thì hụt
	_grapple.aim_arc_degrees = 1.0
	end = await _grapple_from(Vector3(284, 8.42, 12))
	_check(end.z > 20.3, "cung 1°, vòng thẳng trước mặt: móc được (z = %.1f)" % end.z)
	end = await _grapple_from(Vector3(284, 8.42, 12), Callable(), Vector3.RIGHT)
	_check(end.z < 13.0, "cung 1°, quay ngang: móc hụt (z = %.1f)" % end.z)
	_grapple.aim_arc_degrees = 120.0
	_check(ring.enabled, "vòng móc vẫn bật sau khi dùng")
	# Không có vòng: kéo quái về phía mình (so với quãng quái tự đi trong cùng thời gian)
	var enemy := _spawn(ENEMY_SCENE, Vector3(283, 0.42, 88)) as Enemy
	_teleport(Vector3(274, 0.42, 88), Vector3.RIGHT)
	await _frames(20)
	var a := enemy.global_position.distance_to(_player.global_position)
	await _frames(40)
	var walk := a - enemy.global_position.distance_to(_player.global_position)
	enemy.global_position = Vector3(283, 0.42, 88)
	_teleport(Vector3(274, 0.42, 88), Vector3.RIGHT)
	await _frames(20)
	_player.energy.set_current(10)
	a = enemy.global_position.distance_to(_player.global_position)
	await _press(&"skill_grapple")
	await _frames(39)
	var pulled := a - enemy.global_position.distance_to(_player.global_position)
	_check(pulled > walk + 3.0, "không có vòng: kéo quái lại %.1f m trong 0,67 s (quái tự đi %.1f m)" % [pulled, walk])
	enemy.queue_free()
	await _frames(30)


## Đứng ở start quay về facing, bấm G, chờ hết state Móc kéo; trả về vị trí khi đã đứng yên trên đất
func _grapple_from(start: Vector3, on_frames: Callable = Callable(), facing: Vector3 = Vector3.BACK) -> Vector3:
	_player.energy.set_current(10)
	_teleport(start, facing)
	await _frames(int(_grapple.get_lockout() * 60.0) + 5)
	await _press(&"skill_grapple")
	var n := 1
	while _player.state_machine.current_state.name == &"Grapple" and n < 1200:
		await get_tree().physics_frame
		n += 1
	if on_frames.is_valid():
		on_frames.call(n)
	for _i: int in range(120):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.velocity.length() < 0.5:
			break
	return _player.global_position


# ---------- 3. Khiên xỉ ----------

func _t_shield() -> void:
	var caster := _spawn(CASTER_SCENE, Vector3(282, 0.42, 88)) as Enemy
	caster.health.max_health = 50
	caster.health.heal_full()
	var hurtbox := _player.get_node(^"HurtboxComponent") as HurtboxComponent
	_player.energy.set_current(10)
	_teleport(Vector3(274, 0.42, 88), Vector3.RIGHT)
	await _frames(10)
	_player.health.heal_full()
	var hp := _player.health.current_health
	var caster_hp := caster.health.current_health
	Input.action_press(&"skill_shield")
	await _frames(5)
	_check(_player.state_machine.current_state.name == &"SlagShield" and not hurtbox.monitorable, "giữ V: dựng khiên, hurtbox gốc tạm tắt")
	var reflected := [0]
	var bolt := (caster as FireCaster).fire_bolt(Vector3.LEFT)
	bolt.reflected.connect(func(_by: Node3D) -> void: reflected[0] += 1)
	await _frames(int(3.2 * 60.0) - 5)
	_check(reflected[0] == 1 and _player.health.current_health == hp, "cầu lửa phía trước: bị dội ngược, player không mất máu (%d → %d)" % [hp, _player.health.current_health])
	_check(caster.health.current_health < caster_hp, "cầu dội về trúng Quỷ Xương Lửa (%d → %d máu)" % [caster_hp, caster.health.current_health])
	_check(_player.energy.current == 10 - 1 - 3, "giữ 3,2 s: tốn 1 + 3 năng lượng (còn %d)" % _player.energy.current)
	Input.action_release(&"skill_shield")
	await _frames(5)
	_check(_player.state_machine.current_state.name != &"SlagShield" and hurtbox.monitorable, "nhả V: hạ khiên, trả hurtbox gốc")
	# Sau lưng: quay lưng về quái
	_check(await _shield_bolt_case(caster, Vector3.LEFT, 120.0, true) == -1, "cầu lửa từ sau lưng: vẫn trúng (mất 1 máu)")
	# Cực đoan
	_check(await _shield_bolt_case(caster, Vector3.RIGHT, 0.0, true) == -1, "cung 0°: cầu phía trước vẫn trúng")
	_check(await _shield_bolt_case(caster, Vector3.LEFT, 360.0, true) == 1, "cung 360°: cầu sau lưng cũng bị dội")
	_check(await _shield_bolt_case(caster, Vector3.RIGHT, 120.0, false) == 0, "tắt dội: cầu phía trước bị chặn (không mất máu, không dội)")
	_shield.arc_degrees = 120.0
	_shield.reflects_projectiles = true
	# Hết năng lượng: khiên tự hạ dù vẫn giữ phím
	_player.energy.set_current(2)
	_teleport(Vector3(274, 0.42, 92), Vector3.RIGHT)
	await _frames(int(_shield.get_lockout() * 60.0) + 5)
	Input.action_press(&"skill_shield")
	var dropped_at := -1
	for i: int in range(int(4.0 * 60.0)):
		await get_tree().physics_frame
		if dropped_at < 0 and i > 2 and _player.state_machine.current_state.name != &"SlagShield":
			dropped_at = i
	Input.action_release(&"skill_shield")
	await _frames(3)
	_check(dropped_at > 100 and dropped_at < 140 and hurtbox.monitorable,
			"2 năng lượng: khiên tự hạ sau %.2f s (mong ~2 s), trả hurtbox gốc" % (dropped_at / 60.0))
	caster.queue_free()


## Dựng khiên quay về facing (quái ở phía +x), cho quái bắn một cầu vào player.
## Trả về: -1 = player trúng, 1 = cầu bị dội, 0 = bị chặn không dội
func _shield_bolt_case(caster: Enemy, facing: Vector3, arc: float, reflects: bool) -> int:
	_shield.arc_degrees = arc
	_shield.reflects_projectiles = reflects
	_player.energy.set_current(10)
	_teleport(Vector3(274, 0.42, 88), facing)
	await _frames(int(_shield.get_lockout() * 60.0) + 40)
	# Quỷ Xương Lửa tự đi lại gần: đặt lại chỗ cũ, bắn thẳng vào player
	caster.global_position = Vector3(282, 0.42, 88)
	_player.health.heal_full()
	var hp := _player.health.current_health
	Input.action_press(&"skill_shield")
	await _frames(3)
	var reflected := [0]
	var aim := _player.global_position - caster.global_position
	aim.y = 0.0
	var bolt := (caster as FireCaster).fire_bolt(aim.normalized())
	bolt.reflected.connect(func(_by: Node3D) -> void: reflected[0] += 1)
	await _frames(90)
	Input.action_release(&"skill_shield")
	await _frames(5)
	if _player.health.current_health < hp:
		return -1
	return 1 if reflected[0] > 0 else 0


# ---------- Tiện ích ----------

func _active_cyclone() -> FireCyclone:
	var pool := _player.get_node_or_null(^"FireCyclonePool") as ObjectPool
	if pool == null:
		return null
	var active := pool.get_active()
	return active.back() as FireCyclone if not active.is_empty() else null


func _spawn(scene: PackedScene, position: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	_level.add_child(node)
	node.global_position = position
	return node


func _wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_level.add_child(body)
	body.global_position = center
	return body


func _press(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
