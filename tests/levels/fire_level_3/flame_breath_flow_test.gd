extends Node
## Kiểm tra luồng Phun lửa của level 3 bằng input thật (headless):
## 1. Rào gỗ ở chân bậc thang đường bẫy địa nhiệt (lối lên phòng 3 và 2) chặn đường lúc chưa đốt.
## 2. Chưa có Phun lửa: bấm skill_fire trước rào không làm rào cháy.
## 3. Nhặt sách ở phòng 4 (bấm interact) → có kỹ năng flame_breath.
## 4. Phun lửa vào rào → rào cháy, cháy hết thì tan, tắt va chạm, đi xuống bậc thang vào hầm được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/flame_breath_flow_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	# Lồng sinh quái phòng 4 có test riêng (spawner_cage_test): coi như đã dọn để sách hiện sẵn
	GameState.set_flag(&"level_3.room4_cage_cleared")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var barrier2: BurnableBarrier = _level.get_node("BurnableBarriers/IgniteChainBarrier") as BurnableBarrier
	var book: Node3D = _level.get_node("Pickups/Room4BookReveal/FlameBreathBook") as Node3D
	_check(not _player.has_ability(&"flame_breath"), "lúc đầu chưa có Phun lửa")
	# 1. Đi về phía bắc đâm vào rào
	_player.teleport(Vector3(54, 4.4, 44), Vector3.FORWARD)
	await _frames(10)
	await _hold(Vector3.FORWARD, 1.5)
	_check(_player.global_position.z > barrier2.global_position.z + 0.3, "rào chặn đường (dừng ở z = %.2f)" % _player.global_position.z)
	# 2. Bấm phun lửa khi chưa có kỹ năng
	_player.teleport(Vector3(54, 4.4, 42.3), Vector3.FORWARD)
	await _frames(10)
	await _press(&"skill_fire")
	await _frames(40)
	_check(not barrier2.get_node("BurnableComponent").is_burning(), "chưa có kỹ năng thì không đốt được rào")
	await _capture("flame_barrier_closed.png")
	if "--capture" in OS.get_cmdline_user_args():
		# Cận cảnh rào (camera tạm nhìn chéo từ đông nam) để duyệt model
		var game_cam: Camera3D = get_viewport().get_camera_3d()
		var cam: Camera3D = Camera3D.new()
		add_child(cam)
		cam.fov = 40.0
		cam.look_at_from_position(barrier2.global_position + Vector3(4.0, 3.5, 5.5), barrier2.global_position + Vector3(0, 1.4, 0))
		cam.current = true
		await _frames(3)
		await _capture("flame_barrier_closeup.png")
		cam.queue_free()
		game_cam.current = true
	# 3. Nhặt sách ở phòng 4
	_player.teleport(book.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	await _frames(15)
	await _capture("flame_book_room_4.png")
	await _press(&"interact")
	var t: float = 0.0
	while not _player.has_ability(&"flame_breath") and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(_player.has_ability(&"flame_breath"), "nhặt sách phòng 4 → có Phun lửa (%.1f s)" % t)
	# Bảng trình diễn nhận kỹ năng giữ khóa điều khiển tới khi người chơi đóng: đóng bằng API public close_reveal()
	var acquire: Node = book.get_node_or_null("AbilityAcquireVfx") if is_instance_valid(book) else null
	t = 0.0
	while not _player.controls_enabled and t < 10.0:
		if is_instance_valid(acquire):
			acquire.call(&"close_reveal")
		await _frames(10)
		t += 10.0 / 60.0
	_check(_player.controls_enabled, "đóng bảng nhận kỹ năng thì điều khiển lại được")
	# 4. Đốt rào rồi đi xuống hầm
	await _burn(barrier2, Vector3(54, 4.4, 42.3), Vector3.FORWARD)
	_player.teleport(Vector3(54, 4.4, 43), Vector3.FORWARD)
	await _frames(10)
	await _hold(Vector3.FORWARD, 2.0)
	_check(_player.global_position.z < barrier2.global_position.z - 2.0 and _player.global_position.y < 3.0, "rào tan rồi đi xuống hầm (z = %.2f, y = %.2f)" % [_player.global_position.z, _player.global_position.y])
	print("FLAME FLOW RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _burn(barrier: BurnableBarrier, stand: Vector3, facing: Vector3) -> void:
	_player.teleport(stand, facing)
	await _frames(10)
	_player.energy.set_current(_player.energy.get_max())
	# Chạy có cửa sổ (để chụp ảnh) thì phun lửa nhắm theo chuột: đặt chuột lên rào
	if DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(barrier.global_position + Vector3(0, 1.0, 0)))
		await _frames(2)
	# Giữ hướng về phía rào để state phun lửa (headless không có chuột) quay đúng hướng
	Input.action_press(_dir_action(facing))
	await _frames(2)
	await _press(&"skill_fire")
	Input.action_release(_dir_action(facing))
	var t: float = 0.0
	while not barrier.get_node("BurnableComponent").is_burning() and t < 1.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(barrier.get_node("BurnableComponent").is_burning(), "%s bắt lửa" % barrier.name)
	await _frames(30)
	await _capture("flame_barrier_burning_%s.png" % String(barrier.name).to_snake_case())
	t = 0.0
	while not barrier.is_burned and t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _frames(45)
	var shape: CollisionShape3D = barrier.get_node("CollisionShape3D")
	_check(barrier.is_burned and shape.disabled and not barrier.visible, "%s cháy rụi sau %.1f s, tắt va chạm, ẩn" % [barrier.name, t])


## Hướng thế giới → action theo camera chéo 45° là phức tạp; dùng hướng gần nhất của input thật
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


func _hold(dir: Vector3, seconds: float) -> void:
	# Đi thẳng theo hướng thế giới dir bằng hai trục input quy theo camera
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var x: float = dir.dot(right)
	var y: float = -dir.dot(forward)
	if x > 0.05: Input.action_press(&"move_right", x)
	elif x < -0.05: Input.action_press(&"move_left", -x)
	if y > 0.05: Input.action_press(&"move_back", y)
	elif y < -0.05: Input.action_press(&"move_forward", -y)
	await _frames(int(seconds * 60.0))
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
