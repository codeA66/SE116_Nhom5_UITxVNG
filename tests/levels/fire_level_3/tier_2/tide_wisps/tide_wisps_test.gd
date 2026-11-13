extends Node
## Test dung nham dâng / rút (object LavaTide, còn giữ để dùng lại; map tier 2 đã bỏ thủy triều) và phòng 09 Sảnh ma trơi
## bằng phím, va chạm và node thật:
## 1. Dung nham (đặt riêng): đi đúng chu kỳ rút → báo trước → dâng → giữ → rút; mặt dung nham ở low_y / high_y.
##    Cực đoan: chu kỳ 0,1 s / 30 s, high_y thấp hơn sàn (không bao giờ ngập).
## 2. Phòng 09: 6 ma trơi đang cháy; vào phòng thì sinh đợt 3 quái; hạ hết thì sinh đợt mới.
##    Chém, tên thường không dập; tên Cung Gió thật bắn trúng thì dập. Dập hết: lưu cờ, ngừng sinh, hiện rương.
##    Cực đoan: mỗi đợt 1 / 12 quái.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/tide_wisps/tide_wisps_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const TIDE_SCENE: PackedScene = preload("res://objects/combat/hazards/lava_tide/lava_tide.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/_base/enemy.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const WIND_BLAST: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
const BOW_SLOT := WeaponData.Slot.BOW

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
	GameState.set_flag(&"level_3.boss_defeated")
	GameState.set_weapon(SWORD)
	GameState.unlock_ability(WIND_BLAST)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_tide_cycle()
	await _t_tide_extremes()
	await _t_room9()
	print("TIDE WISPS RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Chu kỳ dung nham (đặt riêng trên sàn Hub) ----------

func _t_tide_cycle() -> void:
	var tide := _spawn_tide({"low_time": 1.0, "warning_time": 0.5, "rise_time": 0.5, "high_time": 1.0, "fall_time": 0.5, "size": Vector2(4, 4)})
	var order: Array[String] = []
	for sig: String in ["warned", "rising", "risen", "falling", "fallen"]:
		tide.connect(sig, func() -> void: order.append(sig))
	var t := await _frames_until(func() -> bool: return order.has("risen"), 600)
	var high := tide.get_level()
	await _frames_until(func() -> bool: return order.has("fallen"), 600)
	var low := tide.get_level()
	_check(order.slice(0, 5) == ["warned", "rising", "risen", "falling", "fallen"], "đúng thứ tự: báo trước → dâng → đầy → rút → cạn (%s)" % ", ".join(order))
	_check(absf(t - 2.0) < 0.15, "từ lúc bắt đầu tới khi dâng đầy %.2f s (rút 1 + báo 0,5 + dâng 0,5)" % t)
	_check(is_equal_approx(high, tide.high_y) and is_equal_approx(low, tide.low_y), "mặt dung nham: dâng %.2f (đặt %.2f), rút %.2f (đặt %.2f)" % [high, tide.high_y, low, tide.low_y])
	tide.queue_free()


func _t_tide_extremes() -> void:
	for c: Array in [[0.1, "0,1 s"], [30.0, "30 s"]]:
		var d: float = c[0]
		var tide := _spawn_tide({"low_time": d, "warning_time": d, "rise_time": d, "high_time": d, "fall_time": d, "size": Vector2(4, 4)})
		var risen := {"v": false}
		tide.risen.connect(func() -> void: risen["v"] = true)
		var t := await _frames_until(func() -> bool: return bool(risen["v"]), int(d * 3.0 * 60.0) + 60)
		_check(bool(risen["v"]) and absf(t - d * 3.0) < 0.15, "mỗi pha %s: dâng đầy sau %.2f s" % [c[1], t])
		tide.queue_free()
	# high_y thấp hơn sàn: quái đứng trên sàn không chết
	var tide2 := _spawn_tide({"low_time": 0.2, "warning_time": 0.2, "rise_time": 0.2, "high_time": 1.0, "high_y": -0.5, "size": Vector2(6, 6)})
	var e := _spawn_enemy(tide2.global_position)
	var risen2 := {"v": false}
	tide2.risen.connect(func() -> void: risen2["v"] = true)
	await _frames_until(func() -> bool: return bool(risen2["v"]), 200)
	await _frames(20)
	_check(not e.is_dead(), "dâng tới dưới sàn (high_y −0,5): quái trên sàn không sao")
	e.queue_free()
	tide2.queue_free()


# ---------- 3. Phòng 09 ----------

func _t_room9() -> void:
	var group := _level.get_node(^"Tier2Mechanics/Room09Wisps/WispGroup") as WispGroup
	var spawner := _level.get_node(^"Tier2Mechanics/Room09Wisps/WaveSpawner") as WaveSpawner
	var reveal := _level.get_node(^"Tier2Mechanics/Room09Wisps/ChestReveal") as FlagReveal
	var wisps: Array[WispFlame] = []
	for c: Node in group.get_children():
		wisps.append(c as WispFlame)
	_check(wisps.size() == 6 and wisps.all(func(w: WispFlame) -> bool: return w.is_lit) and spawner.waves == 0, "chưa vào phòng: 6 ma trơi đang cháy, chưa sinh quái")
	_teleport(Vector3(304, 0.42, 86), Vector3.RIGHT)
	await _frames(30)
	_check(spawner.waves == 1 and spawner.get_alive_count() == 3, "vào phòng: sinh đợt 1 (%d quái)" % spawner.get_alive_count())
	# Hạ hết đợt: đợt mới
	_kill_alive(spawner)
	await _frames_until(func() -> bool: return spawner.waves == 2, 300)
	_check(spawner.waves == 2 and spawner.get_alive_count() == 3, "hạ hết đợt 1: sinh đợt 2")
	# Chém thật một ma trơi: không tắt
	var target := wisps[0]
	var resisted := {"n": 0}
	target.resisted.connect(func() -> void: resisted["n"] = int(resisted["n"]) + 1)
	_freeze_wisps(wisps, true)
	_teleport(target.get_flame_position() - Vector3(1.0, 1.0, 0) + Vector3(0, 0.1, 0), Vector3.RIGHT)
	await _frames(10)
	for _i: int in range(3):
		await _tap(&"attack")
		await _frames(20)
	_check(target.is_lit and int(resisted["n"]) >= 1, "chém trúng ma trơi: không tắt (%d lần chặn)" % resisted["n"])
	# Tên thường: không tắt
	GameState.unfuse(BOW_SLOT)
	await _shoot_at(target)
	_check(target.is_lit, "tên thường trúng ma trơi: không tắt")
	# Ghép Gió vào cung, bắn thật: tắt
	_check(GameState.fuse(&"wind", BOW_SLOT), "ghép Gió vào cung")
	var hit := false
	for _attempt: int in range(4):
		await _shoot_at(target)
		if not target.is_lit:
			hit = true
			break
	_check(hit, "tên Cung Gió thật bắn trúng: ma trơi tắt")
	# Các ma trơi còn lại: bắn thật lần lượt
	var real_hits := 1 if hit else 0
	for w: WispFlame in wisps:
		if not w.is_lit:
			continue
		for _attempt: int in range(4):
			await _shoot_at(w)
			if not w.is_lit:
				real_hits += 1
				break
	_freeze_wisps(wisps, false)
	_check(group.get_remaining() == 0 and group.is_active(), "dập hết %d ma trơi bằng tên Cung Gió thật (%d / 6)" % [wisps.size(), real_hits])
	await _frames(10)
	_check(spawner.is_stopped and GameState.has_flag(&"level_3.t2_wisps_cleared") and reveal.get_child_count() == 1,
			"dập hết: ngừng sinh quái, lưu cờ, hiện rương")
	var waves := spawner.waves
	_kill_alive(spawner)
	await _frames(200)
	_check(spawner.waves == waves and spawner.get_alive_count() == 0, "đã dừng: hạ hết quái còn lại không sinh đợt mới")
	# Cực đoan: mỗi đợt 1 / 12 quái
	for n: int in [1, 12]:
		spawner.is_stopped = false
		spawner.per_wave = n
		spawner.waves = 0
		spawner.call(&"_on_player_entered")
		await _frames(5)
		_check(spawner.get_alive_count() == n, "mỗi đợt %d quái: sinh %d" % [n, spawner.get_alive_count()])
		_kill_alive(spawner)
		spawner.is_stopped = true
		await _frames(120)


# ---------- Tiện ích ----------

func _spawn_tide(props: Dictionary) -> LavaTide:
	var t := TIDE_SCENE.instantiate() as LavaTide
	for key: String in props:
		t.set(key, props[key])
	t.position = Vector3(268, 4.32, 58)
	_level.add_child(t)
	return t


func _spawn_enemy(at: Vector3) -> Enemy:
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.position = at
	_level.add_child(e)
	e.sensor.radius = 0.0
	return e


func _kill_alive(spawner: WaveSpawner) -> void:
	for n: Node in spawner.get_parent().get_children():
		if n is Enemy and not (n as Enemy).is_dead():
			(n as Enemy).health.take_damage(9999)


## Dừng / chạy lại quỹ đạo ma trơi (để bắn ngắm đứng yên, không phụ thuộc may rủi)
func _freeze_wisps(wisps: Array[WispFlame], frozen: bool) -> void:
	for w: WispFlame in wisps:
		if w.is_lit:
			w.set_process(not frozen)


## Đứng cách 4 m theo hướng tây của ma trơi, quay mặt vào, giữ ngắm rồi nhả
func _shoot_at(w: WispFlame) -> void:
	var at := w.get_flame_position()
	var stand := Vector3(at.x - 4.0, 0.42, at.z)
	_teleport(stand, Vector3.RIGHT)
	_player.energy.set_current(_player.energy.get_max())
	await _frames(8)
	Input.action_press(&"aim")
	await _frames(54)
	Input.action_release(&"aim")
	await _frames(30)


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


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
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"aim", &"attack", &"jump"]:
		Input.action_release(a)


## Đợi tới khi pred đúng, trả về số giây game đã đợi
func _frames_until(pred: Callable, max_frames: int) -> float:
	var n := 0
	while not pred.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n / float(Engine.physics_ticks_per_second)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
