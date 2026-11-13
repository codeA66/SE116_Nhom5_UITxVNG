extends Node
## Test búa nện (object ForgeHammer, còn giữ để dùng lại; map tier 2 đã bỏ búa) bằng va chạm và node thật, đặt riêng trên sàn Hub:
## báo trước đúng warning_time rồi nện; player đứng dưới mất máu, bị hất ra; quái đứng dưới cũng trúng;
## đứng ngoài mặt búa không trúng. Cực đoan: báo trước 0,1 s / 3 s, búa nhỏ 0,5 m (đứng lệch 1 m không trúng) / to 6 m.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/forge/forge_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const HAMMER_SCENE: PackedScene = preload("res://objects/combat/hazards/forge_hammer/forge_hammer.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/_base/enemy.tscn")

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
	# Trận quái tier 2 coi như đã thắng, để quái không chen vào phép đo búa
	for flag: StringName in [&"level_3.t2_hub_ambush", &"level_3.t2_timber_caster", &"level_3.t2_slime_hall", &"level_3.t2_dark_forge_pack"]:
		GameState.set_flag(flag)
	await _load_level()
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_hammer_alone()
	await _t_hammer_extremes()
	print("FORGE RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Búa đứng riêng (đặt trên sàn phòng 03 Hub, ngoài hành lang búa) ----------

func _t_hammer_alone() -> void:
	var at := Vector3(284, 4.32, 58)
	var hammer := _spawn_hammer(at, {"warning_time": 0.8, "start_delay": 0.3})
	var log := {"warn": -1, "slam": -1}
	hammer.warned.connect(func() -> void: if int(log["warn"]) < 0: log["warn"] = Time.get_ticks_msec())
	hammer.slammed.connect(func() -> void: if int(log["slam"]) < 0: log["slam"] = Time.get_ticks_msec())
	_teleport(at + Vector3(0, 0.1, 0))
	var hp := _player.health.current_health
	await _wait_until(func() -> bool: return int(log["slam"]) >= 0, 300)
	await _frames(20)
	var lead := (int(log["slam"]) - int(log["warn"])) / 1000.0
	var lost := hp - _player.health.current_health
	var pushed := _flat(_player.global_position, at)
	_check(absf(lead - (0.8 + hammer.slam_time)) < 0.1, "búa báo trước rồi mới nện (%.2f s, đặt %.2f + rơi %.2f)" % [lead, 0.8, hammer.slam_time])
	_check(lost >= 1 and pushed > 1.0, "đứng dưới búa: mất %d máu, bị hất %.2f m" % [lost, pushed])
	# Quái đứng dưới cũng trúng
	var dummy := ENEMY_SCENE.instantiate() as Enemy
	dummy.position = at
	add_child(dummy)
	dummy.sensor.radius = 0.0
	# Đứng trong Hub, xa búa (Hub x 264..292, z 36..64: không lùi ra ngoài mép kẻo rơi xuống vực)
	_teleport(at + Vector3(-8, 0.1, -4))
	await _frames(5)
	var ehp := dummy.health.current_health
	await _wait_slam(hammer)
	await _frames(10)
	_check(dummy.health.current_health < ehp, "quái đứng dưới búa cũng trúng (%d → %d)" % [ehp, dummy.health.current_health])
	dummy.queue_free()
	# Đứng ngoài mặt búa (cách tâm 3 m, mặt búa 1,8 m) không trúng
	_teleport(at + Vector3(3, 0.1, 0))
	await _frames(5)
	hp = _player.health.current_health
	await _wait_slam(hammer)
	await _frames(10)
	_check(_player.health.current_health == hp, "đứng ngoài mặt búa (cách 3 m): không mất máu")
	hammer.queue_free()
	await _frames(70)


func _t_hammer_extremes() -> void:
	var at := Vector3(272, 4.32, 58)
	for warn: float in [0.1, 3.0]:
		var h := _spawn_hammer(at, {"warning_time": warn, "start_delay": 0.3})
		var log := {"warn": -1, "slam": -1}
		h.warned.connect(func() -> void: if int(log["warn"]) < 0: log["warn"] = Time.get_ticks_msec())
		h.slammed.connect(func() -> void: if int(log["slam"]) < 0: log["slam"] = Time.get_ticks_msec())
		await _wait_until(func() -> bool: return int(log["slam"]) >= 0, 400)
		var lead := (int(log["slam"]) - int(log["warn"])) / 1000.0
		_check(absf(lead - (warn + h.slam_time)) < 0.1, "báo trước %.1f s: nện sau %.2f s" % [warn, lead])
		h.queue_free()
	# Búa nhỏ 0,5 m: đứng lệch 1 m không trúng; búa to 6 m: đứng lệch 2,5 m vẫn trúng
	for c: Array in [[0.5, 1.0, false], [6.0, 2.5, true]]:
		var size: float = c[0]
		# Lần nện đầu đến sau khi player đã đứng yên chỗ đo (đòn trước làm player bất tử ngắn)
		await _frames(90)
		var h := _spawn_hammer(at, {"head_size": Vector3(size, 0.9, size), "warning_time": 0.3, "start_delay": 1.2})
		_teleport(at + Vector3(float(c[1]), 0.1, 0))
		await _frames(20)
		var hp := _player.health.current_health
		await _wait_slam(h)
		await _frames(10)
		var hit := _player.health.current_health < hp
		_check(hit == bool(c[2]), "búa %.1f m, đứng lệch %.1f m: %s" % [size, float(c[1]), "trúng" if hit else "không trúng"])
		h.queue_free()
		await _frames(70)


# ---------- Tiện ích ----------

func _load_level() -> void:
	_player = null
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()


func _spawn_hammer(at: Vector3, props: Dictionary) -> ForgeHammer:
	var h := HAMMER_SCENE.instantiate() as ForgeHammer
	for key: String in props:
		h.set(key, props[key])
	h.position = at
	_level.add_child(h)
	return h


func _wait_slam(h: ForgeHammer) -> void:
	var done := {"v": false}
	var cb := func() -> void: done["v"] = true
	h.slammed.connect(cb)
	await _wait_until(func() -> bool: return bool(done["v"]), 400)
	h.slammed.disconnect(cb)


## Bấm hướng thật tới đích (mặt phẳng XZ); true nếu tới nơi trong max_frames
func _run_to(target: Vector3, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		var pos := _player.global_position
		var flat := Vector2(target.x - pos.x, target.z - pos.z)
		if flat.length() <= 0.6:
			_release()
			return true
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()
	return false


func _teleport(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
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
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
