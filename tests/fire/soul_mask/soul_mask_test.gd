extends Node3D
## Test Đầu Lửa (SoulMask) bằng hành vi thật: vật lý, va chạm, phím chém thật của player.
## 1. Nạp: model hiện, tên + máu 6, có hàm, miệng ở phía trước mặt, bay lơ lửng đúng độ cao.
## 2. Lượn vòng: sinh xa 12 m thì lại gần tới bán kính lượn rồi bay vòng quanh player.
## 3. Tụ lực rồi bắn: hàm há dần, vạch cảnh báo hiện; bắn đúng charge_time; player đứng trong đường bắn mất 1 máu.
## 4. Né: player bước ngang sau lúc khoá hướng thì không trúng. Tường chắn: tia dừng ở tường, player sau tường không trúng.
## 5. Đánh chết: chém thật đủ máu thì chết, tia tắt.
## 6. Cực đoan: tia rất rộng / rất hẹp, tụ lực 0 s, lock_time lớn hơn charge_time.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/fire/soul_mask/soul_mask_test.tscn
## (bỏ --headless, thêm -- --capture để chụp ảnh)

const MASK_SCENE: PackedScene = preload("res://entities/enemies/volcano/soul_mask/soul_mask.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const DATA: SoulMaskData = preload("res://resources/enemies/volcano/soul_mask/soul_mask.tres")

const PLAYER_HOME := Vector3(0, 0, 8)

var _failed: int = 0
var _checks: int = 0
var _player: Player
var _spawned: Array[Node] = []


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(180.0, true, true).timeout.connect(func() -> void:
		print("SOUL MASK RESULT: TIMEOUT")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	_build_arena()
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(SWORD)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_HOME
	add_child(_player)
	await _frames(10)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_load()
	await _t_orbit()
	await _t_charge_and_hit()
	await _t_dodge()
	await _t_wall()
	await _t_kill()
	await _t_extreme()
	print("SOUL MASK RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- Các mục ----------

func _t_load() -> void:
	_reset_player(PLAYER_HOME)
	var mask := await _spawn(Vector3(0, 0, 0), null, true)
	await _frames(90)
	var model := mask.get_node("Model/Visual/SoulMaskModel") as Node3D
	var jaw := mask.get_node_or_null(mask.jaw_path) as Node3D
	_check(model.is_visible_in_tree() and mask.data.display_name == "Đầu Lửa" and mask.health.max_health == 6, "nạp: model hiện, tên Đầu Lửa, máu 6")
	_check(jaw != null, "có node hàm Mask_Jaw")
	var model_root := mask.get_node("Model") as Node3D
	var muzzle_local := model_root.to_local(mask.muzzle_position())
	_check(muzzle_local.z > 0.1, "miệng nằm phía trước mặt (+Z, %.2f)" % muzzle_local.z)
	_check(absf(mask.global_position.y - DATA.hover.hover_height) < 0.15, "bay lơ lửng đúng độ cao %.1f m (đo %.2f)" % [DATA.hover.hover_height, mask.global_position.y])
	var eyes := mask.get_node("Model/Visual/SoulMaskModel/Mask_Eyes") as MeshInstance3D
	var cranium := mask.get_node("Model/Visual/SoulMaskModel/Mask_Cranium") as MeshInstance3D
	var eyes_z := model_root.to_local(eyes.global_transform * eyes.get_aabb().get_center()).z
	var cranium_z := model_root.to_local(cranium.global_transform * cranium.get_aabb().get_center()).z
	_check(eyes_z > cranium_z + 0.3, "mắt ở mặt trước, khối sọ phía sau (mắt z %.2f, sọ z %.2f)" % [eyes_z, cranium_z])
	mask.set_jaw(1.0, 0.0)
	await _capture("soul_mask_open.png", mask.global_position)
	mask.set_jaw(0.0, 0.0)
	await _capture("soul_mask_idle.png", mask.global_position)
	_cleanup()


func _t_orbit() -> void:
	var data := _data_copy()
	data.attack_cooldown = 999.0
	_reset_player(PLAYER_HOME)
	var mask := await _spawn(PLAYER_HOME + Vector3(0, 0, -12), data)
	mask.target = _player
	mask.start_attack_cooldown()
	mask.state_machine.transition_to(mask.chase_state)
	var reached := await _wait_until(func() -> bool: return _flat(mask.global_position, _player.global_position) <= data.orbit_radius + data.orbit_tolerance + 0.3, 400)
	_check(reached, "sinh xa 12 m: lại gần tới bán kính lượn %.0f m (%.2f m)" % [data.orbit_radius, _flat(mask.global_position, _player.global_position)])
	var prev := _angle_around_player(mask)
	var travelled := 0.0
	var min_d := INF
	var max_d := 0.0
	for i: int in range(240):
		await get_tree().physics_frame
		var a := _angle_around_player(mask)
		travelled += absf(wrapf(a - prev, -PI, PI))
		prev = a
		var d := _flat(mask.global_position, _player.global_position)
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
	_check(rad_to_deg(travelled) > 40.0, "lượn vòng quanh player: đi được %.0f độ trong 4 s" % rad_to_deg(travelled))
	_check(min_d > data.orbit_radius - data.orbit_tolerance - 1.0 and max_d < data.orbit_radius + data.orbit_tolerance + 1.0, "giữ bán kính lượn (%.1f – %.1f m)" % [min_d, max_d])
	_cleanup()


func _t_charge_and_hit() -> void:
	_reset_player(PLAYER_HOME)
	var mask := await _spawn(PLAYER_HOME + Vector3(0, 0, -7), null, true)
	var log := {"charge": -1, "fire": -1}
	var tick := [0]
	mask.charge_started.connect(func() -> void: log["charge"] = tick[0])
	mask.beam_fired.connect(func(_f: Vector3, _t: Vector3) -> void: log["fire"] = tick[0])
	var hp := _player.health.current_health
	mask.target = _player
	mask.state_machine.transition_to(mask.attack_state)
	var warn := mask.beam.get_node("Warn") as MeshInstance3D
	var warn_seen := false
	var warn_mat := warn.material_override as StandardMaterial3D
	# Khung có vạch cảnh báo trắng: đếm số lần bật trắng và khung trắng đầu tiên
	var white_on := 0
	var was_white := false
	var first_white := -1
	var jaw_at_fire := -1.0
	for i: int in range(150):
		await get_tree().physics_frame
		tick[0] += 1
		warn_seen = warn_seen or warn.visible
		var white := warn.visible and warn_mat.albedo_color.is_equal_approx(DATA.beam.lock_color)
		if white and not was_white:
			white_on += 1
			if first_white < 0:
				first_white = tick[0]
		was_white = white
		if log["fire"] >= 0 and jaw_at_fire < 0.0:
			jaw_at_fire = mask.jaw_angle()
		if log["fire"] >= 0 and tick[0] > log["fire"] + 20:
			break
	var expect := int(DATA.beam.charge_time * 60.0)
	_check(log["charge"] >= 0 and warn_seen, "tụ lực: phát charge_started, vạch cảnh báo hiện")
	_check(log["fire"] >= 0 and absi(log["fire"] - log["charge"] - expect) <= 3, "bắn sau đúng %.1f s tụ lực (%d khung, mong %d)" % [DATA.beam.charge_time, log["fire"] - log["charge"], expect])
	var lock_start: int = int(log["charge"]) + int((DATA.beam.charge_time - DATA.beam.lock_time) * 60.0)
	_check(white_on == DATA.beam.lock_flashes and first_white >= lock_start - 2 and first_white < log["fire"], "khoá hướng: vạch cảnh báo chớp trắng %d lần trước khi bắn (đặt %d, bắt đầu khung %d, khoá từ %d)" % [white_on, DATA.beam.lock_flashes, first_white, lock_start])
	_check(jaw_at_fire > deg_to_rad(DATA.beam.jaw_open_degrees) * 0.85, "lúc bắn hàm đã há gần hết (%.0f độ)" % rad_to_deg(jaw_at_fire))
	_check(_player.health.current_health == hp - 1, "player đứng trong đường bắn: mất 1 máu (%d → %d)" % [hp, _player.health.current_health])
	await _capture("soul_mask_beam.png", mask.global_position.lerp(_player.global_position, 0.5))
	await _frames(int((DATA.beam.fire_time + DATA.beam.recover_time) * 60.0) + 10)
	_check(not mask.beam.is_firing() and mask.jaw_angle() < 0.05, "bắn xong: tia tắt, hàm khép (%.0f độ)" % rad_to_deg(mask.jaw_angle()))
	_cleanup()


func _t_dodge() -> void:
	_reset_player(PLAYER_HOME)
	var mask := await _spawn(PLAYER_HOME + Vector3(0, 0, -7), null, true)
	var hp := _player.health.current_health
	mask.target = _player
	mask.state_machine.transition_to(mask.attack_state)
	var b := DATA.beam
	# Bước ngang ngay sau lúc khoá hướng
	await _frames(int((b.charge_time - b.lock_time) * 60.0) + 3)
	await _walk(Vector3.RIGHT, 18)
	await _frames(int(b.fire_time * 60.0) + 10)
	_check(_player.health.current_health == hp, "bước ngang sau lúc khoá hướng: tia không trúng (lệch %.1f m)" % absf(_player.global_position.x))
	_cleanup()


func _t_wall() -> void:
	_reset_player(PLAYER_HOME)
	var wall := _box(PLAYER_HOME + Vector3(0, 1.5, -3.0), Vector3(4, 3, 0.4), Color(0.25, 0.22, 0.2))
	var mask := await _spawn(PLAYER_HOME + Vector3(0, 0, -7), null, true)
	var hp := _player.health.current_health
	var length := [0.0]
	mask.beam_fired.connect(func(from: Vector3, to: Vector3) -> void: length[0] = from.distance_to(to))
	mask.target = _player
	mask.state_machine.transition_to(mask.attack_state)
	await _frames(int((DATA.beam.charge_time + DATA.beam.fire_time) * 60.0) + 10)
	_check(length[0] > 0.0 and length[0] < 4.5, "tường chắn: tia dừng ở tường (dài %.2f m)" % length[0])
	_check(_player.health.current_health == hp, "player sau tường không trúng")
	wall.queue_free()
	_cleanup()


func _t_kill() -> void:
	_reset_player(PLAYER_HOME)
	var mask := await _spawn(PLAYER_HOME + Vector3(0, 0, -1.6), null, true)
	var died := [false]
	mask.died.connect(func(_e: Enemy) -> void: died[0] = true)
	# Đang tụ lực thì bị chém: huỷ chiêu
	mask.target = _player
	mask.state_machine.transition_to(mask.attack_state)
	await _frames(20)
	for i: int in range(14):
		if died[0]:
			break
		_reset_player(Vector3(mask.global_position.x, 0.0, mask.global_position.z + 1.4))
		await _frames(4)
		_aim_mouse_at(mask.global_position)
		await _tap(&"attack")
		await _frames(30)
	_check(died[0] and mask.is_dead(), "chém thật đủ 5 máu: chết")
	await _frames(20)
	_check(not mask.beam.is_firing() and not (mask.beam.get_node("Warn") as Node3D).visible, "chết: tia và vạch cảnh báo tắt")
	_cleanup()


func _t_extreme() -> void:
	var wide := _beam_copy()
	wide.beam.width = 6.0
	wide.beam.lock_time = wide.beam.charge_time
	await _fire_at_offset(wide, 2.5, true, "tia rộng 6 m: player lệch 2,5 m vẫn trúng")
	var thin := _beam_copy()
	thin.beam.width = 0.1
	thin.beam.lock_time = thin.beam.charge_time
	await _fire_at_offset(thin, 0.7, false, "tia hẹp 0,1 m: player lệch 0,7 m không trúng")
	var instant := _beam_copy()
	instant.beam.charge_time = 0.0
	await _fire_at_offset(instant, 0.0, true, "tụ lực 0 s: bắn ngay và trúng")
	var lock := _beam_copy()
	lock.beam.lock_time = 99.0
	await _fire_at_offset(lock, 0.0, true, "lock_time 99 s > charge_time: khoá từ đầu, vẫn bắn trúng")


## Khoá hướng vào player đứng ở PLAYER_HOME, rồi dời player lệch ngang offset m trước khi bắn
func _fire_at_offset(data: SoulMaskData, offset: float, expect_hit: bool, label: String) -> void:
	_reset_player(PLAYER_HOME)
	var mask := await _spawn(PLAYER_HOME + Vector3(0, 0, -7), data, true)
	var hp := _player.health.current_health
	mask.target = _player
	mask.state_machine.transition_to(mask.attack_state)
	await _frames(2)
	# Chỉ dời, không hồi máu: tụ lực 0 s thì tia có thể đã trúng ở khung này
	if not is_zero_approx(offset):
		_player.teleport(PLAYER_HOME + Vector3(offset, 0.05, 0), Vector3.FORWARD)
	await _frames(int((data.beam.charge_time + data.beam.fire_time) * 60.0) + 10)
	var lost := hp - _player.health.current_health
	_check((lost > 0) == expect_hit, "%s (mất %d máu)" % [label, lost])
	_cleanup()


# ---------- Hỗ trợ ----------

func _spawn(pos: Vector3, data: SoulMaskData = null, freeze_ai: bool = false) -> SoulMask:
	var mask := MASK_SCENE.instantiate() as SoulMask
	mask.data = data if data else _data_copy()
	mask.position = pos
	add_child(mask)
	_spawned.append(mask)
	await _frames(3)
	if freeze_ai:
		mask.data.detect_range = 0.0
		mask.sensor.radius = 0.0
		mask.forget_target()
		mask.state_machine.transition_to(&"Idle")
	return mask


func _data_copy() -> SoulMaskData:
	return DATA.duplicate() as SoulMaskData


func _beam_copy() -> SoulMaskData:
	var d := _data_copy()
	d.beam = d.beam.duplicate() as SoulBeamData
	return d


func _angle_around_player(mask: Node3D) -> float:
	var o := mask.global_position - _player.global_position
	return atan2(o.x, o.z)


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	for a: StringName in [&"attack", &"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _reset_player(pos: Vector3) -> void:
	_player.teleport(pos + Vector3.UP * 0.05, Vector3.FORWARD)
	_player.health.heal_full()


## Đi bộ thật theo hướng thế giới trong frames khung
func _walk(world_dir: Vector3, frames: int) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_axis(&"move_right", &"move_left", world_dir.dot(right))
	_axis(&"move_back", &"move_forward", -world_dir.dot(forward))
	await _frames(frames)
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _axis(positive: StringName, negative: StringName, value: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.35, 0.18, 0.12))
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


func _capture(file: String, focus: Vector3) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = focus + Vector3(3.5, 3.0, 4.5)
	cam.look_at(focus)
	cam.fov = 45.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/soul_mask"))
	get_viewport().get_texture().get_image().save_png("res://output/soul_mask/" + file)
	cam.queue_free()
	(_player.get_node("CameraRig/Camera3D") as Camera3D).make_current()
