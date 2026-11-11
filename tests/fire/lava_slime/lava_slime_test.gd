extends Node3D
## Test Slime Dung Nham (LavaSlime) bằng hành vi thật: vật lý, va chạm, phím phun lửa / thổi gió của player thật.
## 1. Nạp: đủ 6 clip trỏ đúng xương, kháng lửa (hệ số 0), không bắt lửa.
## 2. Nảy: đi từng bước (có lúc đứng yên giữa các bước), mỗi bước khoảng hop_distance, tiến về player.
## 3. Châm ngòi rồi nổ: vào attack_range thì đứng lại châm, nổ sau đúng fuse_time; player mất máu, bắt lửa,
##    bị đẩy ra xa; slime chết, ẩn hình.
## 4. Kiểu Creeper: player chạy ra ngoài fuse_cancel_range thì ngòi tắt (không nổ), ngòi tụt dần về 0;
##    quay lại ngay khi ngòi còn thì nổ sớm hơn fuse_time.
## 5. Bị giết trước khi nổ: không nổ, player không mất máu.
## 6. Nổ trúng cả quái khác đứng gần.
## 7. Kháng lửa: phun lửa thật không mất máu. Sợ gió: thổi gió thật lúc châm ngòi -> ngắt ngòi, văng xa hơn quái thường.
## 8. Cực đoan: ngòi 0,05 s / 5 s, bán kính nổ 0,1 / 12 m, bước nảy 0 m / 3 s.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/fire/lava_slime/lava_slime_test.tscn
## (bỏ --headless, thêm -- --capture để chụp ảnh)

const SLIME_SCENE: PackedScene = preload("res://entities/enemies/volcano/lava_slime/lava_slime.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/_base/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const WIND_BLAST: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const DATA: LavaSlimeData = preload("res://resources/enemies/volcano/lava_slime/lava_slime.tres")
const PLAYER_HOME := Vector3(0, 0, 8)
const CLIPS: Array[StringName] = [&"Idle", &"Walk", &"Swell", &"Deflate", &"Hurt", &"Death"]

var _failed: int = 0
var _checks: int = 0
var _player: Player
var _spawned: Array[Node] = []


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	_build_arena()
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(SWORD)
	GameState.unlock_ability(WIND_BLAST)
	GameState.unlock_ability(FLAME_BREATH)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_HOME
	add_child(_player)
	await _frames(10)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_load()
	await _t_hop()
	await _t_explode()
	await _t_creeper_cancel()
	await _t_killed_first()
	await _t_hits_enemies()
	await _t_fire_resist()
	await _t_wind()
	await _t_extreme()
	print("LAVA SLIME RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- Các mục ----------

func _t_load() -> void:
	_reset_player(PLAYER_HOME)
	var s := await _spawn(Vector3(0, 0, -10), null, true)
	var anim := s.get_node("AnimationPlayer") as AnimationPlayer
	var sk := s.get_node("Model/Visual/LavaSlimeModel/LavaSlimeModel/Rig/Skeleton3D") as Skeleton3D
	var has_all := CLIPS.all(func(c: StringName) -> bool: return anim.has_animation(c))
	var bad := 0
	for c: StringName in CLIPS:
		if not anim.has_animation(c):
			continue
		var a := anim.get_animation(c)
		for t: int in range(a.get_track_count()):
			var path := a.track_get_path(t)
			var node := anim.get_node(anim.root_node).get_node_or_null(NodePath(str(path).get_slice(":", 0)))
			if node == null or sk == null or sk.find_bone(path.get_concatenated_subnames()) < 0:
				bad += 1
	_check(has_all and bad == 0, "đủ 6 clip, mọi track trỏ đúng xương (%d sai)" % bad)
	var burn := s.get_node(^"BurnableComponent") as BurnableComponent
	burn.ignite(_player)
	await _frames(2)
	_check(is_zero_approx(s.hurtbox.resistances.get(DamageInfo.Type.FIRE, 1.0)) and not burn.is_burning(),
			"kháng lửa: hệ số 0, châm lửa không cháy")
	await _capture("slime_idle.png", s.global_position)
	await _cleanup()


func _t_hop() -> void:
	_reset_player(PLAYER_HOME)
	var data := _data_copy()
	data.attack_range = 0.0
	data.fuse_cancel_range = 0.0
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -8), data)
	# Ghi đoạn di chuyển: tách bước theo những lúc đứng yên
	var steps: Array[float] = []
	var moving := false
	var start := Vector3.ZERO
	var still_frames := 0
	var d0 := _flat(s.global_position, _player.global_position)
	var captured := false
	for i: int in range(150):
		await get_tree().physics_frame
		var speed := Vector2(s.velocity.x, s.velocity.z).length()
		if speed > 0.05 and not moving:
			moving = true
			start = s.global_position
		elif speed <= 0.05 and moving:
			moving = false
			steps.append(_flat(s.global_position, start))
		if speed <= 0.05:
			still_frames += 1
		if i == 40 and not captured:
			captured = true
			await _capture("slime_hop.png", s.global_position)
	var d1 := _flat(s.global_position, _player.global_position)
	var avg := 0.0
	for x: float in steps:
		avg += x
	avg = avg / steps.size() if steps.size() > 0 else 0.0
	_check(steps.size() >= 3 and still_frames > 20, "đi từng bước nảy: %d bước, %d frame đứng yên giữa bước" % [steps.size(), still_frames])
	_check(absf(avg - data.hop_distance) < 0.35, "mỗi bước %.2f m (đặt %.2f m)" % [avg, data.hop_distance])
	_check(d1 < d0 - 3.0, "tiến về player: %.1f → %.1f m" % [d0, d1])
	await _cleanup()


func _t_explode() -> void:
	_reset_player(PLAYER_HOME)
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), null)
	var log := {"start": -1.0, "boom": -1.0, "hits": 0}
	var t0 := Time.get_ticks_msec()
	s.fuse_started.connect(func() -> void: log["start"] = (Time.get_ticks_msec() - t0) / 1000.0)
	s.exploded.connect(func(_c: Vector3, hits: int) -> void:
		log["boom"] = (Time.get_ticks_msec() - t0) / 1000.0
		log["hits"] = hits)
	var hp := _player.health.current_health
	await _wait_until(func() -> bool: return float(log["start"]) >= 0.0, 400)
	var dist_at_fuse := _flat(s.global_position, _player.global_position)
	var p_before := _player.global_position
	await _frames(40)
	await _capture("slime_swell.png", s.global_position)
	await _wait_until(func() -> bool: return float(log["boom"]) >= 0.0, 200)
	await _frames(3)
	var lost := hp - _player.health.current_health
	var burn := _player.get_node(^"BurnableComponent") as BurnableComponent
	var fuse_len := float(log["boom"]) - float(log["start"])
	await _frames(15)
	var pushed := _flat(_player.global_position, p_before)
	_check(dist_at_fuse <= DATA.attack_range + 0.3, "dừng lại châm ngòi khi cách %.2f m (tầm %.1f m)" % [dist_at_fuse, DATA.attack_range])
	_check(absf(fuse_len - DATA.fuse_time) < 0.15, "nổ sau %.2f s châm ngòi (đặt %.2f s)" % [fuse_len, DATA.fuse_time])
	# Player mất đúng 1 tim mỗi đòn (fixed_damage_per_hit), nên chỉ đòi >= 1
	_check(lost >= 1 and burn.is_burning(), "player mất %d tim, bắt lửa (%s)" % [lost, burn.is_burning()])
	_check(pushed > 0.8, "player bị đẩy %.2f m" % pushed)
	_check(s.is_dead() and not s.model.visible and int(log["hits"]) >= 1, "slime chết sau khi nổ, ẩn hình (trúng %d)" % log["hits"])
	burn.extinguish()
	await _cleanup()


func _t_creeper_cancel() -> void:
	_reset_player(PLAYER_HOME)
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -1.8), null)
	var log := {"cancel": 0, "boom": 0}
	s.fuse_cancelled.connect(func() -> void: log["cancel"] = int(log["cancel"]) + 1)
	s.exploded.connect(func(_c: Vector3, _h: int) -> void: log["boom"] = int(log["boom"]) + 1)
	await _wait_until(func() -> bool: return s.is_fusing(), 120)
	await _frames(45)
	var fuse_mid := s.fuse
	# Chạy ra xa ngoài fuse_cancel_range
	_reset_player(PLAYER_HOME + Vector3(0, 0, 8))
	await _frames(5)
	var fuse_after := s.fuse
	await _frames(20)
	var fuse_later := s.fuse
	_check(int(log["cancel"]) == 1 and int(log["boom"]) == 0, "player chạy xa: tắt ngòi, không nổ (huỷ %d, nổ %d)" % [log["cancel"], log["boom"]])
	_check(fuse_after > 0.2 and fuse_later < fuse_after, "ngòi tụt dần chứ không về 0 ngay (%.2f → %.2f → %.2f)" % [fuse_mid, fuse_after, fuse_later])
	# Quay lại ngay: nổ sớm hơn fuse_time
	var left := s.fuse
	var t0 := Time.get_ticks_msec()
	_reset_player(s.global_position + Vector3(0, 0, 1.2))
	await _wait_until(func() -> bool: return int(log["boom"]) > 0, 200)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	_check(int(log["boom"]) == 1 and took < DATA.fuse_time - 0.2, "quay lại khi ngòi còn %.2f: nổ sau %.2f s (< %.2f s)" % [left, took, DATA.fuse_time])
	var burn := _player.get_node(^"BurnableComponent") as BurnableComponent
	burn.extinguish()
	await _cleanup()
	# Không ở lại: ngòi về 0 trong fuse_decay_time
	_reset_player(PLAYER_HOME)
	var s2 := await _spawn(PLAYER_HOME + Vector3(0, 0, -1.8), null)
	await _wait_until(func() -> bool: return s2.is_fusing(), 120)
	await _frames(60)
	_reset_player(PLAYER_HOME + Vector3(0, 0, 8))
	await _frames(int(DATA.fuse_decay_time * 60.0) + 10)
	_check(is_zero_approx(s2.fuse) and not s2.is_dead(), "để yên %.1f s: ngòi về 0, slime còn sống" % DATA.fuse_decay_time)
	await _cleanup()


func _t_killed_first() -> void:
	_reset_player(PLAYER_HOME)
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -1.8), null)
	var log := {"boom": 0, "died": 0}
	s.exploded.connect(func(_c: Vector3, _h: int) -> void: log["boom"] = 1)
	s.died.connect(func(_e: Enemy) -> void: log["died"] = 1)
	await _wait_until(func() -> bool: return s.is_fusing(), 120)
	await _frames(30)
	var hp := _player.health.current_health
	s.health.take_damage(s.health.current_health)
	await _frames(int(DATA.fuse_time * 60.0) + 20)
	_check(int(log["died"]) == 1 and int(log["boom"]) == 0 and _player.health.current_health == hp,
			"bị giết lúc đang châm ngòi: không nổ, player không mất máu")
	await _cleanup()


func _t_hits_enemies() -> void:
	_reset_player(PLAYER_HOME)
	var dummy := ENEMY_SCENE.instantiate() as Enemy
	dummy.position = Vector3(1.5, 0, -10)
	add_child(dummy)
	_spawned.append(dummy)
	var s := await _spawn(Vector3(0, 0, -10), null, true)
	await _frames(5)
	var hp := dummy.health.current_health
	var hits := s.explosion.explode(s)
	await _frames(3)
	_check(hits >= 1 and dummy.health.current_health < hp, "nổ trúng quái khác đứng gần (%d → %d máu)" % [hp, dummy.health.current_health])
	await _cleanup()


func _t_fire_resist() -> void:
	_reset_player(PLAYER_HOME)
	var data := _data_copy()
	data.attack_range = 0.0
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -2.4), data, true)
	var hp := s.health.current_health
	_player.energy.set_current(_player.energy.get_max())
	await _frames(2)
	_aim_mouse_at(s.global_position + Vector3.UP * 0.4)
	Input.action_press(&"skill_fire")
	await _frames(60)
	Input.action_release(&"skill_fire")
	await _frames(5)
	_check(s.health.current_health == hp, "phun lửa thật: không mất máu (%d → %d)" % [hp, s.health.current_health])
	await _cleanup()


func _t_wind() -> void:
	_reset_player(PLAYER_HOME)
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -1.9), null)
	var log := {"cancel": 0, "boom": 0}
	s.fuse_cancelled.connect(func() -> void: log["cancel"] = int(log["cancel"]) + 1)
	s.exploded.connect(func(_c: Vector3, _h: int) -> void: log["boom"] = int(log["boom"]) + 1)
	await _wait_until(func() -> bool: return s.is_fusing(), 120)
	await _frames(20)
	var p0 := s.global_position
	_player.energy.set_current(_player.energy.get_max())
	_aim_mouse_at(s.global_position + Vector3.UP * 0.4)
	await _tap(&"skill")
	await _frames(40)
	var pushed := _flat(s.global_position, p0)
	_check(int(log["cancel"]) >= 1, "thổi gió lúc châm ngòi: ngắt ngòi (huỷ %d, nổ %d)" % [log["cancel"], log["boom"]])
	await _cleanup()
	# So với quái thường cùng khoảng cách
	_reset_player(PLAYER_HOME)
	await _frames(70)
	var dummy := ENEMY_SCENE.instantiate() as Enemy
	dummy.position = PLAYER_HOME + Vector3(0, 0, -1.9)
	add_child(dummy)
	_spawned.append(dummy)
	await _frames(10)
	var d0 := dummy.global_position
	_player.energy.set_current(_player.energy.get_max())
	_aim_mouse_at(dummy.global_position + Vector3.UP)
	await _tap(&"skill")
	await _frames(40)
	var dummy_pushed := _flat(dummy.global_position, d0)
	_check(pushed > dummy_pushed * 1.3, "bị gió đẩy xa hơn quái thường (%.2f m so với %.2f m)" % [pushed, dummy_pushed])
	await _cleanup()


func _t_extreme() -> void:
	# Ngòi 0,05 s: vào tầm là nổ gần như ngay
	var fast := _data_copy()
	fast.fuse_time = 0.05
	var took := await _time_to_boom(fast)
	_check(took >= 0.0 and took < 0.2, "ngòi 0,05 s: nổ sau %.2f s" % took)
	# Ngòi 5 s
	var slow := _data_copy()
	slow.fuse_time = 5.0
	took = await _time_to_boom(slow)
	_check(absf(took - 5.0) < 0.2, "ngòi 5 s: nổ sau %.2f s" % took)
	# Bán kính 0,1 m: player đứng cách 1,8 m không trúng
	var tiny := _data_copy()
	tiny.explosion_radius = 0.1
	var lost := await _boom_damage(tiny, 1.8)
	_check(lost == 0, "bán kính 0,1 m: player cách 1,8 m không mất máu (%d)" % lost)
	# Bán kính 12 m: player cách 10 m vẫn trúng (nổ tay, slime đứng yên)
	var huge := _data_copy()
	huge.explosion_radius = 12.0
	lost = await _boom_damage(huge, 10.0)
	_check(lost >= 1, "bán kính 12 m: player cách 10 m mất %d tim" % lost)
	# Bước nảy 0 m: không dịch chuyển, không lỗi
	var still := _data_copy()
	still.hop_distance = 0.0
	still.attack_range = 0.0
	_reset_player(PLAYER_HOME)
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -6), still)
	var p0 := s.global_position
	await _frames(90)
	_check(_flat(s.global_position, p0) < 0.1, "bước nảy 0 m: đứng yên (%.2f m)" % _flat(s.global_position, p0))
	await _cleanup()
	# Mỗi bước 3 s: vẫn đi đúng quãng mỗi bước
	var lazy := _data_copy()
	lazy.hop_interval = 3.0
	lazy.attack_range = 0.0
	_reset_player(PLAYER_HOME)
	s = await _spawn(PLAYER_HOME + Vector3(0, 0, -8), lazy)
	p0 = s.global_position
	await _frames(185)
	var moved := _flat(s.global_position, p0)
	_check(absf(moved - lazy.hop_distance) < 0.35, "mỗi bước 3 s: 3 s đi %.2f m (một bước %.2f m)" % [moved, lazy.hop_distance])
	await _cleanup()


# ---------- Tiện ích ----------

## Thời gian từ lúc châm ngòi tới lúc nổ (s); -1 nếu không nổ
func _time_to_boom(data: LavaSlimeData) -> float:
	_reset_player(PLAYER_HOME)
	# Đứng ngoài tầm châm ngòi để kịp nối signal trước khi slime nảy vào
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -4.0), data)
	var log := {"start": -1, "boom": -1}
	s.fuse_started.connect(func() -> void: log["start"] = Time.get_ticks_msec())
	s.exploded.connect(func(_c: Vector3, _h: int) -> void: log["boom"] = Time.get_ticks_msec())
	await _wait_until(func() -> bool: return int(log["boom"]) >= 0, int(data.fuse_time * 60.0) + 300)
	var took := (int(log["boom"]) - int(log["start"])) / 1000.0 if int(log["boom"]) >= 0 and int(log["start"]) >= 0 else -1.0
	(_player.get_node(^"BurnableComponent") as BurnableComponent).extinguish()
	await _cleanup()
	return took


## Máu player mất khi slime đứng cách dist m nổ (gọi nổ trực tiếp)
func _boom_damage(data: LavaSlimeData, dist: float) -> int:
	_reset_player(PLAYER_HOME)
	var s := await _spawn(PLAYER_HOME + Vector3(0, 0, -dist), data, true)
	await _frames(5)
	var hp := _player.health.current_health
	s.explode()
	await _frames(3)
	var lost := hp - _player.health.current_health
	(_player.get_node(^"BurnableComponent") as BurnableComponent).extinguish()
	await _cleanup()
	# Hết bất tử sau đòn trước khi đo tiếp
	await _frames(70)
	return lost


func _spawn(pos: Vector3, data: LavaSlimeData = null, freeze_ai: bool = false) -> LavaSlime:
	var s := SLIME_SCENE.instantiate() as LavaSlime
	s.data = data if data else _data_copy()
	s.position = pos
	add_child(s)
	_spawned.append(s)
	await _frames(3)
	if freeze_ai:
		s.sensor.radius = 0.0
		s.forget_target()
		s.state_machine.transition_to(&"Idle")
	return s


func _data_copy() -> LavaSlimeData:
	return DATA.duplicate() as LavaSlimeData


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	for a: StringName in [&"attack", &"skill", &"skill_fire"]:
		Input.action_release(a)
	await _frames(2)


func _reset_player(pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> void:
	_player.teleport(pos + Vector3.UP * 0.05, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()
	_player.health.heal_full()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(70, 1, 70), Color(0.32, 0.17, 0.12))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	add_child(light)


func _box(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	add_child(body)
	return body


## Có cửa sổ: player ngắm theo chuột thật, nên đưa chuột vào mục tiêu trước khi bấm (headless dùng hướng mặt)
func _aim_mouse_at(world: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(world))


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for i: int in range(max_frames):
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


## Có cửa sổ + "--capture": camera nhìn chéo vào slime rồi chụp
func _capture(file: String, focus: Vector3) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = focus + Vector3(2.4, 2.0, 2.4)
	cam.look_at(focus + Vector3.UP * 0.4)
	cam.fov = 45.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/lava_slime/" + file)
	cam.queue_free()
	(_player.get_node("CameraRig/Camera3D") as Camera3D).make_current()
