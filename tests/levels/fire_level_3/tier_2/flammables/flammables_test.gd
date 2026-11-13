extends Node
## Test cụm 2 tier 2 map Lửa (phòng 04 Xưởng gỗ, phòng 05 tường nứt) bằng phím, va chạm và node thật:
## 1. Dây leo đầu cầu: Phun lửa thật đốt cháy rụi (mở lối); lửa lan sang cầu treo; chạy qua kịp trước khi cầu sập;
##    cầu sập thì đứng lên chỗ cầu là rơi. Ra khỏi phòng: dây leo và cầu dựng lại, đứng lên cầu được.
## 2. Gờ đá phía tây: đốt chồng thùng thì thùng dầu cạnh đó nổ (player đứng gần mất máu), gờ thông, đi bộ qua được.
## 3. Dây leo cửa ra: cháy rụi thì lưu cờ, nạp lại map không còn; vật không cờ vẫn dựng lại.
## 4. Cực đoan: lan 0 m không lan; lan 20 m lan hết; bắt lửa trễ 0 s / 5 s.
## 5. Tường nứt phòng 05: chém thật, phun lửa thật không vỡ; Slime Dung Nham tự nổ cạnh tường thì vỡ, đi qua sang Hang băng;
##    thùng dầu nổ cạnh tường cũng phá được; nạp lại map: tường vẫn vỡ.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/flammables/flammables_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
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
	for flag: StringName in [&"level_3.t2_hub_ambush", &"level_3.t2_timber_caster", &"level_3.t2_slime_hall", &"level_3.t2_dark_forge_pack"]:
		GameState.set_flag(flag)
	GameState.set_weapon(SWORD)
	GameState.unlock_ability(FLAME_BREATH)
	await _load_level()
	await _t_bridge()
	await _t_ledge()
	await _t_exit_vines()
	await _t_extremes()
	await _t_cracked_wall()
	await _t_reload()
	print("FLAMMABLES RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Dây leo đầu cầu + cầu treo ----------

func _t_bridge() -> void:
	var vines := _node("Tier2Mechanics/Room04Flammables/BridgeVines") as Flammable
	var bridge := _node("Tier2Mechanics/Room04Flammables/RopeBridge") as RopeBridge
	# Dây leo chắn thật: đi từ nam qua cầu không được
	_teleport(Vector3(278, 8.42, 22), Vector3.FORWARD)
	await _frames(20)
	await _run_to(Vector3(278, 8.32, 12), 150)
	_check(_player.global_position.z > 15.0, "dây leo chặn đầu cầu (z %.1f)" % _player.global_position.z)
	# Phun lửa thật vào dây leo
	_teleport(Vector3(278, 8.42, 19.2), Vector3.FORWARD)
	await _frames(15)
	var t0 := Time.get_ticks_msec()
	await _breath(40)
	var caught := await _wait_until(func() -> bool: return vines.is_burning or vines.is_burned, 60)
	_check(caught, "phun lửa thật làm dây leo bắt lửa")
	# Chờ dây leo cháy rụi rồi chạy qua ngay
	await _wait_until(func() -> bool: return vines.is_burned, 300)
	var burned_at := (Time.get_ticks_msec() - t0) / 1000.0
	var bridge_caught := bridge.is_burning
	var crossed := await _run_to(Vector3(278, 8.32, 12), 120)
	_check(bridge_caught, "lửa lan từ dây leo sang cầu treo (cầu đang cháy khi dây leo rụi sau %.1f s)" % burned_at)
	_check(crossed and _player.global_position.y > 8.0, "chạy qua cầu kịp trước khi sập (z %.1f)" % _player.global_position.z)
	await _wait_until(func() -> bool: return bridge.is_burned, 400)
	await _frames(70)
	var collapsed := bridge.is_burned
	# Cầu sập: đứng lên chỗ cầu là rơi (rơi khỏi vùng phòng thì cầu dựng lại, nên ghi trạng thái trước)
	_teleport(Vector3(278, 8.6, 18), Vector3.FORWARD)
	await _frames(40)
	_check(collapsed and _player.global_position.y < 6.0, "cầu sập: đứng lên chỗ cầu thì rơi (y %.1f)" % _player.global_position.y)
	await _respawn_if_dead()
	# Ra khỏi phòng rồi vào lại: dựng lại
	_teleport(Vector3(270, 4.42, 44), Vector3.FORWARD)
	await _frames(30)
	_teleport(Vector3(278, 8.6, 18), Vector3.FORWARD)
	await _frames(40)
	_check(not vines.is_burned and not bridge.is_burned and vines.is_visible_in_tree() and _player.is_on_floor() and _player.global_position.y > 8.0,
			"rời phòng rồi vào lại: dây leo, cầu dựng lại, đứng lên cầu được (y %.2f)" % _player.global_position.y)


# ---------- 2. Gờ đá phía tây: thùng gỗ + thùng dầu ----------

func _t_ledge() -> void:
	var crates := _node("Tier2Mechanics/Room04Flammables/LedgeCrates") as Flammable
	var oil := _node("Tier2Mechanics/Room04Flammables/LedgeOilBarrel") as OilBarrel
	var log := {"boom": 0, "hits": 0}
	oil.explosion.exploded.connect(func(_c: Vector3, hits: int) -> void:
		log["boom"] = 1
		log["hits"] = hits)
	_teleport(Vector3(273.2, 8.42, 22.6), Vector3.LEFT)
	await _frames(20)
	var hp := _player.health.current_health
	crates.ignite(_player)
	await _wait_until(func() -> bool: return int(log["boom"]) == 1, 300)
	await _frames(5)
	_check(int(log["boom"]) == 1 and _player.health.current_health < hp, "chồng thùng cháy lan sang thùng dầu: nổ, player đứng gần mất %d máu" % (hp - _player.health.current_health))
	await _wait_until(func() -> bool: return crates.is_burned, 400)
	await _frames(70)
	_teleport(Vector3(270, 8.42, 22.5), Vector3.FORWARD)
	await _frames(20)
	var passed := await _run_to(Vector3(270, 8.32, 12), 150)
	_check(passed, "thùng cháy rụi: đi bộ qua gờ đá phía tây (z %.1f)" % _player.global_position.z)


# ---------- 3. Dây leo cửa ra (nhớ vĩnh viễn) ----------

func _t_exit_vines() -> void:
	var exit_vines := _node("Tier2Mechanics/Room04Flammables/ExitVines") as Flammable
	_teleport(Vector3(282, 8.42, 14), Vector3.RIGHT)
	await _frames(20)
	await _run_to(Vector3(292, 8.32, 14), 120)
	_check(_player.global_position.x < 288.0, "dây leo chặn cửa ra phía đông (x %.1f)" % _player.global_position.x)
	_teleport(Vector3(285.2, 8.42, 14), Vector3.RIGHT)
	await _frames(15)
	await _breath(40)
	await _wait_until(func() -> bool: return exit_vines.is_burned, 300)
	await _frames(40)
	_check(GameState.has_flag(&"level_3.t2_exit_vines"), "dây leo cửa ra cháy rụi: lưu cờ")
	var passed := await _run_to(Vector3(300, 8.32, 14), 150)
	_check(passed, "đi bộ qua cửa ra sang phòng 05 (x %.1f)" % _player.global_position.x)


# ---------- 4. Cực đoan (vật đặt riêng trên sàn Hub) ----------

func _t_extremes() -> void:
	_teleport(Vector3(270, 4.42, 60), Vector3.FORWARD)
	# Lan 0 m: không lan
	var a := _spawn(CRATE, Vector3(280, 4.32, 40), {"spread_radius": 0.0, "spread_delay": 0.2}) as Flammable
	var b := _spawn(CRATE, Vector3(283, 4.32, 40), {}) as Flammable
	a.ignite()
	await _frames(90)
	_check(a.is_burning and not b.is_burning and not b.is_burned, "lan 0 m: vật cạnh (cách 3 m) không bắt lửa")
	a.queue_free(); b.queue_free()
	# Lan 20 m: lan cả vật cách 15 m
	a = _spawn(CRATE, Vector3(280, 4.32, 40), {"spread_radius": 20.0, "spread_delay": 0.2}) as Flammable
	b = _spawn(CRATE, Vector3(280, 4.32, 55), {}) as Flammable
	a.ignite()
	await _frames(40)
	_check(b.is_burning, "lan 20 m: vật cách 15 m bắt lửa")
	a.queue_free(); b.queue_free()
	# Trễ lan 0 s và 2,5 s (thùng cháy 3 s)
	for delay: float in [0.0, 2.5]:
		a = _spawn(CRATE, Vector3(280, 4.32, 40), {"spread_delay": delay}) as Flammable
		b = _spawn(CRATE, Vector3(282.5, 4.32, 40), {}) as Flammable
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
	a = _spawn(CRATE, Vector3(280, 4.32, 40), {"spread_delay": 5.0}) as Flammable
	b = _spawn(CRATE, Vector3(282.5, 4.32, 40), {}) as Flammable
	a.ignite()
	await _frames(400)
	_check(a.is_burned and not b.is_burning and not b.is_burned, "trễ lan 5 s (cháy 3 s): rụi trước khi kịp lan")
	a.queue_free(); b.queue_free()
	await _frames(5)


# ---------- 5. Tường nứt ----------

func _t_cracked_wall() -> void:
	var wall := _node("Tier2Mechanics/IceCaveWall") as CrackedWall
	# Chém thật và phun lửa thật: không vỡ
	_teleport(Vector3(318.2, 8.42, 14), Vector3.RIGHT)
	await _frames(15)
	for _i: int in range(3):
		await _tap(&"attack")
		await _frames(20)
	await _breath(30)
	await _frames(30)
	_check(not wall.is_broken, "chém, phun lửa vào tường nứt: không vỡ")
	await _run_to(Vector3(326, 8.32, 14), 100)
	_check(_player.global_position.x < 320.0, "tường nứt chặn lối sang Hang băng (x %.1f)" % _player.global_position.x)
	# Slime Dung Nham tự nổ cạnh tường
	_teleport(Vector3(316.5, 8.42, 14), Vector3.RIGHT)
	var slime := SLIME.instantiate() as LavaSlime
	slime.position = Vector3(318.6, 8.32, 15.5)
	_level.add_child(slime)
	var boom := await _wait_until(func() -> bool: return slime == null or not is_instance_valid(slime) or slime.has_exploded, 400)
	await _frames(40)
	_check(boom and wall.is_broken and GameState.has_flag(&"level_3.t2_ice_cave_wall"), "Slime tự nổ cạnh tường: tường vỡ, lưu cờ")
	_player.health.heal_full()
	_teleport(Vector3(316.5, 8.42, 14), Vector3.RIGHT)
	await _frames(20)
	var passed := await _run_to(Vector3(334, 8.32, 14), 200)
	_check(passed, "tường vỡ: đi bộ sang Hang băng (x %.1f)" % _player.global_position.x)
	# Thùng dầu nổ cạnh một tường nứt khác (đặt riêng) cũng phá được
	var wall2 := _spawn(WALL, Vector3(280, 4.32, 40), {}) as CrackedWall
	var oil := _spawn(OIL, Vector3(281.5, 4.32, 41.5), {}) as OilBarrel
	_teleport(Vector3(270, 4.42, 60), Vector3.FORWARD)
	await _frames(5)
	oil.ignite()
	await _wait_until(func() -> bool: return wall2.is_broken, 200)
	_check(wall2.is_broken, "thùng dầu nổ cạnh tường nứt: tường vỡ")
	wall2.queue_free()


func _t_reload() -> void:
	_level.queue_free()
	await _frames(5)
	await _load_level()
	var wall := _node("Tier2Mechanics/IceCaveWall") as CrackedWall
	var exit_vines := _node("Tier2Mechanics/Room04Flammables/ExitVines") as Flammable
	var bridge := _node("Tier2Mechanics/Room04Flammables/RopeBridge") as Flammable
	_check(wall.is_broken and exit_vines.is_burned and not exit_vines.is_visible_in_tree() and not bridge.is_burned,
			"nạp lại map: tường vẫn vỡ, dây leo cửa ra vẫn mất, cầu (không cờ) còn nguyên")


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
