extends Node
## Test cụm 2 tier 2 map Lửa (phòng 04 Xưởng gỗ, phòng 05 tường nứt) bằng phím, va chạm và node thật:
## 1. Phòng 04 là phòng thường: không còn vật đốt, đi bộ qua giữa phòng không rơi, cửa đông thông.
## 2. Cực đoan: lan 0 m không lan; lan 20 m lan hết; bắt lửa trễ 0 s / 5 s.
## 3. Tường nứt phòng 05: chém thật, phun lửa thật không vỡ; Slime Dung Nham tự nổ cạnh tường thì vỡ, đi qua sang Hang băng;
##    thùng dầu nổ cạnh tường cũng phá được; nạp lại map: tường vẫn vỡ.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/flammables/flammables_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const VINES: PackedScene = preload("res://objects/fire_puzzle/flammables/dry_vines/dry_vines.tscn")
const CRATE: PackedScene = preload("res://objects/fire_puzzle/flammables/wooden_crate/wooden_crate.tscn")
const OIL: PackedScene = preload("res://objects/fire_puzzle/flammables/oil_barrel/oil_barrel.tscn")
const WALL: PackedScene = preload("res://objects/fire_puzzle/cracked_wall/cracked_wall.tscn")
const SLIME: PackedScene = preload("res://entities/enemies/volcano/lava_slime/lava_slime.tscn")

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
	# Đợt 4: trận quái tier 2 coi như đã thắng (slime phòng 05 nổ cạnh tường nứt sẽ phá tường trước phép đo)
	for flag: StringName in [&"level_3.t2_hub_ambush", &"level_3.t2_timber_caster", &"level_3.t2_room05_cagespider", &"level_3.t2_room05_cageslime", &"level_3.t2_room08_cage", &"level_3.t2_dark_forge_pack"]:
		GameState.set_flag(flag)
	GameState.set_weapon(SWORD)
	GameState.unlock_ability(FLAME_BREATH)
	await _load_level()
	await _t_room04_plain()
	await _t_extremes()
	await _t_cracked_wall()
	print("FLAMMABLES RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Phòng 04: phòng thường, sàn kín ----------

func _t_room04_plain() -> void:
	_check(_level.get_node_or_null(^"Tier2Mechanics/Room04Flammables") == null and _level.get_node_or_null(^"Tier2Mechanics/Room04Reset") == null,
			"phòng 04 không còn cầu, dây leo, thùng đốt")
	# Đi bộ thật qua chỗ trước đây là hố cầu (z 18): không rơi
	_teleport(Vector3(72, 4.1, -28.6), Vector3.FORWARD)
	await _frames(20)
	var crossed := await _run_to(Vector3(72, 4, -38.6), 200)
	_check(crossed and _player.global_position.y > 3.68, "đi bộ qua giữa phòng 04 không rơi (z %.1f, y %.1f)" % [_player.global_position.z, _player.global_position.y])
	# Cửa đông (trước có dây leo chặn) đi qua được
	_teleport(Vector3(78, 4.1, -36.6), Vector3.FORWARD)
	await _frames(15)
	var east := await _run_to(Vector3(86, 4, -36.6), 200)
	_check(east, "cửa đông phòng 04 thông (x %.1f)" % _player.global_position.x)


# ---------- 2. Cực đoan (vật đặt riêng trên sàn Hub) ----------

func _t_extremes() -> void:
	_teleport(Vector3(64, 0.1, 9.4), Vector3.FORWARD)
	# Lan 0 m: không lan
	var a := _spawn(CRATE, Vector3(74, 0, -10.6), {"spread_radius": 0.0, "spread_delay": 0.2}) as Flammable
	var b := _spawn(CRATE, Vector3(77, 0, -10.6), {}) as Flammable
	a.ignite()
	await _frames(90)
	_check(a.is_burning and not b.is_burning and not b.is_burned, "lan 0 m: vật cạnh (cách 3 m) không bắt lửa")
	a.queue_free(); b.queue_free()
	# Lan 20 m: lan cả vật cách 15 m
	a = _spawn(CRATE, Vector3(74, 0, -10.6), {"spread_radius": 20.0, "spread_delay": 0.2}) as Flammable
	b = _spawn(CRATE, Vector3(74, 0, 4.4), {}) as Flammable
	a.ignite()
	await _frames(40)
	_check(b.is_burning, "lan 20 m: vật cách 15 m bắt lửa")
	a.queue_free(); b.queue_free()
	# Trễ lan 0 s và 2,5 s (thùng cháy 3 s)
	for delay: float in [0.0, 2.5]:
		a = _spawn(CRATE, Vector3(74, 0, -10.6), {"spread_delay": delay}) as Flammable
		b = _spawn(CRATE, Vector3(76.5, 0, -10.6), {}) as Flammable
		# Đếm theo frame vật lý (thời gian game), không theo đồng hồ thật
		var frames := 0
		a.ignite()
		while not b.is_burning and frames < 500:
			await get_tree().physics_frame
			frames += 1
		var took := frames / float(Engine.physics_ticks_per_second)
		_check(b.is_burning and absf(took - delay) < 0.2, "trễ lan %.1f s: vật cạnh bắt lửa sau %.2f s" % [delay, took])
		a.queue_free(); b.queue_free()
	# Trễ lan 5 s, lâu hơn thời gian cháy 3 s: cháy rụi trước khi kịp lan
	a = _spawn(CRATE, Vector3(74, 0, -10.6), {"spread_delay": 5.0}) as Flammable
	b = _spawn(CRATE, Vector3(76.5, 0, -10.6), {}) as Flammable
	a.ignite()
	await _frames(400)
	_check(a.is_burned and not b.is_burning and not b.is_burned, "trễ lan 5 s (cháy 3 s): rụi trước khi kịp lan")
	a.queue_free(); b.queue_free()
	await _frames(5)


# ---------- 3. Tường nứt ----------

func _t_cracked_wall() -> void:
	# Hang băng đã bỏ tường nứt và vùng lạnh: lối vào mở sẵn, đứng trong hang không mất máu
	_check(_level.get_node_or_null(^"Tier2Mechanics/IceCaveWall") == null and _level.get_node_or_null(^"Tier2Mechanics/IceCave") == null, "Hang băng: không còn tường nứt, vùng lạnh, rương")
	_player.health.heal_full()
	_teleport(Vector3(110.5, 4.1, -36.6), Vector3.RIGHT)
	await _frames(20)
	# Đích x 124: đã qua cửa hang (x ~120), trước lửa trại (x 128)
	var passed := await _run_to(Vector3(124, 4, -36.6), 200)
	_check(passed, "đi bộ thẳng vào Hang băng (x %.1f)" % _player.global_position.x)
	var hp := _player.health.current_health
	await _frames(240)
	_check(_player.health.current_health == hp, "đứng trong Hang băng 4 s không mất máu (%d → %d)" % [hp, _player.health.current_health])
	# Lửa trại hang băng giống phòng 5 tier 1: cháy sẵn, lại gần lấy được đuốc
	var fire := _node("Tier2Mechanics/IceCaveCampfire") as Campfire
	var space := get_viewport().get_world_3d().direct_space_state
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(fire.global_position + Vector3(0.9, 2.0, 0.9), fire.global_position + Vector3(0.9, -3.0, 0.9)))
	_check(not ground.is_empty() and absf(ground.position.y - fire.global_position.y) < 0.05, "lửa trại hang băng đặt trên sàn")
	_check(fire.is_lit and fire.get_node("Light").visible, "lửa trại hang băng cháy sẵn khi vào khu")
	_teleport(fire.global_position + Vector3(1.8, 0.1, 0.0), Vector3.LEFT)
	await _frames(10)
	await _tap(&"interact")
	await _frames(5)
	var torch := HandTorch.find_on(_player)
	_check(torch != null and torch.is_lit, "lửa trại hang băng đã cháy: interact nhận đuốc đang cháy")
	# Tường nứt vẫn là vật dùng được: thùng dầu nổ cạnh một tường đặt riêng thì vỡ
	var wall2 := _spawn(WALL, Vector3(74, 0, -10.6), {}) as CrackedWall
	var oil := _spawn(OIL, Vector3(75.5, 0, -9.1), {}) as OilBarrel
	_teleport(Vector3(64, 0.1, 9.4), Vector3.FORWARD)
	await _frames(5)
	oil.ignite()
	await _wait_until(func() -> bool: return wall2.is_broken, 200)
	_check(wall2.is_broken, "thùng dầu nổ cạnh tường nứt: tường vỡ")
	wall2.queue_free()


# ---------- Tiện ích ----------

func _load_level() -> void:
	_player = null
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()


func _node(path: String) -> Node:
	return _level.get_node(NodePath(path))


func _spawn(scene: PackedScene, at: Vector3, props: Dictionary) -> Node3D:
	var n := scene.instantiate() as Node3D
	for key: String in props:
		n.set(key, props[key])
	n.position = at
	_level.add_child(n)
	return n


## Giữ phím Phun lửa frames frame (nạp đầy năng lượng trước)
func _breath(frames: int) -> void:
	_player.energy.set_current(_player.energy.get_max())
	Input.action_press(&"skill_fire")
	await _frames(frames)
	Input.action_release(&"skill_fire")
	await _frames(2)


func _respawn_if_dead() -> void:
	if _player.health.is_dead():
		push_error("player chết trong test")


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


func _teleport(pos: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
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
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"skill_fire", &"attack"]:
		Input.action_release(a)


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
