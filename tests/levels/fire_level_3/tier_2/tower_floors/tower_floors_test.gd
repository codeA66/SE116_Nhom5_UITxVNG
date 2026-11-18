extends Node
## Test quái các tầng tháp tier 2 map Lửa, đo bằng thao tác thật (phun lửa, chém):
## 1. T1: lồng sói có khiên; vào phòng thì sinh sói; khiên còn thì chém không mất máu; phun lửa tan khiên, chém vỡ lồng,
##    hạ hết sói thì đĩa lên T2 mở.
## 2. T2: lồng nhện + lồng pháp sư (đúng loại quái); phá xong một lồng đĩa vẫn đóng, phá đủ hai lồng thì mở.
## 3. T4: 4 Đầu Lửa bay lượn quanh player vẫn ở trong phòng (không bay ra ngoài tường) sau 8 s.
## 4. T5: 4 tượng laze ở 4 góc quay vào tâm + lồng pháp sư giữa; phá lồng mà còn tượng thì đĩa đóng; vỡ đủ 4 tượng thì mở.
## 5. Boss T3 / T6 nằm sẵn trong phòng, ngủ yên; player vào tầm nhìn (sight_range) mới bắt trận.
## 6. Vừa dịch chuyển tới (đi bộ thật lên bệ đá / đĩa, màn tối rồi sáng): chỗ đáp nằm trong dải an toàn ngoài vùng trận,
##    đứng yên 4 s không trận nào bắt đầu, không bị đánh; quái / lồng / tượng / chỗ boss xuất hiện cách chỗ đáp đủ xa
##    (T1, T2 >= 6 m; T3..T6 >= 8 m). Bước vào giữa phòng thì trận bắt đầu nhưng 2 s đầu không bị đánh trúng.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/tower_floors/tower_floors_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const FLOORS := "Tier2Mechanics/TowerFloors/"
const STATUES: Array[String] = ["TowerT5StatueNW", "TowerT5StatueNE", "TowerT5StatueSW", "TowerT5StatueSE"]

## Khoảng cách tối thiểu từ chỗ đáp tới quái / lồng / tượng (phòng 16 m chỉ đủ ~6-7 m)
const MIN_GAP: Array[float] = [6.0, 6.0, 8.0, 8.0, 8.0, 8.0]
## Thời gian chờ đầu trận (start_delay) đặt ở scene
const START_DELAY: float = 2.0

var _player: Player
var _last_hurt_frame: int = -1
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(420.0, true, true).timeout.connect(func() -> void:
		print("TOWER FLOORS RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	(_player.get_node("HurtboxComponent") as HurtboxComponent).set_invincible(9999.0)
	_player.unlock_ability(FLAME_BREATH)
	_player.equip_weapon(SWORD)
	await _t_floor_1()
	await _t_floor_2()
	await _t_floor_4()
	await _t_floor_5()
	await _reload_level()
	await _t_arrivals()
	print("TOWER FLOORS RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _t_floor_1() -> void:
	var cage := _level.get_node(FLOORS + "TowerT1Cage") as SpawnerCage
	var pad := _pad(1)
	_player.teleport(cage.global_position + Vector3(0, 0.1, -5))
	await _frames(int(6.0 * 60.0))
	var kinds := _kinds(cage)
	_check(cage.alive_count() > 0 and kinds.keys() == [&"ShadowWolf"], "T1: vào phòng, lồng sinh sói (%s)" % kinds)
	var hp := (cage.get_node("HealthComponent") as HealthComponent)
	var before := hp.current_health
	await _attack(cage, Vector3(0, 0, -1.6), 3)
	_check(cage.is_shielded() and hp.current_health == before, "T1: còn khiên gỗ, chém lồng không mất máu")
	await _burn(cage)
	await _attack(cage, Vector3(0, 0, -1.6), 30)
	_check(cage.is_broken, "T1: tan khiên rồi chém vỡ được lồng")
	_check(not pad.is_active(), "T1: lồng vỡ nhưng còn sói thì đĩa chưa mở")
	_kill_all(cage)
	await _frames(40)
	_check(pad.is_active(), "T1: hạ hết sói thì đĩa lên T2 mở")


func _t_floor_2() -> void:
	var spider := _level.get_node(FLOORS + "TowerT2CageSpider") as SpawnerCage
	var caster := _level.get_node(FLOORS + "TowerT2CageCaster") as SpawnerCage
	var pad := _pad(2)
	_player.teleport((spider.global_position + caster.global_position) * 0.5 + Vector3(0, 0.1, -3))
	await _frames(int(6.0 * 60.0))
	_check(_kinds(spider).keys() == [&"FireSpider"] and _kinds(caster).keys() == [&"FireCaster"],
		"T2: lồng tây sinh nhện, lồng đông sinh pháp sư (%s / %s)" % [_kinds(spider), _kinds(caster)])
	await _burn(spider)
	await _attack(spider, Vector3(0, 0, -1.6), 30)
	_kill_all(spider)
	await _frames(40)
	_check(spider.is_cleared and not pad.is_active(), "T2: phá xong lồng nhện, còn lồng pháp sư thì đĩa đóng")
	await _burn(caster)
	await _attack(caster, Vector3(0, 0, -1.6), 30)
	_kill_all(caster)
	await _frames(40)
	_check(caster.is_cleared and pad.is_active(), "T2: phá đủ hai lồng thì đĩa lên T3 mở")


func _t_floor_4() -> void:
	var enc := _level.get_node(^"Tier2Fights/TowerT4Masks") as Encounter
	var room := _level.get_node(^"Rooms/Tier2/T2T4Chain") as Node3D
	_player.teleport(enc.global_position + Vector3(0, 0.1, 3))
	await _frames(int(8.0 * 60.0))
	var half := 10.0
	var out: Array[String] = []
	for e: Node in enc.get_node(^"Enemies").get_children():
		var p := (e as Node3D).global_position - room.global_position
		if absf(p.x) > half or absf(p.z) > half:
			out.append("%s (%.1f, %.1f)" % [e.name, p.x, p.z])
	_check(enc.is_running() and out.is_empty(), "T4: 4 Đầu Lửa bay lượn 8 s vẫn trong phòng 20 m (ra ngoài: %s)" % str(out))
	for e: Node in enc.get_node(^"Enemies").get_children():
		if e is Enemy and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	await _frames(40)
	_check(_pad(4).is_active(), "T4: hạ 4 Đầu Lửa thì đĩa lên T5 mở")


func _t_floor_5() -> void:
	var cage := _level.get_node(FLOORS + "TowerT5Cage") as SpawnerCage
	var pad := _pad(5)
	var facing_ok := true
	for s: String in STATUES:
		var st := _level.get_node(FLOORS + s) as Node3D
		var to_center := cage.global_position - st.global_position
		to_center.y = 0
		facing_ok = facing_ok and st.global_basis.z.normalized().dot(to_center.normalized()) > 0.95
	_check(facing_ok, "T5: 4 tượng ở 4 góc quay mặt vào tâm phòng")
	_player.teleport(cage.global_position + Vector3(0, 0.1, -4))
	await _frames(int(6.0 * 60.0))
	_check(_kinds(cage).keys() == [&"FireCaster"], "T5: lồng giữa sinh pháp sư (%s)" % _kinds(cage))
	await _burn(cage)
	await _attack(cage, Vector3(0, 0, -1.6), 30)
	_kill_all(cage)
	await _frames(40)
	_check(cage.is_cleared and not pad.is_active(), "T5: phá lồng mà còn tượng thì đĩa đóng")
	for i: int in STATUES.size():
		var st := _level.get_node(FLOORS + STATUES[i]) as LaserStatue
		var to_center := (cage.global_position - st.global_position)
		to_center.y = 0
		await _attack(st, to_center.normalized() * 1.8, 40)
		_check(st.is_destroyed(), "T5: chém vỡ tượng %s" % STATUES[i])
		if i < STATUES.size() - 1:
			await _frames(10)
			_check(not pad.is_active(), "T5: mới vỡ %d/4 tượng, đĩa vẫn đóng" % (i + 1))
	await _frames(40)
	_check(pad.is_active(), "T5: phá lồng + vỡ đủ 4 tượng thì đĩa lên T6 mở")


func _reload_level() -> void:
	_level.queue_free()
	await _frames(5)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()
	(_player.get_node("HurtboxComponent") as HurtboxComponent).hurt.connect(func(_i: DamageInfo, _d: int) -> void:
		_last_hurt_frame = Engine.get_physics_frames())


func _t_arrivals() -> void:
	var sources: Array = [_level.get_node(^"Tier2Links/TowerEntryPortal")]
	for n: int in range(1, 6):
		sources.append(_pad(n))
	var open_flags: Array = [
		[&"level_3.t2_shard_switch"], [&"level_3.t2_t1_cleared"], [&"level_3.t2_t2_cage_spider", &"level_3.t2_t2_cage_caster"],
		[&"level_3.t2_t3_cleared"], [&"level_3.t2_t4_cleared"],
		[&"level_3.t2_t5_cage", &"level_3.t2_t5_statue_nw", &"level_3.t2_t5_statue_ne", &"level_3.t2_t5_statue_sw", &"level_3.t2_t5_statue_se"]]
	var rooms: Array[String] = ["T2T1Forge", "T2T2Anvil", "T2T3Crucible", "T2T4Chain", "T2T5Smelter", "T2T6Summit"]
	for i: int in 6:
		var floor_n := i + 1
		for f: StringName in open_flags[i]:
			GameState.set_flag(f)
		# Như chơi thật: đĩa chỉ mở khi đã dọn sạch tầng, nên gỡ quái tầng trước (còn sống thì chắn đường lên đĩa)
		if floor_n > 1:
			for f: Node in _fights_of(floor_n - 1):
				f.queue_free()
		await _frames(10)
		var src := sources[i] as WarpPortal
		var target := src.target.get_arrival().global_position
		# Đi bộ thật lên bệ / đĩa (đứng cạnh rồi bước vào)
		_player.teleport(src.global_position + Vector3(0, 0.1, -2.5))
		await _frames(15)
		await _walk_to(src.global_position, 0.3)
		await _frames(int(0.6 * 60.0))
		_check(_flat(_player.global_position, target) < 1.0, "T%d: đi bộ lên bệ / đĩa thì dịch chuyển tới chỗ đáp" % floor_n)
		_last_hurt_frame = -1
		var fights := _fights_of(floor_n)
		var bf: BossFight = fights[0] as BossFight if fights[0] is BossFight else null
		var boss_pos := Vector3.ZERO
		if bf:
			_check(bf.boss != null and bf.boss.is_inside_tree() and (bf.boss as Node3D).is_visible_in_tree(),
				"T%d: vừa đáp xuống đã thấy boss nằm sẵn trong phòng" % floor_n)
			boss_pos = (bf.boss as Node3D).global_position if bf.boss else Vector3.ZERO
		# Khoảng cách chỗ đáp -> quái / lồng / tượng / chỗ boss
		var gap := INF
		for p: Vector3 in _threat_points(floor_n):
			gap = minf(gap, _flat(p, target))
		_check(gap >= MIN_GAP[i], "T%d: quái / lồng / tượng gần nhất cách chỗ đáp %.1f m (>= %.0f)" % [floor_n, gap, MIN_GAP[i]])
		await _frames(int(4.0 * 60.0))
		var started := fights.any(func(f: Node) -> bool: return _fight_started(f))
		_check(not started and _last_hurt_frame < 0, "T%d: đứng yên ở dải an toàn 4 s: trận chưa bắt đầu, không bị đánh" % floor_n)
		if bf and bf.boss:
			_check((bf.boss as Node3D).global_position.distance_to(boss_pos) < 0.05, "T%d: boss ngủ yên, không nhúc nhích khi player ở dải an toàn" % floor_n)
			# Lại gần nhưng còn ngoài tầm nhìn
			var spawn := (bf.get_node(^"Spawn") as Node3D).global_position
			var edge := spawn + (target - spawn).normalized() * (bf.sight_range + 1.0)
			await _walk_to(Vector3(edge.x, target.y, edge.z), 0.4)
			await _frames(int(1.5 * 60.0))
			_check(not bf.is_running(), "T%d: cách boss %.1f m (ngoài tầm nhìn %.0f m): trận chưa bắt đầu" % [floor_n, _flat(_player.global_position, spawn), bf.sight_range])
		# Bước vào giữa phòng
		var room := _level.get_node("Rooms/Tier2/" + rooms[i]) as Node3D
		var enter_frame := Engine.get_physics_frames()
		await _walk_to(room.global_position + Vector3(0, 0, -1.0), 0.6)
		await _frames(int(4.0 * 60.0))
		var hurt_after := (_last_hurt_frame - enter_frame) / 60.0 if _last_hurt_frame >= 0 else INF
		started = fights.any(func(f: Node) -> bool: return _fight_started(f))
		_check(started, "T%d: bước vào giữa phòng thì trận bắt đầu" % floor_n)
		_check(hurt_after >= START_DELAY, "T%d: 2 s đầu sau khi bước vào không bị đánh trúng (trúng đòn đầu sau %s s)" % [floor_n, "%.1f" % hurt_after if hurt_after < INF else "-"])
		_player.health.heal_full()


func _fights_of(floor_n: int) -> Array:
	match floor_n:
		1: return [_level.get_node(FLOORS + "TowerT1Cage")]
		2: return [_level.get_node(FLOORS + "TowerT2CageSpider"), _level.get_node(FLOORS + "TowerT2CageCaster")]
		3: return [_level.get_node(^"Tier2Fights/TowerT3MotherFight")]
		4: return [_level.get_node(^"Tier2Fights/TowerT4Masks")]
		5: return [_level.get_node(FLOORS + "TowerT5Cage")] + STATUES.map(func(n: String) -> Node: return _level.get_node(FLOORS + n))
		_: return [_level.get_node(^"Tier2Fights/T2BossFight")]


func _fight_started(f: Node) -> bool:
	if f is SpawnerCage:
		return (f as SpawnerCage).alive_count() > 0
	if f is Encounter:
		return (f as Encounter).is_running()
	if f is BossFight:
		return (f as BossFight).is_running()
	if f is LaserStatue:
		return (f as LaserStatue).has_target()
	return false


## Chỗ quái có thể xuất hiện / tấn công từ đó: vòng sinh quanh lồng, quái đứng sẵn, chỗ boss, tượng
func _threat_points(floor_n: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for f: Node in _fights_of(floor_n):
		if f is SpawnerCage:
			var c := f as SpawnerCage
			for a: int in 16:
				pts.append(c.global_position + Vector3(cos(a * TAU / 16.0), 0, sin(a * TAU / 16.0)) * c.spawn_radius)
		elif f is Encounter:
			for e: Node in f.get_node(^"Enemies").get_children():
				pts.append((e as Node3D).global_position)
		elif f is BossFight:
			pts.append((f.get_node(^"Spawn") as Node3D).global_position)
		elif f is LaserStatue:
			pts.append((f as Node3D).global_position)
	return pts


func _walk_to(to: Vector3, tolerance: float) -> void:
	for _i: int in range(300):
		var flat := Vector2(to.x - _player.global_position.x, to.z - _player.global_position.z)
		# Bị bệ / đĩa đưa đi xa (các tầng cách nhau > 20 m, quãng đi bộ < 15 m): thôi bấm đi
		if flat.length() < tolerance or flat.length() > 15.0:
			break
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var d := Vector3(flat.x, 0, flat.y).normalized()
		_axis(&"move_right", &"move_left", d.dot(right))
		_axis(&"move_back", &"move_forward", -d.dot(forward))
		await get_tree().physics_frame
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


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _pad(n: int) -> WarpPortal:
	return _level.get_node("Tier2Links/TowerExitT%d" % n) as WarpPortal


func _kinds(c: SpawnerCage) -> Dictionary:
	var counts: Dictionary = {}
	for e: Node in _enemies(c):
		var k := StringName(e.get_script().get_global_name())
		counts[k] = int(counts.get(k, 0)) + 1
	return counts


func _burn(c: SpawnerCage) -> void:
	var shield: BurnableBarrier = c.shield
	_player.teleport(c.global_position + Vector3(0, 0.1, -3.4), Vector3.BACK)
	await _frames(10)
	_player.energy.set_current(_player.energy.get_max())
	if DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(c.global_position + Vector3(0, 1.0, 0)))
		await _frames(2)
	Input.action_press(_dir_action(Vector3.BACK))
	await _frames(2)
	await _press(&"skill_fire")
	Input.action_release(_dir_action(Vector3.BACK))
	var t: float = 0.0
	while not shield.is_burned and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _frames(20)
	_check(shield.is_burned and not c.is_shielded(), "%s: phun lửa tan khiên sau %.1f s" % [c.name, t])


## Chém mục tiêu (lồng hoặc tượng) từ vị trí offset, tới khi vỡ hoặc hết lượt
func _attack(target: Node3D, offset: Vector3, presses: int) -> void:
	var dir: Vector3 = -offset.normalized()
	for _i: int in range(presses):
		if (target is SpawnerCage and (target as SpawnerCage).is_broken) or (target is LaserStatue and (target as LaserStatue).is_destroyed()):
			return
		_player.energy.set_current(_player.energy.get_max())
		_player.teleport(target.global_position + offset + Vector3(0, 0.1, 0), dir)
		if DisplayServer.get_name() != "headless":
			get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(target.global_position + Vector3(0, 1.0, 0)))
		await _press(&"attack")
		await _frames(24)


func _enemies(c: SpawnerCage) -> Array[Node]:
	return c.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n is Enemy and not (n as Enemy).is_dead())


func _kill_all(c: SpawnerCage) -> void:
	for e: Node in _enemies(c):
		(e as Enemy).health.take_damage(9999)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


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


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
