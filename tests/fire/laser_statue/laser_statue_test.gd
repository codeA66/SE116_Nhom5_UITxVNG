extends Node
## Test tượng laze (LaserStatue) bằng va chạm, raycast và input thật, đặt riêng trên sàn Hub tier 2:
## 1. Ngoài tầm: không ngắm.
## 2. Đứng yên: ngắm → khóa → quét trúng, mất đúng damage; bắt đầu quét sau aim_time + lock_time;
##    đường tia nằm dọc hướng tượng → player, dài đúng line_length, tâm tại chỗ player.
## 3. Lúc ngắm: tâm đường tia đuổi theo player không nhanh hơn track_speed.
## 4. Chạy ngang ra khỏi đường tia (input thật) lúc khóa: né được. Lùi dọc theo đường thì vẫn trúng.
## 5. Tường chắn giữa tượng và player: không ngắm, không bắn.
## 6. Thông số cực đoan: ngắm rất nhanh + quét 0,05 s + đường rộng 3 m vẫn trúng; tầm rất nhỏ thì không ngắm.
## 7. Đánh bằng phím attack thật: mỗi đòn trừ máu + nháy trắng; hết máu thì vỡ, sụp, không bắn nữa.
## 8. Máu 1: một đòn là vỡ. Đã có cờ persistent_id: vào map tượng đã vỡ sẵn.
## Chạy: godot --path . res://tests/fire/laser_statue/laser_statue_test.tscn [-- --capture]

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/tier_2/tier_2.tscn")
const STATUE_SCENE: PackedScene = preload("res://objects/combat/hazards/laser_statue/laser_statue.tscn")
const DATA: LaserStatueData = preload("res://resources/combat/hazards/laser_statue.tres")
## Tượng ở mép tây Hub, mặt trước (+Z) quay về nam; player đứng phía nam
const STATUE_AT: Vector3 = Vector3(270, 4.32, 50)
const PLAYER_AT: Vector3 = Vector3(270, 4.42, 56)

var _player: Player
var _level: Node
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(150.0, true, true).timeout.connect(func() -> void:
		print("LASER STATUE RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.t2_hub_ambush")
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	await _t_out_of_range()
	await _t_stand_still()
	await _t_tracking()
	await _t_dodge()
	await _t_wall()
	await _t_extremes()
	await _t_destroy_by_attacks()
	await _t_one_hit_and_persist()
	print("LASER STATUE RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


## setup chạy trước khi thêm vào cảnh: nối signal trước khi tượng kịp ngắm
func _spawn(data: LaserStatueData = null, setup: Callable = Callable()) -> LaserStatue:
	var s := STATUE_SCENE.instantiate() as LaserStatue
	if data:
		s.data = data
	if setup.is_valid():
		setup.call(s)
	add_child(s)
	s.global_position = STATUE_AT
	await _frames(3)
	return s


func _t_out_of_range() -> void:
	_teleport(STATUE_AT + Vector3(0, 0.1, DATA.detect_range + 6.0))
	var s := await _spawn()
	var aimed := [false]
	s.aim_started.connect(func() -> void: aimed[0] = true)
	await _frames(120)
	_check(not aimed[0] and s.state_machine.current_state.name == &"StatueIdle", "ngoài tầm %.0f m: tượng không ngắm" % (DATA.detect_range + 6.0))
	s.queue_free()


func _t_stand_still() -> void:
	_teleport(PLAYER_AT)
	_full_health()
	var hp := _player.health.current_health
	var t0 := Time.get_ticks_msec()
	var log := {"aim": -1.0, "fire": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO}
	var s := await _spawn(null, func(st: LaserStatue) -> void:
		st.aim_started.connect(func() -> void: log["aim"] = (Time.get_ticks_msec() - t0) / 1000.0)
		st.fired.connect(func(a: Vector3, b: Vector3) -> void:
			log["fire"] = (Time.get_ticks_msec() - t0) / 1000.0
			log["from"] = a
			log["to"] = b))
	await _frames(30)
	await _capture("aim.png")
	await _wait_until(func() -> bool: return float(log["fire"]) >= 0.0, 300)
	await _frames(int(DATA.sweep_time * 0.6 * Engine.physics_ticks_per_second))
	await _capture("fire.png")
	await _frames(int(DATA.sweep_time * Engine.physics_ticks_per_second) + 5)
	var line: Vector3 = (log["to"] as Vector3) - (log["from"] as Vector3)
	var to_player := PLAYER_AT - STATUE_AT
	var mid: Vector3 = ((log["to"] as Vector3) + (log["from"] as Vector3)) * 0.5
	_check(absf(line.length() - DATA.line_length) < 0.05 and line.normalized().dot(to_player.normalized()) > 0.99,
		"đường tia dài %.2f m (đặt %.1f), dọc hướng tượng → player, quét từ phía tượng ra xa" % [line.length(), DATA.line_length])
	_check(Vector2(mid.x - PLAYER_AT.x, mid.z - PLAYER_AT.z).length() < 0.2, "tâm đường tia tại chỗ player đứng")
	var lost := hp - _player.health.current_health
	var lead := float(log["fire"]) - float(log["aim"])
	_check(float(log["aim"]) >= 0.0, "player trong tầm, không bị che: tượng ngắm")
	_check(lost == DATA.damage, "đứng yên: trúng tia, mất %d máu (đặt %d)" % [lost, DATA.damage])
	_check(absf(lead - (DATA.aim_time + DATA.lock_time)) < 0.15, "bắn sau %.2f s kể từ lúc ngắm (đặt %.2f + %.2f)" % [lead, DATA.aim_time, DATA.lock_time])
	s.queue_free()
	_full_health()
	await _frames(60)


func _t_tracking() -> void:
	_teleport(PLAYER_AT)
	var s := await _spawn()
	await _wait_until(func() -> bool: return s.state_machine.current_state.name == &"StatueAim", 120)
	await _frames(5)
	# Dời player 4 m sang đông: điểm ngắm phải đuổi với tốc độ track_speed, không nhảy theo ngay
	var before := s.aim_point
	_player.global_position = PLAYER_AT + Vector3(4, 0, 0)
	await _frames(15)
	var moved := Vector2(s.aim_point.x - before.x, s.aim_point.z - before.z).length()
	var max_move := DATA.track_speed * 15.0 / Engine.physics_ticks_per_second
	_check(moved > 0.1 and moved <= max_move + 0.05, "điểm ngắm đuổi theo player %.2f m trong 15 frame (tối đa %.2f)" % [moved, max_move])
	s.queue_free()
	await _frames(60)


func _t_dodge() -> void:
	_teleport(PLAYER_AT)
	_full_health()
	var hp := _player.health.current_health
	var s := await _spawn()
	var locked := [false]
	var fired := [false]
	s.locked.connect(func(_p: Vector3) -> void: locked[0] = true)
	s.fired.connect(func(_a: Vector3, _b: Vector3) -> void: fired[0] = true)
	await _wait_until(func() -> bool: return locked[0], 300)
	# Chạy thật sang đông trong lúc khóa: rời khỏi đường tia nằm dọc
	await _run(Vector3.RIGHT, DATA.lock_time + DATA.sweep_time + 0.2)
	await _wait_until(func() -> bool: return fired[0], 60)
	await _frames(int(DATA.sweep_time * Engine.physics_ticks_per_second) + 10)
	_check(fired[0] and _player.health.current_health == hp, "chạy ngang ra khỏi đường tia lúc khóa: né được (máu %d → %d)" % [hp, _player.health.current_health])
	s.queue_free()
	await _frames(60)
	# Lùi dọc theo đường tia (ra xa tượng) trong lúc khóa: vẫn nằm trên đường nên vẫn trúng
	_teleport(PLAYER_AT)
	_full_health()
	hp = _player.health.current_health
	locked[0] = false
	s = await _spawn()
	s.locked.connect(func(_p: Vector3) -> void: locked[0] = true)
	await _wait_until(func() -> bool: return locked[0], 300)
	await _run(Vector3.BACK, DATA.lock_time)
	await _frames(int(DATA.sweep_time * Engine.physics_ticks_per_second) + 10)
	_check(_player.health.current_health < hp, "lùi dọc theo đường tia: vẫn trúng (máu %d → %d)" % [hp, _player.health.current_health])
	s.queue_free()
	await _frames(60)


func _t_wall() -> void:
	_teleport(PLAYER_AT)
	_full_health()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 8, 0.6)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = STATUE_AT + Vector3(0, 2, 3)
	await _frames(3)
	var hp := _player.health.current_health
	var s := await _spawn()
	var aimed := [false]
	s.aim_started.connect(func() -> void: aimed[0] = true)
	await _frames(int((DATA.aim_time + DATA.lock_time + DATA.sweep_time + 0.5) * Engine.physics_ticks_per_second))
	_check(not aimed[0] and _player.health.current_health == hp, "tường chắn giữa tượng và player: không ngắm, không bắn")
	s.queue_free()
	wall.queue_free()
	await _frames(30)


func _t_extremes() -> void:
	# Ngắm rất nhanh, tia rất to
	var fast := DATA.duplicate() as LaserStatueData
	fast.aim_time = 0.1
	fast.lock_time = 0.05
	fast.sweep_time = 0.05
	fast.line_width = 3.0
	fast.track_speed = 40.0
	_teleport(PLAYER_AT)
	_full_health()
	var hp := _player.health.current_health
	var s := await _spawn(fast)
	var fired := [false]
	s.fired.connect(func(_a: Vector3, _b: Vector3) -> void: fired[0] = true)
	await _wait_until(func() -> bool: return fired[0], 120)
	await _frames(10)
	_check(fired[0] and _player.health.current_health < hp, "ngắm 0,1 s, quét 0,05 s, đường rộng 3 m: vẫn trúng")
	s.queue_free()
	_full_health()
	await _frames(60)
	# Tầm rất nhỏ
	var tiny := DATA.duplicate() as LaserStatueData
	tiny.detect_range = 2.0
	_teleport(PLAYER_AT)
	s = await _spawn(tiny)
	var aimed := [false]
	s.aim_started.connect(func() -> void: aimed[0] = true)
	await _frames(90)
	_check(not aimed[0], "tầm 2 m, player cách 6 m: không ngắm")
	s.queue_free()


## Máu đầy trước mỗi phép thử có trúng đòn (level nạp lại máu từ tiến trình sau khi spawn)
func _full_health() -> void:
	_player.health.max_health = 9999
	_player.health.heal_full()


func _t_destroy_by_attacks() -> void:
	# Tượng ngắm rất lâu để player đánh mà không bị tia hất ra
	var slow := DATA.duplicate() as LaserStatueData
	slow.aim_time = 30.0
	_teleport(STATUE_AT + Vector3(0, 0.1, 1.5))
	_full_health()
	var s := await _spawn(slow)
	var log := {"hits": 0, "flash": false, "destroyed": false, "fired": false}
	s.hurtbox.hurt.connect(func(_i: DamageInfo, _d: int) -> void:
		log["hits"] = int(log["hits"]) + 1
		var body := s.get_node("Model").find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
		log["flash"] = bool(log["flash"]) or body.material_overlay != null)
	s.destroyed.connect(func() -> void: log["destroyed"] = true)
	s.fired.connect(func(_a: Vector3, _b: Vector3) -> void: log["fired"] = true)
	await _run(Vector3.FORWARD, 0.15)
	for _i: int in range(40):
		if bool(log["destroyed"]):
			break
		_player.global_position = STATUE_AT + Vector3(0, 0.1, 1.5)
		_aim_mouse_at(STATUE_AT + Vector3.UP * 1.5)
		await _tap(&"attack")
		await _frames(24)
	_check(int(log["hits"]) == DATA.max_health, "đánh thật bằng phím attack: %d đòn trúng (máu %d)" % [log["hits"], DATA.max_health])
	_check(bool(log["flash"]), "trúng đòn: tượng nháy trắng")
	_check(bool(log["destroyed"]) and s.is_destroyed() and s.state_machine.current_state.name == &"StatueDead", "hết máu: tượng vỡ (state StatueDead)")
	await _frames(int(DATA.crumble_time * Engine.physics_ticks_per_second) + 10)
	var model := s.get_node("Model") as Node3D
	_check(model.scale.y < 0.3, "vỡ: model sụp xuống (scale y %.2f)" % model.scale.y)
	await _capture("destroyed.png")
	# Đứng ngay trước tượng đã vỡ đủ lâu cho một vòng ngắm thường: không bắn
	_teleport(PLAYER_AT)
	await _frames(int((DATA.aim_time + DATA.lock_time + DATA.sweep_time + 0.5) * Engine.physics_ticks_per_second))
	_check(not bool(log["fired"]) and not s.hurtbox.monitorable, "tượng đã vỡ: không bắn, không nhận đòn nữa")
	s.queue_free()
	await _frames(30)


func _t_one_hit_and_persist() -> void:
	var fragile := DATA.duplicate() as LaserStatueData
	fragile.max_health = 1
	fragile.aim_time = 30.0
	_teleport(STATUE_AT + Vector3(0, 0.1, 1.5))
	var s := await _spawn(fragile, func(st: LaserStatue) -> void: st.persistent_id = &"test.laser_statue_broken")
	await _run(Vector3.FORWARD, 0.15)
	for _i: int in range(10):
		if s.is_destroyed():
			break
		_player.global_position = STATUE_AT + Vector3(0, 0.1, 1.5)
		_aim_mouse_at(STATUE_AT + Vector3.UP * 1.5)
		await _tap(&"attack")
		await _frames(24)
	_check(s.is_destroyed() and s.health.current_health == 0, "máu 1: một đòn là vỡ")
	_check(GameState.has_flag(&"test.laser_statue_broken"), "vỡ: lưu cờ persistent_id")
	s.queue_free()
	await _frames(10)
	# Vào lại: có cờ thì tượng đã vỡ sẵn, sụp ngay
	_teleport(PLAYER_AT)
	var again := await _spawn(DATA.duplicate() as LaserStatueData, func(st: LaserStatue) -> void: st.persistent_id = &"test.laser_statue_broken")
	await _frames(5)
	_check(again.state_machine.current_state.name == &"StatueDead" and (again.get_node("Model") as Node3D).scale.y < 0.3,
		"có cờ persistent_id: vào map tượng đã vỡ sẵn")
	again.queue_free()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


## Có cửa sổ: player ngắm đòn theo chuột thật, nên đưa chuột vào mục tiêu trước khi bấm (headless dùng hướng mặt)
func _aim_mouse_at(world: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(world))


## Chạy bằng input thật theo hướng thế giới trong seconds giây
func _run(dir: Vector3, seconds: float) -> void:
	for _i: int in range(int(seconds * Engine.physics_ticks_per_second)):
		_press_towards(dir)
		await get_tree().physics_frame
	_release()


func _teleport(at: Vector3) -> void:
	_player.teleport(at)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/laser_statue")
	get_viewport().get_texture().get_image().save_png("res://output/laser_statue/" + file)


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		if cond.call():
			return true
		await get_tree().physics_frame
	return false


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
