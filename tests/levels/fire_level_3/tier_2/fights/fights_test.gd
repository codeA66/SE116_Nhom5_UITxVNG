extends Node
## Test quái và boss tier 2 map Lửa (tháp xoắn ngang):
## 1. Trận quái: đúng số / loại quái mỗi phòng và tầng tháp T4 (4 Đầu Lửa), ngủ trước khi vào, vào vùng thì thức; hạ hết thì lưu cờ;
##    sói cùng trận chung một bầy; slime nổ cạnh tường nứt phòng 05 thì vỡ tường (mở Hang băng). Hạ trận tầng thì đĩa dịch chuyển giữa phòng mở;
##    Slime Mẹ tầng 3 (xuất hiện khi vào phòng, hạ thì lưu cờ, mở đĩa T3).
## 2. (Bỏ) Cổng tháp ở cửa bắc phòng 02: tháp giờ vào bằng bệ dịch chuyển ở Hub.
## 3. Slime Mẹ, thông số cực đoan (đo ở phòng T3): đẻ mỗi 0,5 s (giới hạn 4 con), đẻ 0 con, tách 0 con, nhảy xa tối đa 0 m / cao 0 m.
## 4. Boss tạm: vào tầng boss thì xuất hiện (máu 30); hạ thì lưu cờ, hiện khung cổng tier 3.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/fights/fights_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const MOTHER_SCENE: PackedScene = preload("res://entities/enemies/volcano/lava_slime/mother/slime_mother.tscn")
const EXPECTED: Dictionary = {
	&"T2HubAmbush": {&"FireCaster": 2, &"ShadowWolf": 2},
	&"T2TimberCaster": {&"SoulMask": 4},
	&"T2DarkForgePack": {&"FireCaster": 2, &"FireSpider": 2},
	&"T2WispHall": {&"ShadowWolf": 3},
	# Tháp: T4 là 4 Đầu Lửa. T1 / T2 / T5 là lồng (đo ở tower_floors_test), T3 Slime Mẹ (đo ở _t_tower_fights)
	&"TowerT4Masks": {&"SoulMask": 4},
}
const BOSS_FLAG := &"level_3.t2_boss_defeated"

var _player: Player
var _level: ZoneRoot
var _fights: Node3D
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(300.0, true, true).timeout.connect(func() -> void:
		print("FIGHTS RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	for flag: StringName in [&"level_3.boss_defeated", &"level_3.t2_exit_vines"]:
		GameState.set_flag(flag)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 40
	_player.health.heal_full()
	_fights = _level.get_node(^"Tier2Fights") as Node3D
	await _t_hub_gates(false)
	await _t_room_gates_closed()
	await _t_encounters()
	await _t_hub_gates(true)
	await _t_room_gates_open()
	await _t_tower_fights()
	await _t_south_shard()
	await _t_mother_extremes()
	await _t_boss()
	print("FIGHTS RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Trận quái ----------

func _t_encounters() -> void:
	for enc_name: StringName in EXPECTED:
		var enc := _fights.get_node(NodePath(String(enc_name))) as Encounter
		var enemies: Array[Enemy] = []
		for child in enc.get_node(^"Enemies").get_children():
			if child is Enemy:
				enemies.append(child as Enemy)
		var counts: Dictionary = {}
		for e: Enemy in enemies:
			var kind := StringName(e.get_script().get_global_name())
			counts[kind] = int(counts.get(kind, 0)) + 1
		_check(counts == EXPECTED[enc_name], "%s: đúng quái %s" % [enc_name, counts])
		var wolves := enemies.filter(func(e: Enemy) -> bool: return e is ShadowWolf)
		if not wolves.is_empty():
			var pack: WolfPack = (wolves[0] as ShadowWolf).pack
			_check(pack != null and wolves.all(func(w: ShadowWolf) -> bool: return w.pack == pack), "%s: sói chung một bầy" % enc_name)
		_check(enemies.all(func(e: Enemy) -> bool: return not e.has_target()), "%s: quái ngủ trước khi player vào" % enc_name)
		var started := [false]
		enc.started.connect(func() -> void: started[0] = true, CONNECT_ONE_SHOT)
		var cleared := [false]
		enc.cleared.connect(func() -> void: cleared[0] = true, CONNECT_ONE_SHOT)
		_teleport(enc.global_position + Vector3.UP * 0.1, Vector3.FORWARD)
		# Quái thức lần lượt mỗi spawn_interval giây
		await _frames(int((enc.spawn_interval * enemies.size() + 0.5) * 60.0))
		_check(started[0] and enc.is_running(), "%s: player vào vùng thì trận bắt đầu" % enc_name)
		for e: Enemy in enemies:
			if is_instance_valid(e) and not e.is_dead():
				e.health.take_damage(e.health.current_health)
		await _frames(30)
		_check(cleared[0] and GameState.has_flag(enc.persistent_id), "%s: hạ hết thì xong trận, lưu cờ %s" % [enc_name, enc.persistent_id])
		_player.health.heal_full()
		_teleport(Vector3(6, 0.1, 1.4), Vector3.RIGHT)
		await _frames(20)


## Trận tháp: hạ hết thì cổng dịch chuyển lên tầng sau mở; Slime Mẹ T4 mở cổng T4; các cổng còn lại độc lập
func _t_tower_fights() -> void:
	var gate4 := _level.get_node(^"Tier2Links/TowerExitT4") as WarpPortal
	_check(gate4.is_active(), "TowerExitT4: hạ 4 Đầu Lửa ở _t_encounters thì đĩa lên T5 mở")
	var gate3 := _level.get_node(^"Tier2Links/TowerExitT3") as WarpPortal
	_check(not gate3.is_active(), "TowerExitT3: chưa hạ Slime Mẹ tầng 3 thì đĩa đóng")
	var fight := _fights.get_node(^"TowerT3MotherFight") as BossFight
	var mother_ref := [null]
	fight.started.connect(func(boss: Node3D) -> void: mother_ref[0] = boss, CONNECT_ONE_SHOT)
	_player.health.heal_full()
	_teleport(fight.global_position + Vector3(0, -0.22, 3), Vector3.FORWARD)
	await _frames(20)
	var mother := mother_ref[0] as SlimeMother
	_check(mother != null and mother.health.max_health == 24, "vào tầng 3: Slime Mẹ xuất hiện (máu %d)" % (mother.health.max_health if mother else -1))
	if mother == null:
		return
	_clear_slimes(mother)
	mother.health.take_damage(mother.health.current_health)
	await _frames(10)
	_clear_slimes(null)
	await _frames(int(1.8 * 60.0))
	_check(GameState.has_flag(&"level_3.t2_t3_cleared") and gate3.is_active(), "hạ Slime Mẹ tầng 3: lưu cờ, đĩa lên T4 mở")
	_teleport(Vector3(6, 0.1, 1.4), Vector3.RIGHT)
	await _frames(20)


## 3 cổng Hub (bắc / đông / nam): chưa hạ trận phục kích Hub thì đóng, đi bộ vào bị chặn; hạ xong thì chìm, đi qua được.
## Lối bắc xuất phát sau bệ đá dịch chuyển giữa Hub (bệ chắn đường đi thẳng)
func _t_hub_gates(cleared: bool) -> void:
	var hub := _fights.get_node(^"T2HubAmbush") as Node3D
	var center := hub.global_position + Vector3.UP * 0.1
	var hurtbox := _player.get_node(^"HurtboxComponent") as HurtboxComponent
	# Lúc đo cổng đóng: tắt trận Hub để đi trong Hub không kích hoạt trận trước _t_encounters
	if not cleared:
		hub.process_mode = Node.PROCESS_MODE_DISABLED
	for gate_name: String in ["HubGateNorth", "HubGateEast", "HubGateSouth"]:
		var gate := _fights.get_node(NodePath(gate_name)) as StoneGate
		var dir := Vector3(gate.global_position.x - center.x, 0, gate.global_position.z - center.z)
		var gate_dist := dir.length()
		dir = dir.normalized()
		_check(gate.is_open == cleared, "%s: %s" % [gate_name, "hạ trận Hub xong thì mở" if cleared else "chưa hạ trận Hub thì đóng"])
		var start := center + (dir * 8.0 if gate_name == "HubGateNorth" else Vector3.ZERO)
		hurtbox.set_invincible(10.0)
		_teleport(start, dir)
		await _frames(10)
		for _i: int in range(200):
			_press_towards(dir)
			await get_tree().physics_frame
		_release()
		var gone := (_player.global_position - center).dot(dir)
		if cleared:
			_check(gone > gate_dist + 2.0, "%s: đi bộ qua lối (%.1f m, cổng ở %.1f m)" % [gate_name, gone, gate_dist])
		else:
			_check(gone < gate_dist, "%s: đi bộ vào bị cổng chặn (%.1f m, cổng ở %.1f m)" % [gate_name, gone, gate_dist])
	_player.health.heal_full()
	_teleport(Vector3(6, 0.1, 1.4), Vector3.RIGHT)
	await _frames(20)
	hub.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(5)


## Cổng giữa phòng: [tên, các node phải tắt khi đo cổng đóng (để quái không chắn đường)]
const ROOM_GATES: Array = [
	["Room04Gate", [^"Tier2Fights/T2TimberCaster"]],
	["Room05Gate", [^"Tier2Mechanics/Room05Cages"]],
	["Room06Gate", [^"Tier2Fights/T2DarkForgePack"]],
	["Room08Gate", [^"Tier2Mechanics/Room08Statues"]],
]


## Chưa dọn phòng: đi bộ thật từ trong phòng về cửa đông thì bị cổng chặn
func _t_room_gates_closed() -> void:
	var hurtbox := _player.get_node(^"HurtboxComponent") as HurtboxComponent
	for g: Array in ROOM_GATES:
		var gate := _fights.get_node(NodePath("RoomGates/%s/Gate" % g[0])) as StoneGate
		for path: NodePath in g[1]:
			_level.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
		_check(not gate.is_open, "%s: chưa dọn phòng thì cổng đóng" % g[0])
		hurtbox.set_invincible(10.0)
		_teleport(gate.global_position + Vector3(-6, 0.1, 0), Vector3.RIGHT)
		await _frames(10)
		for _i: int in range(150):
			_press_towards(Vector3.RIGHT)
			await get_tree().physics_frame
		_release()
		_check(_player.global_position.x < gate.global_position.x, "%s: đi bộ vào bị cổng chặn (x %.1f, cổng %.1f)" % [g[0], _player.global_position.x, gate.global_position.x])
		# Ra khỏi phòng trước rồi mới bật lại trận, nếu không trận bắt đầu ngay vì player còn đứng trong vùng
		_teleport(Vector3(6, 0.1, 1.4), Vector3.RIGHT)
		await _frames(10)
		for path: NodePath in g[1]:
			_level.get_node(path).process_mode = Node.PROCESS_MODE_INHERIT
	_player.health.heal_full()
	await _frames(20)


## Bật từng cờ: thiếu một cờ thì vẫn đóng; đủ cờ thì cổng chìm và đi qua được
func _t_room_gates_open() -> void:
	var hurtbox := _player.get_node(^"HurtboxComponent") as HurtboxComponent
	for g: Array in ROOM_GATES:
		var holder := _fights.get_node(NodePath("RoomGates/%s" % g[0]))
		var gate := holder.get_node(^"Gate") as StoneGate
		var flags: Array[StringName] = []
		for c: Node in holder.get_children():
			if c is FlagSource:
				flags.append((c as FlagSource).flag)
		for i: int in range(flags.size() - 1):
			GameState.set_flag(flags[i])
		await _frames(30)
		if flags.size() > 1:
			_check(not gate.is_open, "%s: còn thiếu %s thì cổng vẫn đóng" % [g[0], flags[-1]])
		GameState.set_flag(flags[-1])
		await _frames(150)
		_check(gate.is_open, "%s: đủ %d cờ thì cổng mở" % [g[0], flags.size()])
		for path: NodePath in g[1]:
			_level.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
		hurtbox.set_invincible(10.0)
		_teleport(gate.global_position + Vector3(-6, 0.1, 0), Vector3.RIGHT)
		await _frames(10)
		for _i: int in range(150):
			_press_towards(Vector3.RIGHT)
			await get_tree().physics_frame
		_release()
		_check(_player.global_position.x > gate.global_position.x + 2.0, "%s: đi bộ qua cửa (x %.1f, cổng %.1f)" % [g[0], _player.global_position.x, gate.global_position.x])
		for path: NodePath in g[1]:
			_level.get_node(path).process_mode = Node.PROCESS_MODE_INHERIT
	_player.health.heal_full()
	_teleport(Vector3(6, 0.1, 1.4), Vector3.RIGHT)
	await _frames(20)


## Phòng 09: hạ trận sói (_t_encounters) thì ngọc Nam hiện trên trụ rune
func _t_south_shard() -> void:
	var shard := _level.get_node_or_null(^"Tier2Mechanics/ForgeShards/SouthShardReveal/SouthShard")
	_check(GameState.has_flag(&"level_3.t2_wisps_cleared") and shard != null and (shard as Node3D).is_visible_in_tree(), "hạ trận sói phòng 09: ngọc Nam hiện ra")
	_check(_level.get_node_or_null(^"Tier2Mechanics/Room09Wisps") == null, "phòng 09 không còn ma trơi, đợt quái, rương")


# ---------- 3. Slime Mẹ: thông số cực đoan (đo ở phòng T3) ----------

func _t_mother_extremes() -> void:
	var cases: Array = [
		# [brood_interval, brood_count, max_children, death_split, slam_max_distance, slam_height, nhãn]
		[0.5, 3, 4, 0, 7.0, 3.0, "đẻ mỗi 0,5 s x 3 con, tối đa 4, tách 0"],
		[1.0, 0, 4, 5, 0.0, 0.0, "đẻ 0 con, tách 5, nhảy xa 0 m cao 0 m"],
	]
	var t4 := _fights.get_node(^"TowerT3MotherFight") as Node3D
	for c: Array in cases:
		var mother := MOTHER_SCENE.instantiate() as SlimeMother
		var d := (mother.data as SlimeMotherData).duplicate() as SlimeMotherData
		d.brood_interval = c[0]
		d.brood_count = c[1]
		d.max_children = c[2]
		d.death_split_count = c[3]
		d.slam_max_distance = c[4]
		d.slam_height = c[5]
		mother.data = d
		_level.add_child(mother)
		mother.global_position = t4.global_position + Vector3(0, -0.22, -3)
		# Thêm vào cây rồi mới đặt chỗ: chỗ "nhà" (giới hạn đuổi) lấy lúc _ready là gốc tọa độ, đặt lại cho đúng
		mother.home_position = mother.global_position
		_player.health.heal_full()
		_teleport(t4.global_position + Vector3(0, -0.22, 3), Vector3.BACK)
		mother.target = _player
		var start := mother.global_position
		var max_alive := 0
		var slams := [0]
		mother.slammed.connect(func(_c: Vector3, _h: int) -> void: slams[0] += 1)
		for _i: int in range(240):
			await get_tree().physics_frame
			max_alive = maxi(max_alive, mother.get_alive_children().size())
			if d.slam_max_distance == 0.0:
				_player.health.heal_full()
		var expect_alive := mini(d.max_children, 99) if d.brood_count > 0 else 0
		_check(max_alive == expect_alive, "%s: số con sống tối đa %d (mong %d)" % [c[6], max_alive, expect_alive])
		if d.slam_max_distance == 0.0:
			var drift := Vector2(mother.global_position.x - start.x, mother.global_position.z - start.z).length()
			_check(slams[0] >= 1 and is_finite(mother.global_position.y) and mother.global_position.y < t4.global_position.y + 1.0,
					"%s: vẫn dậm (%d lần), không bay mất (y = %.2f, lệch %.1f m)" % [c[6], slams[0], mother.global_position.y, drift])
		_clear_slimes(mother)
		await _frames(3)
		var before := _count_slimes()
		mother.health.take_damage(mother.health.current_health)
		await _frames(10)
		_check(_count_slimes() - before == d.death_split_count, "%s: chết tách %d con" % [c[6], _count_slimes() - before])
		_clear_slimes(null)
		await _frames(int(1.6 * 60.0))


# ---------- 4. Boss tạm ----------

func _t_boss() -> void:
	var fight := _fights.get_node(^"T2BossFight") as BossFight
	var reveal := _fights.get_node(^"Tier3PortalReveal")
	_check(reveal.get_child_count() == 0 or reveal.get_node_or_null(^"Tier3PortalFrame") == null or not (reveal.get_node(^"Tier3PortalFrame") as Node3D).is_inside_tree(),
			"chưa hạ boss: chưa có khung cổng tier 3")
	var boss_ref := [null]
	fight.started.connect(func(boss: Node3D) -> void: boss_ref[0] = boss, CONNECT_ONE_SHOT)
	_player.health.heal_full()
	_teleport(fight.global_position + Vector3(0, -0.22, 3), Vector3.FORWARD)
	await _frames(30)
	var boss := boss_ref[0] as Boss1
	_check(boss != null and boss.health.max_health == 30 and boss.data.display_name.ends_with("(tạm)"),
			"vào tầng boss T6: boss tạm xuất hiện (%s, máu %d)" % [boss.data.display_name if boss else "-", boss.health.max_health if boss else -1])
	if boss == null:
		return
	var defeated := [false]
	fight.defeated.connect(func() -> void: defeated[0] = true, CONNECT_ONE_SHOT)
	# Boss khoá máu theo phase (có khiên): trừ máu từng chút, chờ giữa các lần, tối đa 20 s
	for _i: int in range(1200):
		if defeated[0]:
			break
		if not boss.health.is_dead():
			boss.health.take_damage(1)
		_player.health.heal_full()
		await get_tree().physics_frame
	await _frames(30)
	var frame := _level.get_node_or_null(^"Tier2Fights/Tier3PortalReveal/Tier3PortalFrame") as Node3D
	_check(defeated[0] and GameState.has_flag(BOSS_FLAG), "hạ boss tạm: lưu cờ %s" % BOSS_FLAG)
	_check(frame != null and frame.is_inside_tree(), "hạ boss: hiện khung cổng lên tier 3")


# ---------- Tiện ích ----------

func _count_slimes() -> int:
	var n := 0
	for node: Node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var slime := (node as HurtboxComponent).owner as LavaSlime
		if slime and not slime is SlimeMother and not slime.is_dead():
			n += 1
	return n


## Xóa mọi slime con đang sống (trừ except) để đo lần sau không lẫn
func _clear_slimes(except: Node) -> void:
	for node: Node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var slime := (node as HurtboxComponent).owner as LavaSlime
		if slime and slime != except and not slime is SlimeMother and not slime.is_dead():
			slime.free()


## Đi bộ thật theo dir trong n frame từ start; trả về z cuối
func _walk(start: Vector3, dir: Vector3, n: int) -> float:
	_teleport(start, dir)
	await _frames(10)
	for _i: int in range(n):
		_press_towards(dir)
		await get_tree().physics_frame
	_release()
	await _frames(5)
	return _player.global_position.z


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
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


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
