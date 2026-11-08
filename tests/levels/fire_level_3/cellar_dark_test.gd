extends Node
## Kiểm tra hầm tối phòng 2, 3 (đo hành vi thật):
## 1. Ngoài hầm: nắng sáng bình thường.
## 2. Bước xuống hầm: nắng, đèn hắt tắt dần, ánh sáng môi trường giảm; không có quầng sáng tự có (dùng đuốc cầm tay).
## 3. Phun lửa vào đuốc tắt: đuốc sáng mãi (đèn có năng lượng, ngọn lửa hiện), lưu cờ.
## 4. Đi qua chỗ hai hộp vùng tối chồng nhau vẫn tối; ra khỏi hầm thì sáng lại như cũ.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/cellar_dark_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.ignite_chain_barrier")
	# Bài này đo ánh sáng: coi như cửa phòng 2 đã mở (cửa đo riêng ở room2_gate_test)
	GameState.set_flag(&"level_3.room_2_east_gate")
	GameState.set_flag(&"level_3.room_2_north_gate")
	GameState.set_flag(&"level_3.room_3_west_gate")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var sun: DirectionalLight3D = _level.get_node("FireLighting/SunLight")
	var env: Environment = (_level.get_node("FireLighting/Environment") as WorldEnvironment).environment
	var zone: DarkZone = _level.get_node("CellarDarkZone") as DarkZone
	var torch: IgnitableBrazier = _level.get_node("CellarTorches/CellarTorch01") as IgnitableBrazier
	var sun0: float = sun.light_energy
	var amb0: float = env.ambient_light_energy
	# 1. Ngoài hầm (chốt chặn)
	_player.teleport(Vector3(62, 4.4, 40))
	await _frames(70)
	_check(not zone.is_dark and is_equal_approx(sun.light_energy, sun0), "ngoài hầm sáng bình thường (nắng %.2f)" % sun.light_energy)
	await _capture("cellar_outside.png")
	# 2. Vào phòng 2
	_player.teleport(Vector3(26, 0.4, 32))
	await _frames(70)
	var carried: OmniLight3D = zone.get_node("CarriedLight")
	_check(zone.is_dark and sun.light_energy < 0.05 and env.ambient_light_energy < amb0 * 0.5, "vào hầm thì tối (nắng %.2f, môi trường %.2f → %.2f)" % [sun.light_energy, amb0, env.ambient_light_energy])
	# Hầm level 3 tắt quầng sáng tự có (use_carried_light = false): soi đường bằng đuốc cầm tay từ lửa trại phòng 5
	_check(not carried.visible and not zone.use_carried_light, "không có quầng sáng tự có (dùng đuốc cầm tay)")
	await _capture("cellar_dark.png")
	# 3. Thắp đuốc bằng Phun lửa thật
	_player.unlock_ability(FLAME_BREATH)
	_player.energy.set_current(_player.energy.get_max())
	_check(not torch.is_lit, "đuốc lúc đầu tắt")
	_player.teleport(torch.global_position + Vector3(0, 0.1, 1.6), Vector3.FORWARD)
	await _frames(10)
	if DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(torch.global_position + Vector3(0, 1.0, 0)))
	Input.action_press(_dir_action(Vector3.FORWARD))
	await _frames(2)
	Input.action_press(&"skill_fire")
	await _frames(2)
	Input.action_release(&"skill_fire")
	Input.action_release(_dir_action(Vector3.FORWARD))
	await _frames(60)
	var light: OmniLight3D = torch.get_node("Light")
	_check(torch.is_lit and light.light_energy > 1.0 and GameState.has_flag(torch.persistent_id), "Phun lửa thắp đuốc: sáng (năng lượng %.2f), lưu cờ" % light.light_energy)
	_player.teleport(Vector3(24, 0.4, 32))
	await _frames(20)
	await _capture("cellar_torch_lit.png")
	# 4. Đi bộ từ phòng 2 sang đường 2 → 3 (chỗ hai hộp chồng nhau) rồi ra khỏi hầm qua bậc thang
	_player.teleport(Vector3(22, 0.4, 26))
	await _frames(5)
	await _walk(Vector3(22, 0, 14), 6.0)
	_check(zone.is_dark, "đi qua chỗ hai hộp vùng tối chồng nhau vẫn tối")
	_player.teleport(Vector3(54, 0.4, 30))
	await _frames(5)
	await _walk(Vector3(54, 4, 44), 6.0)
	await _frames(70)
	_check(not zone.is_dark and is_equal_approx(sun.light_energy, sun0) and is_equal_approx(env.ambient_light_energy, amb0) and not carried.visible, "lên khỏi hầm thì sáng lại như cũ (nắng %.2f)" % sun.light_energy)
	print("CELLAR RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _walk(target: Vector3, timeout: float) -> void:
	var t: float = 0.0
	while t < timeout:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.8:
			break
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var d: Vector3 = Vector3(flat.x, 0.0, flat.y).normalized()
		_axis(&"move_right", &"move_left", d.dot(right))
		_axis(&"move_back", &"move_forward", -d.dot(forward))
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


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


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
