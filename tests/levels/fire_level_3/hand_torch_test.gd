extends Node
## Kiểm tra đuốc cầm tay và cắt tường hầm (input thật, headless):
## 1. Ngoài hầm: mái và tường cao phòng 2, 3 đều hiện (không nhìn thấy bên trong).
## 2. Lấy gậy ở bó gậy phòng 5 (bấm interact): cầm gậy chưa cháy.
## 3. Lại gần lửa trại bấm interact: đuốc cháy, đèn sáng.
## 4. Cầm đuốc vẫn đánh được (không bị khóa chiến đấu).
## 5. Vào phòng 2: mái và tường cao phòng 2 ẩn, phòng 3 vẫn kín; không có quầng sáng tự có, chỉ đèn đuốc.
## 6. Cầm đuốc đi chạm đuốc tường tắt: đuốc tường bắt lửa.
## 7. Ra khỏi phòng 2: mái phòng 2 hiện lại.
## 8. Đuốc hết giờ (burn_time rút ngắn): tắt, châm lại ở lửa trại được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/hand_torch_test.tscn (-- --capture để chụp ảnh)

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
	GameState.set_flag(&"level_3.ignite_chain_barrier")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var cover: Node = _level.get_node("Rooms/CellarCover")
	var roof2: Node3D = cover.get_node("Room02/Roof")
	var walls2: Node3D = cover.get_node("Room02/TallWalls")
	var roof3: Node3D = cover.get_node("Room03/Roof")
	var zone: DarkZone = _level.get_node("CellarDarkZone") as DarkZone
	var campfire: Node3D = _level.get_node("Room5Campfire")
	var bundle: Node3D = _level.get_node("Room5StickBundle")
	# 1. Ngoài hầm
	_player.teleport(Vector3(62, 4.4, 40))
	await _frames(20)
	_check(roof2.visible and walls2.visible and roof3.visible, "ngoài hầm: mái và tường cao phòng 2, 3 đều hiện")
	await _capture("cellar_roof_outside.png")
	# Trang bị kiếm để đo được việc đánh (save mới chưa có vũ khí)
	_player.equip_weapon(load("res://resources/combat/weapons/sword.tres") as WeaponData)
	_player.energy.set_current(_player.energy.get_max())
	await _frames(5)
	# Đối chứng: chưa cầm gậy bấm attack thì vào state nào (save mới có thể chưa có vũ khí)
	await _press(&"attack")
	await _frames(4)
	var base_state: String = String(_player.state_machine.current_state.name)
	print("  đối chứng attack khi chưa cầm gậy: state %s" % base_state)
	await _frames(60)
	# 2. Lấy gậy
	_player.teleport(bundle.global_position + Vector3(0, 0.1, 0.9), Vector3.FORWARD)
	await _frames(10)
	await _press(&"interact")
	await _frames(5)
	var torch: HandTorch = HandTorch.find_on(_player)
	_check(torch != null and not torch.is_lit, "bấm interact ở bó gậy: cầm gậy chưa cháy")
	if torch == null:
		_finish()
		return
	# 3a. Lửa trại lúc đầu tắt: chưa châm được
	var fire: Campfire = campfire as Campfire
	_check(not fire.is_lit and not fire.get_node("Light").visible, "lửa trại lúc đầu tắt")
	_player.teleport(campfire.global_position + Vector3(1.8, 0.1, 0.0), Vector3.LEFT)
	await _frames(10)
	await _press(&"interact")
	await _frames(5)
	_check(not torch.is_lit, "lửa trại tắt: interact không châm được đuốc")
	# 3b. Phun lửa (đòn lửa) trúng thì lửa trại bùng cháy
	fire.get_node("BurnableComponent").ignite()
	await _frames(40)
	_check(fire.is_lit and fire.get_node("Light").visible, "trúng lửa: lửa trại cháy")
	await _capture("campfire_lit.png")
	# 3. Châm ở lửa trại
	_player.teleport(campfire.global_position + Vector3(1.8, 0.1, 0.0), Vector3.LEFT)
	await _frames(10)
	await _press(&"interact")
	await _frames(5)
	var light: OmniLight3D = torch.get_node("Light")
	_check(torch.is_lit and light.visible and light.light_energy > 1.0, "lại gần lửa trại bấm interact: đuốc cháy (còn %.0f s)" % torch.time_left())
	await _capture("hand_torch_lit.png")
	# 4. Vẫn đánh được
	_player.teleport(Vector3(62, 4.4, 40))
	_player.energy.set_current(_player.energy.get_max())
	await _frames(10)
	await _press(&"attack")
	await _frames(4)
	var state: String = String(_player.state_machine.current_state.name)
	_check(base_state != "Idle" and state == base_state and not _player.combat_locked(), "cầm đuốc vẫn đánh được như lúc không cầm (%s / %s)" % [state, base_state])
	await _frames(60)
	# 5. Vào phòng 2
	_player.teleport(Vector3(22, 0.4, 34))
	await _frames(70)
	var carried: OmniLight3D = zone.get_node("CarriedLight")
	_check(not roof2.visible and not walls2.visible and roof3.visible, "trong phòng 2: mái + tường cao phòng 2 ẩn, phòng 3 vẫn kín")
	_check(zone.is_dark and not carried.visible and torch.is_lit, "hầm tối, không có quầng sáng tự có, chỉ còn đuốc")
	await _capture("hand_torch_cellar.png")
	# 6. Chạm đuốc tường bằng đuốc cầm tay
	var wall_torch: IgnitableBrazier = _level.get_node("CellarTorches/CellarTorch03") as IgnitableBrazier
	_check(not wall_torch.is_lit, "đuốc tường lúc đầu tắt")
	_player.teleport(wall_torch.global_position + Vector3(2.5, 0.1, 0.0), Vector3.LEFT)
	await _frames(5)
	await _walk(wall_torch.global_position + Vector3(0.6, 0, 0), 2.0)
	await _frames(30)
	_check(wall_torch.is_lit, "cầm đuốc chạm đuốc tường: đuốc tường bắt lửa")
	await _capture("hand_torch_lit_wall.png")
	# 7. Ra khỏi phòng 2
	_player.teleport(Vector3(62, 4.4, 40))
	await _frames(20)
	_check(roof2.visible and walls2.visible, "ra khỏi hầm: mái phòng 2 hiện lại")
	# 8. Hết giờ rồi châm lại
	torch.burn_time = 1.0
	torch.light_up()
	await _frames(80)
	_check(not torch.is_lit and not light.visible, "hết giờ cháy thì đuốc tắt")
	_player.teleport(campfire.global_position + Vector3(1.8, 0.1, 0.0), Vector3.LEFT)
	await _frames(10)
	await _press(&"interact")
	await _frames(5)
	_check(torch.is_lit, "về lửa trại châm lại được")
	_finish()


func _finish() -> void:
	print("HAND TORCH RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _walk(target: Vector3, timeout: float) -> void:
	var t: float = 0.0
	while t < timeout:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.5:
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


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


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
