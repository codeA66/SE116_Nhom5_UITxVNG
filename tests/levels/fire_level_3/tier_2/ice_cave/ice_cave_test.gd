extends Node
## Test cụm 5 tier 2 map Lửa (Hang băng, vùng lạnh) bằng phím, va chạm và node thật:
## 1. Vào hang, đứng xa lửa trại: bị lạnh; chạy chậm hơn (đo quãng chạy thật 1 s trong / ngoài hang);
##    cứ damage_interval giây mất 1 máu; lạnh không làm máu xuống dưới min_health.
## 2. Được sưởi: đứng cạnh lửa trại / cầm đuốc cháy / kiếm ghép Lửa thì hết lạnh, không mất máu, chạy bình thường.
## 3. Ra khỏi hang: trả lại tốc độ gốc của player (MovementStats ban đầu).
## 4. Cực đoan: mất máu mỗi 0,5 s / 30 s, chậm 0,05 / 1,0 (không chậm), min_health 3.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/ice_cave/ice_cave_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const TORCH_SCENE: PackedScene = preload("res://objects/world/cellar/hand_torch/hand_torch.tscn")
const COLD_SPOT := Vector3(343, 8.42, 20)
const FIRE_SPOT := Vector3(334, 8.42, 15.5)

var _player: Player
var _level: ZoneRoot
var _cold: ColdZone
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	for flag: StringName in [&"level_3.boss_defeated", &"level_3.t2_ice_cave_wall", &"level_3.t2_exit_vines"]:
		GameState.set_flag(flag)
	GameState.unlock_ability(FLAME_BREATH)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 20
	_player.health.heal_full()
	_cold = _level.get_node(^"Tier2Mechanics/IceCave/ColdZone") as ColdZone
	await _t_cold()
	await _t_warm_sources()
	await _t_leave()
	await _t_extremes()
	print("ICE CAVE RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Bị lạnh ----------

func _t_cold() -> void:
	var outside_speed := await _run_distance(Vector3(305, 8.42, 14), Vector3.RIGHT)
	_teleport(COLD_SPOT, Vector3.LEFT)
	await _frames(10)
	_check(_cold.is_chilled, "vào hang, xa lửa trại: bị lạnh")
	var inside_speed := await _run_distance(COLD_SPOT, Vector3.LEFT)
	_check(inside_speed < outside_speed * (_cold.slow_scale + 0.1) and inside_speed > outside_speed * (_cold.slow_scale - 0.1),
			"chạy chậm lại: %.2f m/s trong hang so với %.2f m/s ngoài (đặt %.0f%%)" % [inside_speed, outside_speed, _cold.slow_scale * 100.0])
	_player.health.heal_full()
	var hp := _player.health.current_health
	_teleport(COLD_SPOT, Vector3.LEFT)
	await _frames(int((_cold.damage_interval * 2.0 + 0.5) * 60.0))
	var lost := hp - _player.health.current_health
	_check(lost == 2, "đứng %.1f s trong lạnh: mất %d máu (mỗi %.1f s một máu)" % [_cold.damage_interval * 2.0 + 0.5, lost, _cold.damage_interval])
	_player.health.set_current_health(2)
	await _frames(int((_cold.damage_interval * 3.0) * 60.0))
	_check(_player.health.current_health == _cold.min_health and not _player.health.is_dead(), "lạnh không làm máu xuống dưới %d (còn %d)" % [_cold.min_health, _player.health.current_health])


# ---------- 2. Được sưởi ----------

func _t_warm_sources() -> void:
	# Lửa trại
	_player.health.heal_full()
	_teleport(FIRE_SPOT, Vector3.RIGHT)
	await _frames(10)
	var hp := _player.health.current_health
	await _frames(int((_cold.damage_interval * 2.0 + 0.5) * 60.0))
	_check(not _cold.is_chilled and _player.health.current_health == hp, "đứng cạnh lửa trại: hết lạnh, không mất máu")
	# Đuốc cháy
	var torch := HandTorch.give_to(_player, TORCH_SCENE)
	torch.light_up()
	_teleport(COLD_SPOT, Vector3.LEFT)
	await _frames(10)
	hp = _player.health.current_health
	await _frames(int((_cold.damage_interval + 0.5) * 60.0))
	_check(not _cold.is_chilled and _player.health.current_health == hp, "cầm đuốc cháy: không lạnh")
	torch.queue_free()
	await _frames(5)
	# Kiếm ghép Lửa
	_check(GameState.fuse(&"fire", WeaponData.Slot.SWORD), "ghép Lửa vào kiếm")
	await _frames(10)
	hp = _player.health.current_health
	await _frames(int((_cold.damage_interval + 0.5) * 60.0))
	_check(not _cold.is_chilled and _player.health.current_health == hp, "kiếm ghép Lửa: không lạnh")
	GameState.unfuse(WeaponData.Slot.SWORD)
	await _frames(10)
	_check(_cold.is_chilled, "tháo Lửa khỏi kiếm: lạnh lại")


# ---------- 3. Ra khỏi hang ----------

func _t_leave() -> void:
	_teleport(COLD_SPOT, Vector3.LEFT)
	await _frames(10)
	var slow := _player.movement
	_teleport(Vector3(305, 8.42, 14), Vector3.RIGHT)
	await _frames(10)
	_check(not _cold.is_chilled and _player.movement != slow and _player.movement.max_speed > slow.max_speed,
			"ra khỏi hang: hết lạnh, trả lại tốc độ gốc (%.1f → %.1f m/s)" % [slow.max_speed, _player.movement.max_speed])


# ---------- 4. Cực đoan ----------

func _t_extremes() -> void:
	for interval: float in [0.5, 30.0]:
		_cold.damage_interval = interval
		_player.health.heal_full()
		_teleport(COLD_SPOT, Vector3.LEFT)
		await _frames(5)
		var hp := _player.health.current_health
		await _frames(int(2.25 * 60.0))
		var lost := hp - _player.health.current_health
		var expect := int(2.2 / interval)
		_check(lost == expect, "mất máu mỗi %.1f s: 2,25 s mất %d (mong %d)" % [interval, lost, expect])
		_teleport(Vector3(305, 8.42, 14), Vector3.RIGHT)
		await _frames(10)
	_cold.damage_interval = 4.0
	var outside_speed := await _run_distance(Vector3(305, 8.42, 14), Vector3.RIGHT)
	for scale: float in [0.05, 1.0]:
		_teleport(Vector3(305, 8.42, 14), Vector3.RIGHT)
		await _frames(10)
		_cold.slow_scale = scale
		# Bản chậm tạo một lần mỗi vùng: tạo lại cho hệ số mới
		_cold.set(&"_slow_movement", null)
		var v := await _run_distance(COLD_SPOT, Vector3.LEFT)
		_check(absf(v - outside_speed * scale) < outside_speed * 0.1 + 0.2, "chậm %.2f: chạy %.2f m/s (mong %.2f)" % [scale, v, outside_speed * scale])
	_cold.slow_scale = 0.6
	_cold.set(&"_slow_movement", null)
	_cold.min_health = 3
	_cold.damage_interval = 0.5
	_player.health.set_current_health(5)
	_teleport(COLD_SPOT, Vector3.LEFT)
	await _frames(int(3.0 * 60.0))
	_check(_player.health.current_health == 3, "min_health 3: còn %d máu" % _player.health.current_health)


# ---------- Tiện ích ----------

## Chạy thật 1 s theo hướng dir từ start, trả về tốc độ trung bình nửa sau (m/s, đã hết tăng tốc)
func _run_distance(start: Vector3, dir: Vector3) -> float:
	_teleport(start, dir)
	await _frames(10)
	for _i: int in range(30):
		_press_towards(dir)
		await get_tree().physics_frame
	var p0 := _player.global_position
	for _i: int in range(30):
		_press_towards(dir)
		await get_tree().physics_frame
	_release()
	var d := Vector2(_player.global_position.x - p0.x, _player.global_position.z - p0.z).length()
	await _frames(10)
	return d / 0.5


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
